import SwiftUI

struct RootView: View {
    enum Tab: String, Hashable, CaseIterable {
        case player, library, servers, settings

        var title: String {
            switch self {
            case .player: return "Oynatıcı"
            case .library: return "Kütüphane"
            case .servers: return "Sunucular"
            case .settings: return "Ayarlar"
            }
        }

        var symbolName: String {
            switch self {
            case .player: return "play.fill"
            case .library: return "books.vertical.fill"
            case .servers: return "externaldrive.fill"
            case .settings: return "gearshape.fill"
            }
        }

        var digit: KeyEquivalent {
            switch self {
            case .player: return "1"
            case .library: return "2"
            case .servers: return "3"
            case .settings: return "4"
            }
        }
    }

    @MainActor
    final class State: ObservableObject {
        @Published var selectedTab: Tab = .player
        // Popover her açıldığında benzersiz id sayesinde onChange mutlaka tetiklenir.
        @Published var focusRequest: FocusRequest?

        struct FocusRequest: Equatable {
            let id = UUID()
            let tab: Tab
        }
    }

    @ObservedObject var state: State
    @FocusState private var focusedTab: Tab?
    @AppStorage(Preferences.Key.hasOnboarded) private var hasOnboarded = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                tabBar
                Divider().overlay(Theme.cardBorder)
                tabContent
                footer
            }

            if !hasOnboarded {
                OnboardingView {
                    withAnimation(AppAnimation.standard) {
                        hasOnboarded = true
                        state.selectedTab = .servers
                    }
                    state.focusRequest = .init(tab: .servers)
                }
                .transition(.opacity)
            }
        }
        .frame(width: Metrics.popoverWidth, height: Metrics.popoverHeight)
        .background(Theme.base)
        .environmentObject(state)
        .environmentObject(ServerViewModel.shared)
        .environmentObject(PlayerViewModel.shared)
        .onAppear { focusedTab = state.selectedTab }
        .onChange(of: state.focusRequest) {
            if let tab = state.focusRequest?.tab {
                focusedTab = tab
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "headphones")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.gradient)
            Text("NotchShelf")
                .font(.system(size: 15, weight: .bold, design: .default))
                .foregroundStyle(Theme.ink)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(AppAnimation.standard) {
                        state.selectedTab = tab
                    }
                    focusedTab = tab
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.symbolName)
                            .font(.system(size: 10, weight: .semibold))
                        Text(LocalizedStringKey(tab.title))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                            .fill(state.selectedTab == tab ? Theme.cardFill : .clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                            .stroke(state.selectedTab == tab ? Theme.cardBorder : .clear)
                    )
                    .foregroundStyle(state.selectedTab == tab ? Theme.ink : Theme.muted)
                }
                .buttonStyle(.plain)
                .focusable(true)
                .focused($focusedTab, equals: tab)
                .focusEffectDisabled()
                .keyboardShortcut(tab.digit, modifiers: .command)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch state.selectedTab {
        case .player:
            PlayerView()
        case .library:
            LibraryView()
        case .servers:
            ServerSetupView()
        case .settings:
            SettingsView()
        }
    }

    private var footer: some View {
        HStack {
            Text("v\(appVersion)")
                .font(.system(size: 10))
                .foregroundStyle(Theme.muted.opacity(0.6))
            Spacer()
            Button {
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Text("App Store'da Yakında")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.cardFill))
                    .overlay(Capsule().stroke(Theme.cardBorder))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }
}

#Preview {
    RootView(state: RootView.State())
}
