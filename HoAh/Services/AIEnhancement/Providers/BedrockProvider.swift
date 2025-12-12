import Foundation

/// Handles AWS Bedrock requests (Bearer token or SigV4)
enum BedrockProvider {
    static func performRequest(
        systemMessage: String,
        userMessage: String,
        session: AIEnhancementService.ActiveSession,
        fallbackRegion: String,
        baseTimeout: TimeInterval
    ) async throws -> String {
        // Combine system message and user message into a single prompt
        let prompt = "\(systemMessage)\n\(userMessage)"

        // Build messages array according to Bedrock Converse API format
        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": [
                    ["text": prompt]
                ]
            ]
        ]

        // Build payload - note: modelId is NOT included in the payload body
        let payload: [String: Any] = [
            "messages": messages,
            "inferenceConfig": [
                "maxTokens": 1024,
                "temperature": 0.3
            ]
        ]

        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        var region = session.region ?? fallbackRegion
        switch session.auth {
        case .bedrockSigV4(_, let regionOverride):
            if !regionOverride.isEmpty {
                region = regionOverride
            }
        case .bedrockBearer(_, let regionOverride):
            if !regionOverride.isEmpty {
                region = regionOverride
            }
        default:
            break
        }
        let modelId = session.model
        guard !modelId.isEmpty else {
            throw EnhancementError.notConfigured
        }

        // Determine authentication method and build request
        guard !region.isEmpty else { throw EnhancementError.notConfigured }
        let host = "bedrock-runtime.\(region).amazonaws.com"
        guard let url = URL(string: "https://\(host)/model/\(modelId)/converse") else {
            throw EnhancementError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payloadData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = baseTimeout

        switch session.auth {
        case .bedrockSigV4(let credentials, _):
            request = try AWSSigV4Signer.sign(
                request: request,
                credentials: credentials,
                region: region,
                service: "bedrock-runtime"
            )
        case .bedrockBearer(let token, _):
            guard !token.isEmpty else { throw EnhancementError.notConfigured }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case .bearer(let token):
            guard !token.isEmpty else { throw EnhancementError.notConfigured }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        default:
            throw EnhancementError.notConfigured
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EnhancementError.invalidResponse
            }

            if httpResponse.statusCode == 200 {
                if let result = parseBedrockResponse(data: data) {
                    return AIEnhancementOutputFilter.filter(result.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    throw EnhancementError.enhancementFailed
                }
            } else if httpResponse.statusCode == 429 {
                throw EnhancementError.rateLimitExceeded
            } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw EnhancementError.apiKeyInvalid
            } else if (500...599).contains(httpResponse.statusCode) {
                throw EnhancementError.serverError
            } else {
                let errorString = String(data: data, encoding: .utf8) ?? "Could not decode error response."
                throw EnhancementError.customError("HTTP \(httpResponse.statusCode): \(errorString)")
            }
        } catch let error as EnhancementError {
            throw error
        } catch {
            throw EnhancementError.customError(error.localizedDescription)
        }
    }

    private static func parseBedrockResponse(data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // If JSON parsing fails, try returning as string
            return String(data: data, encoding: .utf8)
        }

        // Parse Bedrock Converse API response format:
        // {"output": {"message": {"content": [{"text": "..."}], "role": "assistant"}}, ...}
        // GPT-OSS format: {"content": [{"reasoningContent": {...}}, {"text": "final answer"}]}
        if let output = json["output"] as? [String: Any],
           let message = output["message"] as? [String: Any],
           let content = message["content"] as? [[String: Any]] {

            // First pass: look for direct "text" field (final answer, not reasoning)
            for contentItem in content {
                if let text = contentItem["text"] as? String {
                    return text
                }
            }

            // Second pass: if no direct text found, check for reasoning content
            // (fallback for models that only return reasoning)
            for contentItem in content {
                if let reasoningContent = contentItem["reasoningContent"] as? [String: Any],
                   let reasoningText = reasoningContent["reasoningText"] as? [String: Any],
                   let text = reasoningText["text"] as? String {
                    return text
                }
            }
        }

        // Fallback: try other possible response formats
        if let text = json["output_text"] as? String { return text }
        if let text = json["outputText"] as? String { return text }
        if let text = json["completion"] as? String { return text }
        if let text = json["generated_text"] as? String { return text }

        if let outputs = json["outputs"] as? [[String: Any]] {
            if let first = outputs.first {
                if let text = first["text"] as? String { return text }
                if let text = first["output_text"] as? String { return text }
            }
        }

        return nil
    }
}
