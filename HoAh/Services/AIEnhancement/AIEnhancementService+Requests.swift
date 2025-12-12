import Foundation
import AppKit

@MainActor
extension AIEnhancementService {
    fileprivate func waitForRateLimit() async throws {
        if let lastRequest = lastRequestTime {
            let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
            if timeSinceLastRequest < rateLimitInterval {
                try await Task.sleep(nanoseconds: UInt64((rateLimitInterval - timeSinceLastRequest) * 1_000_000_000))
            }
        }
        lastRequestTime = Date()
    }

    fileprivate func getSystemMessage(for mode: EnhancementPrompt) async -> String {
        let selectedTextContext: String
        // Only fetch selected text if enabled and process is trusted
        if useSelectedTextContext && AXIsProcessTrusted() {
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

        let userProfileSection = if !userProfileContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            "\n\n<USER_PROFILE>\n\(userProfileContext.trimmingCharacters(in: .whitespacesAndNewlines))\n</USER_PROFILE>"
        } else {
            ""
        }

        let allContextSections = userProfileSection + selectedTextContext + clipboardContext + screenCaptureContext

        if let activePrompt = activePrompt {
            return activePrompt.finalPromptText + allContextSections
        } else {
            guard let fallback = activePrompts.first(where: { $0.id == PredefinedPrompts.defaultPromptId }) ?? activePrompts.first else {
                return allContextSections
            }
            return fallback.finalPromptText + allContextSections
        }
    }

    func makeRequest(text: String, mode: EnhancementPrompt) async throws -> String {
        var session = activeSession

        // If we somehow lost the runtime session (e.g. after a config switch), try to rehydrate once before failing.
        if session == nil {
            aiService.hydrateActiveConfiguration()
            rebuildActiveSession()
            session = activeSession
        }

        guard let session else {
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

        try await waitForRateLimit()

        return try await makeRequestWithRetry(systemMessage: systemMessage, formattedText: formattedText, session: session)
    }

    fileprivate func makeRequestWithRetry(systemMessage: String, formattedText: String, session: ActiveSession, maxRetries: Int = 3, initialDelay: TimeInterval = 1.0) async throws -> String {
        var retries = 0
        var currentDelay = initialDelay

        while retries < maxRetries {
            do {
                return try await performRequest(systemMessage: systemMessage, formattedText: formattedText, session: session)
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

    fileprivate func performRequest(systemMessage: String, formattedText: String, session: ActiveSession) async throws -> String {
        switch session.provider {
        case .awsBedrock:
            return try await BedrockProvider.performRequest(
                systemMessage: systemMessage,
                userMessage: formattedText,
                session: session,
                fallbackRegion: aiService.bedrockRegion,
                baseTimeout: baseTimeout
            )
        case .anthropic:
            return try await AnthropicProvider.performRequest(
                systemMessage: systemMessage,
                formattedText: formattedText,
                session: session,
                baseTimeout: baseTimeout
            )
        default:
            return try await OpenAICompatibleProvider.performRequest(
                systemMessage: systemMessage,
                formattedText: formattedText,
                session: session,
                baseTimeout: baseTimeout
            )
        }
    }

    func enhance(_ text: String) async throws -> (String, TimeInterval, String?) {
        let startTime = Date()
        let enhancementPrompt: EnhancementPrompt = .transcriptionEnhancement
        let promptName = activePrompt?.title

        do {
            if let session = activeSession {
                markEnhancing(with: session)
            }
            let result = try await makeRequest(text: text, mode: enhancementPrompt)
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            if let session = activeSession {
                markReady(with: session)
            }
            return (result, duration, promptName)
        } catch {
            markError(error.localizedDescription)
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
}
