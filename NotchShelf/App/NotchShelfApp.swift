import SwiftUI

@main
struct NotchShelfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Gerçek ayarlar popover içindeki Settings sekmesinde yaşar;
        // LSUIElement uygulamada menü çubuğu kısayolları için boş bir Settings sahnesi gerekir.
        Settings {
            EmptyView()
        }
    }
}
