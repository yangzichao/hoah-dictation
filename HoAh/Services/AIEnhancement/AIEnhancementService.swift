import Foundation
import SwiftData
import AppKit
import os
import Combine

enum EnhancementPrompt {
    case transcriptionEnhancement
}

enum PromptKind {
    case active
    case trigger
}

// AI Enhancement settings are managed by AppSettingsStore.
// Runtime state (lastSystemMessageSent, lastCapturedClipboard, etc.) remains here.
// Prompts (activePrompts, triggerPrompts) are managed locally as they are complex objects.
@MainActor
class AIEnhancementService: ObservableObject {
    let logger = Logger(subsystem: "com.yangzichao.hoah", category: "AIEnhancementService")
    let awsProfileService = AWSProfileService()
    
    private let activePromptsKey = "activePrompts"
    private let triggerPromptsKey = "triggerPrompts"
    private let legacyPromptsKey = "customPrompts"

    // MARK: - Settings (read from AppSettingsStore)
    
    /// Reference to centralized settings store
    weak var appSettings: AppSettingsStore?
    var cancellables = Set<AnyCancellable>()
    
    /// Whether AI enhancement is enabled (computed from AppSettingsStore)
    var isEnhancementEnabled: Bool {
        get { appSettings?.isAIEnhancementEnabled ?? false }
        set {
            appSettings?.isAIEnhancementEnabled = newValue
            if newValue && selectedPromptId == nil {
                selectedPromptId = activePrompts.first?.id
            }
        }
    }
    
    /// Whether to use clipboard context (computed from AppSettingsStore)
    var useClipboardContext: Bool {
        get { appSettings?.useClipboardContext ?? false }
        set { appSettings?.useClipboardContext = newValue }
    }
    
    var useScreenCaptureContext: Bool {
        get { appSettings?.useScreenCaptureContext ?? false }
        set { appSettings?.useScreenCaptureContext = newValue }
    }
    
    /// Whether to use selected text context (computed from AppSettingsStore)
    var useSelectedTextContext: Bool {
        get { appSettings?.useSelectedTextContext ?? false }
        set { appSettings?.useSelectedTextContext = newValue }
    }
    
    /// User profile context (computed from AppSettingsStore)
    var userProfileContext: String {
        get { appSettings?.userProfileContext ?? "" }
        set { appSettings?.userProfileContext = newValue }
    }
    
    /// Selected prompt ID (computed from AppSettingsStore)
    var selectedPromptId: UUID? {
        get {
            guard let idString = appSettings?.selectedPromptId else { return nil }
            return UUID(uuidString: idString)
        }
        set {
            appSettings?.selectedPromptId = newValue?.uuidString
        }
    }
    
    /// Whether prompt triggers are enabled (computed from AppSettingsStore)
    var arePromptTriggersEnabled: Bool {
        get { appSettings?.arePromptTriggersEnabled ?? true }
        set { appSettings?.arePromptTriggersEnabled = newValue }
    }

    // MARK: - Prompts (managed locally as complex objects)
    
    @Published var activePrompts: [CustomPrompt] {
        didSet { persistPrompts() }
    }
    
    @Published var triggerPrompts: [CustomPrompt] {
        didSet { persistPrompts() }
    }

    // MARK: - Runtime State (kept here)
    
    /// High-level runtime state for AI Enhancement
    enum SessionState {
        case idle
        case switching(configId: UUID?)
        case ready(session: ActiveSession)
        case enhancing(session: ActiveSession)
        case error(message: String?)
    }
    
    @Published private(set) var activeSessionState: SessionState = .idle
    @Published var lastSystemMessageSent: String?
    @Published var lastUserMessageSent: String?
    @Published var lastCapturedClipboard: String?

    var activePrompt: CustomPrompt? {
        allPrompts.first { $0.id == selectedPromptId }
    }

    var allPrompts: [CustomPrompt] { activePrompts + triggerPrompts }

    let aiService: AIService
    let screenCaptureService: ScreenCaptureService
    let baseTimeout: TimeInterval = 30
    let rateLimitInterval: TimeInterval = 1.0
    var lastRequestTime: Date?
    private let modelContext: ModelContext
    
    /// Immutable runtime snapshot derived from the active configuration
    var activeSession: ActiveSession?
    
