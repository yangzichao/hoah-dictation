import SwiftUI

/// Sheet for creating or editing AI Configuration
/// IMPORTANT: Save button triggers API verification - only saves on successful response
struct ConfigurationEditSheet: View {
    enum Mode: Equatable {
        case add
        case edit(AIEnhancementConfiguration)
        
        static func == (lhs: Mode, rhs: Mode) -> Bool {
            switch (lhs, rhs) {
            case (.add, .add):
                return true
            case let (.edit(config1), .edit(config2)):
                return config1.id == config2.id
            default:
                return false
            }
        }
    }
    
    let mode: Mode
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appSettings: AppSettingsStore
    @EnvironmentObject private var aiService: AIService
    
    // Form state
    @State private var name: String
    @State private var selectedProvider: AIProvider
    @State private var apiKey: String
    @State private var selectedModel: String
    @State private var region: String
    @State private var enableCrossRegion: Bool
    
    // AWS Authentication state
    enum AWSAuthMethod: String, CaseIterable {
        case apiKey = "API Key"
        case accessKey = "Access Key"
        case profile = "AWS Profile"
    }
    @State private var awsAuthMethod: AWSAuthMethod = .apiKey
    @State private var selectedAWSProfile: String = ""
    @State private var availableAWSProfiles: [String] = []
    @State private var awsAccessKeyId: String = ""
    @State private var awsSecretAccessKey: String = ""
    
    // Verification state
    @State private var isVerifying = false
    @State private var verificationError: String?
    @State private var showError = false
    
    private let awsProfileService = AWSProfileService()
    
    init(mode: Mode) {
        self.mode = mode
        
        switch mode {
        case .add:
            let defaultProvider = AIProvider.groq
            _name = State(initialValue: "")
            _selectedProvider = State(initialValue: defaultProvider)
            _apiKey = State(initialValue: "")
            _selectedModel = State(initialValue: defaultProvider.defaultModel)
            _region = State(initialValue: "us-east-1")
            _enableCrossRegion = State(initialValue: false)
        case .edit(let config):
            _name = State(initialValue: config.name)
            _selectedProvider = State(initialValue: AIProvider(rawValue: config.provider) ?? .gemini)
            _apiKey = State(initialValue: config.getApiKey() ?? "")
            _selectedModel = State(initialValue: config.model)
            _region = State(initialValue: config.region ?? "us-east-1")
            _enableCrossRegion = State(initialValue: config.enableCrossRegion)
            // Determine auth method from config
            if let profileName = config.awsProfileName, !profileName.isEmpty {
                _awsAuthMethod = State(initialValue: .profile)
                _selectedAWSProfile = State(initialValue: profileName)
            } else if let accessKey = config.awsAccessKeyId, !accessKey.isEmpty {
                _awsAuthMethod = State(initialValue: .accessKey)
                _awsAccessKeyId = State(initialValue: accessKey)
                _awsSecretAccessKey = State(initialValue: config.getAwsSecretAccessKey() ?? "")
            } else {
                _awsAuthMethod = State(initialValue: .apiKey)
            }
        }
    }
    
    private var headerTitle: String {
        switch mode {
        case .add:
            return NSLocalizedString("New AI Configuration", comment: "")
        case .edit:
            return NSLocalizedString("Edit AI Configuration", comment: "")
        }
    }
    
