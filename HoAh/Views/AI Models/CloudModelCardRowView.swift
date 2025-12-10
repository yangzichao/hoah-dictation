import SwiftUI
import AppKit

// MARK: - Cloud Model Card View
struct CloudModelCardView: View {
    let model: CloudModel
    let isCurrent: Bool
    var setDefaultAction: () -> Void
    
    @EnvironmentObject private var whisperState: WhisperState
    @State private var isExpanded = false
    @State private var apiKey = ""
    @State private var isVerifying = false
    @State private var verificationStatus: VerificationStatus = .none
    @State private var isConfiguredState: Bool = false
    @State private var verificationError: String? = nil
    @State private var apiKeyEntries: [CloudAPIKeyEntry] = []
    @State private var activeKeyId: UUID? = nil
    
    enum VerificationStatus {
        case none, verifying, success, failure
    }
    
    private var isConfigured: Bool {
        CloudAPIKeyManager.shared.hasKeys(for: providerKey)
    }
    
    private var providerKey: String {
        switch model.provider {
        case .groq:
            return "GROQ"
        case .elevenLabs:
            return "ElevenLabs"
        case .mistral:
            return "Mistral"
        case .gemini:
            return "Gemini"
        case .soniox:
            return "Soniox"
        default:
            return model.provider.rawValue
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main card content
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    headerSection
                    metadataSection
                    descriptionSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                actionSection
            }
            .padding(16)
            
            // Expandable configuration section
            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)
                
