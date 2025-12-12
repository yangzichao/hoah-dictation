import Foundation
import Combine

// AIProvider enum contains only AI enhancement providers (for post-processing transcribed text).
// Transcription-only providers (ElevenLabs, Soniox) are managed separately in WhisperState.
enum AIProvider: String, CaseIterable {
    case awsBedrock = "AWS Bedrock"
    case cerebras = "Cerebras"
    case groq = "GROQ"
    case gemini = "Gemini"
    case anthropic = "Anthropic"
    case openAI = "OpenAI"
    case openRouter = "OpenRouter"
    
    
    var baseURL: String {
        switch self {
        case .cerebras:
            return "https://api.cerebras.ai/v1/chat/completions"
        case .groq:
            return "https://api.groq.com/openai/v1/chat/completions"
        case .gemini:
            return "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
        case .anthropic:
            return "https://api.anthropic.com/v1/messages"
        case .openAI:
            return "https://api.openai.com/v1/chat/completions"
        case .openRouter:
            return "https://openrouter.ai/api/v1/chat/completions"
        case .awsBedrock:
            let region = UserDefaults.standard.string(forKey: "AWSBedrockRegion") ?? "us-east-1"
            return "https://bedrock-runtime.\(region).amazonaws.com"
        }
    }
    
    var defaultModel: String {
        switch self {
        case .cerebras:
            return "gpt-oss-120b"
        case .groq:
            return "openai/gpt-oss-120b"
        case .gemini:
            return "gemini-2.5-flash-lite"
        case .anthropic:
            return "claude-sonnet-4-5"
        case .openAI:
            return "gpt-5.1"
        case .openRouter:
            return "openai/gpt-oss-120b"
        case .awsBedrock:
            return UserDefaults.standard.string(forKey: "AWSBedrockModelId") ?? "us.anthropic.claude-haiku-4-5-20251001-v1:0"
        }
    }
    
    var availableModels: [String] {
        switch self {
        case .cerebras:
            // 注意: llama-4-scout-17b-16e-instruct 已移除 (API 不存在该模型)
            return [
                "gpt-oss-120b",
                "llama-3.1-8b",
                "llama-3.3-70b",
                "qwen-3-32b",
                "qwen-3-235b-a22b-instruct-2507"
            ]
        case .groq:
            return [
                "llama-3.1-8b-instant",
                "llama-3.3-70b-versatile",
                "moonshotai/kimi-k2-instruct-0905",
                "qwen/qwen3-32b",
                "meta-llama/llama-4-maverick-17b-128e-instruct",
                "openai/gpt-oss-120b",
                "openai/gpt-oss-20b"
            ]
        case .gemini:
            return [
                "gemini-3-pro-preview",
                "gemini-2.5-pro",
                "gemini-2.5-flash-lite",
                "gemini-2.0-flash-001"
            ]
        case .anthropic:
            return [
                "claude-opus-4-5",
                "claude-sonnet-4-5",
                "claude-haiku-4-5"
            ]
        case .openAI:
            return [
                "gpt-5.1",
                "gpt-5-mini",
                "gpt-5-nano",
                "gpt-4.1",
                "gpt-4.1-mini"
            ]
        case .openRouter:
            return []
        case .awsBedrock:
            // Cross-region inference profile IDs (Haiku & Sonnet + OpenAI GPT-OSS)
            return [
                // Claude 4.5 (Haiku first as default)
                "us.anthropic.claude-haiku-4-5-20251001-v1:0",
                "us.anthropic.claude-sonnet-4-5-20250929-v1:0",
                // Claude 4
                "us.anthropic.claude-sonnet-4-20250514-v1:0",
                // Claude 3.7
                "us.anthropic.claude-3-7-sonnet-20250219-v1:0",
                // OpenAI GPT-OSS (text-only)
                "openai.gpt-oss-120b-1:0"
            ]
        }
    }
    
    var requiresAPIKey: Bool {
        switch self {
        case .awsBedrock:
            return true
        default:
            return true
        }
    }
    
