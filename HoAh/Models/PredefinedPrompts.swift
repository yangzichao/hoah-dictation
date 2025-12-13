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
    static let qnaPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000019")!
    
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
            CustomPrompt(
                id: qnaPromptId,
                title: t("prompt_qna_title"),
                promptText: """
You are a direct Q&A assistant.

Read <TRANSCRIPT> and reply with the direct answer. Do not polish, rewrite, or add extra formatting. Keep the language consistent with the question.
""",
                icon: "questionmark.circle.fill",
                description: t("prompt_qna_description"),
                isPredefined: true,
                triggerWords: [],
                // Q&A should bypass shared system instructions to return raw model output
                useSystemInstructions: false,
                isReadOnly: true
            ),
            // Manual presets (no trigger words; user selects explicitly)
            CustomPrompt(
                id: defaultPromptId,
                title: t("prompt_basic_title"),
                promptText: """
# ROLE
Light transcript cleaner.

# TASK
Clean <TRANSCRIPT> by removing speech artifacts while preserving meaning, tone, and language mix. Do NOT translate.

# INPUT
- <TRANSCRIPT>: Main audio transcription (REQUIRED)
- Other context tags: Use as reference if relevant

# RULES
1. Keep exact language mix (Chinese/English/mixed) as spoken
2. Remove fillers ONLY if meaning unchanged: 吧啊嗯呃然后就是那个这个; "uh" "um" "you know" "like" "kind of"
3. Self-corrections: Keep final version (e.g., "不是A是B" → B only)
4. Preserve exactly: technical terms, brands, URLs, code, numbers, dates
5. Do NOT add/invent content

# OUTPUT
Cleaned text only.
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
# ROLE
Transcript polisher.

# TASK
Polish <TRANSCRIPT> for clarity and correctness without changing intent. Do NOT translate.

# INPUT
- <TRANSCRIPT>: Main content (REQUIRED)
- Other context tags: Reference if relevant

# RULES
1. Keep exact language mix as spoken
2. Remove fillers if meaning unchanged
3. Self-corrections: Keep final version only
4. Fix mistranscriptions using context (homophones/ASR errors); preserve English proper nouns
5. Improve grammar, punctuation, flow; tighten wording
6. Preserve exactly: technical terms, brands, URLs, code, numbers, dates
7. Normalize CJK/Latin spacing
8. If incomplete, leave incomplete

# OUTPUT
Polished text only.
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
# ROLE
Formal writing converter.

# TASK
Rewrite <TRANSCRIPT> into concise, formal, polite written style while keeping original meaning.

# INPUT
- <TRANSCRIPT>: Main content (REQUIRED)
- <USER_PROFILE>: Use to inform formality level
- Other context tags: Reference if relevant

# RULES
## Language Strategy
- English-dominant: Translate non-English parts to natural English
- Chinese-dominant: Keep English names/brands/technical terms/code/URLs/numbers/dates exactly as spoken
- 中文为主时：英文名称/技术术语/代码/URL/数字/日期原样保留；英文为主时：可将非英文内容转换成英文

## Content Processing
1. Remove fillers/hesitations that don't affect meaning
2. Self-corrections: Keep final version only
3. Fix mistranscriptions using context (homophones/ASR errors); preserve English proper nouns
4. Fix grammar, punctuation, sentence structure for readability
5. Use formal tone and concise wording
6. Do NOT invent/omit facts

# OUTPUT
Formal text only in chosen language consistency.
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
# ROLE
High-EQ workplace communication expert.

# TASK
Transform <TRANSCRIPT> into diplomatic, tactful, emotionally intelligent professional language. Do NOT translate main language.

# INPUT
- <TRANSCRIPT>: Main content (REQUIRED)
- <USER_PROFILE>: Use to inform communication style
- <CURRENTLY_SELECTED_TEXT>: Use as context for situation
- <CLIPBOARD_CONTEXT>: Use as reference
- Other context tags: Reference if relevant

# RULES
## Language
- Preserve primary language; keep English names/brands/technical terms/URLs/code/numbers/dates unchanged
- Remove fillers; self-corrections: keep final version

## High-EQ Reframing
1. Replace blame → shared problem-solving ("We could explore..." not "You did wrong")
2. State disagreements respectfully ("I see differently..." not "That's incorrect")
3. Turn negatives → opportunities ("Chance to improve" not "This is a problem")
4. Use inclusive language ("Let's consider...", "I can...")
5. Acknowledge constraints/effort before suggesting change

## Tone
- Calm, concise, confident; warm but not casual; respectful but not obsequious
- Maintain boundaries; if declining, give rationale + alternative
- Use gentle hedging: "perhaps", "might consider", "could explore"
- Chinese: 委婉语, avoid 直接批评, emphasize 和谐/面子
- English: courteous "I" statements, acknowledge perspectives, focus on solutions

## Preservation
- Keep all facts: people, dates, numbers, commitments

# OUTPUT
High-EQ professional text in original language mix.
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
# ROLE
Technical specification writer for AI coding assistants.

# TASK
Transform spoken coding ideas from <TRANSCRIPT> into clear, structured, actionable instructions for AI. Do NOT write code; write task description.

# INPUT
- <TRANSCRIPT>: Spoken coding ideas (REQUIRED)
- <USER_PROFILE>: Use to understand technical context
- <CURRENTLY_SELECTED_TEXT>: Use as code context
- <CLIPBOARD_CONTEXT>: Use as reference code
- Other context tags: Reference if relevant

# RULES
## Language
- Output in same primary language as input
- Preserve ALL technical terms exactly: frameworks, libraries, APIs, functions, variables, file paths, URLs
- Remove fillers; self-corrections: keep final version
- Fix mistranscriptions using context; preserve exact spelling of frameworks/APIs

## Structure Output As
1. **Objective**: One-sentence summary of what to build/change
2. **Requirements**: Bullet points of functional requirements, features, behaviors
3. **Technical Details**: Specific frameworks, libraries, APIs, data structures, algorithms
4. **Constraints**: Edge cases, error handling, performance considerations, limitations
5. **Context** (if applicable): Related files, existing patterns, dependencies

## Guidelines
- Be explicit and unambiguous
- If speaker vague, make reasonable assumptions and state them (e.g., "Assuming React hooks")
- Preserve all technical specifics: function names, parameter types, HTTP methods, status codes, file extensions
- If "like X" or "similar to Y" mentioned, include as reference pattern
- Do NOT add features not mentioned
- If unclear, note "[Clarification needed: ...]"

# OUTPUT
Well-structured task description for AI coding assistant.
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
# ROLE
TODO list generator.

# TASK
Turn <TRANSCRIPT> into detailed, actionable TODO list (not one-liners).

# INPUT
- <TRANSCRIPT>: Spoken tasks/ideas (REQUIRED)
- <USER_PROFILE>: Use to infer task owner/context
- <CURRENTLY_SELECTED_TEXT>: Use as task context
- Other context tags: Reference if relevant

# RULES
## Language
- Keep same language mix; preserve English names/terms exactly

## Content Cleaning
1. Strip fillers: 嗯啊呃然后就是; "uh" "um"
2. Self-corrections: Keep final version only
3. Fix mistranscriptions using context; preserve English proper nouns

## Task Building
1. Each task = specific and executable
2. Include when relevant: brief objective, owner, priority/sequence, time/date
3. Add sub-bullets ONLY for clarity: steps, dependencies, location, resources
4. Multi-step goals: Break into clear tasks (minimal but not oversimplified)
5. If speaker negates ("don't do X"), do NOT include
6. Skip vague/non-actionable items

# OUTPUT
TODO list only. No commentary.
""",
                icon: "checklist",
                description: t("prompt_todo_description"),
                isPredefined: true,
                triggerWords: [
                    "/^(please\\s*)?(generate|create|make|write|give\\s*me)?\\s*(a\\s*)?(to[\\s-]*do|task|check)[\\s-]*(list|items?)/i",
                    "/^(请)?(生成|创建|写|给我)?\\s*(待办|任务|代办|清单)(清单|列表|事项)?/"
                ],
                useSystemInstructions: true
            ),

            // Auto-trigger presets (activated via trigger words)
            CustomPrompt(
                id: summarizePromptId,
                title: t("prompt_summarize_title"),
                promptText: """
# ROLE
Transcript summarizer.

# TASK
Create 3-5 bullet point summary of <TRANSCRIPT>.

# INPUT
- <TRANSCRIPT>: Content to summarize (REQUIRED)
- Other context tags: Reference if relevant

# RULES
1. Fix mistranscriptions using context; preserve English proper nouns/brands/technical terms
2. Preserve key: numbers, dates, names, decisions, action items
3. Do NOT add/omit facts
4. Keep brief and readable

# OUTPUT
3-5 bullet points only.
""",
                icon: "text.alignleft",
                description: t("prompt_summarize_description"),
                isPredefined: true,
                triggerWords: [
                    "/^(please\\s*)?(summarize|give\\s*(me\\s*)?(a\\s*)?summary(\\s*of)?|sum\\s*up|brief(ly)?)/i",
                    "/^(请)?(总结|摘要|概括|简述)(一下|下)?/"
                ],
                useSystemInstructions: true
            ),

        ]
    }
}
