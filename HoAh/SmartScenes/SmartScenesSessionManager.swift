import Foundation
import AppKit

struct ApplicationState: Codable {
    var isEnhancementEnabled: Bool
    var selectedPromptId: String?
    var selectedAIProvider: String?
    var selectedAIModel: String?
    var selectedLanguage: String?
    var transcriptionModelName: String?
}

struct SmartSceneSession: Codable {
    let id: UUID
    let startTime: Date
    var originalState: ApplicationState
}

// Smart Scene uses session methods to override settings without modifying user preferences
@MainActor
class SmartSceneSessionManager {
    static let shared = SmartSceneSessionManager()
    private let sessionKey = "smartSceneActiveSession.v1"
    private var isApplyingSmartSceneConfig = false

    private var whisperState: WhisperState?
    private var enhancementService: AIEnhancementService?
    private var appSettings: AppSettingsStore?

    private init() {
        recoverSession()
    }

    func configure(whisperState: WhisperState, enhancementService: AIEnhancementService, appSettings: AppSettingsStore? = nil) {
        self.whisperState = whisperState
        self.enhancementService = enhancementService
        self.appSettings = appSettings
    }

    func beginSession(with config: SmartSceneConfig) async {
        guard let whisperState = whisperState, let enhancementService = enhancementService else {
            print("SessionManager not configured.")
            return
        }

        let originalState = ApplicationState(
            isEnhancementEnabled: enhancementService.isEnhancementEnabled,
            selectedPromptId: enhancementService.selectedPromptId?.uuidString,
            selectedAIProvider: enhancementService.getAIService()?.selectedProvider.rawValue,
            selectedAIModel: enhancementService.getAIService()?.currentModel,
            selectedLanguage: UserDefaults.standard.string(forKey: "SelectedLanguage"),
            transcriptionModelName: whisperState.currentTranscriptionModel?.name
        )

        let newSession = SmartSceneSession(
            id: UUID(),
            startTime: Date(),
            originalState: originalState
        )
        saveSession(newSession)
        
        // Notify AppSettingsStore that Smart Scene is active
        appSettings?.beginSmartSceneSession(sceneId: config.id.uuidString)
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateSessionSnapshot), name: .AppSettingsDidChange, object: nil)

        isApplyingSmartSceneConfig = true
        await applyConfiguration(config)
        isApplyingSmartSceneConfig = false
    }

    func endSession() async {
        guard let session = loadSession() else { return }

        isApplyingSmartSceneConfig = true
        await restoreState(session.originalState)
        isApplyingSmartSceneConfig = false
        
        // Notify AppSettingsStore that Smart Scene is no longer active
        appSettings?.endSmartSceneSession()
        
        NotificationCenter.default.removeObserver(self, name: .AppSettingsDidChange, object: nil)

        clearSession()
    }
    
    @objc func updateSessionSnapshot() {
        guard !isApplyingSmartSceneConfig else { return }
        
        guard var session = loadSession(), let whisperState = whisperState, let enhancementService = enhancementService else { return }

        let updatedState = ApplicationState(
            isEnhancementEnabled: enhancementService.isEnhancementEnabled,
            selectedPromptId: enhancementService.selectedPromptId?.uuidString,
            selectedAIProvider: enhancementService.getAIService()?.selectedProvider.rawValue,
            selectedAIModel: enhancementService.getAIService()?.currentModel,
            selectedLanguage: UserDefaults.standard.string(forKey: "SelectedLanguage"),
            transcriptionModelName: whisperState.currentTranscriptionModel?.name
        )
        
        session.originalState = updatedState
        saveSession(session)
    }

    private func applyConfiguration(_ config: SmartSceneConfig) async {
        guard let enhancementService = enhancementService else { return }

        await MainActor.run {
            enhancementService.isEnhancementEnabled = config.isAIEnhancementEnabled

            if config.isAIEnhancementEnabled {
                if let promptId = config.selectedPrompt, let uuid = UUID(uuidString: promptId) {
                    enhancementService.selectedPromptId = uuid
                }

                if let aiService = enhancementService.getAIService() {
                    if let providerName = config.selectedAIProvider, let provider = AIProvider(rawValue: providerName) {
                        aiService.selectedProvider = provider
                    }
                    if let model = config.selectedAIModel {
                        aiService.selectModel(model)
                    }
                }
            }

            if let language = config.selectedLanguage {
                UserDefaults.standard.set(language, forKey: "SelectedLanguage")
                NotificationCenter.default.post(name: .languageDidChange, object: nil)
            }
        }

        if let whisperState = whisperState,
           let modelName = config.selectedTranscriptionModelName,
           let selectedModel = await whisperState.allAvailableModels.first(where: { $0.name == modelName }),
           whisperState.currentTranscriptionModel?.name != modelName {
            await handleModelChange(to: selectedModel)
        }
        
        await MainActor.run {
            NotificationCenter.default.post(name: .smartSceneConfigurationApplied, object: nil)
        }
    }

    private func restoreState(_ state: ApplicationState) async {
        guard let enhancementService = enhancementService else { return }

        await MainActor.run {
            enhancementService.isEnhancementEnabled = state.isEnhancementEnabled
            enhancementService.selectedPromptId = state.selectedPromptId.flatMap(UUID.init)

            if let aiService = enhancementService.getAIService() {
                if let providerName = state.selectedAIProvider, let provider = AIProvider(rawValue: providerName) {
                    aiService.selectedProvider = provider
                }
                if let model = state.selectedAIModel {
                    aiService.selectModel(model)
                }
            }

            if let language = state.selectedLanguage {
                UserDefaults.standard.set(language, forKey: "SelectedLanguage")
                NotificationCenter.default.post(name: .languageDidChange, object: nil)
            }
        }

        if let whisperState = whisperState,
           let modelName = state.transcriptionModelName,
           let selectedModel = await whisperState.allAvailableModels.first(where: { $0.name == modelName }),
           whisperState.currentTranscriptionModel?.name != modelName {
            await handleModelChange(to: selectedModel)
        }
    }
    
    private func handleModelChange(to newModel: any TranscriptionModel) async {
        guard let whisperState = whisperState else { return }

        await whisperState.setDefaultTranscriptionModel(newModel)

        switch newModel.provider {
        case .local:
            await whisperState.cleanupModelResources()
            if let localModel = await whisperState.availableModels.first(where: { $0.name == newModel.name }) {
                do {
                    try await whisperState.loadModel(localModel)
                } catch {
                    print("Power Mode: Failed to load local model '\(localModel.name)': \(error)")
                }
            }
        default:
            await whisperState.cleanupModelResources()
        }
    }
    
    private func recoverSession() {
        guard let session = loadSession() else { return }
        print("Recovering abandoned Power Mode session.")
        Task {
            await endSession()
        }
    }

    private func saveSession(_ session: SmartSceneSession) {
        do {
            let data = try JSONEncoder().encode(session)
            UserDefaults.standard.set(data, forKey: sessionKey)
        } catch {
            print("Error saving Power Mode session: \(error)")
        }
    }
    
    private func loadSession() -> SmartSceneSession? {
        guard let data = UserDefaults.standard.data(forKey: sessionKey) else { return nil }
        do {
            return try JSONDecoder().decode(SmartSceneSession.self, from: data)
        } catch {
            print("Error loading Power Mode session: \(error)")
            return nil
        }
    }

    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }
}
