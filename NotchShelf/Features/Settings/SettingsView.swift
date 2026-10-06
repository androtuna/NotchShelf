import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var server: ServerViewModel
    @EnvironmentObject var rootState: RootView.State

    @AppStorage(Preferences.Key.notchEnabled) private var notchEnabled = true
    @AppStorage(Preferences.Key.syncInterval) private var syncInterval: Double = 15
    @AppStorage(Preferences.Key.menuIcon) private var menuIconRaw = MenuBarIcon.headphones.rawValue
    @AppStorage(Preferences.Key.notifyOnFinish) private var notifyOnFinish = true

    @ObservedObject private var launch = LaunchAtLogin.shared
    @ObservedObject private var language = LanguageManager.shared
    @ObservedObject private var notifications = NotificationService.shared

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(get: { launch.isEnabled }, set: { launch.setEnabled($0) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                serverRow
                section("Oynatma") {
                    row("İlerleme senkron aralığı", "Sunucuya ne sıklıkta ilerleme gönderilsin") {
                        Picker("", selection: $syncInterval) {
                            Text("5 sn").tag(5.0)
                            Text("15 sn").tag(15.0)
                            Text("30 sn").tag(30.0)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 170)
                    }
                }
                section("Görünüm") {
                    row("Notch HUD", "Notch çevresinde canlı oynatıcı") {
                        Toggle("", isOn: $notchEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(Theme.violet)
                            .onChange(of: notchEnabled) { _, on in
                                NotchHUDController.shared.setEnabled(on)
                            }
                    }
                    row("Menü çubuğu ikonu", nil) {
                        Picker("", selection: $menuIconRaw) {
                            ForEach(MenuBarIcon.allCases, id: \.self) { icon in
                                Image(systemName: icon.symbolName).tag(icon.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 130)
                        .onChange(of: menuIconRaw) { _, _ in
                            StatusItemController.shared.refreshIcon()
                        }
                    }
                }
                section("Dil") {
                    row("Arayüz dili", "Yeniden başlatınca uygulanır") {
                        Picker("", selection: Binding(
                            get: { language.selection },
                            set: { language.select($0) }
                        )) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text(lang.title).tag(lang)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 210)
                    }
                    if language.restartNeeded {
                        Button {
                            language.relaunch()
                        } label: {
                            Text("Uygulamayı yeniden başlat")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.gradient))
                        }
                        .buttonStyle(.plain)
                    }
                }
                section("Sistem") {
                    row("Oturum açma ile başlat", "Mac açılınca NotchShelf'de başlasın") {
                        Toggle("", isOn: launchAtLoginBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(Theme.violet)
                    }
                    row("Kitap bittiğinde bildir", nil) {
                        Toggle("", isOn: $notifyOnFinish)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(Theme.violet)
                            .onChange(of: notifyOnFinish) { _, on in
                                if on { NotificationService.shared.requestAuthorization() }
                            }
                    }
                    if notifyOnFinish && !notifications.authorized {
                        Text("Bildirim izni kapalı — Sistem Ayarları > Bildirimler'den açın")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.pink)
                    }
                    if let error = launch.errorMessage {
                        Text("Başlangıç kaydı başarısız: \(error)")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.pink)
                    }
                }
            }
            .padding(20)
        }
        .task { await notifications.refresh() }
    }

    private var serverRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "externaldrive.fill").foregroundStyle(Theme.gradient).font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text(server.isConnected ? L("Bağlı") : L("Bağlı değil"))
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.ink)
                    Text(server.isConnected ? "\(server.username) · \(server.serverURLString)" : L("Sunucu yapılandırılmadı"))
                        .font(.system(size: 10)).foregroundStyle(Theme.muted).lineLimit(1).truncationMode(.middle)
                }
                Spacer()
            }
            Button {
                rootState.selectedTab = .servers
            } label: {
                Text(server.isConnected ? L("Sunucuları yönet") : L("Sunucu ekle"))
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.ink.opacity(0.85))
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.cardFill))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.cardBorder))
            }
            .buttonStyle(.plain)
        }
        .cardStyle()
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L(title).uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.muted.opacity(0.7))
            content()
        }
    }

    private func row(_ title: LocalizedStringKey, _ subtitle: LocalizedStringKey?, @ViewBuilder control: () -> some View) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.ink)
                if let subtitle {
                    Text(subtitle).font(.system(size: 10)).foregroundStyle(Theme.muted)
                }
            }
            Spacer()
            control()
        }
    }
}
