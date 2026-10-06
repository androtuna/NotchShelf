import Foundation
import Security

// Token gibi hassas değerlerin tek giriş/çıkış noktası.
//
// Birincil ve tek kalıcı depo Keychain'dir; token hiçbir Release derlemesinde
// diske düz metin yazılmaz. Geliştirme derlemeleri ad-hoc imzalı olduğu için
// her yeniden derlemede cdhash değişir ve macOS Keychain'i "farklı uygulama"
// sayar: ya izin diyaloğu çıkar ya da okuma errSecInteractionNotAllowed/
// errSecDecode döner. Bu duruma yalnızca DEBUG derlemesinde, Keychain yazımı
// başarısız olduğunda dosya fallback'i devreye girer. Eski sürümlerin bıraktığı
// düz metin dosyası ise Keychain okuması başarılı olduğunda silinir.
enum SecretStore {
    private static let keychainKey = "authToken"

    // Yalnızca DEBUG fallback'i ve eski sürümlerin temizliği için.
    private static let legacyFileURL: URL = {
        FileManager.default.temporaryDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("State", isDirectory: true)
            .appendingPathComponent("session")
    }()

    static func getToken() -> String? {
        if let token = KeychainStore.get(keychainKey), !token.isEmpty {
            removeLegacyFile()
            return token
        }
        #if DEBUG
        return readLegacyFile()
        #else
        return nil
        #endif
    }

    static func setToken(_ token: String) {
        let status = KeychainStore.set(token, for: keychainKey)
        #if DEBUG
        if status == errSecSuccess {
            removeLegacyFile()
        } else {
            writeLegacyFile(token)
        }
        #else
        _ = status
        removeLegacyFile()
        #endif
    }

    static func removeToken() {
        KeychainStore.remove(keychainKey)
        removeLegacyFile()
    }

    private static func readLegacyFile() -> String? {
        guard let data = try? Data(contentsOf: legacyFileURL) else { return nil }
        let token = String(data: data, encoding: .utf8)
        return (token?.isEmpty == false) ? token : nil
    }

    private static func writeLegacyFile(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }
        try? FileManager.default.createDirectory(
            at: legacyFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: legacyFileURL, options: [.atomic, .completeFileProtection])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: legacyFileURL.path)
    }

    private static func removeLegacyFile() {
        try? FileManager.default.removeItem(at: legacyFileURL)
    }
}
