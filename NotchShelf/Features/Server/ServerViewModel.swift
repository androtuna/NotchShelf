import Foundation
import Combine

// Sunucu bağlantısı + oturum durumu. Tüm uygulama boyunca tek örnek;
// RootView'a environmentObject olarak enjekte edilir.
@MainActor
final class ServerViewModel: ObservableObject {
    static let shared = ServerViewModel()

    enum Status: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    enum AuthMode: String, CaseIterable, Identifiable {
        case credentials = "Kullanıcı adı / şifre"
        case token = "API token"
        var id: String { rawValue }
    }

    @Published var serverURLString: String
    @Published var status: Status = .disconnected
    @Published var username: String = ""

    private(set) var client: AudiobookshelfClient?
    private(set) var baseURL: URL?

    private init() {
        serverURLString = Preferences.serverURL
        username = Preferences.serverUsername
        if let url = Self.makeURL(serverURLString),
           let token = SecretStore.getToken(), !token.isEmpty {
            let client = AudiobookshelfClient(baseURL: url, token: token)
            self.client = client
            self.baseURL = url
            // Kayıtlı token'ı doğrula; başarılıysa bağlı say.
            Task { await self.validateStoredSession(client: client) }
        }
    }

    var isConnected: Bool { status == .connected }

    // MARK: - Bağlanma

    func connect(mode: AuthMode, username: String, password: String, token: String) async {
        guard let url = Self.makeURL(serverURLString) else {
            status = .error(L("Geçersiz sunucu URL'si"))
            return
        }
        status = .connecting
        let client = AudiobookshelfClient(baseURL: url)
        do {
            let resolvedToken: String
            switch mode {
            case .credentials:
                let response = try await client.login(username: username, password: password)
                guard let t = response.user.token, !t.isEmpty else {
                    throw AudiobookshelfError.missingToken
                }
                resolvedToken = t
            case .token:
                guard !token.isEmpty else { throw AudiobookshelfError.missingToken }
                resolvedToken = token
            }
            await client.configure(baseURL: url, token: resolvedToken)
            // Token'ı doğrula.
            let me = try await client.me()
            self.client = client
            self.baseURL = url
            self.username = me.username
            self.status = .connected
            persist(url: serverURLString, token: resolvedToken, username: me.username)
        } catch {
            self.client = nil
            self.baseURL = nil
            self.status = .error(Self.describe(error))
        }
    }

    func testConnection() async -> String? {
        guard let client, status == .connected else { return L("Önce bağlanın") }
        do {
            _ = try await client.me()
            return nil
        } catch {
            return Self.describe(error)
        }
    }

    func disconnect() {
        client = nil
        baseURL = nil
        status = .disconnected
        username = ""
        SecretStore.removeToken()
        Preferences.serverUsername = ""
    }

    // MARK: - Yardımcılar

    private func validateStoredSession(client: AudiobookshelfClient) async {
        do {
            let me = try await client.me()
            self.username = me.username
            self.status = .connected
            Preferences.serverUsername = me.username
        } catch {
            self.client = nil
            self.baseURL = nil
            self.status = .disconnected
            SecretStore.removeToken()
        }
    }

    private func persist(url: String, token: String, username: String) {
        Preferences.serverURL = url
        Preferences.serverUsername = username
        SecretStore.setToken(token)
    }

    nonisolated static func makeURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: withScheme), url.host != nil else { return nil }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        return url
    }

    nonisolated static func describe(_ error: Error) -> String {
        if let abs = error as? AudiobookshelfError {
            switch abs {
            case .invalidURL: return L("Geçersiz URL")
            case .missingToken: return L("Token eksik")
            case .unauthorized: return L("Kimlik doğrulama reddedildi (401/403)")
            case .notFound: return L("Bulunamadı (404)")
            case .serverError(let s): return LF("Sunucu hatası (%d)", s)
            case .decoding(let m): return LF("Yanıt çözümlenemedi: %@", m)
            case .transport(let m): return LF("Bağlantı hatası: %@", m)
            }
        }
        return error.localizedDescription
    }
}
