import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct FirstLaunchAutoOpenIntegrationTests {
    @MainActor
    @Test func openerIsCalledExactlyOnceForFreshThenCompletedSequence() {
        var openCount = 0
        let opener = { openCount += 1 }

        FirstLaunchAutoOpenSignaler.signalIfNeeded(settings: AppSettings.defaults, open: opener)

        var second = AppSettings.defaults
        second.onboarding.firstLaunchCompleted = true
        FirstLaunchAutoOpenSignaler.signalIfNeeded(settings: second, open: opener)

        #expect(openCount == 1)
    }
}
