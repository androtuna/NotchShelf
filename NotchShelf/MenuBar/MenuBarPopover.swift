import AppKit
import SwiftUI

@MainActor
final class MenuBarPopover: NSObject, NSPopoverDelegate {
    private let popover = NSPopover()
    private let state = RootView.State()

    override init() {
        super.init()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: Metrics.popoverWidth, height: Metrics.popoverHeight)
        popover.contentViewController = NSHostingController(rootView: RootView(state: state))
        popover.delegate = self
    }

    var isShown: Bool { popover.isShown }

    func toggle(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            close()
        } else {
            show(relativeTo: button)
        }
    }

    func show(relativeTo button: NSStatusBarButton, tab: RootView.Tab? = nil) {
        if let tab {
            state.selectedTab = tab
        }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
        state.focusRequest = .init(tab: tab ?? state.selectedTab)
    }

    func close() {
        popover.performClose(nil)
    }

    // Popover kapansa da uygulama .accessory policy ile arka planda çalışmaya
    // devam eder; oynatma kesilmez.
    nonisolated func popoverDidClose(_ notification: Notification) {}
}
