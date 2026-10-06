import ServiceManagement
import SwiftUI

// SMAppService.mainApp ince sarmalayıcı. Ayrı bir "login item" target'ı değil,
// ana uygulamanın kendisi kaydedilir.
@MainActor
final class LaunchAtLogin: ObservableObject {
    static let shared = LaunchAtLogin()

    @Published private(set) var isEnabled = false
    @Published var errorMessage: String?

    private init() {
        refresh()
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
            isEnabled = enabled
        } catch {
            // Ad-hoc/imzasız derlemelerde macOS kaydı reddedebilir.
            errorMessage = error.localizedDescription
            refresh()
        }
    }
}
