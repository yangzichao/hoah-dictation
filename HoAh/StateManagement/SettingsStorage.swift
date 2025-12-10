import Foundation
import OSLog

/// Protocol for settings persistence
/// Implementations can use UserDefaults, files, or other storage mechanisms
protocol SettingsStorage {
    /// Loads settings from storage
    /// - Returns: AppSettingsState if found, nil otherwise
    func load() -> AppSettingsState?
    
    /// Saves settings to storage
    /// - Parameter state: The settings state to save
    func save(_ state: AppSettingsState)
}

/// UserDefaults-based implementation of SettingsStorage
/// Handles both new format and legacy settings migration
class UserDefaultsStorage: SettingsStorage {
    private let key = "AppSettingsState_v1"
    private let userDefaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.yangzichao.hoah", category: "SettingsStorage")
    
    func load() -> AppSettingsState? {
        // Try to load from new key first
        if let data = userDefaults.data(forKey: key),
           let state = try? JSONDecoder().decode(AppSettingsState.self, from: data) {
            logger.info("Loaded settings from storage (version \(state.version))")
            return state
        }
        
        // Migrate from legacy keys
        logger.info("No existing settings found, attempting legacy migration")
        return migrateLegacySettings()
    }
    
    func save(_ state: AppSettingsState) {
        do {
            let data = try JSONEncoder().encode(state)
            userDefaults.set(data, forKey: key)
            logger.debug("Settings saved successfully")
        } catch {
            logger.error("Failed to save settings: \(error.localizedDescription)")
        }
    }
    
    /// Migrates settings from legacy UserDefaults keys to new format
    /// This ensures users don't lose their settings when upgrading
    /// - Returns: Migrated AppSettingsState or nil if no legacy settings found
    private func migrateLegacySettings() -> AppSettingsState? {
        logger.info("Migrating legacy settings...")
        
        var state = AppSettingsState()
        var foundAnyLegacySettings = false
        
        // Migrate application settings
        if let onboarding = userDefaults.object(forKey: "HasCompletedOnboarding") as? Bool {
            state.hasCompletedOnboarding = onboarding
            foundAnyLegacySettings = true
        }
        
        if let language = userDefaults.string(forKey: "AppInterfaceLanguage") {
            state.appInterfaceLanguage = language
            foundAnyLegacySettings = true
        }
        
        if let menuBarOnly = userDefaults.object(forKey: "IsMenuBarOnly") as? Bool {
            state.isMenuBarOnly = menuBarOnly
            foundAnyLegacySettings = true
        }
        
        if let transcribeEnabled = userDefaults.object(forKey: "isTranscribeAudioEnabled") as? Bool {
            state.isTranscribeAudioEnabled = transcribeEnabled
            foundAnyLegacySettings = true
        }
        
        // Migrate recorder settings
        if let recorderType = userDefaults.string(forKey: "RecorderType") {
            state.recorderType = recorderType
            foundAnyLegacySettings = true
        }
        
        if let preserveClipboard = userDefaults.object(forKey: "preserveTranscriptInClipboard") as? Bool {
            state.preserveTranscriptInClipboard = preserveClipboard
            foundAnyLegacySettings = true
        }
        
        // Migrate hotkey settings
        if let hotkey1 = userDefaults.string(forKey: "selectedHotkey1") {
            state.selectedHotkey1 = hotkey1
            foundAnyLegacySettings = true
        }
        
        if let hotkey2 = userDefaults.string(forKey: "selectedHotkey2") {
            state.selectedHotkey2 = hotkey2
            foundAnyLegacySettings = true
        }
        
        if let middleClick = userDefaults.object(forKey: "isMiddleClickToggleEnabled") as? Bool {
            state.isMiddleClickToggleEnabled = middleClick
            foundAnyLegacySettings = true
        }
        
        if let delay = userDefaults.object(forKey: "middleClickActivationDelay") as? Int {
            state.middleClickActivationDelay = delay
            foundAnyLegacySettings = true
        }
        
        // Migrate audio settings
        if let soundEnabled = userDefaults.object(forKey: "isSoundFeedbackEnabled") as? Bool {
            state.isSoundFeedbackEnabled = soundEnabled
            foundAnyLegacySettings = true
        }
        
        if let systemMute = userDefaults.object(forKey: "isSystemMuteEnabled") as? Bool {
            state.isSystemMuteEnabled = systemMute
            foundAnyLegacySettings = true
        }
        
        if let pauseMedia = userDefaults.object(forKey: "isPauseMediaEnabled") as? Bool {
            state.isPauseMediaEnabled = pauseMedia
            foundAnyLegacySettings = true
        }
        
        // Migrate AI enhancement settings
        if let aiEnabled = userDefaults.object(forKey: "isAIEnhancementEnabled") as? Bool {
            state.isAIEnhancementEnabled = aiEnabled
            foundAnyLegacySettings = true
        }
        
        if let promptId = userDefaults.string(forKey: "selectedPromptId") {
            state.selectedPromptId = promptId
            foundAnyLegacySettings = true
        }
        
        if let clipboardContext = userDefaults.object(forKey: "useClipboardContext") as? Bool {
            state.useClipboardContext = clipboardContext
            foundAnyLegacySettings = true
        }
        
        if let screenContext = userDefaults.object(forKey: "useScreenCaptureContext") as? Bool {
            state.useScreenCaptureContext = screenContext
            foundAnyLegacySettings = true
        }
        
        if let profile = userDefaults.string(forKey: "userProfileContext") {
            state.userProfileContext = profile
            foundAnyLegacySettings = true
        }
        
        if let triggers = userDefaults.object(forKey: "arePromptTriggersEnabled") as? Bool {
            state.arePromptTriggersEnabled = triggers
            foundAnyLegacySettings = true
        }
        
        // Migrate AI provider settings
        if let provider = userDefaults.string(forKey: "selectedAIProvider") {
            state.selectedAIProvider = provider
            foundAnyLegacySettings = true
        }
        
        if let region = userDefaults.string(forKey: "AWSBedrockRegion") {
            state.bedrockRegion = region
            foundAnyLegacySettings = true
        }
        
        if let modelId = userDefaults.string(forKey: "AWSBedrockModelId") {
            state.bedrockModelId = modelId
            foundAnyLegacySettings = true
        }
        
        if let baseURL = userDefaults.string(forKey: "customProviderBaseURL") {
            state.customProviderBaseURL = baseURL
            foundAnyLegacySettings = true
        }
        
        if let model = userDefaults.string(forKey: "customProviderModel") {
            state.customProviderModel = model
            foundAnyLegacySettings = true
        }
        
        // Migrate selected models per provider
        // Note: We need to check all possible providers
        let providerNames = ["AWS Bedrock", "Cerebras", "GROQ", "Gemini", "Anthropic", 
                            "OpenAI", "OpenRouter", "ElevenLabs", "Custom"]
        for providerName in providerNames {
            let key = "\(providerName)SelectedModel"
            if let model = userDefaults.string(forKey: key) {
                state.selectedModels[providerName] = model
                foundAnyLegacySettings = true
            }
        }
        
        // Only return migrated state if we found any legacy settings
        guard foundAnyLegacySettings else {
            logger.info("No legacy settings found")
            return nil
        }
        
        logger.info("Legacy settings migration completed")
        
        // Save migrated settings to new format
        save(state)
        
        return state
    }
}
