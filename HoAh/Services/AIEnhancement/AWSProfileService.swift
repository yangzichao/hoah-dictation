import Foundation
import OSLog

/// Credentials for AWS authentication
struct AWSCredentials: Equatable {
    let accessKeyId: String
    let secretAccessKey: String
    let sessionToken: String?  // Optional, for temporary credentials
    let region: String?        // Optional, from config file
}

/// Errors that can occur when reading AWS profiles
enum AWSProfileError: LocalizedError {
    case credentialsFileNotFound
    case profileNotFound(String)
    case invalidCredentials(String)
    case parseError(String)
    
    var errorDescription: String? {
        switch self {
        case .credentialsFileNotFound:
            return "AWS credentials file not found at ~/.aws/credentials"
        case .profileNotFound(let profile):
            return "AWS profile '\(profile)' not found"
        case .invalidCredentials(let profile):
            return "Invalid credentials for profile '\(profile)'"
        case .parseError(let message):
            return "Failed to parse AWS credentials: \(message)"
        }
    }
}

/// Service for reading AWS profiles from ~/.aws/credentials and ~/.aws/config
/// Used for AWS Bedrock authentication via SigV4 signing
class AWSProfileService {
    
    private let logger = Logger(subsystem: "com.yangzichao.hoah", category: "AWSProfileService")
    private let fileManager = FileManager.default
    
    /// Path to AWS credentials file
    private var credentialsPath: String {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return "\(home)/.aws/credentials"
    }
    
    /// Path to AWS config file
    private var configPath: String {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return "\(home)/.aws/config"
    }
    
    // MARK: - Public Methods
    
    /// Lists available AWS profile names from both credentials and config files
    /// - Returns: Array of unique profile names, empty if no files exist
    func listProfiles() -> [String] {
        var profiles = Set<String>()
        
        // Read from credentials file
        if let credentialsContent = readFile(at: credentialsPath) {
            let credentialProfiles = parseProfileNames(from: credentialsContent, isConfigFile: false)
            profiles.formUnion(credentialProfiles)
        }
        
        // Read from config file (supports SSO, assume-role, credential_process)
        if let configContent = readFile(at: configPath) {
            let configProfiles = parseProfileNames(from: configContent, isConfigFile: true)
            profiles.formUnion(configProfiles)
        }
        
        if profiles.isEmpty {
            logger.info("No AWS profiles found in ~/.aws/credentials or ~/.aws/config")
        } else {
            logger.info("Found \(profiles.count) AWS profiles")
        }
        
        return profiles.sorted()
    }

    
    /// Gets credentials for a specific profile
    /// - Parameter profile: The profile name to get credentials for
    /// - Returns: AWSCredentials if found and valid
    /// - Throws: AWSProfileError if profile not found or credentials invalid
    func getCredentials(for profile: String) throws -> AWSCredentials {
        guard let credentialsContent = readFile(at: credentialsPath) else {
            throw AWSProfileError.credentialsFileNotFound
        }
        
        // Parse credentials file
        let credentialsData = parseINIFile(credentialsContent)
        
        guard let profileData = credentialsData[profile] else {
            throw AWSProfileError.profileNotFound(profile)
        }
        
        guard let accessKeyId = profileData["aws_access_key_id"],
              let secretAccessKey = profileData["aws_secret_access_key"] else {
            throw AWSProfileError.invalidCredentials(profile)
        }
        
        let sessionToken = profileData["aws_session_token"]
        
        // Try to get region from config file
        let region = getRegionForProfile(profile)
        
        logger.info("Loaded credentials for profile: \(profile)")
        return AWSCredentials(
            accessKeyId: accessKeyId,
            secretAccessKey: secretAccessKey,
            sessionToken: sessionToken,
            region: region
        )
    }
    
    /// Checks if a profile exists in the credentials file
    /// - Parameter profile: The profile name to check
    /// - Returns: true if profile exists
    func profileExists(_ profile: String) -> Bool {
        return listProfiles().contains(profile)
    }
    
    /// Gets credentials using AWS CLI credential resolution
    /// This supports SSO, assume-role, credential_process, and static credentials
    /// - Parameter profile: The profile name
    /// - Returns: AWSCredentials if successfully resolved
    /// - Throws: AWSProfileError if credentials cannot be resolved
    func resolveCredentials(for profile: String) async throws -> AWSCredentials {
        // First try to get static credentials from credentials file
        if let credentials = try? getCredentials(for: profile) {
            return credentials
        }
        
        // Fall back to AWS CLI for SSO/assume-role/credential_process
        return try await resolveCredentialsViaCLI(for: profile)
    }
    
