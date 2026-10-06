import SwiftUI

struct ServerSetupView: View {
    @EnvironmentObject var server: ServerViewModel

    @State private var authMode: ServerViewModel.AuthMode = .credentials
    @State private var username = ""
    @State private var password = ""
    @State private var token = ""
    @State private var isBusy = false
    @State private var testResult: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if case .connected = server.status {
                    connectedCard
                } else {
                    formCard
                }
            }
            .padding(20)
        }
        .onAppear {
            if username.isEmpty { username = server.username }
        }
    }

    private var connectedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.gradient)
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bağlı").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
                    Text(server.username).font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
                Spacer()
            }
            Text(server.serverURLString)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 8) {
                secondaryButton("Bağlantıyı test et") {
                    Task {
                        isBusy = true
                        testResult = await server.testConnection()
                        isBusy = false
                    }
                }
                secondaryButton("Düzenle") { server.disconnect() }
            }
            if let testResult {
                Text(testResult.isEmpty ? L("Bağlantı başarılı ✓") : testResult)
                    .font(.system(size: 11))
                    .foregroundStyle(testResult.isEmpty ? Theme.muted : Theme.pink)
            }
        }
        .cardStyle()
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sunucuna bağlan")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Kendi Audiobookshelf sunucunun adresini gir.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)

            field("Sunucu URL", text: $server.serverURLString, placeholder: "https://abs.example.com", secure: false)

            Picker("", selection: $authMode) {
                ForEach(ServerViewModel.AuthMode.allCases) { mode in
                    Text(L(mode.rawValue)).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch authMode {
            case .credentials:
                field("Kullanıcı adı", text: $username, placeholder: "kullanici", secure: false)
                field("Şifre", text: $password, placeholder: "••••••••", secure: true)
            case .token:
                field("API token", text: $token, placeholder: "token", secure: true)
            }

            if case .error(let message) = server.status {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.pink)
            }

            primaryButton(isBusy ? L("Bağlanıyor…") : L("Bağlan")) {
                guard !isBusy else { return }
                isBusy = true
                Task {
                    await server.connect(mode: authMode, username: username, password: password, token: token)
                    isBusy = false
                }
            }
            .disabled(isBusy)

            Text("Şifre/token yalnızca yerel Keychain'de saklanır, hiçbir yere gönderilmez.")
                .font(.system(size: 10))
                .foregroundStyle(Theme.muted.opacity(0.7))
        }
        .cardStyle()
    }

    // MARK: - Bileşenler

    private func field(_ label: LocalizedStringKey, text: Binding<String>, placeholder: LocalizedStringKey, secure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.muted)
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.cardFill))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.cardBorder))
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Theme.gradient))
                .shadow(color: Theme.magenta.opacity(0.4), radius: 20, y: 12)
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.ink.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.cardFill))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.cardBorder))
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).fill(Theme.cardFill))
            .overlay(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).stroke(Theme.cardBorder))
    }
}
