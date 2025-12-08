import Foundation
import SwiftData
import AppKit
import os

enum EnhancementPrompt {
    case transcriptionEnhancement
    case aiAssistant
}

enum PromptKind {
    case active
    case trigger
}

@MainActor
class AIEnhancementService: ObservableObject {
    private let logger = Logger(subsystem: "com.yangzichao.hoah", category: "AIEnhancementService")
    
    private let activePromptsKey = "activePrompts"
    private let triggerPromptsKey = "triggerPrompts"
    private let legacyPromptsKey = "customPrompts"

    @Published var isEnhancementEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnhancementEnabled, forKey: "isAIEnhancementEnabled")
            if isEnhancementEnabled && selectedPromptId == nil {
                selectedPromptId = activePrompts.first?.id
            }
            NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
            NotificationCenter.default.post(name: .enhancementToggleChanged, object: nil)
        }
    }

    @Published var useClipboardContext: Bool {
        didSet {
            UserDefaults.standard.set(useClipboardContext, forKey: "useClipboardContext")
        }
    }

    @Published var useScreenCaptureContext: Bool {
        didSet {
            UserDefaults.standard.set(useScreenCaptureContext, forKey: "useScreenCaptureContext")
            NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
        }
    }

    @Published var activePrompts: [CustomPrompt] {
        didSet { persistPrompts() }
    }
    
    @Published var triggerPrompts: [CustomPrompt] {
        didSet { persistPrompts() }
    }

    @Published var selectedPromptId: UUID? {
        didSet {
            UserDefaults.standard.set(selectedPromptId?.uuidString, forKey: "selectedPromptId")
            NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
            NotificationCenter.default.post(name: .promptSelectionChanged, object: nil)
        }
    }

    @Published var arePromptTriggersEnabled: Bool {
        didSet {
            UserDefaults.standard.set(arePromptTriggersEnabled, forKey: "arePromptTriggersEnabled")
        }
    }

    @Published var lastSystemMessageSent: String?
    @Published var lastUserMessageSent: String?

    var activePrompt: CustomPrompt? {
        allPrompts.first { $0.id == selectedPromptId }
    }

    var allPrompts: [CustomPrompt] { activePrompts + triggerPrompts }

    private let aiService: AIService
    private let screenCaptureService: ScreenCaptureService
    private let baseTimeout: TimeInterval = 30
    private let rateLimitInterval: TimeInterval = 1.0
    private var lastRequestTime: Date?
    private let modelContext: ModelContext
    
    @Published var lastCapturedClipboard: String?
    
    private func persistPrompts() {
        if let encoded = try? JSONEncoder().encode(activePrompts) {
            UserDefaults.standard.set(encoded, forKey: activePromptsKey)
        }
        if let encoded = try? JSONEncoder().encode(triggerPrompts) {
            UserDefaults.standard.set(encoded, forKey: triggerPromptsKey)
        }
    }

    init(aiService: AIService = AIService(), modelContext: ModelContext) {
        self.aiService = aiService
        self.modelContext = modelContext
        self.screenCaptureService = ScreenCaptureService()

        self.isEnhancementEnabled = UserDefaults.standard.bool(forKey: "isAIEnhancementEnabled")
        self.useClipboardContext = UserDefaults.standard.bool(forKey: "useClipboardContext")
        self.useScreenCaptureContext = UserDefaults.standard.bool(forKey: "useScreenCaptureContext")
        self.arePromptTriggersEnabled = UserDefaults.standard.object(forKey: "arePromptTriggersEnabled") as? Bool ?? true

        let decodedActive = UserDefaults.standard.data(forKey: activePromptsKey).flatMap { try? JSONDecoder().decode([CustomPrompt].self, from: $0) }
        let decodedTrigger = UserDefaults.standard.data(forKey: triggerPromptsKey).flatMap { try? JSONDecoder().decode([CustomPrompt].self, from: $0) }
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

        if let savedPromptId = UserDefaults.standard.string(forKey: "selectedPromptId") {
            self.selectedPromptId = UUID(uuidString: savedPromptId)
        }

        if isEnhancementEnabled && (selectedPromptId == nil || !activePrompts.contains(where: { $0.id == selectedPromptId })) {
            self.selectedPromptId = activePrompts.first?.id
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAPIKeyChange),
            name: .aiProviderKeyChanged,
            object: nil
        )

        initializePredefinedPrompts()
        relocalizePredefinedPromptTitles()
        
        if selectedPromptId == nil {
            selectedPromptId = activePrompts.first?.id
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLanguageChange),
            name: .languageDidChange,
            object: nil
        )
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
    private func relocalizePredefinedPromptTitles() {
        let templates = PredefinedPrompts.createDefaultPrompts()
        let templateMap = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })

        func relocalize(_ prompts: inout [CustomPrompt]) {
            for idx in prompts.indices {
                let p = prompts[idx]
                guard p.isPredefined, let template = templateMap[p.id] else { continue }
                prompts[idx] = CustomPrompt(
                    id: p.id,
                    title: template.title,
                    promptText: p.promptText,
                    isActive: p.isActive,
                    icon: p.icon,
                    description: template.description,
                    isPredefined: true,
                    triggerWords: p.triggerWords,
                    useSystemInstructions: p.useSystemInstructions
                )
            }
        }

        relocalize(&activePrompts)
        relocalize(&triggerPrompts)
    }

    func getAIService() -> AIService? {
        return aiService
    }

    var isConfigured: Bool {
        aiService.isAPIKeyValid
    }

    private func waitForRateLimit() async throws {
        if let lastRequest = lastRequestTime {
            let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
            if timeSinceLastRequest < rateLimitInterval {
                try await Task.sleep(nanoseconds: UInt64((rateLimitInterval - timeSinceLastRequest) * 1_000_000_000))
            }
        }
        lastRequestTime = Date()
    }

    private func getSystemMessage(for mode: EnhancementPrompt) async -> String {
        let selectedTextContext: String
        if AXIsProcessTrusted() {
            if let selectedText = await SelectedTextService.fetchSelectedText(), !selectedText.isEmpty {
                selectedTextContext = "\n\n<CURRENTLY_SELECTED_TEXT>\n\(selectedText)\n</CURRENTLY_SELECTED_TEXT>"
            } else {
                selectedTextContext = ""
            }
        } else {
            selectedTextContext = ""
        }

        let clipboardContext = if useClipboardContext,
                              let clipboardText = lastCapturedClipboard,
                              !clipboardText.isEmpty {
            "\n\n<CLIPBOARD_CONTEXT>\n\(clipboardText)\n</CLIPBOARD_CONTEXT>"
        } else {
            ""
        }

        let screenCaptureContext = if useScreenCaptureContext,
                                   let capturedText = screenCaptureService.lastCapturedText,
                                   !capturedText.isEmpty {
            "\n\n<CURRENT_WINDOW_CONTEXT>\n\(capturedText)\n</CURRENT_WINDOW_CONTEXT>"
        } else {
            ""
        }

        let allContextSections = selectedTextContext + clipboardContext + screenCaptureContext

        if let activePrompt = activePrompt {
            return activePrompt.finalPromptText + allContextSections
        } else {
            guard let fallback = activePrompts.first(where: { $0.id == PredefinedPrompts.defaultPromptId }) ?? activePrompts.first else {
                return allContextSections
            }
            return fallback.finalPromptText + allContextSections
        }
    }

    private func makeRequest(text: String, mode: EnhancementPrompt) async throws -> String {
        guard isConfigured else {
            throw EnhancementError.notConfigured
        }

        guard !text.isEmpty else {
            return "" // Silently return empty string instead of throwing error
        }

        let formattedText = "\n<TRANSCRIPT>\n\(text)\n</TRANSCRIPT>"
        let systemMessage = await getSystemMessage(for: mode)
        
        // Persist the exact payload being sent (also used for UI)
        await MainActor.run {
            self.lastSystemMessageSent = systemMessage
            self.lastUserMessageSent = formattedText
        }

        // Log the message being sent to AI enhancement
        logger.notice("AI Enhancement - System Message: \(systemMessage, privacy: .public)")
        logger.notice("AI Enhancement - User Message: \(formattedText, privacy: .public)")

        if aiService.selectedProvider == .ollama {
            do {
                let result = try await aiService.enhanceWithOllama(text: formattedText, systemPrompt: systemMessage)
                let filteredResult = AIEnhancementOutputFilter.filter(result)
                return filteredResult
            } catch {
                if let localError = error as? LocalAIError {
                    throw EnhancementError.customError(localError.errorDescription ?? "An unknown Ollama error occurred.")
                } else {
                    throw EnhancementError.customError(error.localizedDescription)
                }
            }
        }

        try await waitForRateLimit()

        let providerKey = aiService.selectedProvider.rawValue
        let keyManager = CloudAPIKeyManager.shared
        let usesManagedKeys = aiService.selectedProvider.requiresAPIKey &&
            aiService.selectedProvider != .awsBedrock &&
            aiService.selectedProvider != .ollama &&
            aiService.selectedProvider != .custom
        var triedKeyIds = Set<UUID>()

        while true {
            if usesManagedKeys {
                guard let active = keyManager.activeKey(for: providerKey) else {
                    throw EnhancementError.notConfigured
                }
                if triedKeyIds.contains(active.id) {
                    throw EnhancementError.apiKeyInvalid
                }
                triedKeyIds.insert(active.id)
                aiService.selectAPIKey(id: active.id)
            }

            do {
                let result = try await performRequest(systemMessage: systemMessage, formattedText: formattedText)
                if usesManagedKeys {
                    keyManager.markCurrentKeyUsed(for: providerKey)
                }
                return result
            } catch let error as EnhancementError {
                switch error {
                case .apiKeyInvalid, .rateLimitExceeded:
                    if usesManagedKeys, keyManager.rotateKey(for: providerKey) {
                        continue
                    }
                    throw error
                default:
                    throw error
                }
            }
        }
    }

    private func performRequest(systemMessage: String, formattedText: String) async throws -> String {
        switch aiService.selectedProvider {
        case .anthropic:
            let requestBody: [String: Any] = [
                "model": aiService.currentModel,
                "max_tokens": 8192,
                "system": systemMessage,
                "messages": [
                    ["role": "user", "content": formattedText]
                ]
            ]

            var request = URLRequest(url: URL(string: aiService.selectedProvider.baseURL)!)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue(aiService.apiKey, forHTTPHeaderField: "x-api-key")
            request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.timeoutInterval = baseTimeout
            request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw EnhancementError.invalidResponse
                }

                if httpResponse.statusCode == 200 {
                    guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let content = jsonResponse["content"] as? [[String: Any]],
                          let firstContent = content.first,
                          let enhancedText = firstContent["text"] as? String else {
                        throw EnhancementError.enhancementFailed
                    }

                    let filteredText = AIEnhancementOutputFilter.filter(enhancedText.trimmingCharacters(in: .whitespacesAndNewlines))
                    return filteredText
                } else if httpResponse.statusCode == 429 {
                    throw EnhancementError.rateLimitExceeded
                } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    throw EnhancementError.apiKeyInvalid
                } else if (500...599).contains(httpResponse.statusCode) {
                    throw EnhancementError.serverError
                } else {
                    let errorString = String(data: data, encoding: .utf8) ?? "Could not decode error response."
                    throw EnhancementError.customError("HTTP \(httpResponse.statusCode): \(errorString)")
                }

            } catch let error as EnhancementError {
                throw error
            } catch let error as URLError {
                throw error
            } catch {
                throw EnhancementError.customError(error.localizedDescription)
            }

        default:
            if aiService.selectedProvider == .awsBedrock {
                return try await makeBedrockRequest(systemMessage: systemMessage, userMessage: formattedText)
            }
            let url = URL(string: aiService.selectedProvider.baseURL)!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("Bearer \(aiService.apiKey)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = baseTimeout

            let messages: [[String: Any]] = [
                ["role": "system", "content": systemMessage],
                ["role": "user", "content": formattedText]
            ]

            var requestBody: [String: Any] = [
                "model": aiService.currentModel,
                "messages": messages,
                "temperature": aiService.currentModel.lowercased().hasPrefix("gpt-5") ? 1.0 : 0.3,
                "stream": false
            ]

            // Add reasoning_effort parameter if the model supports it
            if let reasoningEffort = ReasoningConfig.getReasoningParameter(for: aiService.currentModel) {
                requestBody["reasoning_effort"] = reasoningEffort
            }

            request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw EnhancementError.invalidResponse
                }

                if httpResponse.statusCode == 200 {
                    guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let choices = jsonResponse["choices"] as? [[String: Any]],
                          let firstChoice = choices.first,
                          let message = firstChoice["message"] as? [String: Any],
                          let enhancedText = message["content"] as? String else {
                        throw EnhancementError.enhancementFailed
                    }

                    let filteredText = AIEnhancementOutputFilter.filter(enhancedText.trimmingCharacters(in: .whitespacesAndNewlines))
                    return filteredText
                } else if httpResponse.statusCode == 429 {
                    throw EnhancementError.rateLimitExceeded
                } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    throw EnhancementError.apiKeyInvalid
                } else if (500...599).contains(httpResponse.statusCode) {
                    throw EnhancementError.serverError
                } else {
                    let errorString = String(data: data, encoding: .utf8) ?? "Could not decode error response."
                    throw EnhancementError.customError("HTTP \(httpResponse.statusCode): \(errorString)")
                }

            } catch let error as EnhancementError {
                throw error
            } catch let error as URLError {
                throw error
            } catch {
                throw EnhancementError.customError(error.localizedDescription)
            }
        }
    }

    private func makeRequestWithRetry(text: String, mode: EnhancementPrompt, maxRetries: Int = 3, initialDelay: TimeInterval = 1.0) async throws -> String {
        var retries = 0
        var currentDelay = initialDelay

        while retries < maxRetries {
            do {
                return try await makeRequest(text: text, mode: mode)
            } catch let error as EnhancementError {
                switch error {
                case .networkError, .serverError, .rateLimitExceeded:
                    retries += 1
                    if retries < maxRetries {
                        logger.warning("Request failed, retrying in \(currentDelay)s... (Attempt \(retries)/\(maxRetries))")
                        try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                        currentDelay *= 2 // Exponential backoff
                    } else {
                        logger.error("Request failed after \(maxRetries) retries.")
                        throw error
                    }
                default:
                    throw error
                }
            } catch {
                // For other errors, check if it's a network-related URLError
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && [NSURLErrorNotConnectedToInternet, NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost].contains(nsError.code) {
                    retries += 1
                    if retries < maxRetries {
                        logger.warning("Request failed with network error, retrying in \(currentDelay)s... (Attempt \(retries)/\(maxRetries))")
                        try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                        currentDelay *= 2 // Exponential backoff
                    } else {
                        logger.error("Request failed after \(maxRetries) retries with network error.")
                        throw EnhancementError.networkError
                    }
                } else {
                    throw error
                }
            }
        }

        // This part should ideally not be reached, but as a fallback:
        throw EnhancementError.enhancementFailed
    }
    
    private func makeBedrockRequest(systemMessage: String, userMessage: String) async throws -> String {
        let apiKey = aiService.bedrockApiKey
        let region = aiService.bedrockRegion
        let modelId = aiService.currentModel
        
        guard !apiKey.isEmpty, !region.isEmpty, !modelId.isEmpty else {
            throw EnhancementError.notConfigured
        }
        
        let prompt = "\(systemMessage)\n\(userMessage)"
        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": [
                    ["text": prompt]
                ]
            ]
        ]
        let payload: [String: Any] = [
            "modelId": modelId,
            "messages": messages,
            "inferenceConfig": [
                "maxTokens": 1024,
                "temperature": aiService.currentModel.lowercased().hasPrefix("gpt-5") ? 1.0 : 0.3
            ]
        ]
        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        
        let host = "bedrock-runtime.\(region).amazonaws.com"
        let url = URL(string: "https://\(host)/model/\(modelId)/converse")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payloadData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EnhancementError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                if let result = Self.parseBedrockResponse(data: data) {
                    return AIEnhancementOutputFilter.filter(result.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    throw EnhancementError.enhancementFailed
                }
            } else if httpResponse.statusCode == 429 {
                throw EnhancementError.rateLimitExceeded
            } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw EnhancementError.apiKeyInvalid
            } else if (500...599).contains(httpResponse.statusCode) {
                throw EnhancementError.serverError
            } else {
                let errorString = String(data: data, encoding: .utf8) ?? "Could not decode error response."
                throw EnhancementError.customError("HTTP \(httpResponse.statusCode): \(errorString)")
            }
        } catch let error as EnhancementError {
            throw error
        } catch {
            throw EnhancementError.customError(error.localizedDescription)
        }
    }
    
    private static func parseBedrockResponse(data: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let text = json["output_text"] as? String { return text }
            if let text = json["outputText"] as? String { return text }
            if let text = json["completion"] as? String { return text }
            if let text = json["generated_text"] as? String { return text }
            if let outputs = json["outputs"] as? [[String: Any]] {
                if let first = outputs.first {
                    if let text = first["text"] as? String { return text }
                    if let text = first["output_text"] as? String { return text }
                }
            }
        } else if let asString = String(data: data, encoding: .utf8) {
            return asString
        }
        return nil
    }

    func enhance(_ text: String) async throws -> (String, TimeInterval, String?) {
        let startTime = Date()
        let enhancementPrompt: EnhancementPrompt = .transcriptionEnhancement
        let promptName = activePrompt?.title

        do {
            let result = try await makeRequestWithRetry(text: text, mode: enhancementPrompt)
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            return (result, duration, promptName)
        } catch {
            throw error
        }
    }

    func captureScreenContext() async {
        // Screen context capture is disabled in this fork.
    }

    func captureClipboardContext() {
        lastCapturedClipboard = NSPasteboard.general.string(forType: .string)
    }
    
    func clearCapturedContexts() {
        lastCapturedClipboard = nil
        screenCaptureService.lastCapturedText = nil
    }

    func addPrompt(title: String, promptText: String, icon: PromptIcon = "doc.text.fill", description: String? = nil, triggerWords: [String] = [], useSystemInstructions: Bool = true, kind: PromptKind) {
        let newPrompt = CustomPrompt(title: title, promptText: promptText, icon: icon, description: description, isPredefined: false, triggerWords: triggerWords, useSystemInstructions: useSystemInstructions)
        switch kind {
        case .active:
            activePrompts.append(newPrompt)
            if selectedPromptId == nil {
                selectedPromptId = newPrompt.id
            }
        case .trigger:
            triggerPrompts.append(newPrompt)
        }
    }

    func updatePrompt(_ prompt: CustomPrompt) {
        if let index = activePrompts.firstIndex(where: { $0.id == prompt.id }) {
            activePrompts[index] = prompt
            return
        }
        if let index = triggerPrompts.firstIndex(where: { $0.id == prompt.id }) {
            triggerPrompts[index] = prompt
        }
    }

    func deletePrompt(_ prompt: CustomPrompt) {
        guard !prompt.isPredefined else { return }
        if activePrompts.contains(where: { $0.id == prompt.id }) {
            activePrompts.removeAll { $0.id == prompt.id }
            if selectedPromptId == prompt.id {
                selectedPromptId = activePrompts.first?.id
            }
        } else if triggerPrompts.contains(where: { $0.id == prompt.id }) {
            triggerPrompts.removeAll { $0.id == prompt.id }
        }
    }

    func setActivePrompt(_ prompt: CustomPrompt) {
        guard activePrompts.contains(where: { $0.id == prompt.id }) else { return }
        selectedPromptId = prompt.id
    }

    func resetPromptToDefault(_ prompt: CustomPrompt) {
        guard prompt.isPredefined,
              let template = PredefinedPrompts.createDefaultPrompts().first(where: { $0.id == prompt.id }) else { return }
        
        if let index = activePrompts.firstIndex(where: { $0.id == prompt.id }) {
            let restoredPrompt = CustomPrompt(
                id: template.id,
                title: template.title,
                promptText: template.promptText,
                isActive: activePrompts[index].isActive,
                icon: template.icon,
                description: template.description,
                isPredefined: true,
                triggerWords: template.triggerWords,
                useSystemInstructions: template.useSystemInstructions
            )
            activePrompts[index] = restoredPrompt
            if selectedPromptId == nil {
                selectedPromptId = restoredPrompt.id
            }
            return
        }
        
        if let index = triggerPrompts.firstIndex(where: { $0.id == prompt.id }) {
            let restoredPrompt = CustomPrompt(
                id: template.id,
                title: template.title,
                promptText: template.promptText,
                isActive: triggerPrompts[index].isActive,
                icon: template.icon,
                description: template.description,
                isPredefined: true,
                triggerWords: template.triggerWords,
                useSystemInstructions: template.useSystemInstructions
            )
            triggerPrompts[index] = restoredPrompt
        }
    }

    func resetPredefinedPrompts() {
        let templates = PredefinedPrompts.createDefaultPrompts()
        let (defaultActive, defaultTrigger) = templates.partitionedByTriggerWords()

        var updatedActive = activePrompts
        var updatedTrigger = triggerPrompts

        for template in defaultActive {
            if let index = updatedActive.firstIndex(where: { $0.id == template.id }) {
                let existing = updatedActive[index]
                updatedActive[index] = CustomPrompt(
                    id: template.id,
                    title: template.title,
                    promptText: template.promptText,
                    isActive: existing.isActive,
                    icon: template.icon,
                    description: template.description,
                    isPredefined: true,
                    triggerWords: template.triggerWords,
                    useSystemInstructions: template.useSystemInstructions
                )
            } else {
                updatedActive.append(template)
            }
        }

        for template in defaultTrigger {
            if let index = updatedTrigger.firstIndex(where: { $0.id == template.id }) {
                let existing = updatedTrigger[index]
                updatedTrigger[index] = CustomPrompt(
                    id: template.id,
                    title: template.title,
                    promptText: template.promptText,
                    isActive: existing.isActive,
                    icon: template.icon,
                    description: template.description,
                    isPredefined: true,
                    triggerWords: template.triggerWords,
                    useSystemInstructions: template.useSystemInstructions
                )
            } else {
                updatedTrigger.append(template)
            }
        }

        activePrompts = updatedActive
        triggerPrompts = updatedTrigger

        if selectedPromptId == nil || !activePrompts.contains(where: { $0.id == selectedPromptId }) {
            selectedPromptId = activePrompts.first?.id
        }
    }

    private func initializePredefinedPrompts() {
        let predefinedTemplates = PredefinedPrompts.createDefaultPrompts()
        let templateIDs = Set(predefinedTemplates.map { $0.id })
        let (defaultActive, defaultTrigger) = predefinedTemplates.partitionedByTriggerWords()

        // Remove predefined prompts that are no longer part of the shipped set
        activePrompts.removeAll { prompt in
            prompt.isPredefined && !templateIDs.contains(prompt.id)
        }
        triggerPrompts.removeAll { prompt in
            prompt.isPredefined && !templateIDs.contains(prompt.id)
        }
        
        // Normalize any misplaced prompts (move trigger-word prompts into trigger collection)
        let (normalizedActive, migratedToTrigger) = activePrompts.partitionedByTriggerWords()
        activePrompts = normalizedActive
        if !migratedToTrigger.isEmpty {
            triggerPrompts.append(contentsOf: migratedToTrigger)
        }

        for template in defaultActive {
            if let existingIndex = activePrompts.firstIndex(where: { $0.id == template.id }) {
                let existingPrompt = activePrompts[existingIndex]
                let mergedPrompt = CustomPrompt(
                    id: existingPrompt.id,
                    title: template.title,
                    promptText: template.promptText,
                    isActive: existingPrompt.isActive,
                    icon: template.icon,
                    description: template.description,
                    isPredefined: true,
                    triggerWords: existingPrompt.triggerWords,
                    useSystemInstructions: template.useSystemInstructions
                )
                activePrompts[existingIndex] = mergedPrompt
            } else {
                activePrompts.append(template)
            }
        }

        for template in defaultTrigger {
            if let existingIndex = triggerPrompts.firstIndex(where: { $0.id == template.id }) {
                let existingPrompt = triggerPrompts[existingIndex]
                let mergedPrompt = CustomPrompt(
                    id: existingPrompt.id,
                    title: template.title,
                    promptText: template.promptText,
                    isActive: existingPrompt.isActive,
                    icon: template.icon,
                    description: template.description,
                    isPredefined: true,
                    triggerWords: existingPrompt.triggerWords,
                    useSystemInstructions: template.useSystemInstructions
                )
                triggerPrompts[existingIndex] = mergedPrompt
            } else {
                triggerPrompts.append(template)
            }
        }
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
