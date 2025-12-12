import Foundation
@testable import HoAh

// MARK: - AI Enhancement Test Helper
// 封装对 HoAh AIService 的测试调用

/// AI Enhancement 测试辅助类
/// 通过 HoAh 现有的服务类进行测试
@MainActor
class AIEnhancementTestHelper {
    private let config: TestConfiguration
    
    init(config: TestConfiguration) {
        self.config = config
    }
    
    /// 测试指定提供商和模型的文本增强功能
    /// 直接复用 HoAh 的请求构建和响应解析逻辑
    func testEnhancement(
        provider: AIProvider,
        model: String,
        text: String,
        systemPrompt: String
    ) async throws -> EnhancementResult {
        let startTime = Date()
        
        // 获取对应的 API Key
        let apiKey = try getAPIKey(for: provider)
        
        // 构建请求 - 复用 HoAh 的请求格式
        let enhancedText = try await performRequest(
            provider: provider,
            model: model,
            apiKey: apiKey,
            systemMessage: systemPrompt,
            userMessage: text
        )
        
        let duration = Date().timeIntervalSince(startTime)
        
        return EnhancementResult(
            enhancedText: enhancedText,
            responseTime: duration,
            provider: provider,
            model: model
        )
    }
    
    private func getAPIKey(for provider: AIProvider) throws -> String {
        switch provider {
        case .openAI:
            guard let key = config.openAIKey, !key.isEmpty else {
                throw TestError.missingAPIKey(provider: provider.rawValue)
            }
            return key
        case .gemini:
            guard let key = config.geminiKey, !key.isEmpty else {
                throw TestError.missingAPIKey(provider: provider.rawValue)
            }
            return key
        case .groq:
            guard let key = config.groqKey, !key.isEmpty else {
                throw TestError.missingAPIKey(provider: provider.rawValue)
            }
            return key
        case .cerebras:
            guard let key = config.cerebrasKey, !key.isEmpty else {
                throw TestError.missingAPIKey(provider: provider.rawValue)
            }
            return key
        case .awsBedrock:
            guard let key = config.awsBedrockKey, !key.isEmpty else {
                throw TestError.missingAPIKey(provider: provider.rawValue)
            }
            return key
        case .anthropic, .openRouter:
            throw TestError.providerNotSupported(provider: provider.rawValue)
        }
    }
    
    /// 执行请求 - 复用 HoAh 的请求逻辑
    private func performRequest(
        provider: AIProvider,
        model: String,
        apiKey: String,
        systemMessage: String,
        userMessage: String
    ) async throws -> String {
        let formattedText = "\n<TRANSCRIPT>\n\(userMessage)\n</TRANSCRIPT>"
        
        switch provider {
        case .awsBedrock:
            return try await makeBedrockRequest(
                model: model,
                apiKey: apiKey,
                region: config.awsBedrockRegion,
                systemMessage: systemMessage,
                userMessage: formattedText
            )
        default:
            return try await makeOpenAICompatibleRequest(
                provider: provider,
                model: model,
                apiKey: apiKey,
                systemMessage: systemMessage,
                userMessage: formattedText
            )
        }
    }
    
    /// OpenAI 模型是否支持 temperature 参数
    /// gpt-5-mini 和 gpt-5-nano 不支持自定义 temperature
    private func supportsTemperature(model: String) -> Bool {
        let noTemperatureModels = ["gpt-5-mini", "gpt-5-nano"]
        return !noTemperatureModels.contains(model)
    }
    
    /// OpenAI 兼容 API 请求 (OpenAI, Gemini, Groq, Cerebras)
    private func makeOpenAICompatibleRequest(
        provider: AIProvider,
        model: String,
        apiKey: String,
        systemMessage: String,
        userMessage: String
    ) async throws -> String {
        let url = URL(string: provider.baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60
        
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemMessage],
            ["role": "user", "content": userMessage]
        ]
        
        var requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": false
        ]
        
        // 只有支持 temperature 的模型才添加该参数
        if supportsTemperature(model: model) {
            requestBody["temperature"] = 0.3
        }
        
        // Add reasoning_effort parameter if the model supports it
        if let reasoningEffort = ReasoningConfig.getReasoningParameter(for: model) {
            requestBody["reasoning_effort"] = reasoningEffort
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TestError.invalidResponse(details: "Not an HTTP response")
        }
        
        if httpResponse.statusCode == 200 {
            guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = jsonResponse["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let enhancedText = message["content"] as? String else {
                throw TestError.invalidResponse(details: "Could not parse response")
            }
            return enhancedText.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if httpResponse.statusCode == 429 {
            throw TestError.rateLimitExceeded(provider: provider.rawValue)
        } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw TestError.authenticationFailed(provider: provider.rawValue, statusCode: httpResponse.statusCode)
        } else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TestError.requestFailed(provider: provider.rawValue, statusCode: httpResponse.statusCode, message: errorString)
        }
    }
    
    /// AWS Bedrock 请求
    private func makeBedrockRequest(
        model: String,
        apiKey: String,
        region: String,
        systemMessage: String,
        userMessage: String
    ) async throws -> String {
        let prompt = "\(systemMessage)\n\(userMessage)"
        
        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": [
                    ["text": prompt]
                ]
            ]
        ]
        
        let payload: [String: Any] = [
            "messages": messages,
            "inferenceConfig": [
                "maxTokens": 1024,
                "temperature": 0.3
            ]
        ]
        
        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        
        let host = "bedrock-runtime.\(region).amazonaws.com"
        guard let url = URL(string: "https://\(host)/model/\(model)/converse") else {
            throw TestError.invalidResponse(details: "Invalid Bedrock URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payloadData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TestError.invalidResponse(details: "Not an HTTP response")
        }
        
        if httpResponse.statusCode == 200 {
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let output = json["output"] as? [String: Any],
                  let message = output["message"] as? [String: Any],
                  let content = message["content"] as? [[String: Any]] else {
                throw TestError.invalidResponse(details: "Could not parse Bedrock response")
            }
            
            // 提取文本内容
            for item in content {
                if let text = item["text"] as? String {
                    return text.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            throw TestError.invalidResponse(details: "No text content in Bedrock response")
        } else if httpResponse.statusCode == 429 {
            throw TestError.rateLimitExceeded(provider: "AWS Bedrock")
        } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw TestError.authenticationFailed(provider: "AWS Bedrock", statusCode: httpResponse.statusCode)
        } else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TestError.requestFailed(provider: "AWS Bedrock", statusCode: httpResponse.statusCode, message: errorString)
        }
    }
}

/// 增强结果
struct EnhancementResult {
    let enhancedText: String
    let responseTime: TimeInterval
    let provider: AIProvider
    let model: String
}

/// 测试错误
enum TestError: Error, LocalizedError {
    case missingAPIKey(provider: String)
    case providerNotSupported(provider: String)
    case authenticationFailed(provider: String, statusCode: Int)
    case rateLimitExceeded(provider: String)
    case requestFailed(provider: String, statusCode: Int, message: String)
    case invalidResponse(details: String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "Missing API key for \(provider)"
        case .providerNotSupported(let provider):
            return "Provider \(provider) is not supported for testing"
        case .authenticationFailed(let provider, let statusCode):
            return "Authentication failed for \(provider) (HTTP \(statusCode))"
        case .rateLimitExceeded(let provider):
            return "Rate limit exceeded for \(provider)"
        case .requestFailed(let provider, let statusCode, let message):
            return "Request failed for \(provider) (HTTP \(statusCode)): \(message)"
        case .invalidResponse(let details):
            return "Invalid response: \(details)"
        }
    }
}
