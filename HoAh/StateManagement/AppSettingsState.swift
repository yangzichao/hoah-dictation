import Foundation

/// Represents the complete application settings state
/// This struct contains all user-configurable settings that need to be persisted
/// Version is used for future migration support
struct AppSettingsState: Codable {
    // MARK: - Version
    
    /// Version number for migration support
    var version: Int = 1
    
    // MARK: - Application Settings
    
    /// Whether the user has completed the onboarding flow
    var hasCompletedOnboarding: Bool = false
    
    /// Interface language: "system", "en", or "zh-Hans"
    var appInterfaceLanguage: String = "system"
    
    /// Whether the app runs in menu bar only mode (hides dock icon)
    var isMenuBarOnly: Bool = false
    
    /// Whether the audio transcription tool is enabled
    var isTranscribeAudioEnabled: Bool = false
    
    // MARK: - Recorder Settings
    
    /// Recorder type: "mini" or "notch"
    var recorderType: String = "mini"
    
    /// Whether to preserve transcript in clipboard after recording
    var preserveTranscriptInClipboard: Bool = true
    
    // MARK: - Hotkey Settings
    
    /// Primary hotkey option: "none", "rightOption", "leftOption", etc.
    var selectedHotkey1: String = "rightOption"
    
    /// Secondary hotkey option: "none", "rightOption", "leftOption", etc.
    var selectedHotkey2: String = "none"
    
    /// Whether middle-click toggle is enabled
    var isMiddleClickToggleEnabled: Bool = false
    
    /// Middle-click activation delay in milliseconds (0-5000)
    var middleClickActivationDelay: Int = 200
    
    // MARK: - Audio Settings
    
    /// Whether sound feedback is enabled
    var isSoundFeedbackEnabled: Bool = true
    
    /// Whether to mute system audio during recording
    var isSystemMuteEnabled: Bool = true
    
    /// Whether to pause media playback during recording
    var isPauseMediaEnabled: Bool = false
    
    // MARK: - AI Enhancement Settings
    
    /// Whether AI enhancement is enabled
    var isAIEnhancementEnabled: Bool = false
    
    /// Selected prompt ID (UUID string)
    var selectedPromptId: String? = nil
    
    /// Whether to use clipboard context in AI enhancement
    var useClipboardContext: Bool = false
    
    /// Whether to use screen capture context in AI enhancement
    var useScreenCaptureContext: Bool = false

    
    /// User profile context for AI enhancement
    var userProfileContext: String = ""
    
    /// Whether prompt triggers are enabled
    var arePromptTriggersEnabled: Bool = true
    
    // MARK: - AI Provider Settings
    
    /// Selected AI provider: "gemini", "openAI", "anthropic", etc.
    var selectedAIProvider: String = "gemini"
    
    /// AWS Bedrock region
    var bedrockRegion: String = "us-east-1"
    
    /// AWS Bedrock model ID
    var bedrockModelId: String = "us.anthropic.claude-sonnet-4-5-20250929-v1:0"
    
    /// Custom provider base URL
    var customProviderBaseURL: String = ""
    
    /// Custom provider model name
    var customProviderModel: String = ""
    
    /// Selected models per provider (provider name -> model name)
    var selectedModels: [String: String] = [:]
    
    // MARK: - Validation
    
    /// Validates the settings state and returns validation result
    /// - Returns: ValidationResult indicating whether the state is valid and any errors found
    func validate() -> ValidationResult {
        var errors: [String] = []
        
        // Validate recorder type
        if recorderType != "mini" && recorderType != "notch" {
            errors.append("Invalid recorderType: \(recorderType). Must be 'mini' or 'notch'.")
        }
        
        // Validate language
        let validLanguages = ["system", "en", "zh-Hans"]
        if !validLanguages.contains(appInterfaceLanguage) {
            errors.append("Invalid appInterfaceLanguage: \(appInterfaceLanguage). Must be one of: \(validLanguages.joined(separator: ", ")).")
        }
        
        // Validate hotkey options
        let validHotkeys = ["none", "rightOption", "leftOption", "leftControl", 
                           "rightControl", "fn", "rightCommand", "rightShift", "custom"]
        if !validHotkeys.contains(selectedHotkey1) {
            errors.append("Invalid selectedHotkey1: \(selectedHotkey1). Must be one of: \(validHotkeys.joined(separator: ", ")).")
        }
        if !validHotkeys.contains(selectedHotkey2) {
            errors.append("Invalid selectedHotkey2: \(selectedHotkey2). Must be one of: \(validHotkeys.joined(separator: ", ")).")
        }
        
        // Validate hotkey conflict
        if selectedHotkey1 != "none" && selectedHotkey2 != "none" && selectedHotkey1 == selectedHotkey2 {
            errors.append("Hotkey conflict: selectedHotkey1 and selectedHotkey2 cannot be the same.")
        }
        
        // Validate delay range
        if middleClickActivationDelay < 0 || middleClickActivationDelay > 5000 {
            errors.append("Invalid middleClickActivationDelay: \(middleClickActivationDelay). Must be between 0 and 5000.")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    /// Returns a copy of this state with safe default values for any invalid settings
    /// This is used when loading corrupted or invalid settings from storage
    /// - Returns: A new AppSettingsState with safe defaults applied
    func withSafeDefaults() -> AppSettingsState {
        var safe = self
        
        // Fix recorder type
        if recorderType != "mini" && recorderType != "notch" {
            safe.recorderType = "mini"
        }
        
        // Fix language
        let validLanguages = ["system", "en", "zh-Hans"]
        if !validLanguages.contains(appInterfaceLanguage) {
            safe.appInterfaceLanguage = "system"
        }
        
        // Fix hotkeys
        let validHotkeys = ["none", "rightOption", "leftOption", "leftControl", 
                           "rightControl", "fn", "rightCommand", "rightShift", "custom"]
        if !validHotkeys.contains(selectedHotkey1) {
            safe.selectedHotkey1 = "rightOption"
        }
        if !validHotkeys.contains(selectedHotkey2) {
            safe.selectedHotkey2 = "none"
        }
        
        // Fix hotkey conflict
        if safe.selectedHotkey1 != "none" && safe.selectedHotkey2 != "none" && safe.selectedHotkey1 == safe.selectedHotkey2 {
            safe.selectedHotkey2 = "none"
        }
        
        // Fix delay
        if middleClickActivationDelay < 0 {
            safe.middleClickActivationDelay = 0
        } else if middleClickActivationDelay > 5000 {
            safe.middleClickActivationDelay = 5000
        }
        
        return safe
    }
}

/// Result of settings validation
struct ValidationResult {
    /// Whether the settings are valid
    let isValid: Bool
    
    /// List of validation errors (empty if valid)
    let errors: [String]
}
