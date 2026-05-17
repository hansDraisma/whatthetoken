import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct MenuBarControllerTests {
    @MainActor
    @Test func openPopoverDelegatesToHosting() {
        let hosting = SpyMenuBarHosting()
        let controller = MenuBarController(hosting: hosting, pulseAnimator: SpyPulseAnimator())

        controller.openPopover()

        #expect(hosting.openCount == 1)
    }

    @MainActor
    @Test func togglePopoverOpensWhenClosed() {
        let hosting = SpyMenuBarHosting()
        hosting.isOpen = false
        let controller = MenuBarController(hosting: hosting, pulseAnimator: SpyPulseAnimator())

        controller.togglePopover()

        #expect(hosting.openCount == 1)
        #expect(hosting.closeCount == 0)
    }

    @MainActor
    @Test func togglePopoverClosesWhenOpen() {
        let hosting = SpyMenuBarHosting()
        hosting.isOpen = true
        let controller = MenuBarController(hosting: hosting, pulseAnimator: SpyPulseAnimator())

        controller.togglePopover()

        #expect(hosting.closeCount == 1)
        #expect(hosting.openCount == 0)
    }

    @MainActor
    @Test func pulseInvokesAnimator() {
        let hosting = SpyMenuBarHosting()
        let animator = SpyPulseAnimator()
        let controller = MenuBarController(hosting: hosting, pulseAnimator: animator)

        controller.pulse()

        #expect(animator.pulseCount == 1)
    }

    @MainActor
    @Test func updateCriticalStateRewritesIcon() {
        let hosting = SpyMenuBarHosting()
        let controller = MenuBarController(hosting: hosting, pulseAnimator: SpyPulseAnimator())

        controller.updateCriticalState(isCritical: true)

        #expect(hosting.lastSetCriticalState == true)
    }
}

@MainActor
final class SpyMenuBarHosting: MenuBarHosting {
    var openCount = 0
    var closeCount = 0
    var isOpen = false
    var lastSetCriticalState: Bool?

    func openPopover() { openCount += 1 }
    func closePopover() { closeCount += 1 }
    func setIconCritical(_ isCritical: Bool) { lastSetCriticalState = isCritical }
}

@MainActor
final class SpyPulseAnimator: MenuBarPulsing {
    var pulseCount = 0
    func pulse() { pulseCount += 1 }
}
