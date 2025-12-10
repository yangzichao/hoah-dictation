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
    
    // MARK: - Data Structures

    struct SettingsOverride {
        var language: String?
        var isAIEnhancementEnabled: Bool?
        var selectedPromptId: String?
        var selectedAIProvider: String?
        var selectedAIModel: String?
    }
    
    // MARK: - Published Properties
    
    // Application Settings
    
    /// Whether the user has completed the onboarding flow
    @Published var hasCompletedOnboarding: Bool {
        didSet { saveSettings() }
    }
    
    // Storage for Interface Language
    @Published private var _appInterfaceLanguage: String
    
    /// Interface language: "system", "en", or "zh-Hans"
    var appInterfaceLanguage: String {
        get { activeOverride?.language ?? _appInterfaceLanguage }
        set {
            _appInterfaceLanguage = newValue
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
    
    // Storage for AI Enhancement
    @Published private var _isAIEnhancementEnabled: Bool
    
    /// Whether AI enhancement is enabled
    var isAIEnhancementEnabled: Bool {
        get { activeOverride?.isAIEnhancementEnabled ?? _isAIEnhancementEnabled }
        set {
            _isAIEnhancementEnabled = newValue
            handleAIEnhancementChange()
            saveSettings()
        }
    }
    
    // Storage for Selected Prompt ID
    @Published private var _selectedPromptId: String?
    
    /// Selected prompt ID (UUID string)
    var selectedPromptId: String? {
        get { activeOverride?.selectedPromptId ?? _selectedPromptId }
        set {
            _selectedPromptId = newValue
            saveSettings()
        }
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
    
    /// Active override settings from Smart Scene (Layer 2)
    @Published var activeOverride: SettingsOverride? = nil {
        didSet { objectWillChange.send() }
    }
    
    // AI Provider Settings
    
    // Storage for Selected AI Provider
    @Published private var _selectedAIProvider: String
    
    /// Selected AI provider
    var selectedAIProvider: String {
        get { activeOverride?.selectedAIProvider ?? _selectedAIProvider }
        set {
            _selectedAIProvider = newValue
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
    
    // Storage for Selected Models
    @Published private var _selectedModels: [String: String]
    
    /// Selected models per provider (provider name -> model name)
    var selectedModels: [String: String] {
        get {
             // Synthesize override model into the map if present
             if let overrideModel = activeOverride?.selectedAIModel, let provider = activeOverride?.selectedAIProvider {
                 var models = _selectedModels
                 models[provider] = overrideModel
                 return models
             }
             return _selectedModels
        }
        set {
            _selectedModels = newValue
            saveSettings()
        }
    }
    
    // MARK: - Computed Properties
    
    /// Whether the recorder is properly configured with at least one hotkey
    var isRecorderConfigured: Bool {
        return selectedHotkey1 != "none" || selectedHotkey2 != "none"
    }

    // Publishers for override-aware properties (use backing storage publishers)
    var appInterfaceLanguagePublisher: Published<String>.Publisher { $_appInterfaceLanguage }
    var isAIEnhancementEnabledPublisher: Published<Bool>.Publisher { $_isAIEnhancementEnabled }
    var selectedPromptIdPublisher: Published<String?>.Publisher { $_selectedPromptId }
    var selectedAIProviderPublisher: Published<String>.Publisher { $_selectedAIProvider }
    var selectedModelsPublisher: Published<[String: String]>.Publisher { $_selectedModels }
    
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
        self._appInterfaceLanguage = state.appInterfaceLanguage // Initialize storage
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
        self._isAIEnhancementEnabled = state.isAIEnhancementEnabled // Initialize storage
        self._selectedPromptId = state.selectedPromptId // Initialize storage
        self.useClipboardContext = state.useClipboardContext
        self.useScreenCaptureContext = state.useScreenCaptureContext
        self.userProfileContext = state.userProfileContext
        self.arePromptTriggersEnabled = state.arePromptTriggersEnabled
        self._selectedAIProvider = state.selectedAIProvider // Initialize storage
        self.bedrockRegion = state.bedrockRegion
        self.bedrockModelId = state.bedrockModelId
        self.customProviderBaseURL = state.customProviderBaseURL
        self.customProviderModel = state.customProviderModel
        self._selectedModels = state.selectedModels // Initialize storage
        
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
                             "OpenAI", "OpenRouter", "ElevenLabs", "Custom"]
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
    
    // MARK: - Smart Scene Management
    
    /// Applies a temporary override for Smart Scenes (Layer 2)
    /// This does NOT modify persistent settings
    func applySmartSceneOverride(_ override: SettingsOverride, sceneId: String) {
        logger.info("Applying Smart Scene override: \(sceneId)")
        self.activeOverride = override
        self.activeSmartSceneId = sceneId
        
        // Notify changes that might be observed via non-binding paths
        if override.language != nil {
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
        }
    }
    
    /// Clears the temporary override (Layer 2)
    func clearSmartSceneOverride() {
        guard let sceneId = activeSmartSceneId else { return }
        logger.info("Clearing Smart Scene override: \(sceneId)")
        
        self.activeOverride = nil
        self.activeSmartSceneId = nil
        
        // Notify to clear any language overrides
        NotificationCenter.default.post(name: .languageDidChange, object: nil)
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
    /// Note: This updates storage properties directly to avoid triggering saveSettings() multiple times via setters
    /// - Parameter state: The state to apply
    private func applyState(_ state: AppSettingsState) {
        hasCompletedOnboarding = state.hasCompletedOnboarding
        _appInterfaceLanguage = state.appInterfaceLanguage // Storage
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
        _isAIEnhancementEnabled = state.isAIEnhancementEnabled // Storage
        _selectedPromptId = state.selectedPromptId // Storage
        useClipboardContext = state.useClipboardContext
        useScreenCaptureContext = state.useScreenCaptureContext
        userProfileContext = state.userProfileContext
        arePromptTriggersEnabled = state.arePromptTriggersEnabled
        _selectedAIProvider = state.selectedAIProvider // Storage
        bedrockRegion = state.bedrockRegion
        bedrockModelId = state.bedrockModelId
        customProviderBaseURL = state.customProviderBaseURL
        customProviderModel = state.customProviderModel
        _selectedModels = state.selectedModels // Storage
    }
    
    // MARK: - Persistence
    
    /// Saves current settings to storage
    private func saveSettings() {
        let state = currentState()
        storage.save(state)
    }
    
    /// Creates an AppSettingsState from current property values
    /// - Returns: Current state snapshot using underlying STORAGE values (ignoring overrides)
    private func currentState() -> AppSettingsState {
        return AppSettingsState(
            hasCompletedOnboarding: hasCompletedOnboarding,
            appInterfaceLanguage: _appInterfaceLanguage,
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
            isAIEnhancementEnabled: _isAIEnhancementEnabled,
            selectedPromptId: _selectedPromptId,
            useClipboardContext: useClipboardContext,
            useScreenCaptureContext: useScreenCaptureContext,
            userProfileContext: userProfileContext,
            arePromptTriggersEnabled: arePromptTriggersEnabled,
            selectedAIProvider: _selectedAIProvider,
            bedrockRegion: bedrockRegion,
            bedrockModelId: bedrockModelId,
            customProviderBaseURL: customProviderBaseURL,
            customProviderModel: customProviderModel,
            selectedModels: _selectedModels
        )
    }
}
