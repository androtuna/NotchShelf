import AppKit
import CryptoKit
import Foundation
import Security

// Ters proxy / self-signed sertifika: yalnızca bilinmeyen kök (self-signed veya
// özel CA) durumunda kullanıcıya sorulur, onaylanırsa SPKI parmak izi
// Keychain'e pin'lenir. Süresi geçmiş/henüz geçerli değil/iptal edilmiş/hostname
// uyuşmayan sertifikalar kullanıcı onayıyla bile kabul edilmez (spec §5).
final class ServerTrustController: NSObject, URLSessionDelegate {
    static func certKey(_ host: String) -> String { "certpin:\(host)" }

    // Bu hata kodları TOFU'yu devre dışı bırakır.
    private static let deniedCodes: Set<OSStatus> = [
        errSecCertificateExpired,
        errSecCertificateNotValidYet,
        errSecCertificateRevoked,
        errSecHostNameMismatch,
    ]

    @MainActor private static var isPrompting = false

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host

        // Hostname doğrulamasını garantiye al.
        let policy = SecPolicyCreateSSL(true, host as CFString)
        SecTrustSetPolicies(trust, policy)

        // Geçerli sertifika: sistemin varsayılan doğrulamasına bırak.
        var evaluationError: CFError?
        if SecTrustEvaluateWithError(trust, &evaluationError) {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Tehlikeli hata (expired/revoked/hostname vb.): kullanıcı onayına izin yok.
        guard Self.isTOFUEligible(evaluationError: evaluationError) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let pin = Self.publicKeyPin(of: trust)

        // Daha önce onaylanmış parmak izi.
        if let pin, KeychainStore.get(Self.certKey(host)) == pin {
            completionHandler(.useCredential, URLCredential(trust: trust))
            return
        }

        Task { @MainActor in
            let approved = await Self.askUser(host: host, pin: pin)
            if approved {
                if let pin { KeychainStore.set(pin, for: Self.certKey(host)) }
                completionHandler(.useCredential, URLCredential(trust: trust))
            } else {
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
        }
    }

    // Yalnızca bilinmeyen kök kaynaklı hatalar (self-signed / özel CA) TOFU'ya uygundur.
    private static func isTOFUEligible(evaluationError: CFError?) -> Bool {
        guard let evaluationError else { return true }
        let code = OSStatus(CFErrorGetCode(evaluationError))
        return !deniedCodes.contains(code)
    }

    // SPKI (Subject Public Key Info) tabanlı pin; aynı anahtarla sertifika
    // yenilenince pin geçerli kalır.
    static func publicKeyPin(of trust: SecTrust) -> String? {
        let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate] ?? []
        guard let leaf = chain.first else { return nil }

        if let key = SecCertificateCopyKey(leaf),
           let representation = SecKeyCopyExternalRepresentation(key, nil) as Data? {
            return "sha256/" + sha256Hex(representation)
        }
        // Anahtar çıkarılamazsa yaprak sertifika parmak izine düş.
        return certificateFingerprint(leaf).map { "sha256/" + $0 }
    }

    static func certificateFingerprint(_ certificate: SecCertificate) -> String? {
        let data = SecCertificateCopyData(certificate) as Data
        guard !data.isEmpty else { return nil }
        return sha256Hex(data)
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    @MainActor
    private static func askUser(host: String, pin: String?) async -> Bool {
        // Aynı anda tek onay diyaloğu; üst üste binen istekleri reddet.
        guard !isPrompting else { return false }
        isPrompting = true
        defer { isPrompting = false }

        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = LF("Doğrulanamayan sertifika: %@", host)
        alert.informativeText = LF("""
        Sunucu sertifikası zinciri doğrulanamadı (self-signed veya özel CA).
        Parmak izi (SHA-256): %@…

        Güvenilsin mi? Onaylarsanız bu parmak izi Keychain'e kaydedilir.
        """, String((pin ?? "?").prefix(48)))
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("Güven"))
        alert.addButton(withTitle: L("Vazgeç"))

        return await withCheckedContinuation { continuation in
            if let window = NSApp.keyWindow ?? NSApp.mainWindow {
                alert.beginSheetModal(for: window) { response in
                    continuation.resume(returning: response == .alertFirstButtonReturn)
                }
            } else {
                continuation.resume(returning: alert.runModal() == .alertFirstButtonReturn)
            }
        }
    }
}
