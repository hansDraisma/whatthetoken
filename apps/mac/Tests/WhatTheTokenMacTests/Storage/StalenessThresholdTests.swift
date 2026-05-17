import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct StalenessThresholdTests {
    @Test func defaultThresholdMatchesStage3Spec() {
        // The shared staleness window. Documented in
        // notifications-background-freshness-design.md as "max(2 * refresh
        // interval, 15 minutes)" under background refresh. For the widget
        // (which has no refresh interval of its own), we use 15 minutes
        // as the floor.
        #expect(StalenessThreshold.minimum == .seconds(15 * 60))
    }

    @Test func isSnapshotStaleWhenAgeExceedsThreshold() {
        let stale = StalenessThreshold.isStale(snapshotAge: .seconds(20 * 60))
        let fresh = StalenessThreshold.isStale(snapshotAge: .seconds(5 * 60))
        #expect(stale == true)
        #expect(fresh == false)
    }
}
