import Foundation

/// Shared validation logic for AI configurations
/// Used by both ConfigurationEditSheet and ConfigurationValidationService
enum AIConfigurationValidator {
    
    // MARK: - Validation Result
    
    struct ValidationResult {
        let success: Bool
        let errorMessage: String?
        let httpStatusCode: Int?
        
        static func success() -> ValidationResult {
            ValidationResult(success: true, errorMessage: nil, httpStatusCode: 200)
        }
        
        static func failure(_ message: String, statusCode: Int? = nil) -> ValidationResult {
            ValidationResult(success: false, errorMessage: message, httpStatusCode: statusCode)
        }
    }
    
    // MARK: - OpenAI Compatible Providers
    
    /// Verifies API key for OpenAI-compatible providers (OpenAI, Gemini, Groq, Cerebras, OpenRouter)
    static func verifyOpenAICompatibleKey(
        apiKey: String,
        provider: AIProvider,
        model: String,
        timeout: TimeInterval = 30
    ) async -> ValidationResult {
        guard let url = URL(string: provider.baseURL) else {
            return .failure("Invalid API URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeout
        
        // OpenAI gpt-5.x models use max_completion_tokens instead of max_tokens
        let useMaxCompletionTokens = provider == .openAI && model.hasPrefix("gpt-5")
        // Use a small but realistic cap; gpt-5.1 needs more than 5 tokens even for a trivial reply
        let maxTokens = 64
        var body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": "test"]]
        ]
        if useMaxCompletionTokens {
            body["max_completion_tokens"] = maxTokens
        } else {
            body["max_tokens"] = maxTokens
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure("Invalid response")
            }
            
            if httpResponse.statusCode == 200 {
                return .success()
            } else {
                let errorMsg = extractErrorMessage(from: data, statusCode: httpResponse.statusCode)
                return .failure(errorMsg, statusCode: httpResponse.statusCode)
            }
        } catch let error as URLError where error.code == .timedOut {
            return .failure("Connection timed out", statusCode: nil)
        } catch let error as URLError where error.code == .cancelled {
            return .failure("Request cancelled", statusCode: nil)
        } catch {
            return .failure(error.localizedDescription)
        }
    }
    
    // MARK: - Anthropic
    
