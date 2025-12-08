import SwiftUI
import UniformTypeIdentifiers

struct EnhancementSettingsView: View {
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @EnvironmentObject private var aiService: AIService
    @State private var isEditingPrompt = false
    @State private var isSettingsExpanded = true
    @State private var isProviderExpanded = false
    @State private var selectedPromptForEdit: CustomPrompt?
    @State private var pendingPromptKind: PromptKind = .active
    @State private var showProviderAlert = false
    @State private var isUserProfileExpanded = false

    private var autoPrompts: [CustomPrompt] { enhancementService.activePrompts }
    private var triggerPrompts: [CustomPrompt] { enhancementService.triggerPrompts }

    private var activeAutoPromptTitle: String {
        if let prompt = autoPrompts.first(where: { $0.id == enhancementService.selectedPromptId }) {
            return prompt.displayTitle
        }
        return NSLocalizedString("None", comment: "")
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Main Settings Sections
                VStack(spacing: 24) {
                    // Enable/Disable Toggle Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Enable Auto Enhancement")
                                        .font(.headline)
                                     
                                    InfoTip(
                                        title: "AI Enhancement",
                                        message: "AI enhancement lets you pass the transcribed audio through LLMS to post-process using different prompts suitable for different use cases like e-mails, summary, writing, etc.",
                                        learnMoreURL: "https://www.youtube.com/@tryvoiceink/videos"
                                    )
                                }
                                
                                Text("Automatically apply AI-powered enhancement after each transcription")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { enhancementService.isEnhancementEnabled },
                                set: { newValue in
                                    if newValue {
                                        if aiService.isAPIKeyValid {
                                            enhancementService.isEnhancementEnabled = true
                                        } else {
                                            // User tries to enable but no provider configured
                                            isProviderExpanded = true
                                            showProviderAlert = true
                                        }
                                    } else {
                                        enhancementService.isEnhancementEnabled = false
                                    }
                                }
                            ))
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .labelsHidden()
                            .scaleEffect(1.2)
                            .popover(isPresented: $showProviderAlert) {
                                Text(NSLocalizedString("ai_provider_configure_prompt", comment: ""))
                                    .padding()
                                    .foregroundColor(.red)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Clipboard Context", isOn: $enhancementService.useClipboardContext)
                                .toggleStyle(.switch)
                                .disabled(!enhancementService.isEnhancementEnabled)
                            Text("Use text from clipboard to understand the context")
                                .font(.caption)
                                .foregroundColor(enhancementService.isEnhancementEnabled ? .secondary : .secondary.opacity(0.5))
                        }
                    }
                    .padding()
                    .background(CardBackground(isSelected: false))
                    
                    // 1. AI Provider Integration Section (Collapsible)
                    DisclosureGroup(isExpanded: $isProviderExpanded) {
                        VStack(alignment: .leading, spacing: 16) {
                            Divider()
                            APIKeyManagementView()
                        }
                    } label: {
                        HStack {
                            Text("AI Provider Integration")
                                .font(.headline)
                            
                            Spacer()
                            
                            // Status Badge
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(aiService.isAPIKeyValid ? Color.green : Color.orange)
                                    .frame(width: 8, height: 8)
                                
                                if aiService.isAPIKeyValid {
                                    Text("\(aiService.selectedProvider.rawValue) (\(NSLocalizedString("provider_status_ready", comment: "")))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(NSLocalizedString("provider_status_not_configured", comment: ""))
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(CardBackground(isSelected: false))
                    
                    // 3. Enhancement Modes & Assistant Section
                    VStack(alignment: .leading, spacing: 16) {
                        // Auto enhancement (manual selection) section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Auto Enhancement Modes")
                                    .font(.headline)
                                Spacer()
                                Button("Reset Built-in Prompts") {
                                    enhancementService.resetPredefinedPrompts()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            
                            Text("\(NSLocalizedString("ai_enhancement_auto_prompt_hint", comment: "")) \(activeAutoPromptTitle).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        ReorderablePromptGrid(
                            boundPrompts: $enhancementService.activePrompts,
                            selectedPromptId: enhancementService.selectedPromptId,
                            onPromptSelected: { prompt in
                                enhancementService.setActivePrompt(prompt)
                            },
                            onEditPrompt: { prompt in
                                selectedPromptForEdit = prompt
                            },
                            onDeletePrompt: { prompt in
                                enhancementService.deletePrompt(prompt)
                            },
                            onAddNewPrompt: {
                                pendingPromptKind = .active
                                isEditingPrompt = true
                            }
                        )

                        Divider()

                        // Trigger-based prompts section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Prompt Triggers")
                                    .font(.headline)
                                Spacer()
                                Toggle(
                                    "Enable Prompt Triggers",
                                    isOn: Binding(
                                        get: { enhancementService.arePromptTriggersEnabled },
                                        set: { newValue in
                                            enhancementService.arePromptTriggersEnabled = newValue
                                            if newValue && !enhancementService.isEnhancementEnabled {
                                                enhancementService.isEnhancementEnabled = true
                                            }
                                        }
                                    )
                                )
                                .toggleStyle(.switch)
                            }
                            
                            Text("When enabled, these prompts auto-activate if their trigger words are present in your text.")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if !enhancementService.isEnhancementEnabled {
                                Text("Auto enhancement is off, so triggers are inactive until you turn it on.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        ReorderablePromptGrid(
                            boundPrompts: $enhancementService.triggerPrompts,
                            selectedPromptId: nil,
                            onPromptSelected: { _ in },
                            onEditPrompt: { prompt in
                                selectedPromptForEdit = prompt
                            },
                            onDeletePrompt: { prompt in
                                enhancementService.deletePrompt(prompt)
                            },
                            onAddNewPrompt: {
                                pendingPromptKind = .trigger
                                isEditingPrompt = true
                            },
                            isEnabled: enhancementService.isEnhancementEnabled && enhancementService.arePromptTriggersEnabled
                        )
                    }
                    .padding()
                    .background(CardBackground(isSelected: false))
                    
                    // User Profile Section
                    DisclosureGroup(isExpanded: $isUserProfileExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            Divider()
                            
                            Text(NSLocalizedString("Provide optional context about yourself to help AI better tailor responses. This information will be included in all enhancement requests.", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            ZStack(alignment: .topLeading) {
                                if enhancementService.userProfileContext.isEmpty {
                                    Text(NSLocalizedString("user_profile_placeholder", comment: ""))
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary.opacity(0.5))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 8)
                                }
                                
                                TextEditor(text: $enhancementService.userProfileContext)
                                    .font(.system(size: 13))
                                    .frame(minHeight: 100, maxHeight: 150)
                                    .scrollContentBackground(.hidden)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            
                            HStack {
                                Text("\(enhancementService.userProfileContext.count) / 500")
                                    .font(.caption2)
                                    .foregroundColor(enhancementService.userProfileContext.count > 500 ? .red : .secondary)
                                
                                Spacer()
                                
                                if !enhancementService.userProfileContext.isEmpty {
                                    Button(NSLocalizedString("Clear", comment: "")) {
                                        enhancementService.userProfileContext = ""
                                    }
                                    .buttonStyle(.plain)
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(NSLocalizedString("User Profile", comment: ""))
                                .font(.headline)
                            
                            InfoTip(
                                title: NSLocalizedString("User Profile", comment: ""),
                                message: NSLocalizedString("Optional: Add context about yourself (name, role, industry, tech stack, etc.) to help AI provide more relevant responses.", comment: "")
                            )
                            
                            Spacer()
                            
                            if !enhancementService.userProfileContext.isEmpty {
                                Text(NSLocalizedString("Configured", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(CardBackground(isSelected: false))
                    
                    EnhancementShortcutsSection()
                }
            }
            .padding(24)
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(isPresented: $isEditingPrompt) {
            PromptEditorView(mode: .add(kind: pendingPromptKind))
        }
        .sheet(item: $selectedPromptForEdit) { prompt in
            PromptEditorView(mode: .edit(prompt))
        }
    }
}

// MARK: - Drag & Drop Reorderable Grid
private struct ReorderablePromptGrid: View {
    @EnvironmentObject private var enhancementService: AIEnhancementService
    
    @Binding var boundPrompts: [CustomPrompt]
    let selectedPromptId: UUID?
    let onPromptSelected: (CustomPrompt) -> Void
    let onEditPrompt: ((CustomPrompt) -> Void)?
    let onDeletePrompt: ((CustomPrompt) -> Void)?
    let onAddNewPrompt: (() -> Void)?
    var isEnabled: Bool = true
    
    @State private var draggingItem: CustomPrompt?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if boundPrompts.isEmpty {
                Text("No prompts available")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                let columns = [
                    GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 36)
                ]
                
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(boundPrompts) { prompt in
                        prompt.promptIcon(
                            isSelected: selectedPromptId == prompt.id,
                            onTap: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    onPromptSelected(prompt)
                                }
                            },
                            onEdit: onEditPrompt,
                            onDelete: onDeletePrompt
                        )
                        .opacity(draggingItem?.id == prompt.id ? 0.3 : 1.0)
                        .scaleEffect(draggingItem?.id == prompt.id ? 1.05 : 1.0)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    draggingItem != nil && draggingItem?.id != prompt.id
                                    ? Color.accentColor.opacity(0.25)
                                    : Color.clear,
                                    lineWidth: 1
                                )
                        )
                        .animation(.easeInOut(duration: 0.15), value: draggingItem?.id == prompt.id)
                        .onDrag {
                            draggingItem = prompt
                            return NSItemProvider(object: prompt.id.uuidString as NSString)
                        }
                        .onDrop(
                            of: [UTType.text],
                            delegate: PromptDropDelegate(
                                item: prompt,
                                prompts: $boundPrompts,
                                draggingItem: $draggingItem
                            )
                        )
                    }
                    
                    if let onAddNewPrompt = onAddNewPrompt {
                        CustomPrompt.addNewButton {
                            onAddNewPrompt()
                        }
                        .help("Add new prompt")
                        .onDrop(
                            of: [UTType.text],
                            delegate: PromptEndDropDelegate(
                                prompts: $boundPrompts,
                                draggingItem: $draggingItem
                            )
                        )
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .opacity(isEnabled ? 1 : 0.55)
                
                HStack {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Double-click to edit • Right-click for more options")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Drop Delegates
private struct PromptDropDelegate: DropDelegate {
    let item: CustomPrompt
    @Binding var prompts: [CustomPrompt]
    @Binding var draggingItem: CustomPrompt?
    
    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem, draggingItem != item else { return }
        guard let fromIndex = prompts.firstIndex(of: draggingItem),
              let toIndex = prompts.firstIndex(of: item) else { return }
        
        // Move item as you hover for immediate visual update
        if prompts[toIndex].id != draggingItem.id {
            withAnimation(.easeInOut(duration: 0.12)) {
                let from = fromIndex
                let to = toIndex
                prompts.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            }
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }
}

private struct PromptEndDropDelegate: DropDelegate {
    @Binding var prompts: [CustomPrompt]
    @Binding var draggingItem: CustomPrompt?
    
    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    
    func performDrop(info: DropInfo) -> Bool {
        guard let draggingItem = draggingItem,
              let currentIndex = prompts.firstIndex(of: draggingItem) else {
            self.draggingItem = nil
            return false
        }
        
        // Move to end if dropped on the trailing "Add New" tile
        withAnimation(.easeInOut(duration: 0.12)) {
            prompts.move(fromOffsets: IndexSet(integer: currentIndex), toOffset: prompts.endIndex)
        }
        self.draggingItem = nil
        return true
    }
}
