import Testing
import Foundation
@testable import HoAh

// MARK: - OpenAI Integration Tests
// 测试 HoAh 通过 OpenAI API 的 AI Enhancement 功能

@Suite("OpenAI Integration Tests")
struct OpenAIIntegrationTests {
    let config = TestConfiguration.load()
    
    /// OpenAI 可用模型列表
    static let availableModels = [
        "gpt-5.1",
        "gpt-5-mini",
        "gpt-5-nano",
        "gpt-4.1",
        "gpt-4.1-mini"
    ]
    
    // MARK: - Model Tests
    
    @Test("Test gpt-5.1 text enhancement")
    func testGPT51Enhancement() async throws {
        try await testModelEnhancement(model: "gpt-5.1")
    }
    
    @Test("Test gpt-5-mini text enhancement")
    func testGPT5MiniEnhancement() async throws {
        try await testModelEnhancement(model: "gpt-5-mini")
    }
    
    @Test("Test gpt-5-nano text enhancement")
    func testGPT5NanoEnhancement() async throws {
        try await testModelEnhancement(model: "gpt-5-nano")
    }
    
    @Test("Test gpt-4.1 text enhancement")
    func testGPT41Enhancement() async throws {
        try await testModelEnhancement(model: "gpt-4.1")
    }
    
    @Test("Test gpt-4.1-mini text enhancement")
    func testGPT41MiniEnhancement() async throws {
        try await testModelEnhancement(model: "gpt-4.1-mini")
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func testModelEnhancement(model: String) async throws {
        // Skip if not configured
        guard config.isConfigured(for: "OpenAI") else {
            print("⏭️ Skipping OpenAI \(model) test - API key not configured")
            return
        }
        
        let helper = AIEnhancementTestHelper(config: config)
        
        let result = try await helper.testEnhancement(
            provider: .openAI,
            model: model,
            text: TestFixtures.simpleText,
            systemPrompt: TestFixtures.systemPrompt
        )
        
        // Verify response
        #expect(!result.enhancedText.isEmpty, "Enhanced text should not be empty")
        #expect(result.responseTime > 0, "Response time should be positive")
        #expect(result.provider == .openAI, "Provider should be OpenAI")
        #expect(result.model == model, "Model should match")
        
        // 验证响应有实际语义内容 - 应该包含一些常见词汇
        let hasSemanticContent = result.enhancedText.lowercased().contains("hello") ||
                                  result.enhancedText.lowercased().contains("world") ||
                                  result.enhancedText.lowercased().contains("test")
        #expect(hasSemanticContent, "Response should contain meaningful content related to input")
        
        print("✅ OpenAI \(model): \(String(format: "%.2f", result.responseTime))s")
        print("   Response preview: \(String(result.enhancedText.prefix(100)))...")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test OpenAI error handling with empty input")
    @MainActor
    func testEmptyInputHandling() async throws {
        guard config.isConfigured(for: "OpenAI") else {
            print("⏭️ Skipping OpenAI error handling test - API key not configured")
            return
        }
        
        let helper = AIEnhancementTestHelper(config: config)
        
        // Empty input should still work (API will return something)
        let result = try await helper.testEnhancement(
            provider: .openAI,
            model: "gpt-4.1-mini",
            text: "",
            systemPrompt: TestFixtures.systemPrompt
        )
        
        // Just verify we got a response without error
        #expect(result.responseTime > 0, "Should complete without error")
    }
}
