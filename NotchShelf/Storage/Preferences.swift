import Foundation

// UserDefaults sarmalayıcı. View'larda @AppStorage ile, view-dışı kodda
// (MenuBarIcon, NotchHUDController) buradan okunur.
enum Preferences {
    enum Key {
        static let syncInterval = "syncInterval"    // saniye: 5 / 15 / 30
        static let notchEnabled = "notchEnabled"
        static let menuIcon = "menuIcon"            // MenuBarIcon.rawValue
        static let serverURL = "serverURL"          // hassas değil → Keychain yerine UD
        static let serverUsername = "serverUsername"
        static let notifyOnFinish = "notifyOnFinish"
        static let hasOnboarded = "hasOnboarded"
        static let appLanguage = "appLanguage"      // AppLanguage.rawValue: system/tr/en
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Key.syncInterval: 15.0,
            Key.notchEnabled: true,
            Key.menuIcon: MenuBarIcon.headphones.rawValue,
            Key.notifyOnFinish: true,
        ])
    }

    static func boolDefaultTrue(_ key: String) -> Bool {
        let d = UserDefaults.standard
        return d.object(forKey: key) == nil ? true : d.bool(forKey: key)
    }

    static var notifyOnFinish: Bool {
        get { boolDefaultTrue(Key.notifyOnFinish) }
        set { UserDefaults.standard.set(newValue, forKey: Key.notifyOnFinish) }
    }

    static var serverURL: String {
        get { UserDefaults.standard.string(forKey: Key.serverURL) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Key.serverURL) }
    }

    static var serverUsername: String {
        get { UserDefaults.standard.string(forKey: Key.serverUsername) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Key.serverUsername) }
    }

    static var syncInterval: Double {
        get { UserDefaults.standard.double(forKey: Key.syncInterval).nonZero ?? 15 }
        set { UserDefaults.standard.set(newValue, forKey: Key.syncInterval) }
    }

    static var notchEnabled: Bool {
        get { boolDefaultTrue(Key.notchEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: Key.notchEnabled) }
    }

    static var appLanguage: String {
        get { UserDefaults.standard.string(forKey: Key.appLanguage) ?? AppLanguage.system.rawValue }
        set { UserDefaults.standard.set(newValue, forKey: Key.appLanguage) }
    }

    static var menuIcon: MenuBarIcon {
        get {
            let raw = UserDefaults.standard.string(forKey: Key.menuIcon) ?? ""
            return MenuBarIcon(rawValue: raw) ?? .headphones
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Key.menuIcon) }
    }
}

private extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}
