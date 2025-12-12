import Foundation

/// Handles Anthropic chat requests (x-api-key + anthropic-version headers)
enum AnthropicProvider {
    static func performRequest(
        systemMessage: String,
        formattedText: String,
        session: AIEnhancementService.ActiveSession,
        baseTimeout: TimeInterval
    ) async throws -> String {
        guard case .anthropic(let apiKey) = session.auth, !apiKey.isEmpty else {
            throw EnhancementError.notConfigured
        }

        let requestBody: [String: Any] = [
            "model": session.model,
            "max_tokens": 8192,
            "system": systemMessage,
            "messages": [
                ["role": "user", "content": formattedText]
            ]
        ]

        var request = URLRequest(url: URL(string: session.provider.baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = baseTimeout
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw EnhancementError.invalidResponse
            }

            if httpResponse.statusCode == 200 {
                guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let content = jsonResponse["content"] as? [[String: Any]],
                      let firstContent = content.first,
                      let enhancedText = firstContent["text"] as? String else {
                    throw EnhancementError.enhancementFailed
                }

                let filteredText = AIEnhancementOutputFilter.filter(enhancedText.trimmingCharacters(in: .whitespacesAndNewlines))
                return filteredText
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
        } catch let error as URLError {
            throw error
        } catch {
            throw EnhancementError.customError(error.localizedDescription)
        }
    }
}