    /// URL to get API key for this provider
    var apiKeyURL: URL? {
        switch self {
        case .awsBedrock:
            return URL(string: "https://console.aws.amazon.com/bedrock/")
        case .cerebras:
            return URL(string: "https://cloud.cerebras.ai/")
        case .groq:
            return URL(string: "https://console.groq.com/keys")
        case .gemini:
            return URL(string: "https://aistudio.google.com/apikey")
        case .anthropic:
            return URL(string: "https://console.anthropic.com/settings/keys")
        case .openAI:
            return URL(string: "https://platform.openai.com/api-keys")
        case .openRouter:
            return URL(string: "https://openrouter.ai/keys")
        }
    }
}

// AI Provider settings are managed by AppSettingsStore.
// Runtime state (apiKey, isAPIKeyValid) remains here.
@MainActor
class AIService: ObservableObject {
    @Published private(set) var apiKey: String = ""
    @Published var isAPIKeyValid: Bool = false
    
    // Reference to centralized settings store
    private weak var appSettings: AppSettingsStore?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Active Configuration Support
    
    /// The currently active AI Enhancement configuration from AppSettingsStore
    var activeConfiguration: AIEnhancementConfiguration? {
        appSettings?.activeAIConfiguration
    }
    
    /// Whether to use the new configuration profile system
    /// Returns true if there's an active configuration, false to use legacy settings
    var useConfigurationProfiles: Bool {
        activeConfiguration != nil
    }
    
    // AWS Bedrock credentials/config - runtime state
    @Published var bedrockApiKey: String = ""
    
    /// AWS Bedrock region - reads from AppSettingsStore
    var bedrockRegion: String {
        get { appSettings?.bedrockRegion ?? "us-east-1" }
        set {
            objectWillChange.send()
            appSettings?.bedrockRegion = newValue
        }
    }
    
    /// AWS Bedrock model ID - reads from AppSettingsStore
    var bedrockModelId: String {
        get { appSettings?.bedrockModelId ?? "us.anthropic.claude-sonnet-4-5-20250929-v1:0" }
        set {
            objectWillChange.send()
            appSettings?.bedrockModelId = newValue
        }
    }
    
    /// Selected AI provider - reads from AppSettingsStore
    var selectedProvider: AIProvider {
        get {
            if let appSettings = appSettings {
                return AIProvider(rawValue: appSettings.selectedAIProvider) ?? .gemini
            }
            return .gemini
        }
        set {
            objectWillChange.send()
            appSettings?.selectedAIProvider = newValue.rawValue
            refreshAPIKeyState()
            NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
        }
    }
    
    /// Selected models per provider - reads from AppSettingsStore
    private var selectedModels: [AIProvider: String] {
        get {
            if let appSettings = appSettings {
                var result: [AIProvider: String] = [:]
                for (key, value) in appSettings.selectedModels {
                    if let provider = AIProvider(rawValue: key) {
                        result[provider] = value
                    }
                }
                return result
            }
            return [:]
        }
        set {
            objectWillChange.send()
            if let appSettings = appSettings {
                var stringDict: [String: String] = [:]
                for (provider, model) in newValue {
                    stringDict[provider.rawValue] = model
                }
                appSettings.selectedModels = stringDict
            }
        }
    }
    
    private let userDefaults = UserDefaults.standard
    private let keyManager = CloudAPIKeyManager.shared
    private let awsProfileService = AWSProfileService()
    
    @Published private var openRouterModels: [String] = []
    
    var connectedProviders: [AIProvider] {
        AIProvider.allCases.filter { provider in
            if provider.requiresAPIKey {
                if provider == .awsBedrock {
                    let hasKey = keyManager.activeKey(for: AIProvider.awsBedrock.rawValue) != nil
                    return hasKey && !bedrockRegion.isEmpty && !bedrockModelId.isEmpty
                }
                return userDefaults.string(forKey: "\(provider.rawValue)APIKey") != nil
            }
            return false
        }
    }
    
    var currentModel: String {
        if selectedProvider == .awsBedrock {
            return bedrockModelId
        }
        if let selectedModel = selectedModels[selectedProvider],
           !selectedModel.isEmpty,
           availableModels.contains(selectedModel) {
            return selectedModel
        }
        return selectedProvider.defaultModel
    }
    
