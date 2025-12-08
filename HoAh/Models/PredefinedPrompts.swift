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
    static let emailDraftPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000007")!
    static let formalPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000009")!
    static let terminalPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
    static let todoPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000013")!
    static let professionalPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000015")!
    static let vibeCodingPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000017")!
    
    static var all: [CustomPrompt] {
        // Always return the latest predefined prompts from source code
        createDefaultPrompts()
    }
    
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
You rewrite the transcript into concise, formal, and polite written style while keeping the original meaning. Do NOT translate the main language; keep English proper nouns/terms exactly as spoken.
- Input may be Chinese, English, or mixed. Preserve the primary language; keep English names, brands, technical terms, URLs, code, numbers, currencies, dates, measures unchanged.
- Remove fillers/hesitations/stutters that do not affect meaning. Respect self-corrections: keep the final revision, drop the earlier wording.
- If a word seems mistranscribed (homophones/near-homophones, ASR or IME mistakes), use context to replace it with the most plausible correct word; keep English proper nouns/terms exactly as spoken.
- Fix grammar, punctuation, and sentence structure for best readability. Use formal tone and concise wording.
- For Chinese input, watch for homophone or ASR mis-hearings (e.g., 同音字/近音字). Use context to replace mistranscribed words with the most plausible correct words; do not change English terms.
- For English input, ensure clarity and formality; preserve English proper nouns as-is.
- Do not invent or omit facts. If something is ambiguous, choose the most contextually likely wording without adding new information.
- Output only the finalized formal text in the original language mix (with English nouns preserved).
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
Turn the transcript into a concise, actionable TODO list.
- Input may be Chinese, English, or mixed; keep the same language mix for task text and keep English names/terms exactly as spoken.
- First, clean the text: strip gibberish/ASR artifacts/repeated fillers (e.g., 嗯、啊、呃、然后、就是; “uh”, “um”), collapse repeats, and honor self-corrections (“不是A，是B” / “I mean B”) by keeping only the final version.
- If a word seems mistranscribed (Chinese homophones/near-homophones, English ASR/IME slips), use context to replace it with the most plausible correct word; keep English proper nouns/commands unchanged.
- Build a TODO list with bullet points. Each bullet must be a clear, doable action. Add short sub-bullets only when needed for owner, deadline, or key details.
- If the speaker negates/cancels something (“don’t do X”, “no need for Y”), do NOT include it. Skip vague or non-actionable items rather than inventing tasks.
- Output only the TODO list; no extra commentary.
""",
                icon: "checklist",
                description: t("prompt_todo_description"),
                isPredefined: true,
                triggerWords: [
                    "generate to do list",
                    "generate todo list",
                    "create a to do list",
                    "make a task list",
                    "create a task list",
                    "生成待办事项",
                    "生成待办清单",
                    "创建待办清单",
                    "生成待办",
                    "创建任务列表"
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
                    "summarize this transcript",
                    "summarize the above",
                    "give me a summary of this conversation",
                    "write a brief summary",
                    "please summarize",
                    "帮我总结一下",
                    "生成总结",
                    "写一个摘要",
                    "请写摘要",
                    "总结一下上面的内容",
                    "给我一个总结"
                ],
                useSystemInstructions: true
            ),
            CustomPrompt(
                id: emailDraftPromptId,
                title: t("prompt_email_title"),
                promptText: """
Rewrite as a concise, polite, professional email with a clear greeting and sign-off.
- Maintain the original language (Chinese/English/mixed) unless the user explicitly asked to translate.
- Fix obvious mistranscriptions (homophones/near-homophones, ASR/IME slips) using context; keep English names/brands/technical terms exactly as spoken.
- Keep all facts intact (people, dates, numbers, commitments). Do not add or remove information.
- Tone: professional, courteous, readable; keep it brief and structured.
""",
                icon: "envelope.fill",
                description: t("prompt_email_description"),
                isPredefined: true,
                triggerWords: [
                    "draft an email reply",
                    "compose an email reply",
                    "write an email response",
                    "write a reply email",
                    "generate an email reply",
                    "write an email draft",
                    "draft a reply email",
                    "帮我写一封邮件",
                    "写一封回复邮件",
                    "生成回复邮件",
                    "生成邮件草稿",
                    "写封邮件回复",
                    "写邮件回信"
                ],
                useSystemInstructions: true
            ),
            CustomPrompt(
                id: terminalPromptId,
                title: t("prompt_terminal_title"),
                promptText: """
You are a precise command-line assistant.
1. Output ONLY the raw shell command(s). NO markdown (no ```), no explanations, no chat.
2. If the input is natural language (e.g., "list files"), generate the corresponding macOS zsh command (e.g., "ls -la").
3. If the input is a dictated command with typos (e.g., "get status"), fix it (e.g., "git status").
4. Handle "common line" or "comment line" as a shell comment (e.g., "# comment").
5. If ambiguous or unsafe, output `echo "unsafe/ambiguous command"`.
""",
                icon: "terminal.fill",
                description: t("prompt_terminal_description"),
                isPredefined: true,
                triggerWords: [
                    "generate terminal command",
                    "generate shell command",
                    "write shell command",
                    "create shell script",
                    "generate command line",
                    "生成终端命令",
                    "生成 Shell 命令",
                    "写个 Shell 命令",
                    "生成命令行指令",
                    "创建终端指令"
                ],
                useSystemInstructions: true
            ),

            // Assistant remains available for freeform Q&A (manual)
        ]
    }
}
