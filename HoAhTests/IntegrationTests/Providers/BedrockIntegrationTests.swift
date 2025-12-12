import Testing
import Foundation
@testable import HoAh

// MARK: - AWS Bedrock Integration Tests
// 测试 HoAh 通过 AWS Bedrock API 的 AI Enhancement 功能

@Suite("AWS Bedrock Integration Tests")
struct BedrockIntegrationTests {
    let config = TestConfiguration.load()
    
    /// AWS Bedrock 可用模型列表 (Cross-region inference profile IDs)
    static let availableModels = [
        "us.anthropic.claude-haiku-4-5-20251001-v1:0",
        "us.anthropic.claude-sonnet-4-5-20250929-v1:0",
        "us.anthropic.claude-sonnet-4-20250514-v1:0",
        "us.anthropic.claude-3-7-sonnet-20250219-v1:0",
        "openai.gpt-oss-120b-1:0"
    ]
    
    // MARK: - Model Tests
    
    @Test("Test claude-haiku-4-5 text enhancement")
    func testClaudeHaiku45Enhancement() async throws {
        try await testModelEnhancement(model: "us.anthropic.claude-haiku-4-5-20251001-v1:0")
    }
    
    @Test("Test claude-sonnet-4-5 text enhancement")
    func testClaudeSonnet45Enhancement() async throws {
        try await testModelEnhancement(model: "us.anthropic.claude-sonnet-4-5-20250929-v1:0")
    }
    
    @Test("Test claude-sonnet-4 text enhancement")
    func testClaudeSonnet4Enhancement() async throws {
        try await testModelEnhancement(model: "us.anthropic.claude-sonnet-4-20250514-v1:0")
    }
    
    @Test("Test claude-3-7-sonnet text enhancement")
    func testClaude37SonnetEnhancement() async throws {
        try await testModelEnhancement(model: "us.anthropic.claude-3-7-sonnet-20250219-v1:0")
    }
    
    @Test("Test openai.gpt-oss-120b text enhancement")
    func testGptOss120bEnhancement() async throws {
        try await testModelEnhancement(model: "openai.gpt-oss-120b-1:0")
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func testModelEnhancement(model: String) async throws {
        // Skip if API Key not configured (this test uses Bearer Token auth, not SigV4)
        // For SigV4/Profile auth, see BedrockProfileIntegrationTests
        guard config.hasBedrockAPIKey else {
            print("⏭️ Skipping AWS Bedrock \(model) test - API key not configured (use BedrockProfileIntegrationTests for Profile/SigV4)")
            return
        }
        
        let helper = AIEnhancementTestHelper(config: config)
        
        let result = try await helper.testEnhancement(
            provider: .awsBedrock,
            model: model,
            text: TestFixtures.simpleText,
            systemPrompt: TestFixtures.systemPrompt
        )
        
        // Verify response
        #expect(!result.enhancedText.isEmpty, "Enhanced text should not be empty")
        #expect(result.responseTime > 0, "Response time should be positive")
        #expect(result.provider == .awsBedrock, "Provider should be AWS Bedrock")
        #expect(result.model == model, "Model should match")
        
        // 验证响应有实际语义内容 - 应该包含一些常见词汇
        let hasSemanticContent = result.enhancedText.lowercased().contains("hello") ||
                                  result.enhancedText.lowercased().contains("world") ||
                                  result.enhancedText.lowercased().contains("test")
        #expect(hasSemanticContent, "Response should contain meaningful content related to input")
        
        print("✅ AWS Bedrock \(model): \(String(format: "%.2f", result.responseTime))s")
        print("   Response preview: \(String(result.enhancedText.prefix(100)))...")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test AWS Bedrock error handling with empty input")
    @MainActor
    func testEmptyInputHandling() async throws {
        guard config.hasBedrockAPIKey else {
            print("⏭️ Skipping AWS Bedrock error handling test - API key not configured")
            return
        }
        
        // 添加延迟避免 rate limiting (其他测试可能刚运行完)
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 秒
        
        let helper = AIEnhancementTestHelper(config: config)
        
        let result = try await helper.testEnhancement(
            provider: .awsBedrock,
            model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
            text: "",
            systemPrompt: TestFixtures.systemPrompt
        )
        
        #expect(result.responseTime > 0, "Should complete without error")
    }
}