    /// Token used to prevent stale async config applications from overwriting newer ones
    private var activeSessionToken: UUID = UUID()
    
    struct ActiveSession {
        let provider: AIProvider
        let model: String
        let region: String?
        let auth: Auth
        
        enum Auth {
            case bearer(String)          // OpenAI-compatible
            case anthropic(String)       // Anthropic x-api-key
            case bedrockSigV4(AWSCredentials, region: String)
            case bedrockBearer(String, region: String)
        }
    }
    
    func persistPrompts() {
        if let encoded = try? JSONEncoder().encode(activePrompts) {
            UserDefaults.standard.set(encoded, forKey: activePromptsKey)
        }
        if let encoded = try? JSONEncoder().encode(triggerPrompts) {
            UserDefaults.standard.set(encoded, forKey: triggerPromptsKey)
        }
    }
    
    /// Begin a new session switch; increments token to invalidate older async setters
    func beginSessionSwitch() -> UUID {
        let token = UUID()
        activeSessionToken = token
        markSwitching(configId: nil)
        return token
    }
    
    /// Set activeSession only if the caller still holds the latest token
    func setActiveSession(_ session: ActiveSession?, token: UUID) {
        guard token == activeSessionToken else { return }
        activeSession = session
        if let session {
            markReady(with: session)
        } else {
            markError("Session not configured")
        }
    }

    // MARK: - State helpers (single write point for activeSessionState)

    func markSwitching(configId: UUID?) {
        activeSessionState = .switching(configId: configId)
    }

    func markReady(with session: ActiveSession) {
        activeSessionState = .ready(session: session)
    }

    func markEnhancing(with session: ActiveSession) {
        activeSessionState = .enhancing(session: session)
    }

    func markError(_ message: String?) {
        activeSessionState = .error(message: message)
    }

    init(aiService: AIService, modelContext: ModelContext) {
        self.aiService = aiService
        self.modelContext = modelContext
        self.screenCaptureService = ScreenCaptureService()
        self.activeSession = nil

        // Load prompts from UserDefaults (complex objects not in AppSettingsStore)
        let decodedActive = UserDefaults.standard.data(forKey: activePromptsKey).flatMap { try? JSONDecoder().decode([CustomPrompt].self, from: $0) }
        let decodedTrigger = UserDefaults.standard.data(forKey: triggerPromptsKey).flatMap { try? JSONDecoder().decode([CustomPrompt].self, from: $0) }
        let shouldNormalizeDefaults = decodedTrigger == nil && UserDefaults.standard.data(forKey: legacyPromptsKey) == nil
        if let decodedActive, let decodedTrigger {
            self.activePrompts = decodedActive
            self.triggerPrompts = decodedTrigger
        } else if let legacyData = UserDefaults.standard.data(forKey: legacyPromptsKey),
                  let legacyPrompts = try? JSONDecoder().decode([CustomPrompt].self, from: legacyData) {
            let (actives, triggers) = legacyPrompts.partitionedByTriggerWords()
            self.activePrompts = actives
            self.triggerPrompts = triggers
        } else {
            self.activePrompts = []
            self.triggerPrompts = []
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAPIKeyChange),
            name: .aiProviderKeyChanged,
            object: nil
        )

        initializePredefinedPrompts()
        relocalizePredefinedPromptTitles()

