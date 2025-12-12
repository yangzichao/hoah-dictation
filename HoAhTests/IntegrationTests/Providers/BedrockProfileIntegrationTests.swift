import Testing
import Foundation
@testable import HoAh

// MARK: - AWS Bedrock Profile (SigV4) Integration Tests
// 测试 HoAh 通过 AWS Profile 和 SigV4 签名的 AI Enhancement 功能

@Suite("AWS Bedrock Profile Integration Tests", .serialized)
struct BedrockProfileIntegrationTests {
    let config = TestConfiguration.load()
    
    /// 测试用的模型 - 使用最快的 Haiku 模型
    static let testModel = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
    
    // MARK: - Profile Service Tests
    
    @Test("Test AWS Profile service can list profiles")
    func testListProfiles() async throws {
        let profileService = AWSProfileService()
        let profiles = profileService.listProfiles()
        
        print("📋 Found AWS profiles: \(profiles)")
        #expect(!profiles.isEmpty, "Should find at least one AWS profile")
        #expect(profiles.contains("default"), "Should have 'default' profile")
    }
    
    @Test("Test AWS Profile service can get credentials")
    func testGetCredentials() async throws {
        guard let profileName = config.awsProfile, !profileName.isEmpty else {
            print("⏭️ Skipping - AWS_PROFILE not configured in .env.test")
            return
        }
        
        let profileService = AWSProfileService()
        
        do {
            let credentials = try profileService.getCredentials(for: profileName)
            
            #expect(!credentials.accessKeyId.isEmpty, "Access key should not be empty")
            #expect(!credentials.secretAccessKey.isEmpty, "Secret key should not be empty")
            
            print("✅ Got credentials for profile '\(profileName)'")
            print("   Access Key: \(TestConfiguration.mask(credentials.accessKeyId))")
            print("   Region: \(credentials.region ?? "not set")")
        } catch {
            Issue.record("Failed to get credentials: \(error.localizedDescription)")
        }
    }
    
    @Test("Test AWS Profile service can resolve credentials")
    func testResolveCredentials() async throws {
        guard let profileName = config.awsProfile, !profileName.isEmpty else {
            print("⏭️ Skipping - AWS_PROFILE not configured in .env.test")
            return
        }
        
        let profileService = AWSProfileService()
        
        do {
            let credentials = try await profileService.resolveCredentials(for: profileName)
            
            #expect(!credentials.accessKeyId.isEmpty, "Access key should not be empty")
            #expect(!credentials.secretAccessKey.isEmpty, "Secret key should not be empty")
            
            print("✅ Resolved credentials for profile '\(profileName)'")
            print("   Access Key: \(TestConfiguration.mask(credentials.accessKeyId))")
            print("   Region: \(credentials.region ?? "not set")")
        } catch {
            Issue.record("Failed to resolve credentials: \(error.localizedDescription)")
        }
    }
    
    // MARK: - SigV4 Authentication Tests
    
    @Test("Test text enhancement with AWS Profile (SigV4)")
    @MainActor
    func testEnhancementWithProfile() async throws {
        guard let profileName = config.awsProfile, !profileName.isEmpty else {
            print("⏭️ Skipping - AWS_PROFILE not configured in .env.test")
            return
        }
        
        let profileService = AWSProfileService()
        
        // Get credentials
        let credentials: AWSCredentials
        do {
            credentials = try await profileService.resolveCredentials(for: profileName)
        } catch {
            Issue.record("Failed to resolve credentials: \(error.localizedDescription)")
            return
        }
        
        let region = credentials.region ?? "us-west-2"
        
        // Make SigV4 signed request
        let result = try await makeSigV4Request(
            model: Self.testModel,
            credentials: credentials,
            region: region,
            text: TestFixtures.simpleText,
            systemPrompt: TestFixtures.systemPrompt
        )
        
        // Verify response
        #expect(!result.isEmpty, "Enhanced text should not be empty")
        
        // 验证响应有实际语义内容
        let hasSemanticContent = result.lowercased().contains("hello") ||
                                  result.lowercased().contains("world") ||
                                  result.lowercased().contains("test")
        #expect(hasSemanticContent, "Response should contain meaningful content")
        
        print("✅ AWS Profile SigV4 authentication successful")
        print("   Response preview: \(String(result.prefix(100)))...")
    }
    
    // MARK: - Helper Methods
    
    /// 使用 SigV4 签名发送 Bedrock 请求
    private func makeSigV4Request(
        model: String,
        credentials: AWSCredentials,
        region: String,
        text: String,
        systemPrompt: String
    ) async throws -> String {
        let prompt = "\(systemPrompt)\n\n<TRANSCRIPT>\n\(text)\n</TRANSCRIPT>"
        
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
        // Don't manually encode - let URL handle it, but we need the encoded path for signing
        let path = "/model/\(model)/converse"
        guard let url = URL(string: "https://\(host)\(path)") else {
            throw TestError.invalidResponse(details: "Invalid Bedrock URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payloadData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        
        // Sign request with SigV4
        let signedRequest = try AWSSigV4Signer.sign(
            request: request,
            credentials: credentials,
            region: region,
            service: "bedrock"
        )
        
        let (data, response) = try await URLSession.shared.data(for: signedRequest)
        
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
            
            for item in content {
                if let text = item["text"] as? String {
                    return text.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            throw TestError.invalidResponse(details: "No text content in Bedrock response")
        } else if httpResponse.statusCode == 403 {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ 403 Error: \(errorString)")
            throw TestError.authenticationFailed(provider: "AWS Bedrock SigV4", statusCode: 403)
        } else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TestError.requestFailed(provider: "AWS Bedrock SigV4", statusCode: httpResponse.statusCode, message: errorString)
        }
    }
}
