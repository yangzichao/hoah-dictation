import Testing
import Foundation
@testable import HoAh

// MARK: - Gemini Integration Tests
// 测试 HoAh 通过 Gemini API 的 AI Enhancement 功能

@Suite("Gemini Integration Tests", .serialized)
struct GeminiIntegrationTests {
    let config = TestConfiguration.load()
    
    /// Gemini 可用模型列表
    /// 注意: Gemini API 有严格的 rate limit，免费 tier 可能只能测试 flash-lite 模型
    static let availableModels = [
        "gemini-2.5-flash-lite",  // 最稳定的模型，免费 tier 可用
        "gemini-2.0-flash-001",   // 需要更高 quota
        "gemini-2.5-pro",         // 需要更高 quota
        "gemini-3-pro-preview"    // 需要更高 quota
    ]
    
    /// Rate limit 延迟时间 (秒)
    static let rateLimitDelay: UInt64 = 15_000_000_000 // 15 秒
    
    // MARK: - Model Tests
    // 注意: 整个 Suite 串行执行以避免 rate limiting
    // Gemini API 有严格的 rate limit，免费 tier 可能只能测试 flash-lite 模型
    
    @Test("Test gemini-2.5-flash-lite text enhancement (primary)")
    func testGemini25FlashLiteEnhancement() async throws {
        try await testModelEnhancementWithRetry(model: "gemini-2.5-flash-lite")
    }
    
    // 以下测试需要更高的 API quota，可能会因 rate limit 失败
    // 如果你有付费 Gemini API，可以取消注释运行这些测试
    
    @Test("Test gemini-2.0-flash-001 text enhancement (requires higher quota)", .disabled("Rate limited on free tier"))
    func testGemini20Flash001Enhancement() async throws {
        try await Task.sleep(nanoseconds: Self.rateLimitDelay)
        try await testModelEnhancementWithRetry(model: "gemini-2.0-flash-001")
    }
    
    @Test("Test gemini-2.5-pro text enhancement (requires higher quota)", .disabled("Rate limited on free tier"))
    func testGemini25ProEnhancement() async throws {
        try await Task.sleep(nanoseconds: Self.rateLimitDelay)
        try await testModelEnhancementWithRetry(model: "gemini-2.5-pro")
    }
    
    @Test("Test gemini-3-pro-preview text enhancement (requires higher quota)", .disabled("Rate limited on free tier"))
    func testGemini3ProPreviewEnhancement() async throws {
        try await Task.sleep(nanoseconds: Self.rateLimitDelay)
        try await testModelEnhancementWithRetry(model: "gemini-3-pro-preview")
    }
    
    // MARK: - Helper Methods
    
    /// 带重试的测试方法 - 处理 rate limiting
    @MainActor
    private func testModelEnhancementWithRetry(model: String, maxRetries: Int = 2) async throws {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            if attempt > 0 {
                print("⏳ Retry \(attempt) for \(model), waiting 15 seconds...")
                try await Task.sleep(nanoseconds: 15_000_000_000) // 15 秒重试延迟
            }
            
            do {
                try await testModelEnhancement(model: model)
                return // 成功则返回
            } catch let error as TestError {
                if case .rateLimitExceeded = error {
                    lastError = error
                    continue // rate limit 错误则重试
                }
                throw error // 其他错误直接抛出
            }
        }
        
        // 所有重试都失败
        if let error = lastError {
            throw error
        }
    }
    
    @MainActor
    private func testModelEnhancement(model: String) async throws {
        // Skip if not configured
        guard config.isConfigured(for: "Gemini") else {
            print("⏭️ Skipping Gemini \(model) test - API key not configured")
            return
        }
        
        let helper = AIEnhancementTestHelper(config: config)
        
        let result = try await helper.testEnhancement(
            provider: .gemini,
            model: model,
            text: TestFixtures.simpleText,
            systemPrompt: TestFixtures.systemPrompt
        )
        
        // Verify response
        #expect(!result.enhancedText.isEmpty, "Enhanced text should not be empty")
        #expect(result.responseTime > 0, "Response time should be positive")
        #expect(result.provider == .gemini, "Provider should be Gemini")
        #expect(result.model == model, "Model should match")
        
        // 验证响应有实际语义内容 - 应该包含一些常见词汇
        let hasSemanticContent = result.enhancedText.lowercased().contains("hello") ||
                                  result.enhancedText.lowercased().contains("world") ||
                                  result.enhancedText.lowercased().contains("test")
        #expect(hasSemanticContent, "Response should contain meaningful content related to input")
        
        print("✅ Gemini \(model): \(String(format: "%.2f", result.responseTime))s")
        print("   Response preview: \(String(result.enhancedText.prefix(100)))...")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test Gemini error handling with empty input")
    @MainActor
    func testEmptyInputHandling() async throws {
        try await Task.sleep(nanoseconds: Self.rateLimitDelay)
        
        guard config.isConfigured(for: "Gemini") else {
            print("⏭️ Skipping Gemini error handling test - API key not configured")
            return
        }
        
        let helper = AIEnhancementTestHelper(config: config)
        
        // 带重试的空输入测试
        var lastError: Error?
        for attempt in 0..<2 {
            if attempt > 0 {
                try await Task.sleep(nanoseconds: 15_000_000_000)
            }
            do {
                let result = try await helper.testEnhancement(
                    provider: .gemini,
                    model: "gemini-2.5-flash-lite",
                    text: "",
                    systemPrompt: TestFixtures.systemPrompt
                )
                #expect(result.responseTime > 0, "Should complete without error")
                return
            } catch let error as TestError {
                if case .rateLimitExceeded = error {
                    lastError = error
                    continue
                }
                // 空输入可能返回解析错误，这是可接受的
                if case .invalidResponse = error {
                    print("⚠️ Empty input returned invalid response (expected behavior)")
                    return
                }
                throw error
            }
        }
        if let error = lastError {
            throw error
        }
    }
}
