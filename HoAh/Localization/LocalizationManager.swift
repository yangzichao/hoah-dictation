import Foundation
import SwiftUI
import ObjectiveC.runtime

enum AppLanguage: String {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    init(code: String) {
        self = AppLanguage(rawValue: code) ?? .system
    }

    var locale: Locale {
        switch self {
        case .system:
            return .autoupdatingCurrent
        case .english:
            return Locale(identifier: "en")
        case .simplifiedChinese:
            return Locale(identifier: "zh-Hans")
        }
    }

    var bundleCode: String? {
        switch self {
        case .system:
            return nil
        case .english:
            return "en"
        case .simplifiedChinese:
            return "zh-Hans"
        }
    }
}

final class LocalizationManager: ObservableObject {
    @Published private(set) var locale: Locale

    init(savedLanguageCode: String = UserDefaults.standard.string(forKey: "AppInterfaceLanguage") ?? "system") {
        let language = AppLanguage(code: savedLanguageCode)
        locale = language.locale
        Bundle.setLanguage(language.bundleCode)
    }

    func apply(languageCode: String) {
        let language = AppLanguage(code: languageCode)
        locale = language.locale
        Bundle.setLanguage(language.bundleCode)
    }
}

private var bundleKey: UInt8 = 0

private final class LanguageBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let bundle = objc_getAssociatedObject(self, &bundleKey) as? Bundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    static func setLanguage(_ code: String?) {
        let selectedBundle: Bundle?

        if let code,
           let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            selectedBundle = bundle
        } else {
            selectedBundle = nil
        }

        objc_setAssociatedObject(Bundle.main, &bundleKey, selectedBundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        object_setClass(Bundle.main, LanguageBundle.self)
    }
}
