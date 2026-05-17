import Foundation
#if canImport(AppKit)
import AppKit
import SwiftUI
#endif

@MainActor
protocol MenuBarHosting: AnyObject {
    var isOpen: Bool { get }
    func openPopover()
    func closePopover()
    func setIconCritical(_ isCritical: Bool)
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

    func openPopover() { hosting.openPopover() }
    func closePopover() { hosting.closePopover() }
    func togglePopover() { hosting.isOpen ? hosting.closePopover() : hosting.openPopover() }
    func pulse() { pulseAnimator.pulse() }
    func updateCriticalState(isCritical: Bool) { hosting.setIconCritical(isCritical) }
}

#if canImport(AppKit)
@MainActor
final class LiveMenuBarHosting: NSObject, MenuBarHosting {
    let statusItem: NSStatusItem
    let popover: NSPopover

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
    }

    var isOpen: Bool { popover.isShown }

    func openPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func closePopover() {
        popover.performClose(nil)
    }

    func setIconCritical(_ isCritical: Bool) {
        statusItem.button?.image = MenuBarStatusItemImage.make(isCritical: isCritical)
    }

    @objc private func handleButtonClick() {
        isOpen ? closePopover() : openPopover()
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
