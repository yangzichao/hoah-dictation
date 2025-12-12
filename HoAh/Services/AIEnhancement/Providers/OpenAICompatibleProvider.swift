import Foundation

/// Handles OpenAI-compatible chat completions (OpenAI, Groq, Gemini-compatible, OpenRouter, Cerebras)
enum OpenAICompatibleProvider {
    static func performRequest(
        systemMessage: String,
        formattedText: String,
        session: AIEnhancementService.ActiveSession,
        baseTimeout: TimeInterval
    ) async throws -> String {
        guard case .bearer(let apiKey) = session.auth, !apiKey.isEmpty else {
            throw EnhancementError.notConfigured
        }

        let url = URL(string: session.provider.baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = baseTimeout

        let messages: [[String: Any]] = [
            ["role": "system", "content": systemMessage],
            ["role": "user", "content": formattedText]
        ]

        var requestBody: [String: Any] = [
            "model": session.model,
            "messages": messages,
            "stream": false
        ]

        // gpt-5-mini 和 gpt-5-nano 不支持 temperature 参数
        let noTemperatureModels = ["gpt-5-mini", "gpt-5-nano"]
        if !noTemperatureModels.contains(session.model) {
            requestBody["temperature"] = 0.3
        }

        if let reasoningEffort = ReasoningConfig.getReasoningParameter(for: session.model) {
            requestBody["reasoning_effort"] = reasoningEffort
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw EnhancementError.invalidResponse
            }

            if httpResponse.statusCode == 200 {
                guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = jsonResponse["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let enhancedText = message["content"] as? String else {
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
