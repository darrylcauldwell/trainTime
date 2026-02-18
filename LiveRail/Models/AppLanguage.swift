import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Hashable {
    case system = "system"
    case english = "en-GB"
    case welsh = "cy"
    case french = "fr"
    case german = "de"
    case spanish = "es"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return String(localized: "System Default")
        case .english: return "English (UK)"
        case .welsh: return "Cymraeg"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .spanish: return "Español"
        }
    }

    var flag: String {
        switch self {
        case .system: return "🌐"
        case .english: return "🇬🇧"
        case .welsh: return "🏴󠁧󠁢󠁷󠁬󠁳󠁿"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .spanish: return "🇪🇸"
        }
    }

    var locale: Locale? {
        self == .system ? nil : Locale(identifier: rawValue)
    }
}

@Observable
class LanguageManager {
    static let shared = LanguageManager()

    var selectedLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: "AppLanguage")
        }
    }

    var currentLocale: Locale {
        selectedLanguage.locale ?? Locale.current
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "AppLanguage"),
           let language = AppLanguage(rawValue: saved) {
            selectedLanguage = language
        } else {
            selectedLanguage = .system
        }
    }
}
