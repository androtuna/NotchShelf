import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    static let shared = StatusItemController()

    private var statusItem: NSStatusItem?
    private let popoverController = MenuBarPopover()

    private override init() {
        super.init()
    }

    func setup() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = item.button else { return }
        button.image = MenuBarIcon.current.image
        button.toolTip = "NotchShelf"
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || (event?.type == .leftMouseUp && event?.modifierFlags.contains(.control) == true)
        if isRightClick {
            showMenu(from: sender)
        } else {
            popoverController.toggle(relativeTo: sender)
        }
    }

    // statusItem.menu atanmaz; atanırsa sol tık da menüye gider (AppKit davranışı).
    private func showMenu(from button: NSStatusBarButton) {
        popoverController.close()

        let menu = NSMenu()
        let about = NSMenuItem(title: L("NotchShelf Hakkında"), action: #selector(showAbout), keyEquivalent: "")
        let settings = NSMenuItem(title: L("Ayarlar…"), action: #selector(openSettings), keyEquivalent: ",")
        let quit = NSMenuItem(title: L("NotchShelf'ten Çık"), action: #selector(quit), keyEquivalent: "q")
        for item in [about, settings, quit] {
            item.target = self
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    func refreshIcon() {
        statusItem?.button?.image = MenuBarIcon.current.image
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func openSettings() {
        guard let button = statusItem?.button else { return }
        popoverController.show(relativeTo: button, tab: .settings)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