    var availableModels: [String] {
        if selectedProvider == .openRouter {
            return openRouterModels
        }
        return selectedProvider.availableModels
    }
    
    init() {
        // Migration: Check for misplaced transcription provider API keys
        migrateTranscriptionProviderKeys()
        
        // Debug assertion: Ensure all AIProvider cases are enhancement providers
        #if DEBUG
        for provider in AIProvider.allCases {
            assert(isValidEnhancementProvider(provider.rawValue),
                   "AIProvider enum contains invalid provider: \(provider.rawValue)")
        }
        #endif
        
        refreshAPIKeyState()
        refreshAPIKeyState()
        loadSavedOpenRouterModels()
        
        // Listen for external API key changes (e.g. from APIKeyManagementView)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAPIKeyChanged),
            name: .aiProviderKeyChanged,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleAPIKeyChanged() {
        Task { @MainActor in
            self.refreshAPIKeyState()
            self.objectWillChange.send()
        }
    }
    
    /// Migrates any misplaced transcription provider API keys from AIService storage
    /// This handles backward compatibility for users who may have configured
    /// ElevenLabs or Soniox through the old AIService interface
    private func migrateTranscriptionProviderKeys() {
        let transcriptionProviders = ["ElevenLabs"]
        
        for providerName in transcriptionProviders {
            // Check for legacy API keys in UserDefaults
            if let legacyKey = userDefaults.string(forKey: "\(providerName)APIKey"), !legacyKey.isEmpty {
                print("⚠️ Migration: Found \(providerName) API key in AIService storage.")
                print("   \(providerName) is a transcription provider and should be configured in the AI Models tab.")
                print("   The key has been left in place but will not be used by AIService.")
                // Note: We don't remove the key here to avoid data loss
                // The transcription service can pick it up if needed
            }
            
            // Check for keys in CloudAPIKeyManager
            let keys = keyManager.keys(for: providerName)
            if !keys.isEmpty {
                print("⚠️ Migration: Found \(keys.count) \(providerName) API key(s) in CloudAPIKeyManager.")
                print("   \(providerName) is a transcription provider and should be configured in the AI Models tab.")
                // Note: We don't remove the keys here to avoid data loss
            }
        }
        
        // If the selected provider was a transcription provider, reset to default
        if let savedProvider = userDefaults.string(forKey: "selectedAIProvider"),
           transcriptionProviders.contains(savedProvider) {
            print("⚠️ Migration: Selected provider was \(savedProvider), resetting to Gemini.")
            userDefaults.set(AIProvider.gemini.rawValue, forKey: "selectedAIProvider")
        }
    }
    
    /// Configure with AppSettingsStore for centralized state management
    func configure(with appSettings: AppSettingsStore) {
        self.appSettings = appSettings
        
        // Subscribe to settings changes
        appSettings.selectedAIProviderPublisher
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                self?.refreshAPIKeyState()
            }
            .store(in: &cancellables)
        
        appSettings.$bedrockRegion
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        appSettings.$bedrockModelId
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        appSettings.selectedModelsPublisher
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Subscribe to configuration profile changes
        appSettings.aiEnhancementConfigurationsPublisher
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                self?.refreshAPIKeyState()
            }
            .store(in: &cancellables)
        
