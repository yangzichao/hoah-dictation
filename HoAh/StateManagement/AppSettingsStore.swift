import Foundation
import SwiftUI
import OSLog

/// Central store for all application settings
/// This is the single source of truth for user-configurable settings
/// All UI components should read from and write to this store
/// 
/// State Management Rule: To modify any application setting, update properties in this store.
/// Do not use @AppStorage or direct UserDefaults access elsewhere in the app.
@MainActor
class AppSettingsStore: ObservableObject {
    
    // MARK: - Published Properties
    
    // Application Settings
    
    /// Whether the user has completed the onboarding flow
    @Published var hasCompletedOnboarding: Bool {
        didSet { saveSettings() }
    }
    
    /// Interface language: "system", "en", or "zh-Hans"
    @Published var appInterfaceLanguage: String {
        didSet { 
            validateLanguage()
            saveSettings() 
        }
    }
    
    /// Whether the app runs in menu bar only mode (hides dock icon)
    @Published var isMenuBarOnly: Bool {
        didSet { saveSettings() }
    }
    
    /// Whether the audio transcription tool is enabled
    @Published var isTranscribeAudioEnabled: Bool {
        didSet { saveSettings() }
    }
    
    // Recorder Settings
    
    /// Recorder type: "mini" or "notch"
    @Published var recorderType: String {
        didSet { 
            validateRecorderType()
            saveSettings() 
        }
    }
    
    /// Whether to preserve transcript in clipboard after recording
    @Published var preserveTranscriptInClipboard: Bool {
        didSet { saveSettings() }
    }
    
    // Hotkey Settings
    
    /// Primary hotkey option
    @Published var selectedHotkey1: String {
        didSet { 
            validateHotkeys()
            saveSettings() 
        }
    }
    
    /// Secondary hotkey option
    @Published var selectedHotkey2: String {
        didSet { 
            validateHotkeys()
            saveSettings() 
        }
    }
    
    /// Whether middle-click toggle is enabled
    @Published var isMiddleClickToggleEnabled: Bool {
        didSet { saveSettings() }
    }
    
    /// Middle-click activation delay in milliseconds (0-5000)
    @Published var middleClickActivationDelay: Int {
        didSet { 
            validateDelay()
            saveSettings() 
        }
    }
    
    // Audio Settings
    
    /// Whether sound feedback is enabled
    @Published var isSoundFeedbackEnabled: Bool {
        didSet { saveSettings() }
    }
    
    /// Whether to mute system audio during recording
    @Published var isSystemMuteEnabled: Bool {
        didSet { saveSettings() }
    }
    
    /// Whether to pause media playback during recording
    @Published var isPauseMediaEnabled: Bool {
        didSet { saveSettings() }
    }
    
    // AI Enhancement Settings
    
    /// Whether AI enhancement is enabled
    @Published var isAIEnhancementEnabled: Bool {
        didSet { 
            handleAIEnhancementChange()
            saveSettings() 
        }
    }
    
    /// Selected prompt ID (UUID string)
    @Published var selectedPromptId: String? {
        didSet { saveSettings() }
    }
    
    /// Whether to use clipboard context in AI enhancement
    @Published var useClipboardContext: Bool {
        didSet { saveSettings() }
    }
    
    /// Whether to use screen capture context in AI enhancement
    @Published var useScreenCaptureContext: Bool {
        didSet { saveSettings() }
    }
    
    /// User profile context for AI enhancement
    @Published var userProfileContext: String {
        didSet { saveSettings() }
    }
    
    /// Whether prompt triggers are enabled
    @Published var arePromptTriggersEnabled: Bool {
        didSet { saveSettings() }
    }
    
    // Smart Scene State (runtime, not persisted directly)
    
    /// Currently active Smart Scene ID
    @Published var activeSmartSceneId: String? = nil
    
    /// Whether Smart Scene is overriding user settings
    @Published var isSmartSceneOverrideActive: Bool = false
    
    // AI Provider Settings
    
    /// Selected AI provider
    @Published var selectedAIProvider: String {
        didSet { 
            validateProvider()
            saveSettings() 
        }
    }
    
    /// AWS Bedrock region
    @Published var bedrockRegion: String {
        didSet { saveSettings() }
    }
    
