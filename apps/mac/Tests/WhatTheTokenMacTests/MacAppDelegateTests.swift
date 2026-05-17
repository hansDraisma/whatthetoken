import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct MacAppDelegateTests {
    @MainActor
    @Test func reopenOpensPopoverAndPulses() {
        let actions = SpyDelegateActions()
        let delegate = MacAppDelegate(actions: actions)

        let result = delegate.applicationShouldHandleReopen(hasVisibleWindows: false)

        #expect(result == false)
        #expect(actions.openPopoverCount == 1)
        #expect(actions.pulseCount == 1)
    }

    @MainActor
    @Test func reopenAlsoSuppressesEvenWithVisibleWindows() {
        let actions = SpyDelegateActions()
        let delegate = MacAppDelegate(actions: actions)

        let result = delegate.applicationShouldHandleReopen(hasVisibleWindows: true)

        #expect(result == false)
        #expect(actions.openPopoverCount == 1)
    }

    @MainActor
    @Test func signalsLaunchWindowWhenFirstLaunchNotCompleted() {
        var opened = false
        var settings = AppSettings.defaults
        settings.onboarding.firstLaunchCompleted = false

        FirstLaunchAutoOpenSignaler.signalIfNeeded(settings: settings, open: { opened = true })

        #expect(opened == true)
    }

    @MainActor
    @Test func doesNotSignalLaunchWindowOnSubsequentLaunch() {
        var opened = false
        var settings = AppSettings.defaults
        settings.onboarding.firstLaunchCompleted = true

        FirstLaunchAutoOpenSignaler.signalIfNeeded(settings: settings, open: { opened = true })

        #expect(opened == false)
    }
}

@MainActor
private final class SpyDelegateActions: MacAppDelegateActions {
    var openPopoverCount = 0
    var pulseCount = 0

    func openPopover() {
        openPopoverCount += 1
    }

    func pulseMenuBarIcon() {
        pulseCount += 1
    }
}