    private var canVerify: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        hasValidAuthentication
    }
    
    private var hasValidAuthentication: Bool {
        switch selectedProvider {
        case .awsBedrock:
            let hasRegion = !region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            switch awsAuthMethod {
            case .apiKey:
                return !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasRegion
            case .accessKey:
                return !awsAccessKeyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                       !awsSecretAccessKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasRegion
            case .profile:
                return !selectedAWSProfile.isEmpty && hasRegion
            }
        default:
            return !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerBar
            ScrollView {
                VStack(spacing: 20) {
                    nameSection
                    providerSection
                    authenticationSection
                    providerSpecificSection
                    modelSection
                }
                .padding(.vertical, 20)
            }
        }
        .frame(minWidth: 500, minHeight: 420)
        .onChange(of: selectedProvider) { _, newProvider in
            selectedModel = newProvider.defaultModel
            if newProvider != .awsBedrock {
                awsAuthMethod = .apiKey
            }
            // Clear error when changing provider
            verificationError = nil
        }
        .onAppear {
            if selectedProvider == .awsBedrock {
                availableAWSProfiles = awsProfileService.listProfiles()
            }
        }
        .alert(NSLocalizedString("Verification Failed", comment: ""), isPresented: $showError) {
            Button(NSLocalizedString("OK", comment: ""), role: .cancel) {}
            Button(NSLocalizedString("Save Anyway", comment: "")) {
                saveConfiguration()
                dismiss()
            }
        } message: {
            Text(verificationError ?? NSLocalizedString("Unknown error", comment: ""))
        }
    }
    
    private var headerBar: some View {
        HStack {
            Text(headerTitle)
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
            HStack(spacing: 12) {
                Button(NSLocalizedString("Cancel", comment: "")) {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Button {
                    verifyAndSave()
                } label: {
                    HStack(spacing: 6) {
                        if isVerifying {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 14, height: 14)
                        }
                        Text(isVerifying ? NSLocalizedString("Verifying...", comment: "") : NSLocalizedString("Verify & Save", comment: ""))
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canVerify || isVerifying)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("Name", comment: ""))
                .font(.headline)
                .foregroundColor(.secondary)
            
            TextField(NSLocalizedString("e.g. My Gemini Config", comment: ""), text: $name)
                .textFieldStyle(.roundedBorder)
        }
        .padding(.horizontal)
    }
    
    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("Provider", comment: ""))
                .font(.headline)
                .foregroundColor(.secondary)
            
            Picker("", selection: $selectedProvider) {
                ForEach(AIProvider.allCases, id: \.self) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var authenticationSection: some View {
        // For AWS Bedrock, auth is handled in bedrockSection
        if selectedProvider == .awsBedrock {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(NSLocalizedString("API Key", comment: ""))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let url = selectedProvider.apiKeyURL {
                        Link(destination: url) {
                            HStack(spacing: 4) {
                                Text(NSLocalizedString("Get API Key", comment: ""))
                                Image(systemName: "arrow.up.right.square")
                            }
                            .font(.caption)
                        }
                    }
                }
                
                SecureField(NSLocalizedString("Enter your API key", comment: ""), text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: apiKey) { _, _ in
                        verificationError = nil
                    }
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var providerSpecificSection: some View {
        switch selectedProvider {
        case .awsBedrock:
            bedrockSection
        default:
            EmptyView()
        }
    }
    
    private var bedrockSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("Region", comment: ""))
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $region) {
                    ForEach(awsRegions, id: \.self) { r in
                        Text(r).tag(r)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("Authentication", comment: ""))
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $awsAuthMethod) {
                    ForEach(AWSAuthMethod.allCases, id: \.self) { method in
                        Text(NSLocalizedString(method.rawValue, comment: "")).tag(method)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: awsAuthMethod) { _, newValue in
                    if newValue == .profile {
                        availableAWSProfiles = awsProfileService.listProfiles()
                    }
                    verificationError = nil
                }
                
                // Auth method specific fields
                switch awsAuthMethod {
                case .apiKey:
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(NSLocalizedString("Bearer Token", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            if let url = selectedProvider.apiKeyURL {
                                Link(destination: url) {
                                    HStack(spacing: 4) {
                                        Text(NSLocalizedString("Get Token", comment: ""))
                                        Image(systemName: "arrow.up.right.square")
                                    }
                                    .font(.caption)
                                }
                            }
                        }
                        SecureField(NSLocalizedString("Enter your Bearer token", comment: ""), text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: apiKey) { _, _ in
                                verificationError = nil
                            }
                    }
                    
                case .accessKey:
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("Access Key ID", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField(NSLocalizedString("AKIA...", comment: ""), text: $awsAccessKeyId)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: awsAccessKeyId) { _, _ in
                                    verificationError = nil
                                }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("Secret Access Key", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            SecureField(NSLocalizedString("Enter your secret access key", comment: ""), text: $awsSecretAccessKey)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: awsSecretAccessKey) { _, _ in
                                    verificationError = nil
                                }
                        }
                        Text(NSLocalizedString("Get your Access Key from AWS IAM Console", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                case .profile:
                    if availableAWSProfiles.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(NSLocalizedString("No AWS profiles found in ~/.aws/credentials or ~/.aws/config", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Picker("", selection: $selectedAWSProfile) {
                            Text(NSLocalizedString("Select Profile", comment: "")).tag("")
                            ForEach(availableAWSProfiles, id: \.self) { profile in
                                Text(profile).tag(profile)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }
            }
            
            Toggle(NSLocalizedString("Enable Cross-Region Inference", comment: ""), isOn: $enableCrossRegion)
                .toggleStyle(.checkbox)
        }
        .padding(.horizontal)
    }
    
    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("Model", comment: ""))
                .font(.headline)
                .foregroundColor(.secondary)
            
            if selectedProvider.availableModels.isEmpty {
                TextField(NSLocalizedString("Enter model name", comment: ""), text: $selectedModel)
                    .textFieldStyle(.roundedBorder)
            } else {
                Picker("", selection: $selectedModel) {
                    ForEach(selectedProvider.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
        .padding(.horizontal)
    }
    
    private var awsRegions: [String] {
        ["us-east-1", "us-east-2", "us-west-2", "eu-west-1", "eu-west-2", "eu-central-1", "ap-northeast-1", "ap-southeast-1", "ap-southeast-2"]
    }
    
    // MARK: - Verification & Save
    
    private func verifyAndSave() {
        isVerifying = true
        verificationError = nil
        
        let trimmedApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // For AWS Bedrock, handle different auth methods
        if selectedProvider == .awsBedrock {
            switch awsAuthMethod {
            case .profile:
                Task {
                    await verifyAWSProfileWithSigV4(profile: selectedAWSProfile, region: region, model: trimmedModel)
                }
                return
            case .accessKey:
                Task {
                    await verifyAWSAccessKeyWithSigV4(
                        accessKeyId: awsAccessKeyId.trimmingCharacters(in: .whitespacesAndNewlines),
                        secretAccessKey: awsSecretAccessKey.trimmingCharacters(in: .whitespacesAndNewlines),
                        region: region,
                        model: trimmedModel
                    )
                }
                return
            case .apiKey:
                aiService.verifyBedrockConnection(
                    apiKey: trimmedApiKey,
                    region: region,
                    modelId: trimmedModel
                ) { success, errorMessage in
                    handleVerificationResult(success: success, errorMessage: errorMessage)
                }
                return
            }
        }
        
        // Verify based on provider
        switch selectedProvider {
        case .awsBedrock:
            // Already handled above
            break
            
        case .anthropic:
            verifyAnthropicKey(trimmedApiKey, model: trimmedModel)
            
        default:
            verifyOpenAICompatibleKey(trimmedApiKey, model: trimmedModel)
        }
    }
    
    private func verifyOpenAICompatibleKey(_ key: String, model: String) {
        guard let url = URL(string: selectedProvider.baseURL) else {
            handleVerificationResult(success: false, errorMessage: "Invalid API URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        
        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": "test"]],
            "max_tokens": 5
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    handleVerificationResult(success: false, errorMessage: error.localizedDescription)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    handleVerificationResult(success: false, errorMessage: "Invalid response")
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    handleVerificationResult(success: true, errorMessage: nil)
                } else {
                    var errorMsg = "HTTP \(httpResponse.statusCode)"
                    if let data = data, let responseStr = String(data: data, encoding: .utf8) {
                        // Try to extract error message from JSON
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let errorObj = json["error"] as? [String: Any],
                           let message = errorObj["message"] as? String {
                            errorMsg = message
                        } else {
                            errorMsg += ": \(responseStr.prefix(200))"
                        }
                    }
                    handleVerificationResult(success: false, errorMessage: errorMsg)
                }
            }
        }.resume()
    }
    
    private func verifyAnthropicKey(_ key: String, model: String) {
        guard let url = URL(string: selectedProvider.baseURL) else {
            handleVerificationResult(success: false, errorMessage: "Invalid API URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(key, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30
        
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 5,
            "messages": [["role": "user", "content": "test"]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    handleVerificationResult(success: false, errorMessage: error.localizedDescription)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    handleVerificationResult(success: false, errorMessage: "Invalid response")
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    handleVerificationResult(success: true, errorMessage: nil)
                } else {
                    var errorMsg = "HTTP \(httpResponse.statusCode)"
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorObj = json["error"] as? [String: Any],
                       let message = errorObj["message"] as? String {
                        errorMsg = message
                    }
                    handleVerificationResult(success: false, errorMessage: errorMsg)
                }
            }
        }.resume()
    }
    
    private func handleVerificationResult(success: Bool, errorMessage: String?) {
        isVerifying = false
        
        if success {
            saveConfiguration()
            dismiss()
        } else {
            verificationError = errorMessage ?? NSLocalizedString("Verification failed. Please check your API key and try again.", comment: "")
            showError = true
        }
    }
    
    /// Verifies AWS Access Key credentials by calling ListFoundationModels API
    private func verifyAWSAccessKeyWithSigV4(accessKeyId: String, secretAccessKey: String, region: String, model: String) async {
        guard isVerifying else { return }
        
        let credentials = AWSCredentials(
            accessKeyId: accessKeyId,
            secretAccessKey: secretAccessKey,
            sessionToken: nil,
            region: region
        )
        
        await verifyAWSCredentialsWithSigV4(credentials: credentials, region: region, model: model)
    }
    
    /// Verifies AWS Profile credentials by calling ListFoundationModels API
    /// This is a lightweight GET request that validates credentials without invoking a model
    private func verifyAWSProfileWithSigV4(profile: String, region: String, model: String) async {
        guard isVerifying else { return }
        
        // First resolve credentials (supports SSO, assume-role, credential_process)
        let credentials: AWSCredentials
        do {
            credentials = try await awsProfileService.resolveCredentials(for: profile)
        } catch {
            await MainActor.run {
                guard isVerifying else { return }
                isVerifying = false
                verificationError = String(format: NSLocalizedString("Failed to resolve credentials for AWS Profile '%@': %@", comment: ""), profile, error.localizedDescription)
                showError = true
            }
            return
        }
        
        await verifyAWSCredentialsWithSigV4(credentials: credentials, region: region, model: model)
    }
    
    /// Common SigV4 verification for both Profile and Access Key auth
    private func verifyAWSCredentialsWithSigV4(credentials: AWSCredentials, region: String, model: String) async {
        guard isVerifying else { return }
        
        // Use ListFoundationModels API as a lightweight probe
        let host = "bedrock.\(region).amazonaws.com"
        guard let url = URL(string: "https://\(host)/foundation-models?byOutputModality=TEXT&maxResults=1") else {
            await MainActor.run {
                guard isVerifying else { return }
                isVerifying = false
                verificationError = NSLocalizedString("Invalid Bedrock URL", comment: "")
                showError = true
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        
        // Sign the request with SigV4
        do {
            request = try AWSSigV4Signer.sign(
                request: request,
                credentials: credentials,
                region: region,
                service: "bedrock"
            )
        } catch {
            await MainActor.run {
                guard isVerifying else { return }
                isVerifying = false
                verificationError = String(format: NSLocalizedString("Failed to sign request: %@", comment: ""), error.localizedDescription)
                showError = true
            }
            return
        }
        
        // Make the request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard isVerifying else { return }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run {
                    isVerifying = false
                    verificationError = NSLocalizedString("Invalid response from Bedrock", comment: "")
                    showError = true
                }
                return
            }
            
            switch httpResponse.statusCode {
            case 200:
                await MainActor.run {
                    isVerifying = false
                    saveConfiguration()
                    dismiss()
                }
                
            case 403:
                let errorMsg: String
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? String {
                    errorMsg = message
                } else {
                    errorMsg = NSLocalizedString("Access denied. Ensure your IAM policy includes bedrock:ListFoundationModels permission.", comment: "")
                }
                await MainActor.run {
                    isVerifying = false
                    verificationError = errorMsg
                    showError = true
                }
                
            case 401:
                await MainActor.run {
                    isVerifying = false
                    verificationError = NSLocalizedString("Invalid AWS credentials. Please check your Access Key and Secret Key.", comment: "")
                    showError = true
                }
                
            default:
                var errorMsg = "HTTP \(httpResponse.statusCode)"
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? String {
                    errorMsg = message
                }
                await MainActor.run {
                    isVerifying = false
                    verificationError = errorMsg
                    showError = true
                }
            }
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            await MainActor.run {
                guard isVerifying else { return }
                isVerifying = false
                verificationError = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func saveConfiguration() {
        // Determine auth values based on method
        var awsProfile: String? = nil
        var finalApiKey: String? = nil
        var accessKeyId: String? = nil
        var secretAccessKey: String? = nil
        
        if selectedProvider == .awsBedrock {
            switch awsAuthMethod {
            case .apiKey:
                finalApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            case .accessKey:
                accessKeyId = awsAccessKeyId.trimmingCharacters(in: .whitespacesAndNewlines)
                secretAccessKey = awsSecretAccessKey.trimmingCharacters(in: .whitespacesAndNewlines)
            case .profile:
                awsProfile = selectedAWSProfile
            }
        } else {
            finalApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        let config: AIEnhancementConfiguration
        
        switch mode {
        case .add:
            config = AIEnhancementConfiguration(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                provider: selectedProvider.rawValue,
                model: selectedModel.trimmingCharacters(in: .whitespacesAndNewlines),
                apiKey: finalApiKey,
                awsProfileName: awsProfile,
                awsAccessKeyId: accessKeyId,
                awsSecretAccessKey: secretAccessKey,
                region: selectedProvider == .awsBedrock ? region : nil,
                enableCrossRegion: selectedProvider == .awsBedrock ? enableCrossRegion : false
            )
            appSettings.addConfiguration(config)
            
        case .edit(let existingConfig):
            config = AIEnhancementConfiguration(
                id: existingConfig.id,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                provider: selectedProvider.rawValue,
                model: selectedModel.trimmingCharacters(in: .whitespacesAndNewlines),
                apiKey: finalApiKey,
                awsProfileName: awsProfile,
                awsAccessKeyId: accessKeyId,
                awsSecretAccessKey: secretAccessKey,
                region: selectedProvider == .awsBedrock ? region : nil,
                enableCrossRegion: selectedProvider == .awsBedrock ? enableCrossRegion : false,
                createdAt: existingConfig.createdAt,
                lastUsedAt: existingConfig.lastUsedAt
            )
            appSettings.updateConfiguration(config)
        }
    }
}
