import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Preferences.registerDefaults()
        NSLog("NotchShelf: arayüz dili=%@ seçim=%@",
              Bundle.main.preferredLocalizations.first ?? "?", Preferences.appLanguage)
        NSApp.setActivationPolicy(.accessory)
        StatusItemController.shared.setup()
        if Preferences.notchEnabled {
            NotchHUDController.shared.setupIfSupported()
        }
        // İzin durumunu açılışta öğren; kitap bittiğinde sormak için geç oluyor.
        Task {
            let notifications = NotificationService.shared
            await notifications.refresh()
            if Preferences.notifyOnFinish {
                await notifications.requestAuthorizationAsync()
            }
        }
        // GEÇİCİ: bildirim ikonunu doğrulama tetikleyicisi; doğrulanınca kaldırılacak.
        if ProcessInfo.processInfo.environment["NOTCHSHELF_TEST_NOTIFICATION"] == "1" {
            Task { await NotificationService.shared.bookFinished(title: "İkon testi") }
        }
    }

    // Kapanışta son konumu sunucuya bildir.
    func applicationWillTerminate(_ notification: Notification) {
        PlayerViewModel.shared.stop()
    }
}