    /// Verifies API key for Anthropic
    static func verifyAnthropicKey(
        apiKey: String,
        model: String,
        timeout: TimeInterval = 30
    ) async -> ValidationResult {
        guard let url = URL(string: AIProvider.anthropic.baseURL) else {
            return .failure("Invalid API URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = timeout
        
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 5,
            "messages": [["role": "user", "content": "test"]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure("Invalid response")
            }
            
            if httpResponse.statusCode == 200 {
                return .success()
            } else {
                let errorMsg = extractAnthropicErrorMessage(from: data, statusCode: httpResponse.statusCode)
                return .failure(errorMsg, statusCode: httpResponse.statusCode)
            }
        } catch let error as URLError where error.code == .timedOut {
            return .failure("Connection timed out", statusCode: nil)
        } catch let error as URLError where error.code == .cancelled {
            return .failure("Request cancelled", statusCode: nil)
        } catch {
            return .failure(error.localizedDescription)
        }
    }
    
    // MARK: - AWS Bedrock
    
    /// Verifies AWS credentials using SigV4 signed request to ListFoundationModels API
    static func verifyAWSCredentials(
        credentials: AWSCredentials,
        region: String,
        modelId: String? = nil,
        timeout: TimeInterval = 15
    ) async -> ValidationResult {
        // Prefer a tiny Converse call to avoid requiring ListFoundationModels permission
        if let modelId = modelId, !modelId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let host = "bedrock-runtime.\(region).amazonaws.com"
            let path = "/model/\(modelId)/converse"
            guard let url = URL(string: "https://\(host)\(path)") else {
                return .failure("Invalid Bedrock URL")
            }
            
            let payload: [String: Any] = [
                "messages": [
                    [
                        "role": "user",
                        "content": [["text": "Hello"]]
                    ]
                ],
                "inferenceConfig": [
                    "maxTokens": 16,
                    "temperature": 0.3
                ]
            ]
            
            guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
                return .failure("Failed to create test request.")
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = timeout
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            do {
                request = try AWSSigV4Signer.sign(
                    request: request,
                    credentials: credentials,
                    region: region,
                    service: "bedrock"
                )
            } catch {
                return .failure("Failed to sign request: \(error.localizedDescription)")
            }
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    return .failure("Invalid response from Bedrock")
                }
                
                if httpResponse.statusCode == 200 {
                    return .success()
                } else if httpResponse.statusCode == 401 {
                    return .failure("Invalid AWS credentials. Please check your Access Key and Secret Key.", statusCode: 401)
                } else if httpResponse.statusCode == 403 {
                    let errorMsg = extractAWSErrorMessage(from: data) ?? "Access denied. Ensure your IAM policy allows invoking the target model."
                    return .failure(errorMsg, statusCode: 403)
                } else {
                    let errorMsg = extractAWSErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
                    return .failure(errorMsg, statusCode: httpResponse.statusCode)
                }
            } catch let error as URLError where error.code == .timedOut {
                return .failure("Connection timed out", statusCode: nil)
            } catch let error as URLError where error.code == .cancelled {
                return .failure("Request cancelled", statusCode: nil)
            } catch {
                return .failure(error.localizedDescription)
            }
        }
        
        // Fallback to ListFoundationModels if no modelId provided
        let host = "bedrock.\(region).amazonaws.com"
        guard let url = URL(string: "https://\(host)/foundation-models?byOutputModality=TEXT&maxResults=1") else {
            return .failure("Invalid Bedrock URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        
        // Sign the request with SigV4
        do {
            request = try AWSSigV4Signer.sign(
                request: request,
                credentials: credentials,
                region: region,
                service: "bedrock"
            )
        } catch {
            return .failure("Failed to sign request: \(error.localizedDescription)")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure("Invalid response from Bedrock")
            }
            
            switch httpResponse.statusCode {
            case 200:
                return .success()
            case 401:
                return .failure("Invalid AWS credentials. Please check your Access Key and Secret Key.", statusCode: 401)
            case 403:
                let errorMsg = extractAWSErrorMessage(from: data) ?? "Access denied. Ensure your IAM policy includes bedrock:ListFoundationModels permission."
                return .failure(errorMsg, statusCode: 403)
            default:
                let errorMsg = extractAWSErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
                return .failure(errorMsg, statusCode: httpResponse.statusCode)
            }
        } catch let error as URLError where error.code == .timedOut {
            return .failure("Connection timed out", statusCode: nil)
        } catch let error as URLError where error.code == .cancelled {
            return .failure("Request cancelled", statusCode: nil)
        } catch {
            return .failure(error.localizedDescription)
        }
    }
    
    /// Verifies AWS Bedrock Bearer Token
    static func verifyBedrockBearerToken(
        apiKey: String,
        region: String,
        modelId: String,
        timeout: TimeInterval = 30
    ) async -> ValidationResult {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !modelId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure("Please provide API key, region, and model.")
        }
        
        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": [["text": "Hello"]]
            ]
        ]
        
        let payload: [String: Any] = [
            "messages": messages,
            "inferenceConfig": [
                "maxTokens": 10,
                "temperature": 0.3
            ]
        ]
        
        guard let payloadData = try? JSONSerialization.data(withJSONObject: payload) else {
            return .failure("Failed to create test request.")
        }
        
        let host = "bedrock-runtime.\(region).amazonaws.com"
        guard let url = URL(string: "https://\(host)/model/\(modelId)/converse") else {
            return .failure("Invalid endpoint URL.")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payloadData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeout
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure("Invalid response")
            }
            
            if httpResponse.statusCode == 200 {
                return .success()
            } else {
                let errorMsg = extractAWSErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
                return .failure(errorMsg, statusCode: httpResponse.statusCode)
            }
        } catch let error as URLError where error.code == .timedOut {
            return .failure("Connection timed out", statusCode: nil)
        } catch let error as URLError where error.code == .cancelled {
            return .failure("Request cancelled", statusCode: nil)
        } catch {
            return .failure(error.localizedDescription)
        }
    }
    
    // MARK: - Helper Methods
    
    private static func extractErrorMessage(from data: Data, statusCode: Int) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorObj = json["error"] as? [String: Any],
           let message = errorObj["message"] as? String {
            return message
        }
        if let responseStr = String(data: data, encoding: .utf8) {
            return "HTTP \(statusCode): \(String(responseStr.prefix(200)))"
        }
        return "HTTP \(statusCode)"
    }
    
    private static func extractAnthropicErrorMessage(from data: Data, statusCode: Int) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorObj = json["error"] as? [String: Any],
           let message = errorObj["message"] as? String {
            return message
        }
        return "HTTP \(statusCode)"
    }
    
    private static func extractAWSErrorMessage(from data: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = json["message"] as? String {
            return message
        }
        return nil
    }
}
