import Testing
import Foundation
@testable import HoAh

// MARK: - Cerebras Integration Tests
// 测试 HoAh 通过 Cerebras API 的 AI Enhancement 功能

@Suite("Cerebras Integration Tests")
struct CerebrasIntegrationTests {
    let config = TestConfiguration.load()
    
    /// Cerebras 可用模型列表
    /// 注意: llama-4-scout-17b-16e-instruct 已从列表中移除 (API 不存在该模型)
    static let availableModels = [
        "gpt-oss-120b",
        "llama-3.1-8b",
        "llama-3.3-70b",
        "qwen-3-32b",
        "qwen-3-235b-a22b-instruct-2507"
    ]
    
    // MARK: - Model Tests
    
    @Test("Test gpt-oss-120b text enhancement")
    func testGptOss120bEnhancement() async throws {
        try await testModelEnhancement(model: "gpt-oss-120b")
    }
    
    @Test("Test llama-3.1-8b text enhancement")
    func testLlama31_8bEnhancement() async throws {
        try await testModelEnhancement(model: "llama-3.1-8b")
    }
    
    @Test("Test llama-3.3-70b text enhancement")
    func testLlama33_70bEnhancement() async throws {
        try await testModelEnhancement(model: "llama-3.3-70b")
    }
    
    @Test("Test qwen-3-32b text enhancement")
    func testQwen3_32bEnhancement() async throws {
        try await testModelEnhancement(model: "qwen-3-32b")
    }
    
    @Test("Test qwen-3-235b-a22b-instruct-2507 text enhancement")
    func testQwen3_235bEnhancement() async throws {
        try await testModelEnhancement(model: "qwen-3-235b-a22b-instruct-2507")
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func testModelEnhancement(model: String) async throws {
        // Skip if not configured
        guard config.isConfigured(for: "Cerebras") else {
            print("⏭️ Skipping Cerebras \(model) test - API key not configured")
            return
        }
        
        let helper = AIEnhancementTestHelper(config: config)
        
        let result = try await helper.testEnhancement(
            provider: .cerebras,
            model: model,
            text: TestFixtures.simpleText,
            systemPrompt: TestFixtures.systemPrompt
        )
        
        // Verify response
        #expect(!result.enhancedText.isEmpty, "Enhanced text should not be empty")
        #expect(result.responseTime > 0, "Response time should be positive")
        #expect(result.provider == .cerebras, "Provider should be Cerebras")
        #expect(result.model == model, "Model should match")
        
        // 验证响应有实际语义内容 - 应该包含一些常见词汇
        let hasSemanticContent = result.enhancedText.lowercased().contains("hello") ||
                                  result.enhancedText.lowercased().contains("world") ||
                                  result.enhancedText.lowercased().contains("test")
        #expect(hasSemanticContent, "Response should contain meaningful content related to input")
        
        print("✅ Cerebras \(model): \(String(format: "%.2f", result.responseTime))s")
        print("   Response preview: \(String(result.enhancedText.prefix(100)))...")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test Cerebras error handling with empty input")
    @MainActor
    func testEmptyInputHandling() async throws {
        guard config.isConfigured(for: "Cerebras") else {
            print("⏭️ Skipping Cerebras error handling test - API key not configured")
            return
        }
        
        let helper = AIEnhancementTestHelper(config: config)
        
        let result = try await helper.testEnhancement(
            provider: .cerebras,
            model: "llama-3.1-8b",
            text: "",
            systemPrompt: TestFixtures.systemPrompt
        )
        
        #expect(result.responseTime > 0, "Should complete without error")
    }
}
