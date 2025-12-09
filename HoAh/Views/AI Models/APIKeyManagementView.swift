import SwiftUI

struct APIKeyManagementView: View {
    @EnvironmentObject private var aiService: AIService
    @State private var apiKey: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isVerifying = false
    @State private var keyEntries: [CloudAPIKeyEntry] = []
    @State private var activeKeyId: UUID?
    @State private var bedrockRegionSelection: String = "us-east-1"
    @State private var bedrockModelSelection: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Provider Selection
            HStack {
                Picker("AI Provider", selection: $aiService.selectedProvider) {
                    ForEach(AIProvider.allCases.filter { $0 != .elevenLabs && $0 != .soniox }, id: \.self) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                
                Spacer()
                
                if aiService.isAPIKeyValid {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Connected to")
                            .font(.caption)
                        Text(aiService.selectedProvider.rawValue)
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .foregroundColor(.secondary)
                    .cornerRadius(6)
                }
            }
            
            .onChange(of: aiService.selectedProvider) { oldValue, newValue in
                reloadKeys()
                syncBedrockRegionSelection()
            }
            
            // Model Selection
            if aiService.selectedProvider == .openRouter {
                HStack {
                    if aiService.availableModels.isEmpty {
                        Text("No models loaded")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Model", selection: Binding(
                            get: { aiService.currentModel },
                            set: { aiService.selectModel($0) }
                        )) {
                            ForEach(aiService.availableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                    }
                    
                    
                    
                    Button(action: {
                        Task {
                            await aiService.fetchOpenRouterModels()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh models")
                }
            } else if !aiService.availableModels.isEmpty &&
                        aiService.selectedProvider != .custom {
                HStack {
                    Picker("Model", selection: Binding(
                        get: { aiService.currentModel },
                        set: { aiService.selectModel($0) }
                    )) {
                        ForEach(aiService.availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                }
            }
            
            if aiService.selectedProvider == .custom {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Custom Provider Configuration")
                            .font(.headline)
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("Requires OpenAI-compatible API endpoint")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Configuration Fields
                    VStack(alignment: .leading, spacing: 8) {
                        if !aiService.isAPIKeyValid {
                            TextField("API Endpoint URL (e.g., https://api.example.com/v1/chat/completions)", text: $aiService.customBaseURL)
                                .textFieldStyle(.roundedBorder)
                            
                            TextField("Model Name (e.g., gpt-4o-mini, claude-3-5-sonnet-20240620)", text: $aiService.customModel)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("API Endpoint URL")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(aiService.customBaseURL)
                                    .font(.system(.body, design: .monospaced))
                                
                                Text("Model")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(aiService.customModel)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                        
                        if aiService.isAPIKeyValid {
                            Text("API Key")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text(String(repeating: "•", count: 40))
                                    .font(.system(.body, design: .monospaced))
                                
                                Spacer()
                                
                                Button(action: {
                                    aiService.clearAPIKey()
                                }) {
                                    Label("Remove Key", systemImage: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.borderless)
                            }
                        } else {
                            Text("Enter your API Key")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            SecureField("API Key", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                            
                            HStack {
                            Button(action: {
                                isVerifying = true
                                aiService.saveAPIKey(apiKey) { success, errorMessage in
                                    isVerifying = false
                                    if !success {
                                        alertMessage = errorMessage ?? "Verification failed"
                                        showAlert = true
                                    }
                                    apiKey = ""
                                }
                            }) {
                                HStack {
                                    if isVerifying {
                                        ProgressView()
                                            .scaleEffect(0.5)
                                            .frame(width: 16, height: 16)
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                    }
                                    Text("Verify and Save")
                                }
                            }
                                .disabled(aiService.customBaseURL.isEmpty || aiService.customModel.isEmpty || apiKey.isEmpty)
                                
                                Spacer()
                            }
                        }
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.03))
                .cornerRadius(12)
            } else if aiService.selectedProvider == .awsBedrock {
                let presetRegions = [
                    "us-east-1",
                    "us-east-2",
                    "us-west-1",
                    "us-west-2",
                    "eu-west-1",
                    "eu-central-1",
                    "ap-southeast-1",
                    "ap-northeast-1",
                    "ap-south-1",
                    "custom"
                ]

                let presetModels = [
                    "us.anthropic.claude-sonnet-4-5-20250929-v1:0",
                    "us.anthropic.claude-opus-4-20250514-v1:0",
                    "openai.gpt-oss-safeguard-120b",
                    "us.amazon.nova-pro-v1:0"
                ]

                VStack(alignment: .leading, spacing: 16) {
                    Text("AWS Bedrock Configuration")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        SecureField("API Key (ABSKQmVkcm9ja0FQSUtleS1...)", text: $aiService.bedrockApiKey)
                            .textFieldStyle(.roundedBorder)
                        
                        HStack {
                            Picker("Region", selection: $bedrockRegionSelection) {
                                ForEach(presetRegions, id: \.self) { region in
                                    Text(region == "custom" ? "Custom…" : region).tag(region)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: bedrockRegionSelection) { _, newValue in
                                if newValue != "custom" {
                                    aiService.bedrockRegion = newValue
                                }
                            }
                            
                            if bedrockRegionSelection == "custom" {
                                TextField("Enter region (e.g., us-west-2)", text: $aiService.bedrockRegion)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 220)
                            }
                        }
                        
                        Picker("Model", selection: $bedrockModelSelection) {
                            ForEach(presetModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: bedrockModelSelection) { _, newValue in
                            aiService.bedrockModelId = newValue
                        }
                    }
                    
                    HStack {
                        Button(action: {
                            isVerifying = true
                            aiService.verifyBedrockConnection(
                                apiKey: aiService.bedrockApiKey,
                                region: aiService.bedrockRegion,
                                modelId: aiService.bedrockModelId
                            ) { success, message in
                                isVerifying = false
                                if success {
                                    // Save configuration after successful test
                                    aiService.saveBedrockConfig(
                                        apiKey: aiService.bedrockApiKey,
                                        region: aiService.bedrockRegion,
                                        modelId: aiService.bedrockModelId
                                    )
                                    aiService.bedrockApiKey = ""
                                    alertMessage = "✅ Connection successful! Configuration saved."
                                } else {
                                    alertMessage = "❌ " + (message ?? "Connection failed.")
                                }
                                showAlert = true
                            }
                        }) {
                            HStack {
                                if isVerifying {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "bolt.horizontal.circle.fill")
                                }
                                Text(isVerifying ? "Testing..." : "Test & Save")
                            }
                        }
                        .disabled(aiService.bedrockApiKey.isEmpty || aiService.bedrockRegion.isEmpty || aiService.bedrockModelId.isEmpty || isVerifying)
                        .buttonStyle(.borderedProminent)
                        
                        Spacer()
                        
                        if aiService.isAPIKeyValid && aiService.selectedProvider == .awsBedrock {
                            Button(role: .destructive) {
                                aiService.clearAPIKey()
                            } label: {
                                Label("Clear", systemImage: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.03))
                .cornerRadius(12)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("API Keys")
                            .font(.headline)
                        Spacer()
                        Button {
                            aiService.rotateAPIKey()
                            reloadKeys()
                        } label: {
                            Label("Next Key", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .disabled(keyEntries.count <= 1)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    if keyEntries.isEmpty {
                        Text("No keys added yet for \(aiService.selectedProvider.rawValue). Add one below.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(keyEntries) { entry in
                                let isActive = entry.id == activeKeyId
                                HStack {
                                    Text(maskKey(entry.value))
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(isActive ? .primary : .secondary)
                                    
                                    if let lastUsed = entry.lastUsedAt {
                                        Text("Last used \(relativeDate(lastUsed))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if isActive {
                                        Label("Active", systemImage: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    } else {
                                        Button("Use") {
                                            aiService.selectAPIKey(id: entry.id)
                                            reloadKeys()
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                    
                                    Button(role: .destructive) {
                                        CloudAPIKeyManager.shared.removeKey(id: entry.id, for: aiService.selectedProvider.rawValue)
                                        reloadKeys()
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundColor(.red)
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isActive ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.05))
                                )
                            }
                        }
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add New API Key")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        SecureField("API Key", text: $apiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(.body, design: .monospaced))
                        
                        HStack {
                            Button(action: {
                                isVerifying = true
                                aiService.saveAPIKey(apiKey) { success, errorMessage in
                                    isVerifying = false
                                    if !success {
                                        alertMessage = errorMessage ?? "Verification failed"
                                        showAlert = true
                                    }
                                    apiKey = ""
                                    reloadKeys()
                                }
                            }) {
                                HStack {
                                    if isVerifying {
                                        ProgressView()
                                            .scaleEffect(0.5)
                                            .frame(width: 16, height: 16)
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                    }
                                    Text("Verify and Save")
                                }
                            }
                            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            
                            Spacer()
                            
                            Button(role: .destructive) {
                                aiService.clearAPIKey()
                                reloadKeys()
                            } label: {
                                Label("Remove All", systemImage: "trash")
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.red)
                            .disabled(keyEntries.isEmpty)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Text((aiService.selectedProvider == .groq || aiService.selectedProvider == .gemini || aiService.selectedProvider == .cerebras) ? "Free" : "Paid")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                        
                        if aiService.selectedProvider != .custom {
                            Button {
                                let url = switch aiService.selectedProvider {
                                case .groq:
                                    URL(string: "https://console.groq.com/keys")!
                                case .openAI:
                                    URL(string: "https://platform.openai.com/api-keys")!
                                case .gemini:
                                    URL(string: "https://makersuite.google.com/app/apikey")!
                                case .anthropic:
                                    URL(string: "https://console.anthropic.com/settings/keys")!
                                case .mistral:
                                    URL(string: "https://console.mistral.ai/api-keys")!
                                case .elevenLabs:
                                    URL(string: "https://elevenlabs.io/speech-synthesis")!
                                case .soniox:
                                    URL(string: "https://console.soniox.com/")!
                                case .custom:
                                    URL(string: "")! // not used
                                case .openRouter:
                                    URL(string: "https://openrouter.ai/keys")!
                                case .cerebras:
                                    URL(string: "https://cloud.cerebras.ai/")!
                                case .awsBedrock:
                                    URL(string: "https://console.aws.amazon.com/iam/home#/security_credentials")!
                                }
                                NSWorkspace.shared.open(url)
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Get API Key")
                                        .foregroundColor(.accentColor)
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            reloadKeys()
            syncBedrockRegionSelection()
            syncBedrockModelSelection()
        }
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        let gigabytes = Double(bytes) / 1_000_000_000
        return String(format: "%.1f GB", gigabytes)
    }
    
    private func reloadKeys() {
        keyEntries = aiService.currentKeyEntries()
        activeKeyId = CloudAPIKeyManager.shared.activeKey(for: aiService.selectedProvider.rawValue)?.id
    }

    private func syncBedrockRegionSelection() {
        let presets = [
            "us-east-1",
            "us-east-2",
            "us-west-1",
            "us-west-2",
            "eu-west-1",
            "eu-central-1",
            "ap-southeast-1",
            "ap-northeast-1",
            "ap-south-1"
        ]
        if presets.contains(aiService.bedrockRegion) {
            bedrockRegionSelection = aiService.bedrockRegion
        } else {
            bedrockRegionSelection = "custom"
        }
    }

    private func syncBedrockModelSelection() {
        let presets = [
            "us.anthropic.claude-sonnet-4-5-20250929-v1:0",
            "us.anthropic.claude-opus-4-20250514-v1:0",
            "openai.gpt-oss-safeguard-120b",
            "us.amazon.nova-pro-v1:0"
        ]
        if presets.contains(aiService.bedrockModelId) {
            bedrockModelSelection = aiService.bedrockModelId
        } else {
            // Default to first preset if current model is not in the list
            bedrockModelSelection = presets.first ?? "us.anthropic.claude-sonnet-4-5-20250929-v1:0"
            aiService.bedrockModelId = bedrockModelSelection
        }
    }
    
    private func maskKey(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 8 { return String(repeating: "•", count: trimmed.count) }
        let start = trimmed.prefix(4)
        let end = trimmed.suffix(4)
        return "\(start)\(String(repeating: "•", count: max(0, trimmed.count - 8)))\(end)"
    }
    
    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
