import UserNotifications
import AppKit

// Yerel bildirimler. Tek kullanım yeri: kitap bitince bilgilendirme (spec §8).
@MainActor
final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    @Published private(set) var authorized = false
    @Published private(set) var didAsk = false

    private override init() { super.init() }

    // Sistem tarafındaki gerçek durum; imza/bundle değişince izin sıfırlanabiliyor.
    func refresh() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        authorized = status == .authorized || status == .provisional
        didAsk = status != .notDetermined
    }

    func requestAuthorization() {
        Task { await self.requestAuthorizationAsync() }
    }

    @discardableResult
    func requestAuthorizationAsync() async -> Bool {
        if !didAsk {
            do {
                authorized = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound])
            } catch {
                NSLog("NotchShelf: bildirim izni alınamadı: %@", error.localizedDescription)
            }
            didAsk = true
        }
        if !authorized {
            NSLog("NotchShelf: bildirim izni yok, Sistem Ayarları > Bildirimler'den açılmalı")
        }
        return authorized
    }

    func bookFinished(title: String, coverData: Data? = nil) async {
        guard Preferences.notifyOnFinish else { return }
        await refresh()
        guard authorized else {
            NSLog("NotchShelf: 'Kitap bitti' bildirimi atlandı (izin yok)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = L("Kitap bitti")
        content.body = title
        content.sound = .default
        if let attachment = Self.makeAttachment(from: coverData) {
            content.attachments = [attachment]
        }

        let request = UNNotificationRequest(
            identifier: "notchshelf.finished.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            NSLog("NotchShelf: bildirim eklenemedi: %@", error.localizedDescription)
        }
    }

    // Kapak görselini bildirime ek olarak iliştirir; ikon yerine kapak görünür.
    private static func makeAttachment(from coverData: Data?) -> UNNotificationAttachment? {
        guard let coverData, let image = NSImage(data: coverData),
              let png = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("notchshelf-cover-\(UUID().uuidString).png")
        do {
            try png.write(to: url)
            return try UNNotificationAttachment(identifier: "cover", url: url, options: nil)
        } catch {
            NSLog("NotchShelf: kapak eki oluşturulamadı: %@", error.localizedDescription)
            return nil
        }
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
