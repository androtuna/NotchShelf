import AppKit
import SwiftUI

@MainActor
final class NotchHUDController: NSObject {
    static let shared = NotchHUDController()

    private let state = NotchHUDState()
    private var window: NotchWindow?
    private var notchInfo: NotchInfo?
    private var hoverTimer: Timer?
    private var isVisible = false

    private override init() {
        super.init()
    }

    func setupIfSupported() {
        guard window == nil, let info = NotchDetector.detect() else { return }
        notchInfo = info

        let hud = NotchHUDView(
            state: state,
            player: PlayerViewModel.shared,
            notchWidth: info.width,
            notchHeight: info.height,
            isSimulated: info.isSimulated
        )
        let window = NotchWindow(notchInfo: info, rootView: hud)
        window.alphaValue = 0
        self.window = window

        // HUD yalnızca imleç notch üzerine geldiğinde açılır (kullanıcı tercihi);
        // çalma başlangıcında otomatik gösterilmez.

        // Menü çubuğu bandında üçüncü parti pencerelere mouse event'i teslim
        // edilmediği için NSTrackingArea burada çalışmıyor; imleç konumunu
        // bunun yerine biz poll'luyoruz (erişilebilirlik izni gerektirmez).
        hoverTimer = Timer.scheduledTimer(
            timeInterval: 0.05,
            target: self,
            selector: #selector(tick),
            userInfo: nil,
            repeats: true
        )

        if info.isSimulated {
            NSLog("NotchShelf: fiziksel notch bulunamadı, simüle notch HUD etkin.")
        }
        // Adım 5: PlayerViewModel.isPlaying değişince göster, 3 sn sonra gizle.
    }

    func teardown() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        window?.orderOut(nil)
        window = nil
        notchInfo = nil
        isVisible = false
    }

    // Ayarlar > Notch HUD anahtarı.
    func setEnabled(_ enabled: Bool) {
        if enabled {
            setupIfSupported()
        } else {
            teardown()
        }
    }

    // Fiziksel notch bölgesi + küçük pay: hover hedefi.
    private func hoverZone(for info: NotchInfo) -> CGRect {
        info.notchRect.insetBy(dx: -12, dy: -6)
    }

    @objc private func tick() {
        guard window != nil, let info = notchInfo else { return }
        let point = NSEvent.mouseLocation
        let expandedRect = NotchWindow.frame(size: NotchWindow.expandedSize(for: info), notchInfo: info)
        // Pay: imleç ekranın tam tepesindeyken mouseY == screen.maxY olur ve
        // contains'in sınır davranışı yüzünden hide/show döngüsü (titreme) başlar.
        let expandedTest = expandedRect.insetBy(dx: -24, dy: -24)
        if isVisible {
            if !expandedTest.contains(point) {
                hide()
            }
        } else if hoverZone(for: info).contains(point) {
            show()
        }
    }

    private func show() {
        guard let window, let info = notchInfo, !isVisible else { return }
        isVisible = true
        state.isExpanded = true

        let collapsed = NotchWindow.frame(size: NotchWindow.collapsedSize(for: info), notchInfo: info)
        let expanded = NotchWindow.frame(size: NotchWindow.expandedSize(for: info), notchInfo: info)
        window.setFrame(collapsed, display: false)
        window.alphaValue = 0
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = AppAnimation.hudDuration
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.2, 1)
            window.animator().setFrame(expanded, display: true)
            window.animator().alphaValue = 1
        }
    }

    private func hide() {
        guard let window, let info = notchInfo, isVisible else { return }
        isVisible = false

        let collapsed = NotchWindow.frame(size: NotchWindow.collapsedSize(for: info), notchInfo: info)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.6, 1)
            window.animator().setFrame(collapsed, display: true)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, !self.isVisible else { return }
                self.window?.orderOut(nil)
                self.state.isExpanded = false
            }
        })
    }
}
