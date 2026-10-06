import AppKit
import SwiftUI

// Kaynak dili Türkçe. SwiftUI Text literalleri otomatik çevrilir; hesaplanan
// (ternary/return) metinler bu yardımcılardan geçer.
func L(_ key: String) -> String {
    NSLocalizedString(key, bundle: .main, comment: "")
}

func LF(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, bundle: .main, comment: ""), arguments: args)
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case tr
    case en

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return L("Sistem dili")
        case .tr: return "Türkçe"
        case .en: return "English"
        }
    }
}

// AppleLanguages üzerine yazıp yeniden başlatarak uygulanır (standart yol).
@MainActor
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published private(set) var selection: AppLanguage

    private init() {
        selection = AppLanguage(rawValue: Preferences.appLanguage) ?? .system
    }

    // Uygulama dilini açılışta okur; seçim değişip yeniden başlatılana kadar true kalır.
    var restartNeeded: Bool {
        let running = Bundle.main.preferredLocalizations.first ?? "tr"
        let target: String
        switch selection {
        case .system: target = Locale.preferredLanguages.first ?? "tr"
        case .tr, .en: target = selection.rawValue
        }
        return !running.hasPrefix(String(target.prefix(2)))
    }

    func select(_ lang: AppLanguage) {
        guard lang != selection else { return }
        selection = lang
        Preferences.appLanguage = lang.rawValue
        if lang == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([lang.rawValue], forKey: "AppleLanguages")
        }
    }

    // Yeni bir örnek başlatıp (open -n) ancak o zaman kapanırız; başarısız olursa
    // mevcut oturum açık kalır.
    func relaunch() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", Bundle.main.bundleURL.path]
        task.terminationHandler = { process in
            guard process.terminationStatus == 0 else { return }
            Task { @MainActor in NSApp.terminate(nil) }
        }
        do {
            try task.run()
        } catch {
            NSLog("NotchShelf: yeniden başlatılamadı: %@", error.localizedDescription)
        }
    }
}