    /// AWS Bedrock model ID
    @Published var bedrockModelId: String {
        didSet { saveSettings() }
    }
    
    /// Custom provider base URL
    @Published var customProviderBaseURL: String {
        didSet { saveSettings() }
    }
    
    /// Custom provider model name
    @Published var customProviderModel: String {
        didSet { saveSettings() }
    }
    
    /// Selected models per provider (provider name -> model name)
    @Published var selectedModels: [String: String] {
        didSet { saveSettings() }
    }
    
    // MARK: - Computed Properties
    
    /// The effective AI enhancement state, considering Smart Scene overrides
    /// Use this property in business logic instead of isAIEnhancementEnabled
    var effectiveAIEnhancementEnabled: Bool {
        if isSmartSceneOverrideActive {
            // Smart Scene overrides user setting
            // TODO: Read from Smart Scene config when implementing Smart Scene integration
            return true
        }
        return isAIEnhancementEnabled
    }
    
    /// Whether the recorder is properly configured with at least one hotkey
    var isRecorderConfigured: Bool {
        return selectedHotkey1 != "none" || selectedHotkey2 != "none"
    }
    
    // MARK: - Storage
    
    private let storage: SettingsStorage
    private let logger = Logger(subsystem: "com.yangzichao.hoah", category: "AppSettingsStore")
    
    // MARK: - Initialization
    
    /// Initializes the settings store with the specified storage backend
    /// - Parameter storage: Storage implementation (defaults to UserDefaultsStorage)
    init(storage: SettingsStorage = UserDefaultsStorage()) {
        self.storage = storage
        
        // Load settings from storage or use defaults
        let state = storage.load() ?? AppSettingsState()
        
        // Initialize all @Published properties
        self.hasCompletedOnboarding = state.hasCompletedOnboarding
        self.appInterfaceLanguage = state.appInterfaceLanguage
        self.isMenuBarOnly = state.isMenuBarOnly
        self.isTranscribeAudioEnabled = state.isTranscribeAudioEnabled
        self.recorderType = state.recorderType
        self.preserveTranscriptInClipboard = state.preserveTranscriptInClipboard
        self.selectedHotkey1 = state.selectedHotkey1
        self.selectedHotkey2 = state.selectedHotkey2
        self.isMiddleClickToggleEnabled = state.isMiddleClickToggleEnabled
        self.middleClickActivationDelay = state.middleClickActivationDelay
        self.isSoundFeedbackEnabled = state.isSoundFeedbackEnabled
        self.isSystemMuteEnabled = state.isSystemMuteEnabled
        self.isPauseMediaEnabled = state.isPauseMediaEnabled
        self.isAIEnhancementEnabled = state.isAIEnhancementEnabled
        self.selectedPromptId = state.selectedPromptId
        self.useClipboardContext = state.useClipboardContext
        self.useScreenCaptureContext = state.useScreenCaptureContext
        self.userProfileContext = state.userProfileContext
        self.arePromptTriggersEnabled = state.arePromptTriggersEnabled
        self.selectedAIProvider = state.selectedAIProvider
        self.bedrockRegion = state.bedrockRegion
        self.bedrockModelId = state.bedrockModelId
        self.customProviderBaseURL = state.customProviderBaseURL
        self.customProviderModel = state.customProviderModel
        self.selectedModels = state.selectedModels
        
        logger.info("AppSettingsStore initialized")
    }
    
    // MARK: - Validation Methods
    
    /// Validates language setting and corrects if invalid
    private func validateLanguage() {
        let validLanguages = ["system", "en", "zh-Hans"]
        if !validLanguages.contains(appInterfaceLanguage) {
            logger.warning("Invalid language '\(self.appInterfaceLanguage)', resetting to 'system'")
            appInterfaceLanguage = "system"
        }
    }
    
    /// Validates recorder type and corrects if invalid
    private func validateRecorderType() {
        if recorderType != "mini" && recorderType != "notch" {
            logger.warning("Invalid recorder type '\(self.recorderType)', resetting to 'mini'")
            recorderType = "mini"
        }
    }
    
