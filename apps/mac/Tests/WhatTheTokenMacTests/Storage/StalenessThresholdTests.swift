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

    @Test func ageEqualToThresholdIsStale() {
        #expect(StalenessThreshold.isStale(snapshotAge: StalenessThreshold.minimum) == true)
    }

    @Test func futureSnapshotTimestampsRecordClockSkew() {
        let snapshot = UsageSnapshotFixture.claudeSample()
            .copy(confidence: "verified", staleReason: nil)
        let evaluated = snapshot.evaluatingStaleness(
            now: ISO8601DateFormatter().date(from: "2026-05-06T23:59:00Z")!,
            staleAfterMinutes: 60
        )

        #expect(evaluated.confidence == "verified")
        #expect(evaluated.staleReason == "Last update timestamp is in the future.")
    }

    @Test func utilizationRoundsToNearestPercent() {
        #expect(SnapshotEntryBuilder.percent(for: 0.495) == 50)
        #expect(SnapshotEntryBuilder.percent(for: 0.005) == 1)
        #expect(SnapshotEntryBuilder.percent(for: 0.0) == 0)
    }
}
