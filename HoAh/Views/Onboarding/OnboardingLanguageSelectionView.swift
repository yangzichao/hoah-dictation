import SwiftUI

struct OnboardingLanguageSelectionView: View {
    @EnvironmentObject private var appSettings: AppSettingsStore
    @EnvironmentObject private var localizationManager: LocalizationManager
    // DEPRECATED: Use AppSettingsStore instead of @AppStorage
    @AppStorage("SelectedLanguage") private var selectedLanguage: String = "auto"
    
    let onContinue: () -> Void
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: CGFloat = 0
    @State private var selectedOption: LanguageOption = .system
    
    enum LanguageOption {
        case system
        case simplifiedChinese
        case english
    }
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                OnboardingBackgroundView()
                
                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        Text(LocalizedStringKey("onboarding_language_title"))
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        Text(LocalizedStringKey("onboarding_language_subtitle"))
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .scaleEffect(scale)
                    .opacity(opacity)
                    
                    HStack(spacing: 20) {
                        languageButton(
                            titleKey: "onboarding_language_follow_system_title",
                            subtitleKey: "onboarding_language_follow_system_subtitle",
                            option: .system
                        )
                        languageButton(
                            titleKey: "onboarding_language_zh_title",
                            subtitleKey: "onboarding_language_zh_subtitle",
                            option: .simplifiedChinese
                        )
                        languageButton(
                            titleKey: "onboarding_language_en_title",
                            subtitleKey: "onboarding_language_en_subtitle",
                            option: .english
                        )
                    }
                    .frame(maxWidth: min(geometry.size.width * 0.9, 900))
                    .scaleEffect(scale)
                    .opacity(opacity)
                    
                    Button(action: applySelectionAndContinue) {
                        Text(LocalizedStringKey("onboarding_continue"))
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(width: 200, height: 50)
                            .background(Color.white)
                            .cornerRadius(25)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .scaleEffect(scale)
                    .opacity(opacity)
                    
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            animateIn()
        }
    }
    
    private func languageButton(titleKey: String, subtitleKey: String, option: LanguageOption) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                selectedOption = option
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey(titleKey))
                    .font(.headline)
                    .foregroundColor(.white)
                Text(LocalizedStringKey(subtitleKey))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(selectedOption == option ? 0.15 : 0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                selectedOption == option ? Color.accentColor : Color.white.opacity(0.2),
                                lineWidth: selectedOption == option ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func applySelectionAndContinue() {
        switch selectedOption {
        case .system:
            appSettings.appInterfaceLanguage = "system"
            selectedLanguage = "auto"
        case .simplifiedChinese:
            appSettings.appInterfaceLanguage = "zh-Hans"
            selectedLanguage = "zh"
        case .english:
            appSettings.appInterfaceLanguage = "en"
            selectedLanguage = "en"
        }
        
        // Apply language immediately so subsequent onboarding steps update
        localizationManager.apply(languageCode: appSettings.appInterfaceLanguage)
        onContinue()
    }
    
    private func animateIn() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            scale = 1
            opacity = 1
        }
    }
}
