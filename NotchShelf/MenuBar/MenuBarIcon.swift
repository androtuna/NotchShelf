import AppKit

enum MenuBarIcon: String, CaseIterable {
    case headphones
    case waveform
    case book

    // Ayarlar'dan seçilir; Preferences üzerinden okunur.
    static var current: MenuBarIcon { Preferences.menuIcon }

    var symbolName: String {
        switch self {
        case .headphones: return "headphones"
        case .waveform: return "waveform"
        case .book: return "book.closed"
        }
    }

    var image: NSImage {
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "NotchShelf")
            ?? NSImage()
        image.isTemplate = true
        return image
    }
}
