import Testing
@testable import HoAh
import SwiftData

struct SessionStateTests {

    @Test func ignoresStaleSessionTokenAndKeepsLatestSession() throws {
        let container = try ModelContainer(
            for: Transcription.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        let aiService = AIService()
        let enhancementService = AIEnhancementService(
            aiService: aiService,
            modelContext: container.mainContext
        )

        let oldToken = enhancementService.beginSessionSwitch()
        let newToken = enhancementService.beginSessionSwitch()

        let oldSession = AIEnhancementService.ActiveSession(
            provider: .openAI,
            model: "gpt-5.1",
            region: nil,
            auth: .bearer("old-key")
        )

        let newSession = AIEnhancementService.ActiveSession(
            provider: .openAI,
            model: "gpt-4.1",
            region: nil,
            auth: .bearer("new-key")
        )

        // Apply stale session with old token (should be ignored)
        enhancementService.setActiveSession(oldSession, token: oldToken)
        // Apply latest session with current token
        enhancementService.setActiveSession(newSession, token: newToken)

        #expect(enhancementService.activeSession?.model == "gpt-4.1")

        if case .ready(let session) = enhancementService.activeSessionState {
            #expect(session.model == "gpt-4.1")
        } else {
            Issue.record("activeSessionState not ready after latest token applied")
        }
    }
}