    /// Uses AWS CLI to resolve credentials (supports SSO, assume-role, etc.)
    private func resolveCredentialsViaCLI(for profile: String) async throws -> AWSCredentials {
        // Check if AWS CLI is available
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["aws"]
        whichProcess.standardOutput = Pipe()
        whichProcess.standardError = Pipe()
        
        do {
            try whichProcess.run()
            whichProcess.waitUntilExit()
        } catch {
            throw AWSProfileError.parseError("AWS CLI not found. Please install AWS CLI to use AWS Profile authentication.")
        }
        
        guard whichProcess.terminationStatus == 0 else {
            throw AWSProfileError.parseError("AWS CLI not found. Please install AWS CLI to use AWS Profile authentication.")
        }
        
        // Run aws configure export-credentials with timeout
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["aws", "configure", "export-credentials", "--profile", profile, "--format", "env"]
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        do {
            try process.run()
        } catch {
            throw AWSProfileError.parseError("Failed to run AWS CLI: \(error.localizedDescription)")
        }
        
        // Wait with 10 second timeout
        let timeoutSeconds: TimeInterval = 10
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        if process.isRunning {
            process.terminate()
            throw AWSProfileError.parseError("AWS CLI timed out. Check your network connection or SSO session.")
        }
        
        // Read stderr for error messages
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrOutput = String(data: stderrData, encoding: .utf8) ?? ""
        
        guard process.terminationStatus == 0 else {
            // Parse stderr for more helpful error message
            if stderrOutput.contains("SSO") && stderrOutput.contains("expired") {
                throw AWSProfileError.parseError("SSO session expired. Run 'aws sso login --profile \(profile)' to refresh.")
            } else if stderrOutput.contains("SSO") {
                throw AWSProfileError.parseError("SSO login required. Run 'aws sso login --profile \(profile)' first.")
            } else if !stderrOutput.isEmpty {
                // Return first line of stderr as error
                let firstLine = stderrOutput.components(separatedBy: .newlines).first ?? stderrOutput
                throw AWSProfileError.parseError(firstLine.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            throw AWSProfileError.invalidCredentials(profile)
        }
        
        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw AWSProfileError.parseError("Failed to read AWS CLI output")
        }
        
        // Parse environment variable format output
        var accessKeyId: String?
        var secretAccessKey: String?
        var sessionToken: String?
        
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("export ") {
                let parts = String(trimmed.dropFirst("export ".count)).components(separatedBy: "=")
                if parts.count >= 2 {
                    let key = parts[0]
                    let value = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    
                    switch key {
                    case "AWS_ACCESS_KEY_ID":
                        accessKeyId = value
                    case "AWS_SECRET_ACCESS_KEY":
                        secretAccessKey = value
                    case "AWS_SESSION_TOKEN":
                        sessionToken = value
                    default:
                        break
                    }
                }
            }
        }
        
        guard let accessKey = accessKeyId, let secretKey = secretAccessKey else {
            throw AWSProfileError.invalidCredentials(profile)
        }
        
        let region = getRegionForProfile(profile)
        
        return AWSCredentials(
            accessKeyId: accessKey,
            secretAccessKey: secretKey,
            sessionToken: sessionToken,
            region: region
        )
    }
    
    // MARK: - Private Methods
    
    /// Reads file content at path
    private func readFile(at path: String) -> String? {
        guard fileManager.fileExists(atPath: path) else {
            return nil
        }
        return try? String(contentsOfFile: path, encoding: .utf8)
    }
    
    /// Parses profile names from INI-style content
    /// - Parameters:
    ///   - content: The file content to parse
    ///   - isConfigFile: If true, handles "profile <name>" format used in config file
    private func parseProfileNames(from content: String, isConfigFile: Bool) -> [String] {
        var profiles: [String] = []
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                var profileName = String(trimmed.dropFirst().dropLast())
                
                // Config file uses "profile <name>" format for non-default profiles
                if isConfigFile && profileName.hasPrefix("profile ") {
                    profileName = String(profileName.dropFirst("profile ".count))
                }
                
                profiles.append(profileName)
            }
        }
        
        return profiles
    }

    
    /// Parses INI-style file into dictionary of sections
    private func parseINIFile(_ content: String) -> [String: [String: String]] {
        var result: [String: [String: String]] = [:]
        var currentSection: String?
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix(";") {
                continue
            }
            
            // Check for section header
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                currentSection = String(trimmed.dropFirst().dropLast())
                result[currentSection!] = [:]
                continue
            }
            
            // Parse key=value pairs
            if let currentSection = currentSection,
               let equalsIndex = trimmed.firstIndex(of: "=") {
                let key = String(trimmed[..<equalsIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespaces)
                result[currentSection]?[key] = value
            }
        }
        
        return result
    }
    
    /// Gets region for a profile from config file
    /// Config file uses "profile <name>" format for non-default profiles
    private func getRegionForProfile(_ profile: String) -> String? {
        guard let configContent = readFile(at: configPath) else {
            return nil
        }
        
        let configData = parseINIFile(configContent)
        
        // Config file uses different section naming:
        // - [default] for default profile
        // - [profile <name>] for other profiles
        let sectionName = profile == "default" ? "default" : "profile \(profile)"
        
        return configData[sectionName]?["region"]
    }
}
