import Testing
import Foundation
@testable import HoAh

/// AWS Bedrock Access Key (SigV4) Integration Tests
/// Uses env vars:
/// - AWS_ACCESS_KEY_ID
/// - AWS_SECRET_ACCESS_KEY
/// - AWS_SESSION_TOKEN (optional)
/// - AWS_BEDROCK_REGION (optional, default us-east-1)
@Suite("AWS Bedrock AccessKey Integration Tests", .serialized)
struct BedrockAccessKeyIntegrationTests {
    static let testModel = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
    let config = TestConfiguration.load()

    @Test("Verify SigV4 with Access Key + Secret Key")
    func testSigV4WithAccessKey() async throws {
        guard
            let accessKey = config.awsAccessKeyId, !accessKey.isEmpty,
            let secretKey = config.awsSecretAccessKey, !secretKey.isEmpty
        else {
            print("⏭️ Skipping - AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY not set (env or .env.test)")
            return
        }

        let sessionToken = config.awsSessionToken
        let region = config.awsBedrockRegion

        let credentials = AWSCredentials(
            accessKeyId: accessKey,
            secretAccessKey: secretKey,
            sessionToken: sessionToken,
            region: region
        )

        // 1) Verify credentials by calling ListFoundationModels
        let verifyResult = await AIConfigurationValidator.verifyAWSCredentials(
            credentials: credentials,
            region: region,
            modelId: Self.testModel
        )
        #expect(verifyResult.success, "SigV4 credential verification failed: \(verifyResult.errorMessage ?? "unknown error")")

        // 2) Make a small Converse request
        let response = try await makeSigV4Request(
            model: Self.testModel,
            credentials: credentials,
            region: region,
            text: TestFixtures.simpleText,
            systemPrompt: TestFixtures.systemPrompt
        )

        #expect(!response.isEmpty, "Response should not be empty")

        let hasSemanticContent = response.lowercased().contains("hello") ||
                                 response.lowercased().contains("world") ||
                                 response.lowercased().contains("test")
        #expect(hasSemanticContent, "Response should contain meaningful content")

        print("✅ AWS Access Key SigV4 successful for model \(Self.testModel)")
        print("   AccessKey: \(TestConfiguration.mask(accessKey))")
        print("   Region: \(region)")
        print("   Preview: \(String(response.prefix(80)))...")
    }

    // MARK: - Helpers

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
                "maxTokens": 256,
                "temperature": 0.3
            ]
        ]

        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        let host = "bedrock-runtime.\(region).amazonaws.com"
        let path = "/model/\(model)/converse"
        guard let url = URL(string: "https://\(host)\(path)") else {
            throw TestError.invalidResponse(details: "Invalid Bedrock URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payloadData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

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