        appSettings.activeAIConfigurationIdPublisher
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                self?.refreshAPIKeyState()
            }
            .store(in: &cancellables)
        
        // Refresh API key state with new settings
        refreshAPIKeyState()
    }
    
    private func loadSavedOpenRouterModels() {
        if let savedModels = userDefaults.array(forKey: "openRouterModels") as? [String] {
            openRouterModels = savedModels
        }
    }
    
    private func refreshAPIKeyState() {
        // If using configuration profiles, check the active configuration
        if let config = activeConfiguration {
            refreshAPIKeyStateFromConfiguration(config)
            return
        }
        
        // Legacy behavior: use selectedProvider
        if selectedProvider.requiresAPIKey {
            if let active = keyManager.activeKey(for: selectedProvider.rawValue) {
                self.apiKey = active.value
                if selectedProvider == .awsBedrock {
                    self.isAPIKeyValid = !bedrockRegion.isEmpty && !bedrockModelId.isEmpty
                } else {
                    self.isAPIKeyValid = true
                }
            } else if let legacy = userDefaults.string(forKey: "\(selectedProvider.rawValue)APIKey"), !legacy.isEmpty {
                // migrate legacy single key into manager
                let entry = keyManager.addKey(legacy, for: selectedProvider.rawValue)
                keyManager.selectKey(id: entry.id, for: selectedProvider.rawValue)
                self.apiKey = entry.value
                if selectedProvider == .awsBedrock {
                    self.isAPIKeyValid = !bedrockRegion.isEmpty && !bedrockModelId.isEmpty
                } else {
                    self.isAPIKeyValid = true
                }
            } else {
                self.apiKey = ""
                self.isAPIKeyValid = false
            }
        } else {
            self.apiKey = ""
            self.isAPIKeyValid = true
        }
    }
    
    /// Flag to prevent recursive refresh calls
    private var isRefreshingFromConfiguration = false
    
    /// Refreshes API key state from a configuration profile
    /// Also syncs provider, model, region, and other settings from the configuration
    /// Uses equality checks to prevent unnecessary updates and potential infinite loops
    private func refreshAPIKeyStateFromConfiguration(_ config: AIEnhancementConfiguration) {
        // Prevent recursive calls
        guard !isRefreshingFromConfiguration else { return }
        isRefreshingFromConfiguration = true
        defer { isRefreshingFromConfiguration = false }
        
        let isAWSProfileConfig = (config.awsProfileName?.isEmpty == false) && config.provider == AIProvider.awsBedrock.rawValue
        // Check validity for non-profile configs; AWS Profile will be validated below
        if !isAWSProfileConfig {
            guard config.isValid else {
                self.apiKey = ""
                self.isAPIKeyValid = false
                return
            }
        }
        
        // Sync provider settings from configuration (with equality checks to prevent loops)
        if let provider = AIProvider(rawValue: config.provider) {
            // Update provider only if different
            if appSettings?.selectedAIProvider != provider.rawValue {
                appSettings?.selectedAIProvider = provider.rawValue
            }
            
            // Update model only if different
            if let appSettings = appSettings {
                let currentModel = appSettings.selectedModels[provider.rawValue]
                if currentModel != config.model {
                    var models = appSettings.selectedModels
                    models[provider.rawValue] = config.model
                    appSettings.selectedModels = models
                }
            }
            
            // Update provider-specific settings only if different
            if provider == .awsBedrock {
                let newRegion = config.region ?? "us-east-1"
                if appSettings?.bedrockRegion != newRegion {
                    appSettings?.bedrockRegion = newRegion
                }
                if appSettings?.bedrockModelId != config.model {
                    appSettings?.bedrockModelId = config.model
                }
            }
        }
        
        // Handle authentication
        if let profileName = config.awsProfileName, !profileName.isEmpty {
            self.apiKey = ""
            self.isAPIKeyValid = false
            let regionToUse = config.region ?? appSettings?.bedrockRegion ?? "us-east-1"
            Task { [weak self] in
                await self?.validateAWSProfileConfiguration(profileName: profileName, region: regionToUse)
            }
            return
        }
        
        // API Key authentication - read from Keychain (use hasActualApiKey for reliability)
        if let key = config.getApiKey(), !key.isEmpty {
            self.apiKey = key
            self.isAPIKeyValid = true
        } else {
            self.apiKey = ""
            self.isAPIKeyValid = false
        }
    }
    
    /// Resolves AWS profile credentials on selection to allow profile-based switching
    private func validateAWSProfileConfiguration(profileName: String, region: String?) async {
        do {
            let credentials = try await awsProfileService.resolveCredentials(for: profileName)
            let resolvedRegion = region ?? credentials.region ?? "us-east-1"
            await MainActor.run {
                if let appSettings = appSettings, appSettings.bedrockRegion != resolvedRegion {
                    appSettings.bedrockRegion = resolvedRegion
                }
                self.apiKey = ""
                self.isAPIKeyValid = true
            }
        } catch {
            await MainActor.run {
                self.apiKey = ""
                self.isAPIKeyValid = false
                print("⚠️ AWS profile validation failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func saveOpenRouterModels() {
        userDefaults.set(openRouterModels, forKey: "openRouterModels")
    }
    
    func selectModel(_ model: String) {
        guard !model.isEmpty else { return }
        
        if let appSettings = appSettings {
            // Update through AppSettingsStore
            var models = appSettings.selectedModels
            models[selectedProvider.rawValue] = model
            appSettings.selectedModels = models
        }
        
        objectWillChange.send()
        NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
    }
    
    /// Validates that the provider is an enhancement provider (not a transcription provider)
    /// - Parameter providerName: The raw value of the provider to validate
    /// - Returns: True if the provider is valid for AI enhancement, false otherwise
    func isValidEnhancementProvider(_ providerName: String) -> Bool {
        // Check if the provider exists in the AIProvider enum
        guard AIProvider(rawValue: providerName) != nil else {
            return false
        }
        // All providers in AIProvider enum are enhancement providers
        // (transcription-only providers have been removed)
        return true
    }
    
    func saveAPIKey(_ key: String, completion: @escaping (Bool, String?) -> Void) {
        guard selectedProvider.requiresAPIKey else {
            completion(true, nil)
            return
        }
        
        // Validate that this is an enhancement provider
        guard isValidEnhancementProvider(selectedProvider.rawValue) else {
            completion(false, "Invalid provider: This provider is not available for AI enhancement.")
            return
        }
        
        if selectedProvider == .awsBedrock {
            saveBedrockConfig(
                apiKey: bedrockApiKey,
                region: bedrockRegion,
                modelId: bedrockModelId
            )
            completion(isAPIKeyValid, nil)
            return
        }
        
        verifyAPIKey(key) { [weak self] isValid, errorMessage in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if isValid {
                    let entry = self.keyManager.addKey(key, for: self.selectedProvider.rawValue)
                    self.apiKey = entry.value
                    self.isAPIKeyValid = true
                    self.keyManager.selectKey(id: entry.id, for: self.selectedProvider.rawValue)
                    NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
                } else {
                    self.isAPIKeyValid = false
                }
                completion(isValid, errorMessage)
            }
        }
    }
    
    func verifyAPIKey(_ key: String, completion: @escaping (Bool, String?) -> Void) {
        guard selectedProvider.requiresAPIKey else {
            completion(true, nil)
            return
        }
        
        if selectedProvider == .awsBedrock {
            let hasRegion = !bedrockRegion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasModel = !bedrockModelId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            completion(hasRegion && hasModel && !trimmedKey.isEmpty, hasRegion && hasModel && !trimmedKey.isEmpty ? nil : "Provide API key, region, and model.")
            return
        }
        
        switch selectedProvider {
        case .anthropic:
            verifyAnthropicAPIKey(key, completion: completion)
        default:
            verifyOpenAICompatibleAPIKey(key, completion: completion)
        }
    }
    
    func saveBedrockConfig(apiKey: String, region: String, modelId: String) {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        bedrockRegion = region.trimmingCharacters(in: .whitespacesAndNewlines)
        bedrockModelId = modelId.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !trimmedKey.isEmpty {
            let entry = keyManager.addKey(trimmedKey, for: AIProvider.awsBedrock.rawValue)
            keyManager.selectKey(id: entry.id, for: AIProvider.awsBedrock.rawValue)
            self.apiKey = entry.value
        }
        
        isAPIKeyValid = keyManager.activeKey(for: AIProvider.awsBedrock.rawValue) != nil && !bedrockRegion.isEmpty && !bedrockModelId.isEmpty
        NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
    }
    
    func clearAPIKey() {
        keyManager.removeAllKeys(for: selectedProvider.rawValue)
        apiKey = ""
        isAPIKeyValid = false
        NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
    }
    
    func rotateAPIKey() -> Bool {
        let didRotate = keyManager.rotateKey(for: selectedProvider.rawValue)
        refreshAPIKeyState()
        return didRotate
    }
    
    func selectAPIKey(id: UUID) {
        keyManager.selectKey(id: id, for: selectedProvider.rawValue)
        refreshAPIKeyState()
    }
    
    func currentKeyEntries() -> [CloudAPIKeyEntry] {
        keyManager.keys(for: selectedProvider.rawValue)
    }
    
    private func verifyOpenAICompatibleAPIKey(_ key: String, completion: @escaping (Bool, String?) -> Void) {
        let url = URL(string: selectedProvider.baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        
        let testBody: [String: Any] = [
            "model": currentModel,
            "messages": [
                ["role": "user", "content": "test"]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: testBody)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                let isValid = httpResponse.statusCode == 200
                
                if !isValid {
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        completion(false, responseString)
                    } else {
                        completion(false, nil)
                    }
                } else {
                    completion(true, nil)
                }
            } else {
                completion(false, nil)
            }
        }.resume()
    }
    
    private func verifyAnthropicAPIKey(_ key: String, completion: @escaping (Bool, String?) -> Void) {
        let url = URL(string: selectedProvider.baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(key, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let testBody: [String: Any] = [
            "model": currentModel,
            "max_tokens": 1024,
            "system": "You are a test system.",
            "messages": [
                ["role": "user", "content": "test"]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: testBody)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    completion(true, nil)
                } else {
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        completion(false, responseString)
                    } else {
                        completion(false, nil)
                    }
                }
            } else {
                completion(false, nil)
            }
        }.resume()
    }
    
    func verifyBedrockConnection(apiKey: String, region: String, modelId: String, completion: @escaping (Bool, String?) -> Void) {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !modelId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion(false, "Please provide API key, region, and model.")
            return
        }
        
        // Build test request
        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": [
                    ["text": "Hello"]
                ]
            ]
        ]
        
        let payload: [String: Any] = [
            "messages": messages,
            "inferenceConfig": [
                "maxTokens": 10,
                "temperature": 0.3
            ]
        ]
        
        guard let payloadData = try? JSONSerialization.data(withJSONObject: payload) else {
            completion(false, "Failed to create test request.")
            return
        }
        
        let host = "bedrock-runtime.\(region).amazonaws.com"
        guard let url = URL(string: "https://\(host)/model/\(modelId)/converse") else {
            completion(false, "Invalid endpoint URL.")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payloadData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, "Connection failed: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "Invalid response from server.")
                return
            }
            
            guard let data = data else {
                completion(false, "No data received from server.")
                return
            }
            
            if httpResponse.statusCode == 200 {
                // Try to parse response to ensure it's valid
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let output = json["output"] as? [String: Any],
                   let message = output["message"] as? [String: Any],
                   let content = message["content"] as? [[String: Any]],
                   !content.isEmpty {
                    completion(true, nil)
                } else {
                    completion(false, "Received unexpected response format.")
                }
            } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                completion(false, "Authentication failed. Please check your API key.")
            } else if httpResponse.statusCode == 404 {
                completion(false, "Model not found. Please check the model ID.")
            } else {
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                completion(false, "HTTP \(httpResponse.statusCode): \(errorString)")
            }
        }.resume()
    }

    func fetchOpenRouterModels() async {
        let url = URL(string: "https://openrouter.ai/api/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                await MainActor.run { 
                    self.openRouterModels = []
                    self.saveOpenRouterModels()
                    self.objectWillChange.send()
                }
                return
            }
            
            guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any], 
                  let dataArray = jsonResponse["data"] as? [[String: Any]] else {
                await MainActor.run { 
                    self.openRouterModels = []
                    self.saveOpenRouterModels()
                    self.objectWillChange.send()
                }
                return
            }
            
            let models = dataArray.compactMap { $0["id"] as? String }
            await MainActor.run { 
                self.openRouterModels = models.sorted()
                self.saveOpenRouterModels() // Save to UserDefaults
                if self.selectedProvider == .openRouter && self.currentModel == self.selectedProvider.defaultModel && !models.isEmpty {
                    self.selectModel(models.sorted().first!)
                }
                self.objectWillChange.send()
            }
            
        } catch {
            await MainActor.run { 
                self.openRouterModels = []
                self.saveOpenRouterModels()
                self.objectWillChange.send()
            }
        }

    }
}
