import Foundation
import SwiftUI    // Import to ensure we have access to SwiftUI types if needed

enum PredefinedPrompts {
    private static let predefinedPromptsKey = "PredefinedPrompts"
    
    // Static UUIDs for predefined prompts
    static let defaultPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let assistantPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let polishPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    static let summarizePromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
    static let actionItemsPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000006")!
    static let emailDraftPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000007")!
    
    static var all: [CustomPrompt] {
        // Always return the latest predefined prompts from source code
        createDefaultPrompts()
    }
    
    static func createDefaultPrompts() -> [CustomPrompt] {
        [
            // Manual presets (no trigger words; user selects explicitly)
            CustomPrompt(
                id: defaultPromptId,
                title: "Default",
                promptText: """
Rewrite the transcript to keep meaning intact but:
- Remove filler particles/hesitations (e.g., 吧、啊、嗯、呃，以及重复的“吧吧吧”等) unless they change meaning.
- If the user corrects a previous phrase (e.g., “不是A，是B”), honor the latest correction and drop the earlier version.
- Keep proper nouns and numbers as spoken; do not shorten or summarize.
- Return clean, concise sentences in the original language.
""",
                icon: "checkmark.seal.fill",
                description: "Simple clean-up: drop filler words and apply the user’s last stated corrections.",
                isPredefined: true,
                triggerWords: [],
                useSystemInstructions: true
            ),
            CustomPrompt(
                id: polishPromptId,
                title: "Polish",
                promptText: "Rewrite the transcript with better grammar, clear sentences, and concise wording while keeping meaning unchanged.",
                icon: "wand.and.stars",
                description: "Polish and clarify transcripts without changing intent.",
                isPredefined: true,
                triggerWords: [],
                useSystemInstructions: true
            ),

            // Auto-trigger presets (activated via trigger words)
            CustomPrompt(
                id: summarizePromptId,
                title: "Summarize",
                promptText: "Create a concise summary in 3-5 bullet points highlighting the key ideas and outcomes.",
                icon: "text.alignleft",
                description: "Auto-activates on summary cues",
                isPredefined: true,
                triggerWords: ["summarize", "tl;dr", "summary"],
                useSystemInstructions: true
            ),
            CustomPrompt(
                id: actionItemsPromptId,
                title: "Action Items",
                promptText: "Extract action items with assignee (if mentioned), due date (if stated), and a short imperative task line.",
                icon: "checkmark.circle",
                description: "Auto-activates on action/todo cues",
                isPredefined: true,
                triggerWords: ["action items", "todo", "to-do", "tasks"],
                useSystemInstructions: true
            ),
            CustomPrompt(
                id: emailDraftPromptId,
                title: "Email Draft",
                promptText: "Rewrite as a concise, polite email with greeting and sign-off. Keep factual details intact.",
                icon: "envelope.fill",
                description: "Auto-activates on email cues",
                isPredefined: true,
                triggerWords: ["email", "draft email", "compose email"],
                useSystemInstructions: true
            ),

            // Assistant remains available for freeform Q&A (manual)
            CustomPrompt(
                id: assistantPromptId,
                title: "Assistant",
                promptText: AIPrompts.assistantMode,
                icon: "bubble.left.and.bubble.right.fill",
                description: "AI assistant that provides direct answers to queries",
                isPredefined: true,
                triggerWords: [],
                useSystemInstructions: false
            )
        ]
    }
}
