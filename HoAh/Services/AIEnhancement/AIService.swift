import Foundation

enum AIProvider: String, CaseIterable {
    case cerebras = "Cerebras"
    case groq = "GROQ"
    case gemini = "Gemini"
    case anthropic = "Anthropic"
    case openAI = "OpenAI"
    case openRouter = "OpenRouter"
    case mistral = "Mistral"
    case elevenLabs = "ElevenLabs"
    case soniox = "Soniox"
    case custom = "Custom"
    case awsBedrock = "AWS Bedrock"
    
    
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
        case .mistral:
            return "https://api.mistral.ai/v1/chat/completions"
        case .elevenLabs:
            return "https://api.elevenlabs.io/v1/speech-to-text"
        case .soniox:
            return "https://api.soniox.com/v1"
        case .custom:
            return UserDefaults.standard.string(forKey: "customProviderBaseURL") ?? ""
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
        case .mistral:
            return "mistral-large-latest"
        case .elevenLabs:
            return "scribe_v2"
        case .soniox:
            return "stt-async-v3"
        case .custom:
            return UserDefaults.standard.string(forKey: "customProviderModel") ?? ""
        case .openRouter:
            return "openai/gpt-oss-120b"
        case .awsBedrock:
            return UserDefaults.standard.string(forKey: "AWSBedrockModelId") ?? "meta.llama3-70b-instruct-v1:0"
        }
    }
    
    var availableModels: [String] {
        switch self {
        case .cerebras:
            return [
                "gpt-oss-120b",
                "llama-3.1-8b",
                "llama-4-scout-17b-16e-instruct",
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
        case .mistral:
            return [
                "mistral-large-latest",
                "mistral-medium-latest",
                "mistral-small-latest",
                "mistral-saba-latest"
            ]
        case .elevenLabs:
            return ["scribe_v2", "scribe_v1_experimental"]
        case .soniox:
            return ["stt-async-v3"]
        case .custom:
            return []
        case .openRouter:
            return []
        case .awsBedrock:
            return []
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
}

class AIService: ObservableObject {
    @Published private(set) var apiKey: String = ""
    @Published var isAPIKeyValid: Bool = false
    
    // AWS Bedrock credentials/config
    @Published var bedrockApiKey: String = UserDefaults.standard.string(forKey: "AWSBedrockAPIKey") ?? "" {
        didSet { userDefaults.set(bedrockApiKey, forKey: "AWSBedrockAPIKey") }
    }
    @Published var bedrockRegion: String = UserDefaults.standard.string(forKey: "AWSBedrockRegion") ?? "us-east-1" {
        didSet { userDefaults.set(bedrockRegion, forKey: "AWSBedrockRegion") }
    }
    @Published var bedrockModelId: String = UserDefaults.standard.string(forKey: "AWSBedrockModelId") ?? "meta.llama3-70b-instruct-v1:0" {
        didSet { userDefaults.set(bedrockModelId, forKey: "AWSBedrockModelId") }
    }
    @Published var customBaseURL: String = UserDefaults.standard.string(forKey: "customProviderBaseURL") ?? "" {
        didSet {
            userDefaults.set(customBaseURL, forKey: "customProviderBaseURL")
        }
    }
    @Published var customModel: String = UserDefaults.standard.string(forKey: "customProviderModel") ?? "" {
        didSet {
            userDefaults.set(customModel, forKey: "customProviderModel")
        }
    }
    @Published var selectedProvider: AIProvider {
        didSet {
            userDefaults.set(selectedProvider.rawValue, forKey: "selectedAIProvider")
            refreshAPIKeyState()
            NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
        }
    }
    
    @Published private var selectedModels: [AIProvider: String] = [:]
    private let userDefaults = UserDefaults.standard
    private let keyManager = CloudAPIKeyManager.shared
    
    @Published private var openRouterModels: [String] = []
    
    var connectedProviders: [AIProvider] {
        AIProvider.allCases.filter { provider in
            if provider.requiresAPIKey {
                if provider == .awsBedrock {
                    return !bedrockApiKey.isEmpty && !bedrockRegion.isEmpty && !bedrockModelId.isEmpty
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
        if let savedProvider = userDefaults.string(forKey: "selectedAIProvider"),
           let provider = AIProvider(rawValue: savedProvider) {
            self.selectedProvider = provider
        } else {
            self.selectedProvider = .gemini
        }
        
        refreshAPIKeyState()
        
        loadSavedModelSelections()
        loadSavedOpenRouterModels()
    }
    
    private func loadSavedModelSelections() {
        for provider in AIProvider.allCases {
            let key = "\(provider.rawValue)SelectedModel"
            if let savedModel = userDefaults.string(forKey: key), !savedModel.isEmpty {
                selectedModels[provider] = savedModel
            }
        }
    }
    
    private func loadSavedOpenRouterModels() {
        if let savedModels = userDefaults.array(forKey: "openRouterModels") as? [String] {
            openRouterModels = savedModels
        }
    }
    
    private func refreshAPIKeyState() {
        if selectedProvider.requiresAPIKey {
            if selectedProvider == .awsBedrock {
                self.apiKey = ""
                self.isAPIKeyValid = !bedrockApiKey.isEmpty && !bedrockRegion.isEmpty && !bedrockModelId.isEmpty
            } else {
                if let active = keyManager.activeKey(for: selectedProvider.rawValue) {
                    self.apiKey = active.value
                    self.isAPIKeyValid = true
                } else if let legacy = userDefaults.string(forKey: "\(selectedProvider.rawValue)APIKey"), !legacy.isEmpty {
                    // migrate legacy single key into manager
                    let entry = keyManager.addKey(legacy, for: selectedProvider.rawValue)
                    keyManager.selectKey(id: entry.id, for: selectedProvider.rawValue)
                    self.apiKey = entry.value
                    self.isAPIKeyValid = true
                } else {
                    self.apiKey = ""
                    self.isAPIKeyValid = false
                }
            }
        } else {
            self.apiKey = ""
            self.isAPIKeyValid = true
        }
    }
    
    private func saveOpenRouterModels() {
        userDefaults.set(openRouterModels, forKey: "openRouterModels")
    }
    
    func selectModel(_ model: String) {
        guard !model.isEmpty else { return }
        
        selectedModels[selectedProvider] = model
        let key = "\(selectedProvider.rawValue)SelectedModel"
        userDefaults.set(model, forKey: key)
        
        objectWillChange.send()
        NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
    }
    
    func saveAPIKey(_ key: String, completion: @escaping (Bool, String?) -> Void) {
        guard selectedProvider.requiresAPIKey else {
            completion(true, nil)
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
            completion(true, nil)
            return
        }
        
        switch selectedProvider {
        case .anthropic:
            verifyAnthropicAPIKey(key, completion: completion)
        case .elevenLabs:
            verifyElevenLabsAPIKey(key, completion: completion)
        case .mistral:
            verifyMistralAPIKey(key, completion: completion)
        case .soniox:
            verifySonioxAPIKey(key, completion: completion)
        default:
            verifyOpenAICompatibleAPIKey(key, completion: completion)
        }
    }
    
    func saveBedrockConfig(apiKey: String, region: String, modelId: String) {
        bedrockApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        bedrockRegion = region.trimmingCharacters(in: .whitespacesAndNewlines)
        bedrockModelId = modelId.trimmingCharacters(in: .whitespacesAndNewlines)
        isAPIKeyValid = !bedrockApiKey.isEmpty && !bedrockRegion.isEmpty && !bedrockModelId.isEmpty
        NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
    }
    
    func clearAPIKey() {
        if selectedProvider == .awsBedrock {
            bedrockApiKey = ""
            bedrockRegion = ""
            bedrockModelId = ""
        } else {
            keyManager.removeAllKeys(for: selectedProvider.rawValue)
            apiKey = ""
        }
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
    
    private func verifyElevenLabsAPIKey(_ key: String, completion: @escaping (Bool, String?) -> Void) {
        let url = URL(string: "https://api.elevenlabs.io/v1/user")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(key, forHTTPHeaderField: "xi-api-key")

        URLSession.shared.dataTask(with: request) { data, response, _ in
            let isValid = (response as? HTTPURLResponse)?.statusCode == 200

            if let data = data, let body = String(data: data, encoding: .utf8) {
                if !isValid {
                    completion(false, body)
                    return
                }
            }

            completion(isValid, nil)
        }.resume()
    }
    
    private func verifyMistralAPIKey(_ key: String, completion: @escaping (Bool, String?) -> Void) {
        let url = URL(string: "https://api.mistral.ai/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    completion(true, nil)
                } else {
                    if let data = data, let body = String(data: data, encoding: .utf8) {
                        completion(false, body)
                    } else {
                        completion(false, nil)
                    }
                }
            } else {
                completion(false, nil)
            }
        }.resume()
    }

    private func verifySonioxAPIKey(_ key: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "https://api.soniox.com/v1/files") else {
            completion(false, nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
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
