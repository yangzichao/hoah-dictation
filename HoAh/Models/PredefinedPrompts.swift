import Foundation
import SwiftUI    // Import to ensure we have access to SwiftUI types if needed

enum PredefinedPrompts {
    private static let predefinedPromptsKey = "PredefinedPrompts"
    private static func t(_ key: String) -> String {
        NSLocalizedString(key, bundle: .main, comment: "")
    }
    
    // Static UUIDs for predefined prompts
    static let defaultPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let polishPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    static let summarizePromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
    static let formalPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000009")!

    static let todoPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000013")!
    static let professionalPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000015")!
    static let vibeCodingPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000017")!
    
    static var all: [CustomPrompt] {
        // Always return the latest predefined prompts from source code
        createDefaultPrompts()
    }
    
    /// Returns the initial set of predefined prompts.
    ///
    /// # Guide for Future AI: Defining Trigger Words
    ///
    /// Triggers determine when a specific prompt is automatically selected based on the user's dictated text.
    /// You can define triggers in two ways:
    ///
    /// 1. **Simple String Match**:
    ///    - "phrase" -> Matches if the text *starts with*, *ends with*, or *is exactly* this phrase.
    ///    - Case-insensitive matching logic applies, but it is less flexible than Regex.
    ///    - Example: "summarize this"
    ///
    /// 2. **Regex Match** (Recommended for robustness):
    ///    - Syntax: `/pattern/flags`
    ///    - Wrap the pattern in forward slashes `/.../`.
    ///    - Append flags after the closing slash.
    ///    - Flags Supported:
    ///      - `i`: Case Insensitive (Most used). Matches "todo", "ToDo", "TODO".
    ///      - `m`: Multiline mode (`^` and `$` match start/end of lines).
    ///      - `s`: Dot matches newlines.
    ///
    /// # Best Practices for Regex Triggers
    ///
    /// * **Be Flexible with Spacing**: Use `\s*` or `[\s-]*` for optional spaces/hyphens.
    ///   - Bad: `/to do/i` (Misses "to-do", "todo")
    ///   - Good: `/(to[\s-]*do|task)\s*list/i`
    ///
    /// * **Make Verbs Optional**: Users often drop the verb.
    ///   - Bad: `/generate todo list/i` (Misses just "todo list")
    ///   - Good: `/(generate|create|make)?.*todo list/i`
    ///
    /// * **Avoid Over-Matching**: Don't use `.*` too liberally at the start/end if it risks matching common sentences.
    ///   - Bad: `/.*email.*/i` (Matches "I will email you later")
    ///   - Good: `/(draft|write|compose).*(email|reply)/i` (Matches "Draft an email", "Compose reply")
    ///
    /// * **Capture Variants**: Use groupings `(a|b)` for synonyms.
    ///   - English: `/(summarize|summary|brief)/i`
    ///   - Chinese: `/(总结|摘要|概括)/`
    static func createDefaultPrompts() -> [CustomPrompt] {
        [
            // Manual presets (no trigger words; user selects explicitly)
            CustomPrompt(
                id: defaultPromptId,
                title: t("prompt_basic_title"),
                promptText: """
You are a light transcript cleaner. Keep the original meaning, tone, and language mix; do NOT translate.
- Input can be Chinese, English, or mixed. Keep the same languages and code-mix.
- Remove obvious fillers/hesitations/stutters only if they don’t change meaning. Examples: 吧、啊、嗯、呃、呢、嘛、欸、喔、然后、就是、那个、这个、好像、之类的、吧吧吧；“uh”, “um”, “er”, “you know”, “like” (when not meaning “similar”), “kind of”, “sort of”; repeated syllables from stuttering.
- If the speaker self-corrects (e.g., “不是A，是B” / “I mean B”), keep the final correction and drop the earlier wording.
- Preserve technical terms, product names, URLs, code, numbers, currencies, dates, and measures exactly as spoken.
- Do not add or invent content. If the input is incomplete, leave it incomplete.
- Output only the lightly cleaned text in the original language mix.
""",
                icon: "checkmark.seal.fill",
                description: t("prompt_basic_description"),
                isPredefined: true,
                triggerWords: [],
                useSystemInstructions: true
            ),
            CustomPrompt(
                id: polishPromptId,
                title: t("prompt_polish_title"),
                promptText: """
You are polishing a transcript for clarity, concision, and correctness without changing intent. Do NOT translate.
- Input may be Chinese, English, or mixed; keep the same language mix.
- Remove fillers/hesitations/stutters only if meaning is unchanged. Examples: 吧、啊、嗯、呃、呢、嘛、欸、喔、然后、就是、那个、这个、好像、之类的、吧吧吧；“uh”, “um”, “er”, “you know”, “like” (when filler), “kind of”, “sort of”; repeated syllables/words from stuttering.
- Respect self-corrections: if the speaker revises (e.g., “不是A，是B” / “I mean B”), keep the final correction, drop the earlier wording.
- If a word seems mistranscribed (homophones/near-homophones, ASR or IME mistakes), use context to pick the most plausible correct word—preserve English proper nouns/terms as spoken.
- Improve grammar, punctuation, and flow; split run-ons; tighten wording while keeping meaning.
- Preserve technical terms, product names, URLs, code, numbers, currencies, dates, measures exactly; do not invent or omit details.
- Normalize spacing/punctuation across CJK/Latin text. If input is incomplete, leave it incomplete.
- Output only the polished text in the original language mix; no added commentary.
""",
                icon: "wand.and.stars",
                description: t("prompt_polish_description"),
                isPredefined: true,
                triggerWords: [],
                useSystemInstructions: true
            ),
            CustomPrompt(
                id: formalPromptId,
                title: t("prompt_formal_title"),
                promptText: """
You rewrite the transcript into concise, formal, and polite written style while keeping the original meaning. For English-dominant input, translate non-English parts into natural English. For Chinese-dominant input, do NOT translate English names/brands/technical terms/code/URLs/numbers/dates/measures—keep them exactly as spoken.
- 输入可能是中文、英文或混合：保持主语言一致；中文为主时，英文名称/技术术语/代码/URL/数字/日期/度量单位原样保留；英文为主时，可将非英文内容自然转换成英文。
- Remove fillers/hesitations/stutters that do not affect meaning. Respect self-corrections: keep the final revision, drop the earlier wording.
- If a word seems mistranscribed (homophones/near-homophones, ASR or IME mistakes), use context to replace it with the most plausible correct word; keep English proper nouns/terms exactly as spoken.
- Fix grammar, punctuation, and sentence structure for best readability. Use formal tone and concise wording.
- For Chinese input, watch for homophone or ASR mis-hearings (e.g., 同音字/近音字). Use context to replace mistranscribed words with the most plausible correct words; do not change English terms.
- For English input, ensure clarity and formality; preserve English proper nouns as-is.
- Do not invent or omit facts. If something is ambiguous, choose the most contextually likely wording without adding new information.
- Output only the finalized formal text in the chosen language consistency (with English nouns preserved where applicable). This mode should provide polished writing output.
""",
                icon: "doc.text.magnifyingglass",
                description: t("prompt_formal_description"),
                isPredefined: true,
                triggerWords: [],
                useSystemInstructions: true
            ),
            CustomPrompt(
                id: professionalPromptId,
                title: t("prompt_professional_title"),
                promptText: """
You are a high-EQ workplace communication expert. Transform the transcript into diplomatic, tactful, and emotionally intelligent professional language. Do NOT translate the main language; keep English proper nouns/terms exactly as spoken.
- Input may be Chinese, English, or mixed; preserve the primary language and keep English names, brands, technical terms, URLs, code, numbers, currencies, dates, measures unchanged.
- Remove fillers/hesitations/stutters. Honor self-corrections: keep the final revision, drop the earlier wording.
- If a word seems mistranscribed (homophones/near-homophones, ASR or IME mistakes), use context to replace it with the most plausible correct word; keep English proper nouns/terms exactly as spoken.
- Reframe direct criticism or tension into collaborative, face-saving language:
  * Replace blame with shared problem-solving ("We could explore..." instead of "You did this wrong")
  * State disagreements with respect ("I see it differently..." instead of "That's incorrect")
  * Turn negatives into opportunities ("This is a chance to improve..." instead of "This is a problem")
  * Use inclusive language and first-person accountability ("Let's consider...", "I can...")
  * Acknowledge constraints and appreciate effort before suggesting change
- Keep tone calm, concise, and confident; warm but not overly casual, respectful but not obsequious.
- Maintain boundaries: avoid over-promising; if declining, give a brief rationale and, when possible, an alternative or next step.
- Preserve all factual content (people, dates, numbers, commitments) while elevating emotional intelligence and clarity.
- Use gentle hedging where needed ("perhaps", "might consider", "could explore") to soften sharp edges without diluting intent.
- For Chinese input, use 委婉语, avoid 直接批评, emphasize 和谐 and 面子; for English input, use courteous "I" statements, acknowledge perspectives, and focus on solutions.
- Output only the refined high-EQ professional text in the original language mix (with English nouns preserved).
""",
                icon: "person.2.fill",
                description: t("prompt_professional_description"),
                isPredefined: true,
                triggerWords: [],
                useSystemInstructions: true
            ),
            CustomPrompt(
                id: vibeCodingPromptId,
                title: t("prompt_vibe_coding_title"),
                promptText: """
You are a technical specification writer for AI coding assistants. Transform spoken coding ideas into clear, structured, and actionable instructions that an AI can use to write code. Do NOT write code yourself; write the task description for the AI.
- Input may be Chinese, English, or mixed. Output in the same primary language; preserve ALL technical terms (frameworks, libraries, APIs, functions, variable names, file paths, URLs) exactly as spoken in English.
- Remove fillers/hesitations/stutters. Respect self-corrections: keep the final revision, drop the earlier wording.
- If a word seems mistranscribed (homophones/near-homophones, ASR or IME mistakes), use context to replace it with the most plausible correct technical term; preserve exact spelling of frameworks/APIs.
- Structure the output clearly:
  1. **Objective**: One-sentence summary of what needs to be built/changed
  2. **Requirements**: Bullet points of functional requirements, features, or behaviors
  3. **Technical Details**: Specific frameworks, libraries, APIs, data structures, algorithms mentioned
  4. **Constraints**: Edge cases, error handling, performance considerations, or limitations mentioned
  5. **Context** (if applicable): Related files, existing code patterns, or dependencies
- Be explicit and unambiguous. If the speaker was vague, make reasonable technical assumptions and state them clearly (e.g., "Assuming React hooks for state management").
- Preserve all technical specifics: exact function names, parameter types, HTTP methods, status codes, file extensions, etc.
- If the speaker mentions "like X" or "similar to Y", include that as a reference pattern.
- Do NOT add features or requirements not mentioned. If something is unclear, note it as "[Clarification needed: ...]".
- Output a well-structured task description that an AI coding assistant can immediately act upon.
""",
                icon: "chevron.left.forwardslash.chevron.right",
                description: t("prompt_vibe_coding_description"),
                isPredefined: true,
                triggerWords: [],
                useSystemInstructions: true
            ),

            CustomPrompt(
                id: todoPromptId,
                title: t("prompt_todo_title"),
                promptText: """
Turn the transcript into a detailed, actionable TODO list (not just one-liners).
- Input may be Chinese, English, or mixed; keep the same language mix for tasks and keep English names/terms exactly as spoken.
- Clean text first: strip gibberish/ASR artifacts/repeated fillers (e.g., 嗯、啊、呃、然后、就是; “uh”, “um”), collapse repeats, and honor self-corrections (“不是A，是B” / “I mean B”) by keeping only the final version. Fix obvious mistranscriptions (Chinese homophones/near-homophones, English ASR/IME slips) using context; keep English proper nouns/commands unchanged.
- Build bullet points where each task is specific and executable. Include concise detail: brief objective, owner (if mentioned or implied), priority or sequence (if implied), and time/when (date/relative timing) when present. Add short sub-bullets only when they add clarity (steps, dependencies, location, resources).
- If something is a multi-step goal, break it into a few clear tasks instead of a vague umbrella item; keep it minimal but not oversimplified.
- If the speaker negates/cancels something (“don’t do X”, “no need for Y”), do NOT include it. Skip vague or non-actionable items rather than inventing tasks.
- Output only the TODO list; no extra commentary.
""",
                icon: "checklist",
                description: t("prompt_todo_description"),
                isPredefined: true,
                triggerWords: [
                    "/(generate|create|make|write)?.*(to[\\s-]*do|task)\\s*list/i",
                    "/.*(生成|创建|写).*(待办|任务|代办)(清单|列表|事项)?/"
                ],
                useSystemInstructions: true
            ),

            // Auto-trigger presets (activated via trigger words)
            CustomPrompt(
                id: summarizePromptId,
                title: t("prompt_summarize_title"),
                promptText: """
Create a crisp summary in 3–5 bullet points.
- Fix obvious mistranscriptions (homophones/near-homophones, ASR/IME slips) using context; keep English proper nouns/brands/technical terms exactly as spoken.
- Preserve key numbers, dates, names, decisions, and action items. Do not add or omit facts.
- Keep wording brief and readable; no extra commentary.
""",
                icon: "text.alignleft",
                description: t("prompt_summarize_description"),
                isPredefined: true,
                triggerWords: [
                    "/(please)?\\s*(summarize|give.*summary).*/i",
                    "/.*(总结|摘要).*/"
                ],
                useSystemInstructions: true
            ),

        ]
    }
}
