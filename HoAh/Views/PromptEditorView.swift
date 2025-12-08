import SwiftUI

struct PromptEditorView: View {
    enum Mode: Equatable {
        case add(kind: PromptKind)
        case edit(CustomPrompt)
        
        static func == (lhs: Mode, rhs: Mode) -> Bool {
            switch (lhs, rhs) {
            case let (.add(kind1), .add(kind2)):
                return kind1 == kind2
            case let (.edit(prompt1), .edit(prompt2)):
                return prompt1.id == prompt2.id
            default:
                return false
            }
        }
    }
    
    let mode: Mode
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @State private var title: String
    @State private var promptText: String
    @State private var selectedIcon: PromptIcon
    @State private var description: String
    @State private var triggerWords: [String]
    @State private var showingPredefinedPrompts = false
    @State private var useSystemInstructions: Bool
    @State private var showingIconPicker = false

    private var isTriggerKind: Bool {
        switch mode {
        case .add(let kind):
            return kind == .trigger
        case .edit(let prompt):
            return enhancementService.triggerPrompts.contains(where: { $0.id == prompt.id })
        }
    }
    private var shouldShowTriggerWordsEditor: Bool { isTriggerKind }

    private var isEditingPredefinedPrompt: Bool {
        if case .edit(let prompt) = mode {
            return prompt.isPredefined
        }
        return false
    }
    
    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .add:
            _title = State(initialValue: "")
            _promptText = State(initialValue: "")
            _selectedIcon = State(initialValue: "doc.text.fill")
            _description = State(initialValue: "")
            _triggerWords = State(initialValue: [])
            _useSystemInstructions = State(initialValue: true)
        case .edit(let prompt):
            _title = State(initialValue: prompt.title)
            _promptText = State(initialValue: prompt.promptText)
            _selectedIcon = State(initialValue: prompt.icon)
            _description = State(initialValue: prompt.description ?? "")
            _triggerWords = State(initialValue: prompt.triggerWords)
            _useSystemInstructions = State(initialValue: prompt.useSystemInstructions)
        }
    }
    
    private var headerTitle: String {
        switch mode {
        case .add:
            return NSLocalizedString("New Prompt", comment: "Title for creating a new prompt")
        case .edit:
            return isEditingPredefinedPrompt 
                ? NSLocalizedString("Edit Built-in Prompt", comment: "Title for editing a built-in prompt")
                : NSLocalizedString("Edit Prompt", comment: "Title for editing a custom prompt")
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerBar
            ScrollView {
                contentSections
                    .padding(.vertical, 20)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    private var headerBar: some View {
        HStack {
            Text(headerTitle)
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Button {
                    save()
                    dismiss()
                } label: {
                    Text("Save")
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding()
        .background(
            Color(NSColor.windowBackgroundColor)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
        )
    }

    @ViewBuilder
    private var contentSections: some View {
        VStack(spacing: 24) {
            builtInNotice
            titleAndIcon
            descriptionField
            promptTextSection
            if shouldShowTriggerWordsEditor {
                TriggerWordsEditor(triggerWords: $triggerWords)
                    .padding(.horizontal)
            }
            templatePicker
        }
    }

    @ViewBuilder
    private var builtInNotice: some View {
        if isEditingPredefinedPrompt, case .edit(let prompt) = mode {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Built-in prompt")
                        .font(.headline)
                    Text("Default and other built-in prompts can be edited but not deleted. Reset anytime to restore the original text and trigger words.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Reset to Default") {
                    resetToDefaultTemplate(for: prompt)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    private var titleAndIcon: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.headline)
                    .foregroundColor(.secondary)
                TextField("Enter a short, descriptive title", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
            }
            .frame(maxWidth: .infinity)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Icon")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    showingIconPicker = true
                }) {
                    Image(systemName: selectedIcon)
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                        .frame(width: 48, height: 48)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .popover(isPresented: $showingIconPicker, arrowEdge: .bottom) {
                IconPickerPopover(selectedIcon: $selectedIcon, isPresented: $showingIconPicker)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Add a brief description of what this prompt does")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextField("Enter a description", text: $description)
                .textFieldStyle(.roundedBorder)
                .font(.body)
        }
        .padding(.horizontal)
    }

    private var promptTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prompt Instructions")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Define how AI should enhance your transcriptions")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                Toggle("Use System Instructions", isOn: $useSystemInstructions)
                
                InfoTip(
                    title: "System Instructions",
                    message: "If enabled, your instructions are combined with a general-purpose template to improve transcription quality.\n\nDisable for full control over the AI's system prompt (for advanced users)."
                )
            }
            .padding(.bottom, 4)

            TextEditor(text: $promptText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 200)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var templatePicker: some View {
        if case .add = mode {
            Button("Start with a Predefined Template") {
                showingPredefinedPrompts.toggle()
            }
            .font(.headline)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color(.windowBackgroundColor).opacity(0.9))
            )
            .overlay(
                Capsule()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .buttonStyle(.plain)
            .padding(.horizontal)
            .popover(isPresented: $showingPredefinedPrompts, arrowEdge: .bottom) {
                PredefinedPromptsView { template in
                    applyTemplate(template)
                }
            }
        }
    }
    
    private func applyTemplate(_ template: TemplatePrompt) {
        title = template.title
        promptText = template.promptText
        selectedIcon = template.icon
        description = template.description ?? ""
        triggerWords = []
        showingPredefinedPrompts = false
    }
    
    private func save() {
        switch mode {
        case .add(let kind):
            let cleanedTriggers = (kind == .trigger) ? triggerWords : []
            enhancementService.addPrompt(
                title: title,
                promptText: promptText,
                icon: selectedIcon,
                description: description.isEmpty ? nil : description,
                triggerWords: cleanedTriggers,
                useSystemInstructions: useSystemInstructions,
                kind: kind
            )
        case .edit(let prompt):
            let isTriggerPrompt = enhancementService.triggerPrompts.contains(where: { $0.id == prompt.id })
            let cleanedTriggers = isTriggerPrompt ? triggerWords : []
            let updatedPrompt = CustomPrompt(
                id: prompt.id,
                title: title,
                promptText: promptText,
                isActive: prompt.isActive,
                icon: selectedIcon,
                description: description.isEmpty ? nil : description,
                isPredefined: prompt.isPredefined,
                triggerWords: cleanedTriggers,
                useSystemInstructions: useSystemInstructions
            )
            enhancementService.updatePrompt(updatedPrompt)
        }
    }

    private func resetToDefaultTemplate(for prompt: CustomPrompt) {
        guard let template = PredefinedPrompts.createDefaultPrompts().first(where: { $0.id == prompt.id }) else { return }

        title = template.title
        promptText = template.promptText
        selectedIcon = template.icon
        description = template.description ?? ""
        triggerWords = template.triggerWords
        useSystemInstructions = template.useSystemInstructions

        enhancementService.resetPromptToDefault(prompt)
    }
}

// Reusable Trigger Words Editor Component
struct TriggerWordsEditor: View {
    @Binding var triggerWords: [String]
    @State private var newTriggerWord: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trigger Words")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Add multiple words that can activate this prompt")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Display existing trigger words as tags
            if !triggerWords.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 220))], spacing: 8) {
                    ForEach(triggerWords, id: \.self) { word in
                        TriggerWordItemView(word: word) {
                            triggerWords.removeAll { $0 == word }
                        }
                    }
                }
            }
            
            // Input for new trigger word
            HStack {
                TextField("Add trigger word", text: $newTriggerWord)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .onSubmit {
                        addTriggerWord()
                    }
                
                Button("Add") {
                    addTriggerWord()
                }
                .disabled(newTriggerWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    
    private func addTriggerWord() {
        let trimmedWord = newTriggerWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWord.isEmpty else { return }
        
        // Check for duplicates (case insensitive)
        let lowerCaseWord = trimmedWord.lowercased()
        guard !triggerWords.contains(where: { $0.lowercased() == lowerCaseWord }) else { return }
        
        triggerWords.append(trimmedWord)
        newTriggerWord = ""
    }
}


struct TriggerWordItemView: View {
    let word: String
    let onDelete: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 6) {
            Text(word)
                .font(.system(size: 13))
                .lineLimit(1)
                .foregroundColor(.primary)
            
            Spacer(minLength: 8)
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isHovered ? .red : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.borderless)
            .help("Remove word")
            .onHover { hover in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hover
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.windowBackgroundColor).opacity(0.4))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        }
    }
}

// Icon Picker Popover - shows icons in a grid format without category labels
struct IconPickerPopover: View {
    @Binding var selectedIcon: PromptIcon
    @Binding var isPresented: Bool
    
    var body: some View {
        let columns = [
            GridItem(.adaptive(minimum: 45, maximum: 52), spacing: 14)
        ]
        
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(PromptIcon.allCases, id: \.self) { icon in
                    Button(action: {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            selectedIcon = icon
                            isPresented = false
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedIcon == icon ? Color(NSColor.windowBackgroundColor) : Color(NSColor.controlBackgroundColor))
                                .frame(width: 52, height: 52)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedIcon == icon ? Color(NSColor.separatorColor) : Color.secondary.opacity(0.2), lineWidth: selectedIcon == icon ? 2 : 1)
                                )
                            
                            Image(systemName: icon)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .scaleEffect(selectedIcon == icon ? 1.1 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: selectedIcon == icon)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .frame(width: 400, height: 400)
    }
}
