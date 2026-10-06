import AppKit
import SwiftUI

// NSPanel + .nonactivatingPanel: HUD tıklamaları uygulamayı aktive etmez,
// menü çubuğu popover'ının odağını çalmaz (NotchNook tarzı yaklaşım).
final class NotchWindow: NSPanel {
    let notchInfo: NotchInfo

    init(notchInfo: NotchInfo, rootView: some View) {
        self.notchInfo = notchInfo
        super.init(
            contentRect: Self.frame(size: Self.collapsedSize(for: notchInfo), notchInfo: notchInfo),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        ignoresMouseEvents = false
        contentView = NSHostingView(rootView: rootView)
    }

    override var canBecomeKey: Bool { true }

    static func collapsedSize(for info: NotchInfo) -> CGSize {
        CGSize(width: info.width + 56, height: info.height + 6)
    }

    static func expandedSize(for info: NotchInfo) -> CGSize {
        CGSize(width: 380, height: info.height + 240)
    }

    // Üst kenar ekrana yapışık, notch ortasına hizalı kalır.
    static func frame(size: CGSize, notchInfo info: NotchInfo) -> CGRect {
        CGRect(
            x: info.notchRect.midX - size.width / 2,
            y: info.screen.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }
}
