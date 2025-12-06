import Foundation
import SwiftUI    // Import to ensure we have access to SwiftUI types if needed

enum PredefinedPrompts {
    private static let predefinedPromptsKey = "PredefinedPrompts"
    
    // Static UUIDs for predefined prompts
    static let defaultPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let assistantPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let polishPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    static let summarizePromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
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
Lightweight cleanup only. Keep the original wording and language; do NOT translate or rewrite grammar.
- Input may be multilingual or code-mixed (Chinese/English). Keep the original language mix.
- Remove filler particles/hesitations and stutters only when they don’t change meaning. Examples: 吧、啊、嗯、呃、呢、嘛、欸、喔、然后、就是、那个、这个、好像、之类的、吧吧吧；“uh”, “um”, “er”, “you know”, “like” (when not meaning “similar”), “kind of”, “sort of”. Also trim obvious repeated syllables/words caused by stuttering.
- Preserve technical terms, product names, URLs, code, numbers, currencies, dates, and measures exactly as spoken.
- Do not add or infer missing content. Output only the lightly cleaned text in the original language(s).
""",
                icon: "checkmark.seal.fill",
                description: "Light cleanup: drop fillers/stutters, keep wording and language mix intact.",
                isPredefined: true,
                triggerWords: [],
                useSystemInstructions: true
            ),
            CustomPrompt(
                id: polishPromptId,
                title: "Polish",
                promptText: """
You are polishing a transcript for clarity and correctness without changing intent.
- Handle multilingual and code-mixed input (Chinese/English) without translating.
- Remove filler words/hesitations only when they don’t change meaning (e.g., 吧、啊、嗯、呃、呢、嘛、欸、喔、然后、就是、那个、这个、好像、之类的；“uh”, “um”, “er”, “you know”, “like” when filler; repeated “um um”, “吧吧吧”).
- If the speaker corrects themselves (e.g., “不是A，是B” / “I mean B” / “sorry, B”), keep the final correction and drop the earlier wording.
- Fix grammar, punctuation, and fluency; break run-ons into clear sentences; keep concise wording.
- Preserve technical terms, product names, URLs, code snippets, numbers, currencies, dates, and measures exactly; do not invent or summarize away details.
- Normalize spacing and punctuation across CJK/Latin text. If text is incomplete, don’t hallucinate endings.
- Output only the polished transcript in the original language mix; never translate.
""",
                icon: "wand.and.stars",
                description: "Full polish: clearer grammar/flow, respects final corrections and language mix.",
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
                triggerWords: ["summarize my conversation", "give me a summary of this conversation"],
                useSystemInstructions: true
            ),
            CustomPrompt(
                id: emailDraftPromptId,
                title: "Email Draft",
                promptText: "Rewrite as a concise, polite email with greeting and sign-off. Keep factual details intact.",
                icon: "envelope.fill",
                description: "Auto-activates on email cues",
                isPredefined: true,
                triggerWords: ["draft an email reply", "compose an email reply", "write an email reply"],
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
