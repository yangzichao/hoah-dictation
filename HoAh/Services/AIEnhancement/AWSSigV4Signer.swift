import Foundation
import CommonCrypto

/// AWS Signature Version 4 signer for authenticating requests to AWS services
/// Reference: https://docs.aws.amazon.com/general/latest/gr/sigv4_signing.html
enum AWSSigV4Signer {
    
    enum SigningError: LocalizedError {
        case invalidURL
        case missingHost
        case signingFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL for signing"
            case .missingHost: return "URL is missing host"
            case .signingFailed(let msg): return "Signing failed: \(msg)"
            }
        }
    }
    
    /// Signs an HTTP request using AWS Signature Version 4
    /// - Parameters:
    ///   - request: The URLRequest to sign
    ///   - credentials: AWS credentials (access key, secret key, optional session token)
    ///   - region: AWS region (e.g., "us-west-2")
    ///   - service: AWS service name (e.g., "bedrock")
    /// - Returns: A new URLRequest with authorization headers added
    static func sign(
        request: URLRequest,
        credentials: AWSCredentials,
        region: String,
        service: String
    ) throws -> URLRequest {
        var signedRequest = request
        
        guard let url = request.url else {
            throw SigningError.invalidURL
        }
        
        guard let host = url.host else {
            throw SigningError.missingHost
        }
        
        // Current time for signing
        let now = Date()
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate, .withTime, .withTimeZone, .withColonSeparatorInTimeZone]
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        
        let amzDate = amzDateString(from: now)
        let dateStamp = dateStampString(from: now)
        
        // Set required headers
        signedRequest.setValue(host, forHTTPHeaderField: "Host")
        signedRequest.setValue(amzDate, forHTTPHeaderField: "X-Amz-Date")
        
        // Add session token if present (for temporary credentials)
        if let sessionToken = credentials.sessionToken, !sessionToken.isEmpty {
            signedRequest.setValue(sessionToken, forHTTPHeaderField: "X-Amz-Security-Token")
        }
        
        // Calculate content hash
        let payloadHash = sha256Hash(data: request.httpBody ?? Data())
        signedRequest.setValue(payloadHash, forHTTPHeaderField: "X-Amz-Content-Sha256")
        
        // Create canonical request
        let httpMethod = request.httpMethod ?? "GET"
        let canonicalURI = url.path.isEmpty ? "/" : url.path
        let canonicalQueryString = url.query ?? ""
        
        // Get signed headers (sorted alphabetically)
        let signedHeaderNames = getSignedHeaderNames(from: signedRequest)
        let canonicalHeaders = getCanonicalHeaders(from: signedRequest, signedHeaders: signedHeaderNames)
        let signedHeadersString = signedHeaderNames.joined(separator: ";")
        
        let canonicalRequest = [
            httpMethod,
            canonicalURI,
            canonicalQueryString,
            canonicalHeaders,
            signedHeadersString,
            payloadHash
        ].joined(separator: "\n")
        
        // Create string to sign
        let algorithm = "AWS4-HMAC-SHA256"
        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let canonicalRequestHash = sha256Hash(string: canonicalRequest)
        
        let stringToSign = [
            algorithm,
            amzDate,
            credentialScope,
            canonicalRequestHash
        ].joined(separator: "\n")
        
        // Calculate signature
        let signingKey = getSignatureKey(
            secretKey: credentials.secretAccessKey,
            dateStamp: dateStamp,
            region: region,
            service: service
        )
        let signature = hmacSHA256(key: signingKey, data: stringToSign.data(using: .utf8)!).hexString
        
        // Create authorization header
        let authorizationHeader = "\(algorithm) Credential=\(credentials.accessKeyId)/\(credentialScope), SignedHeaders=\(signedHeadersString), Signature=\(signature)"
        signedRequest.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
        
        return signedRequest
    }
    
    // MARK: - Helper Methods
    
    /// Format date as YYYYMMDD'T'HHMMSS'Z'
    private static func amzDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
    
    /// Format date as YYYYMMDD
    private static func dateStampString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
    
    /// Get sorted list of header names to sign
    private static func getSignedHeaderNames(from request: URLRequest) -> [String] {
        guard let headers = request.allHTTPHeaderFields else { return [] }
        return headers.keys
            .map { $0.lowercased() }
            .filter { isSignableHeader($0) }
            .sorted()
    }
    
    /// Check if header should be included in signature
    private static func isSignableHeader(_ name: String) -> Bool {
        let lowercased = name.lowercased()
        // Include host, content-type, and all x-amz-* headers
        return lowercased == "host" ||
               lowercased == "content-type" ||
               lowercased.hasPrefix("x-amz-")
    }
    
    /// Create canonical headers string
    private static func getCanonicalHeaders(from request: URLRequest, signedHeaders: [String]) -> String {
        guard let headers = request.allHTTPHeaderFields else { return "" }
        
        let lowercasedHeaders = Dictionary(uniqueKeysWithValues: headers.map { ($0.key.lowercased(), $0.value) })
        
        return signedHeaders.map { headerName in
            let value = lowercasedHeaders[headerName] ?? ""
            // Trim whitespace and collapse multiple spaces
            let trimmedValue = value.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            return "\(headerName):\(trimmedValue)\n"
        }.joined()
    }
    
    /// Derive signing key using HMAC-SHA256
    private static func getSignatureKey(secretKey: String, dateStamp: String, region: String, service: String) -> Data {
        let kSecret = "AWS4\(secretKey)".data(using: .utf8)!
        let kDate = hmacSHA256(key: kSecret, data: dateStamp.data(using: .utf8)!)
        let kRegion = hmacSHA256(key: kDate, data: region.data(using: .utf8)!)
        let kService = hmacSHA256(key: kRegion, data: service.data(using: .utf8)!)
        let kSigning = hmacSHA256(key: kService, data: "aws4_request".data(using: .utf8)!)
        return kSigning
    }
    
    /// Calculate SHA256 hash of data
    private static func sha256Hash(data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Calculate SHA256 hash of string
    private static func sha256Hash(string: String) -> String {
        sha256Hash(data: string.data(using: .utf8) ?? Data())
    }
    
    /// Calculate HMAC-SHA256
    private static func hmacSHA256(key: Data, data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        key.withUnsafeBytes { keyBuffer in
            data.withUnsafeBytes { dataBuffer in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256),
                       keyBuffer.baseAddress, key.count,
                       dataBuffer.baseAddress, data.count,
                       &hash)
            }
        }
        return Data(hash)
    }
}

// MARK: - Data Extension

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