    /// Validates hotkey settings and resolves conflicts
    /// Ensures hotkey1 and hotkey2 are not the same (except "none")
    private func validateHotkeys() {
        // Check for conflicts between hotkey1 and hotkey2
        if selectedHotkey1 != "none" && 
           selectedHotkey2 != "none" && 
           selectedHotkey1 == selectedHotkey2 {
            logger.warning("Hotkey conflict detected, disabling hotkey2")
            selectedHotkey2 = "none"
        }
    }
    
    /// Validates delay and corrects if out of range (0-5000ms)
    private func validateDelay() {
        if middleClickActivationDelay < 0 {
            logger.warning("Negative delay detected, setting to 0")
            middleClickActivationDelay = 0
        } else if middleClickActivationDelay > 5000 {
            logger.warning("Delay too large, setting to 5000")
            middleClickActivationDelay = 5000
        }
    }
    
    /// Validates AI provider and corrects if invalid
    private func validateProvider() {
        let validProviders = ["AWS Bedrock", "Cerebras", "GROQ", "Gemini", "Anthropic", 
                             "OpenAI", "OpenRouter", "Mistral", "ElevenLabs", "Soniox", "Custom"]
        if !validProviders.contains(selectedAIProvider) {
            logger.warning("Invalid provider '\(self.selectedAIProvider)', resetting to 'gemini'")
            selectedAIProvider = "gemini"
        }
    }
    
    /// Handles AI enhancement state change
    /// Ensures consistent state (e.g., disables triggers when AI is disabled)
    private func handleAIEnhancementChange() {
        // If enabling AI but no prompt selected, log warning
        // Coordinator will handle selecting default prompt
        if isAIEnhancementEnabled && selectedPromptId == nil {
            logger.info("AI enabled without prompt, coordinator will select default")
        }
        
        // If disabling AI, also disable prompt triggers
        if !isAIEnhancementEnabled && arePromptTriggersEnabled {
            logger.info("Disabling prompt triggers with AI enhancement")
            arePromptTriggersEnabled = false
        }
    }

    
    // MARK: - Batch Update Methods
    
    /// Updates AI settings atomically to avoid intermediate invalid states
    /// - Parameters:
    ///   - enabled: Whether to enable AI enhancement
    ///   - promptId: The prompt ID to use (optional)
    func updateAISettings(enabled: Bool, promptId: String?) {
        var finalPromptId = promptId
        
        // Validate: if enabling, should have a prompt
        if enabled && finalPromptId == nil {
            logger.warning("Enabling AI without prompt, coordinator should provide default")
        }
        
        // Atomic update (no intermediate state)
        isAIEnhancementEnabled = enabled
        selectedPromptId = finalPromptId
        
        logger.info("AI settings updated: enabled=\(enabled), promptId=\(finalPromptId ?? "nil")")
    }
    
    /// Updates hotkey settings with automatic conflict resolution
    /// - Parameters:
    ///   - hotkey1: Primary hotkey
    ///   - hotkey2: Secondary hotkey
    func updateHotkeySettings(hotkey1: String, hotkey2: String) {
        var finalHotkey2 = hotkey2
        
        // Resolve conflicts: hotkey1 and hotkey2 cannot be the same
        if hotkey1 != "none" && hotkey2 != "none" && hotkey1 == hotkey2 {
            logger.warning("Hotkey conflict, setting hotkey2 to none")
            finalHotkey2 = "none"
        }
        
        // Atomic update
        selectedHotkey1 = hotkey1
        selectedHotkey2 = finalHotkey2
        
        logger.info("Hotkey settings updated: hotkey1=\(hotkey1), hotkey2=\(finalHotkey2)")
    }
    
    // MARK: - Smart Scene Support
    
    /// Begins a Smart Scene session with configuration override
    /// User's base settings remain unchanged and will be restored when session ends
    /// - Parameters:
    ///   - sceneId: Unique identifier for the Smart Scene
    ///   - config: Smart Scene configuration (applied by Coordinator)
    func beginSmartSceneSession(sceneId: String) {
        logger.info("Beginning Smart Scene session: \(sceneId)")
        
        activeSmartSceneId = sceneId
        isSmartSceneOverrideActive = true
        
        // Note: Smart Scene config is applied by Coordinator
        // User's base settings remain unchanged
    }
    