        if shouldNormalizeDefaults {
            normalizeTriggerActivityDefaults(shouldForceEnableDefaults: true)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLanguageChange),
            name: .languageDidChange,
            object: nil
        )

        rebuildActiveSession()
    }
    
    /// Configure with AppSettingsStore for centralized settings management
    /// - Parameter appSettings: The centralized settings store
    func configure(with appSettings: AppSettingsStore) {
        self.appSettings = appSettings
        
        // Subscribe to settings changes to trigger objectWillChange
        appSettings.isAIEnhancementEnabledPublisher
            .sink { [weak self] isEnabled in
                self?.objectWillChange.send()
                if !isEnabled {
                    self?.disableAllTriggerPrompts()
                }
            }
            .store(in: &cancellables)
        
        appSettings.selectedPromptIdPublisher
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        appSettings.$useClipboardContext
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        appSettings.$useScreenCaptureContext
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        appSettings.$useSelectedTextContext
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        appSettings.$userProfileContext
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        appSettings.$arePromptTriggersEnabled
            .sink { [weak self] isEnabled in
                self?.objectWillChange.send()
                if !isEnabled {
                    self?.disableAllTriggerPrompts()
                }
            }
            .store(in: &cancellables)
        
        // Initialize selected prompt if needed
        if isEnhancementEnabled && (selectedPromptId == nil || !activePrompts.contains(where: { $0.id == selectedPromptId })) {
            selectedPromptId = activePrompts.first?.id
        }
        
        if selectedPromptId == nil {
            selectedPromptId = activePrompts.first?.id
        }
        
        logger.info("AIEnhancementService configured with AppSettingsStore")
        
        // Build runtime session from current active configuration (if any)
        rebuildActiveSession()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleAPIKeyChange() {
        DispatchQueue.main.async {
            self.objectWillChange.send()
            if !self.aiService.isAPIKeyValid {
                self.isEnhancementEnabled = false
            }
        }
    }

    @objc private func handleLanguageChange() {
        DispatchQueue.main.async {
            self.relocalizePredefinedPromptTitles()
            self.objectWillChange.send()
        }
    }

    /// Ensure predefined prompts pick up localized titles/descriptions each launch (language-dependent UI).
    func relocalizePredefinedPromptTitles() {
        let templates = PredefinedPrompts.createDefaultPrompts()
        let templateMap = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })

        func relocalize(_ prompts: inout [CustomPrompt]) {
            for idx in prompts.indices {
                let p = prompts[idx]
                guard p.isPredefined, let template = templateMap[p.id] else { continue }
                prompts[idx] = CustomPrompt(
                    id: p.id,
                    title: template.title,
                    promptText: template.promptText,
                    isActive: p.isActive,
                    icon: p.icon,
                    description: template.description,
                    isPredefined: true,
                    triggerWords: template.triggerWords,
                    useSystemInstructions: p.useSystemInstructions
                )
            }
        }

        relocalize(&activePrompts)
        relocalize(&triggerPrompts)
    }

    /// Ensure trigger-word prompts default to enabled only on first launch (no prior state).
    func normalizeTriggerActivityDefaults(shouldForceEnableDefaults: Bool) {
        guard shouldForceEnableDefaults else { return }
        
        triggerPrompts = triggerPrompts.map { prompt in
            var updated = prompt
            if !updated.triggerWords.isEmpty && updated.isActive == false {
                updated.isActive = true
            }
            return updated
        }
    }

    /// Disable all trigger prompts (used when master toggle or AI enhancement is turned off).
    func disableAllTriggerPrompts() {
        guard triggerPrompts.contains(where: { $0.isActive }) else { return }
        triggerPrompts = triggerPrompts.map { prompt in
            var updated = prompt
            updated.isActive = false
            return updated
        }
    }

    func getAIService() -> AIService? {
        return aiService
    }

    var isConfigured: Bool {
        // During migration, keep legacy fallback to avoid false negatives
        return activeSession != nil || aiService.isAPIKeyValid
    }
}

enum EnhancementError: Error {
    case notConfigured
    case invalidResponse
    case enhancementFailed
    case networkError
    case serverError
    case rateLimitExceeded
    case apiKeyInvalid
    case customError(String)
}

extension EnhancementError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI provider not configured. Please check your API key."
        case .invalidResponse:
            return "Invalid response from AI provider."
        case .enhancementFailed:
            return "AI enhancement failed to process the text."
        case .networkError:
            return "Network connection failed. Check your internet."
        case .serverError:
            return "The AI provider's server encountered an error. Please try again later."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .apiKeyInvalid:
            return "The API key appears to be invalid or has been revoked."
        case .customError(let message):
            return message
        }
    }
}

// Helper to split prompts into active vs trigger-based collections
extension Array where Element == CustomPrompt {
    func partitionedByTriggerWords() -> ([CustomPrompt], [CustomPrompt]) {
        var actives: [CustomPrompt] = []
        var triggers: [CustomPrompt] = []
        for prompt in self {
            if prompt.triggerWords.isEmpty {
                actives.append(prompt)
            } else {
                triggers.append(prompt)
            }
        }
        return (actives, triggers)
    }
}
