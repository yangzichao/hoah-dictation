import Testing
import Foundation
@testable import HoAh

// MARK: - Groq Integration Tests
// 测试 HoAh 通过 Groq API 的 AI Enhancement 功能

@Suite("Groq Integration Tests")
struct GroqIntegrationTests {
    let config = TestConfiguration.load()
    
    /// Groq 可用模型列表
    static let availableModels = [
        "llama-3.1-8b-instant",
        "llama-3.3-70b-versatile",
        "moonshotai/kimi-k2-instruct-0905",
        "qwen/qwen3-32b",
        "meta-llama/llama-4-maverick-17b-128e-instruct",
        "openai/gpt-oss-120b",
        "openai/gpt-oss-20b"
    ]
    
    // MARK: - Model Tests
    
    @Test("Test llama-3.1-8b-instant text enhancement")
    func testLlama31_8bInstantEnhancement() async throws {
        try await testModelEnhancement(model: "llama-3.1-8b-instant")
    }
    
    @Test("Test llama-3.3-70b-versatile text enhancement")
    func testLlama33_70bVersatileEnhancement() async throws {
        try await testModelEnhancement(model: "llama-3.3-70b-versatile")
    }
    
    @Test("Test moonshotai/kimi-k2-instruct-0905 text enhancement")
    func testKimiK2Enhancement() async throws {
        try await testModelEnhancement(model: "moonshotai/kimi-k2-instruct-0905")
    }
    
    @Test("Test qwen/qwen3-32b text enhancement")
    func testQwen3_32bEnhancement() async throws {
        try await testModelEnhancement(model: "qwen/qwen3-32b")
    }
    
    @Test("Test meta-llama/llama-4-maverick-17b-128e-instruct text enhancement")
    func testLlama4MaverickEnhancement() async throws {
        try await testModelEnhancement(model: "meta-llama/llama-4-maverick-17b-128e-instruct")
    }
    
    @Test("Test openai/gpt-oss-120b text enhancement")
    func testGptOss120bEnhancement() async throws {
        try await testModelEnhancement(model: "openai/gpt-oss-120b")
    }
    
    @Test("Test openai/gpt-oss-20b text enhancement")
    func testGptOss20bEnhancement() async throws {
        try await testModelEnhancement(model: "openai/gpt-oss-20b")
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func testModelEnhancement(model: String) async throws {
        // Skip if not configured
        guard config.isConfigured(for: "GROQ") else {
            print("⏭️ Skipping Groq \(model) test - API key not configured")
            return
        }
        
        let helper = AIEnhancementTestHelper(config: config)
        
        let result = try await helper.testEnhancement(
            provider: .groq,
            model: model,
            text: TestFixtures.simpleText,
            systemPrompt: TestFixtures.systemPrompt
        )
        
        // Verify response
        #expect(!result.enhancedText.isEmpty, "Enhanced text should not be empty")
        #expect(result.responseTime > 0, "Response time should be positive")
        #expect(result.provider == .groq, "Provider should be Groq")
        #expect(result.model == model, "Model should match")
        
        // 验证响应有实际语义内容 - 应该包含一些常见词汇
        let hasSemanticContent = result.enhancedText.lowercased().contains("hello") ||
                                  result.enhancedText.lowercased().contains("world") ||
                                  result.enhancedText.lowercased().contains("test")
        #expect(hasSemanticContent, "Response should contain meaningful content related to input")
        
        print("✅ Groq \(model): \(String(format: "%.2f", result.responseTime))s")
        print("   Response preview: \(String(result.enhancedText.prefix(100)))...")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test Groq error handling with empty input")
    @MainActor
    func testEmptyInputHandling() async throws {
        guard config.isConfigured(for: "GROQ") else {
            print("⏭️ Skipping Groq error handling test - API key not configured")
            return
        }
        
        let helper = AIEnhancementTestHelper(config: config)
        
        let result = try await helper.testEnhancement(
            provider: .groq,
            model: "llama-3.1-8b-instant",
            text: "",
            systemPrompt: TestFixtures.systemPrompt
        )
        
        #expect(result.responseTime > 0, "Should complete without error")
    }
}
