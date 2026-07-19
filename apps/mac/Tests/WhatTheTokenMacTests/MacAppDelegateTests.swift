import Foundation
import AppKit
import Testing
@testable import WhatTheTokenMac

@Suite struct MacAppDelegateTests {
    @MainActor
    @Test func reopenSuppressesDefaultHandling() {
        let actions = SpyDelegateActions()
        let delegate = MacAppDelegate(actions: actions)

        let result = delegate.applicationShouldHandleReopen(hasVisibleWindows: false)

        #expect(result == false)
    }

    @MainActor
    @Test func reopenAlsoSuppressesEvenWithVisibleWindows() {
        let actions = SpyDelegateActions()
        let delegate = MacAppDelegate(actions: actions)

        let result = delegate.applicationShouldHandleReopen(hasVisibleWindows: true)

        #expect(result == false)
    }

    @MainActor
    @Test func closingLastWindowKeepsMenuBarAppRunning() {
        let actions = SpyDelegateActions()
        let delegate = MacAppDelegate(actions: actions)

        let result = delegate.applicationShouldTerminateAfterLastWindowClosed()

        #expect(result == false)
    }

    @MainActor
    @Test func appDelegateAdaptorKeepsMenuBarAppRunningAfterLastWindowCloses() {
        let adaptor = MacAppDelegateAdaptor()

        let result = adaptor.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)

        #expect(result == false)
    }

    @Test func defaultLaunchOpensTheRealWindow() {
        #expect(AppLaunchPresentation.shouldOpenWindow())
    }

    @Test func nonDefaultLaunchStaysQuietForBackgroundStarts() {
        #expect(!AppLaunchPresentation.shouldOpenWindow(launchedAsLoginItem: true))
        #expect(!AppLaunchPresentation.shouldOpenWindow(launchedAsServiceItem: true))
    }

    @MainActor
    @Test func reopenWithVisibleLaunchWindowBringsItForward() {
        let actions = SpyDelegateActions(hasVisibleLaunchWindow: true)
        let delegate = MacAppDelegate(actions: actions)

        let result = delegate.applicationShouldHandleReopen(hasVisibleWindows: true)

        #expect(result == false)
        #expect(actions.calls == ["bringLaunchWindowForward"])
    }

    @MainActor
    @Test func reopenWithNoVisibleLaunchWindowOpensIt() {
        let actions = SpyDelegateActions(hasVisibleLaunchWindow: false)
        let delegate = MacAppDelegate(actions: actions)

        let result = delegate.applicationShouldHandleReopen(hasVisibleWindows: false)

        #expect(result == false)
        #expect(actions.calls == ["openLaunchWindow"])
    }

}

@MainActor
private final class SpyDelegateActions: MacAppDelegateActions {
    var openPopoverCount = 0
    var pulseCount = 0
    var calls: [String] = []
    var hasVisibleLaunchWindow: Bool

    init(hasVisibleLaunchWindow: Bool = false) {
        self.hasVisibleLaunchWindow = hasVisibleLaunchWindow
    }

    func openPopover() {
        openPopoverCount += 1
        calls.append("openPopover")
    }

    func pulseMenuBarIcon() {
        pulseCount += 1
        calls.append("pulseMenuBarIcon")
    }

    func openLaunchWindow() {
        calls.append("openLaunchWindow")
    }

    func bringLaunchWindowForward() {
        calls.append("bringLaunchWindowForward")
    }
}
