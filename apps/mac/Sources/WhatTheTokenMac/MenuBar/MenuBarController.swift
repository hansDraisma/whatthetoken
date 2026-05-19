import Foundation
#if canImport(AppKit)
import AppKit
import SwiftUI
#endif

@MainActor
protocol MenuBarHosting: AnyObject, Sendable {
    var isOpen: Bool { get }
    func activateAppForPopover()
    func openPopover()
    func closePopover()
    func setIconCritical(_ isCritical: Bool)
    func teardown()
}

@MainActor
protocol MenuBarPulsing: AnyObject {
    func pulse()
}

@MainActor
final class MenuBarController {
    let hosting: MenuBarHosting
    let pulseAnimator: MenuBarPulsing

    init(hosting: MenuBarHosting, pulseAnimator: MenuBarPulsing) {
        self.hosting = hosting
        self.pulseAnimator = pulseAnimator
    }

    deinit {
        let hosting = hosting
        Task { @MainActor in
            hosting.teardown()
        }
    }

    func openPopover() {
        hosting.activateAppForPopover()
        hosting.openPopover()
    }
    func closePopover() { hosting.closePopover() }
    func togglePopover() { hosting.isOpen ? hosting.closePopover() : openPopover() }
    func pulse() { pulseAnimator.pulse() }
    func updateCriticalState(isCritical: Bool) { hosting.setIconCritical(isCritical) }
}

#if canImport(AppKit)
@MainActor
final class LiveMenuBarHosting: NSObject, MenuBarHosting, @unchecked Sendable {
    let statusItem: NSStatusItem
    let popover: NSPopover
    nonisolated(unsafe) private var globalMonitor: Any?
    private var closeObserver: NSObjectProtocol?

    init(popoverContent: NSViewController) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = popoverContent

        super.init()

        statusItem.button?.image = MenuBarStatusItemImage.make(isCritical: false)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleButtonClick)
        statusItem.button?.sendAction(on: [.leftMouseUp])
        statusItem.button?.wantsLayer = true
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSPopover.didCloseNotification,
            object: popover,
            queue: .main
        ) { [weak self] _ in
            self?.removeGlobalMonitor()
        }
    }

    var isOpen: Bool { popover.isShown }

    func activateAppForPopover() {
        NSApp.activate(ignoringOtherApps: true)
    }

    func openPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.identifier = .whatTheTokenMenuBarPopover
        removeGlobalMonitor()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.popover.performClose(nil)
        }
    }

    func closePopover() {
        popover.performClose(nil)
    }

    func setIconCritical(_ isCritical: Bool) {
        statusItem.button?.image = MenuBarStatusItemImage.make(isCritical: isCritical)
    }

    func teardown() {
        removeGlobalMonitor()
        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
            self.closeObserver = nil
        }
        popover.performClose(nil)
        statusItem.button?.target = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    nonisolated private func removeGlobalMonitor() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }

    @objc private func handleButtonClick() {
        if isOpen {
            closePopover()
        } else {
            activateAppForPopover()
            openPopover()
        }
    }
}

extension MenuBarController {
    static func live(popoverContent: NSViewController) -> MenuBarController {
        let hosting = LiveMenuBarHosting(popoverContent: popoverContent)
        let animator = MenuBarIconPulseAnimator.liveSystem(statusItem: hosting.statusItem)
        let pulser = LiveMenuBarPulseAdapter(animator: animator)
        return MenuBarController(hosting: hosting, pulseAnimator: pulser)
    }
}

@MainActor
final class LiveMenuBarPulseAdapter: MenuBarPulsing {
    let animator: MenuBarIconPulseAnimator

    init(animator: MenuBarIconPulseAnimator) {
        self.animator = animator
    }

    func pulse() {
        animator.pulse()
    }
}
#endif
