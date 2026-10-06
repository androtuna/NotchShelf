import AppKit

struct NotchInfo {
    let screen: NSScreen
    let notchRect: CGRect // global ekran koordinatlarında
    let width: CGFloat
    let height: CGFloat
    let isSimulated: Bool
}

@MainActor
enum NotchDetector {
    // MacBook Pro 14"/16" notch genişliği ≈ 200pt (resmi API yok, spec §4).
    static let defaultNotchWidth: CGFloat = 200
    static let simulatedNotchHeight: CGFloat = 32

    static func detect() -> NotchInfo? {
        guard !NSScreen.screens.isEmpty else { return nil }

        for screen in NSScreen.screens {
            let inset = screen.safeAreaInsets.top
            guard inset > 0 else { continue }
            let frame = screen.frame
            let rect = CGRect(
                x: frame.midX - defaultNotchWidth / 2,
                y: frame.maxY - inset,
                width: defaultNotchWidth,
                height: inset
            )
            return NotchInfo(screen: screen, notchRect: rect,
                             width: defaultNotchWidth, height: inset,
                             isSimulated: false)
        }

        // Notch'suz makine: HUD'u test edebilmek için üst-ortada simüle notch.
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return nil }
        let frame = screen.frame
        let rect = CGRect(
            x: frame.midX - defaultNotchWidth / 2,
            y: frame.maxY - simulatedNotchHeight,
            width: defaultNotchWidth,
            height: simulatedNotchHeight
        )
        return NotchInfo(screen: screen, notchRect: rect,
                         width: defaultNotchWidth, height: simulatedNotchHeight,
                         isSimulated: true)
    }
}