    /// Ends the Smart Scene session and restores user settings
    /// User settings are automatically restored since they were never changed
    func endSmartSceneSession() {
        guard let sceneId = activeSmartSceneId else { return }
        
        logger.info("Ending Smart Scene session: \(sceneId)")
        
        activeSmartSceneId = nil
        isSmartSceneOverrideActive = false
        
        // User settings are automatically restored (they were never changed)
    }
    
    // MARK: - Private Methods
    
    /// Loads settings from state, applying validation and safe defaults if needed
    /// - Parameter state: The state to load
    private func loadFromState(_ state: AppSettingsState) {
        // Validate before loading
        let validation = state.validate()
        if !validation.isValid {
            logger.warning("Invalid settings detected: \(validation.errors.joined(separator: ", "))")
            let safeState = state.withSafeDefaults()
            applyState(safeState)
        } else {
            applyState(state)
        }
    }
    
    /// Applies state to all published properties
    /// Note: This is called during initialization, so didSet handlers won't trigger saves
    /// - Parameter state: The state to apply
    private func applyState(_ state: AppSettingsState) {
        hasCompletedOnboarding = state.hasCompletedOnboarding
        appInterfaceLanguage = state.appInterfaceLanguage
        isMenuBarOnly = state.isMenuBarOnly
        isTranscribeAudioEnabled = state.isTranscribeAudioEnabled
        recorderType = state.recorderType
        preserveTranscriptInClipboard = state.preserveTranscriptInClipboard
        selectedHotkey1 = state.selectedHotkey1
        selectedHotkey2 = state.selectedHotkey2
        isMiddleClickToggleEnabled = state.isMiddleClickToggleEnabled
        middleClickActivationDelay = state.middleClickActivationDelay
        isSoundFeedbackEnabled = state.isSoundFeedbackEnabled
        isSystemMuteEnabled = state.isSystemMuteEnabled
        isPauseMediaEnabled = state.isPauseMediaEnabled
        isAIEnhancementEnabled = state.isAIEnhancementEnabled
        selectedPromptId = state.selectedPromptId
        useClipboardContext = state.useClipboardContext
        useScreenCaptureContext = state.useScreenCaptureContext
        userProfileContext = state.userProfileContext
        arePromptTriggersEnabled = state.arePromptTriggersEnabled
        selectedAIProvider = state.selectedAIProvider
        bedrockRegion = state.bedrockRegion
        bedrockModelId = state.bedrockModelId
        customProviderBaseURL = state.customProviderBaseURL
        customProviderModel = state.customProviderModel
        selectedModels = state.selectedModels
    }
    
    /// Saves current settings to storage
    private func saveSettings() {
        let state = currentState()
        storage.save(state)
    }
    
    /// Creates an AppSettingsState from current property values
    /// - Returns: Current state snapshot
    private func currentState() -> AppSettingsState {
        return AppSettingsState(
            hasCompletedOnboarding: hasCompletedOnboarding,
            appInterfaceLanguage: appInterfaceLanguage,
            isMenuBarOnly: isMenuBarOnly,
            isTranscribeAudioEnabled: isTranscribeAudioEnabled,
            recorderType: recorderType,
            preserveTranscriptInClipboard: preserveTranscriptInClipboard,
            selectedHotkey1: selectedHotkey1,
            selectedHotkey2: selectedHotkey2,
            isMiddleClickToggleEnabled: isMiddleClickToggleEnabled,
            middleClickActivationDelay: middleClickActivationDelay,
            isSoundFeedbackEnabled: isSoundFeedbackEnabled,
            isSystemMuteEnabled: isSystemMuteEnabled,
            isPauseMediaEnabled: isPauseMediaEnabled,
            isAIEnhancementEnabled: isAIEnhancementEnabled,
            selectedPromptId: selectedPromptId,
            useClipboardContext: useClipboardContext,
            useScreenCaptureContext: useScreenCaptureContext,
            userProfileContext: userProfileContext,
            arePromptTriggersEnabled: arePromptTriggersEnabled,
            selectedAIProvider: selectedAIProvider,
            bedrockRegion: bedrockRegion,
            bedrockModelId: bedrockModelId,
            customProviderBaseURL: customProviderBaseURL,
            customProviderModel: customProviderModel,
            selectedModels: selectedModels
        )
    }
}