                configurationSection
                    .padding(16)
            }
        }
        .background(CardBackground(isSelected: isCurrent, useAccentGradientWhenSelected: isCurrent))
        .onAppear {
            loadKeys()
            isConfiguredState = isConfigured
        }
    }
    
    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(model.displayName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(.labelColor))
            
            statusBadge
            
            Spacer()
        }
    }
    
    private var statusBadge: some View {
        Group {
            if isCurrent {
                Text("Default")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor))
                    .foregroundColor(.white)
            } else if isConfiguredState {
                Text("Configured")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color(.systemGreen).opacity(0.2)))
                    .foregroundColor(Color(.systemGreen))
            } else {
                Text("Setup Required")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color(.systemOrange).opacity(0.2)))
                    .foregroundColor(Color(.systemOrange))
            }
        }
    }
    
    private var metadataSection: some View {
        HStack(spacing: 12) {
            // Provider
            Label(model.provider.rawValue, systemImage: "cloud")
                .font(.system(size: 11))
                .foregroundColor(Color(.secondaryLabelColor))
                .lineLimit(1)
            
            // Language
            Label(model.language, systemImage: "globe")
                .font(.system(size: 11))
                .foregroundColor(Color(.secondaryLabelColor))
                .lineLimit(1)
            
            Label("Cloud Model", systemImage: "icloud")
                .font(.system(size: 11))
                .foregroundColor(Color(.secondaryLabelColor))
                .lineLimit(1)
            
            // Accuracy
            HStack(spacing: 3) {
                Text("Accuracy")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(.secondaryLabelColor))
                progressDotsWithNumber(value: model.accuracy * 10)
            }
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
        }
        .lineLimit(1)
    }
    
    private var descriptionSection: some View {
        Text(model.description)
            .font(.system(size: 11))
            .foregroundColor(Color(.secondaryLabelColor))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }
    
    private var actionSection: some View {
        HStack(spacing: 8) {
            if isCurrent {
                Text("Default Model")
                    .font(.system(size: 12))
                    .foregroundColor(Color(.secondaryLabelColor))
            } else if isConfiguredState {
                Button(action: setDefaultAction) {
                    Text("Set as Default")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button(action: {
                    withAnimation(.interpolatingSpring(stiffness: 170, damping: 20)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("Configure")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "gear")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(.controlAccentColor))
                            .shadow(color: Color(.controlAccentColor).opacity(0.2), radius: 2, x: 0, y: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            
            if isConfiguredState {
                Menu {
                    Button {
                        withAnimation(.interpolatingSpring(stiffness: 170, damping: 20)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Label("Manage API Keys", systemImage: "key")
                    }
                    
                    Button {
                        clearAPIKey()
                    } label: {
                        Label("Remove API Key", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 20, height: 20)
            }
        }
    }
    
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("API Key Configuration")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(.labelColor))
            
            if apiKeyEntries.isEmpty {
                // Initial state: no keys yet, show simple input
                HStack(spacing: 8) {
                    SecureField("Enter your \(model.provider.rawValue) API key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isVerifying)
                    
                    Button(action: verifyAPIKey) {
                        HStack(spacing: 4) {
                            if isVerifying {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: verificationStatus == .success ? "checkmark" : "checkmark.shield")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            Text(isVerifying ? "Verifying..." : "Verify")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(verificationStatus == .success ? Color(.systemGreen) : Color(.controlAccentColor))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(apiKey.isEmpty || isVerifying)
                }
            } else {
                // Multiple keys management
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(apiKeyEntries) { entry in
                        HStack(spacing: 8) {
                            if activeKeyId == entry.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(maskedKey(entry.value))
                                .font(.system(.body, design: .monospaced))
                            
                            Spacer()
                            
                            Text(formatLastUsed(entry.lastUsedAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if activeKeyId != entry.id {
                                Button("Use") {
                                    selectKey(entry)
                                }
                                .buttonStyle(.borderless)
                            }
                            
                            Button {
                                removeKey(entry)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.red)
                        }
                    }
                }
                .padding(8)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
                
                HStack {
                    Button {
                        rotateToNextKey()
                    } label: {
                        Label("Next Key", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Spacer()
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add Another API Key")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        SecureField("Enter your \(model.provider.rawValue) API key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .disabled(isVerifying)
                        
                        Button(action: verifyAPIKey) {
                            HStack(spacing: 4) {
                                if isVerifying {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 12, height: 12)
                                } else {
                                    Image(systemName: "checkmark.shield")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                Text(isVerifying ? "Verifying..." : "Verify")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(.controlAccentColor))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(apiKey.isEmpty || isVerifying)
                    }
                }
            }
            
            if verificationStatus == .failure {
                if let error = verificationError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Color(.systemRed))
                } else {
                    Text("Verification failed")
                        .font(.caption)
                        .foregroundColor(Color(.systemRed))
                }
            } else if verificationStatus == .success && apiKeyEntries.count == 1 {
                // Only show initial success message in the first-time flow
                Text("API key verified successfully!")
                    .font(.caption)
                    .foregroundColor(Color(.systemGreen))
            }
        }
    }
    
    private func loadKeys() {
        let manager = CloudAPIKeyManager.shared
        apiKeyEntries = manager.keys(for: providerKey)
        activeKeyId = manager.activeKeyId(for: providerKey)
        verificationStatus = .none
        verificationError = nil
        apiKey = ""
    }
    
    private func verifyAPIKey() {
        guard !apiKey.isEmpty else { return }
        
        isVerifying = true
        verificationStatus = .verifying
        
        // Verify the API key based on the provider type
        switch model.provider {
        case .groq, .mistral, .gemini:
            // For transcription providers, save key directly (no AIProvider mapping needed)
            handleVerificationResult(isValid: true, errorMessage: nil)
        case .elevenLabs:
            // ElevenLabs is a transcription-only provider, verify directly
            verifyElevenLabsAPIKey(apiKey) { isValid, errorMessage in
                self.handleVerificationResult(isValid: isValid, errorMessage: errorMessage)
            }
        case .soniox:
            // Soniox is a transcription-only provider, verify directly
            verifySonioxAPIKey(apiKey) { isValid, errorMessage in
                self.handleVerificationResult(isValid: isValid, errorMessage: errorMessage)
            }
        default:
            // For other providers, just save the key without verification
            print("Warning: verifyAPIKey called for unsupported provider \(model.provider.rawValue)")
            self.handleVerificationResult(isValid: true, errorMessage: nil)
        }
    }
    
    private func handleVerificationResult(isValid: Bool, errorMessage: String?) {
        DispatchQueue.main.async {
            self.isVerifying = false
            if isValid {
                self.verificationStatus = .success
                self.verificationError = nil
                
                let manager = CloudAPIKeyManager.shared
                manager.addKey(self.apiKey, for: self.providerKey)
                self.loadKeys()
                self.isConfiguredState = true
                
                // Collapse the configuration section after successful verification
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.isExpanded = false
                }
            } else {
                self.verificationStatus = .failure
                self.verificationError = errorMessage
            }
        }
    }
    
    private func verifyElevenLabsAPIKey(_ key: String, completion: @escaping (Bool, String?) -> Void) {
        let url = URL(string: "https://api.elevenlabs.io/v1/user")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(key, forHTTPHeaderField: "xi-api-key")
        
        URLSession.shared.dataTask(with: request) { data, response, _ in
            let isValid = (response as? HTTPURLResponse)?.statusCode == 200
            
            if let data = data, let body = String(data: data, encoding: .utf8) {
                if !isValid {
                    completion(false, body)
                    return
                }
            }
            
            completion(isValid, nil)
        }.resume()
    }
    
    private func verifySonioxAPIKey(_ key: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "https://api.soniox.com/v1/files") else {
            completion(false, nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    completion(true, nil)
                } else {
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        completion(false, responseString)
                    } else {
                        completion(false, nil)
                    }
                }
            } else {
                completion(false, nil)
            }
        }.resume()
    }
    
    private func clearAPIKey() {
        let manager = CloudAPIKeyManager.shared
        manager.removeAllKeys(for: providerKey)
        apiKey = ""
        verificationStatus = .none
        verificationError = nil
        isConfiguredState = false
        apiKeyEntries = []
        activeKeyId = nil
        
        // If this model is currently the default, clear it
        if isCurrent {
            Task {
                await MainActor.run {
                    whisperState.currentTranscriptionModel = nil
                    UserDefaults.standard.removeObject(forKey: "CurrentTranscriptionModel")
                }
            }
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            isExpanded = false
        }
    }
    
    private func selectKey(_ entry: CloudAPIKeyEntry) {
        let manager = CloudAPIKeyManager.shared
        manager.selectKey(id: entry.id, for: providerKey)
        loadKeys()
    }
    
    private func removeKey(_ entry: CloudAPIKeyEntry) {
        let manager = CloudAPIKeyManager.shared
        manager.removeKey(id: entry.id, for: providerKey)
        loadKeys()
        isConfiguredState = !apiKeyEntries.isEmpty
    }
    
    private func rotateToNextKey() {
        let manager = CloudAPIKeyManager.shared
        if manager.rotateKey(for: providerKey) {
            loadKeys()
        }
    }
    
    private func maskedKey(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return String(repeating: "•", count: 8) }
        let suffix = trimmed.suffix(4)
        return "••••\(suffix)"
    }
    
    private func formatLastUsed(_ date: Date?) -> String {
        guard let date = date else { return "Never used" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
