import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct NotificationEvaluatorTests {
    @Test func warningFiresOnceBelowTwentyPercent() {
        let snapshot = UsageSnapshotFixture.claudeIncludedSample(remaining: 19, utilization: 0.81)
        var state = NotificationState.empty
        let result = NotificationEvaluator.evaluate(
            snapshots: [snapshot],
            settings: alertSettings(),
            state: state,
            now: Date(timeIntervalSince1970: 1_000),
            suppressDelivery: false
        )

        #expect(result.intents.count == 1)
        #expect(result.intents.first?.level == .warning)
        state = result.state

        let second = NotificationEvaluator.evaluate(
            snapshots: [snapshot],
            settings: alertSettings(),
            state: state,
            now: Date(timeIntervalSince1970: 1_060),
            suppressDelivery: false
        )
        #expect(second.intents.isEmpty)
    }

    @Test func criticalFiresAfterWarningAndDirectlyFromHealthy() {
        let warning = UsageSnapshotFixture.claudeIncludedSample(remaining: 19, utilization: 0.81)
        let critical = UsageSnapshotFixture.claudeIncludedSample(remaining: 9, utilization: 0.91)
        let first = NotificationEvaluator.evaluate(
            snapshots: [warning],
            settings: alertSettings(),
            state: .empty,
            now: Date(timeIntervalSince1970: 1_000),
            suppressDelivery: false
        )
        let second = NotificationEvaluator.evaluate(
            snapshots: [critical],
            settings: alertSettings(),
            state: first.state,
            now: Date(timeIntervalSince1970: 1_060),
            suppressDelivery: false
        )
        let direct = NotificationEvaluator.evaluate(
            snapshots: [critical],
            settings: alertSettings(),
            state: .empty,
            now: Date(timeIntervalSince1970: 1_000),
            suppressDelivery: false
        )

        #expect(second.intents.first?.level == .critical)
        #expect(direct.intents.first?.level == .critical)
    }

    @Test func stalePausedDisabledAndFallbackCreditSnapshotsDoNotNotify() {
        var pausedSettings = alertSettings()
        pausedSettings.connectors.claudeCode.isPaused = true
        var disabledSettings = alertSettings()
        disabledSettings.connectors.claudeCode.isEnabled = false
        let stale = UsageSnapshotFixture.claudeIncludedSample(remaining: 5, utilization: 0.95, staleReason: "old")
        let fallback = UsageSnapshotFixture.claudeCreditsSample(remaining: 0)

        #expect(NotificationEvaluator.evaluate(snapshots: [stale], settings: alertSettings(), state: .empty, now: Date(), suppressDelivery: false).intents.isEmpty)
        #expect(NotificationEvaluator.evaluate(snapshots: [UsageSnapshotFixture.claudeIncludedSample(remaining: 5, utilization: 0.95)], settings: pausedSettings, state: .empty, now: Date(), suppressDelivery: false).intents.isEmpty)
        #expect(NotificationEvaluator.evaluate(snapshots: [UsageSnapshotFixture.claudeIncludedSample(remaining: 5, utilization: 0.95)], settings: disabledSettings, state: .empty, now: Date(), suppressDelivery: false).intents.isEmpty)
        #expect(NotificationEvaluator.evaluate(snapshots: [fallback], settings: alertSettings(), state: .empty, now: Date(), suppressDelivery: false).intents.isEmpty)
    }

    @Test func cacheLoadSuppressionUpdatesStateWithoutDelivering() {
        let snapshot = UsageSnapshotFixture.codexIncludedSample(remaining: 8, utilization: 0.92)
        let result = NotificationEvaluator.evaluate(
            snapshots: [snapshot],
            settings: alertSettings(),
            state: .empty,
            now: Date(timeIntervalSince1970: 1_000),
            suppressDelivery: true
        )

        #expect(result.intents.isEmpty)
        #expect(result.state.records.isEmpty == false)
    }

    @Test func warningRefiresOnlyAfterRecoveryAndRollingCooldown() {
        let warning = UsageSnapshotFixture.claudeIncludedSample(remaining: 19, utilization: 0.81)
        let healthy = UsageSnapshotFixture.claudeIncludedSample(remaining: 26, utilization: 0.74)
        let first = NotificationEvaluator.evaluate(
            snapshots: [warning],
            settings: alertSettings(),
            state: .empty,
            now: Date(timeIntervalSince1970: 1_000),
            suppressDelivery: false
        )
        let recoveredInsideCooldown = NotificationEvaluator.evaluate(
            snapshots: [healthy],
            settings: alertSettings(),
            state: first.state,
            now: Date(timeIntervalSince1970: 1_600),
            suppressDelivery: false
        )
        let repeatedInsideCooldown = NotificationEvaluator.evaluate(
            snapshots: [warning],
            settings: alertSettings(),
            state: recoveredInsideCooldown.state,
            now: Date(timeIntervalSince1970: 1_700),
            suppressDelivery: false
        )
        let recoveredAfterCooldown = NotificationEvaluator.evaluate(
            snapshots: [healthy],
            settings: alertSettings(),
            state: repeatedInsideCooldown.state,
            now: Date(timeIntervalSince1970: 4_700),
            suppressDelivery: false
        )
        let repeatedAfterCooldown = NotificationEvaluator.evaluate(
            snapshots: [warning],
            settings: alertSettings(),
            state: recoveredAfterCooldown.state,
            now: Date(timeIntervalSince1970: 4_760),
            suppressDelivery: false
        )

        #expect(first.intents.count == 1)
        #expect(repeatedInsideCooldown.intents.isEmpty)
        #expect(repeatedAfterCooldown.intents.count == 1)
    }

    @Test func criticalRefiresOnlyAfterRecoveryAboveCriticalHysteresis() {
        let critical = UsageSnapshotFixture.claudeIncludedSample(remaining: 9, utilization: 0.91)
        let stillLow = UsageSnapshotFixture.claudeIncludedSample(remaining: 12, utilization: 0.88)
        let recovered = UsageSnapshotFixture.claudeIncludedSample(remaining: 16, utilization: 0.84)
        let first = NotificationEvaluator.evaluate(snapshots: [critical], settings: alertSettings(), state: .empty, now: Date(timeIntervalSince1970: 1_000), suppressDelivery: false)
        let notRecovered = NotificationEvaluator.evaluate(snapshots: [stillLow], settings: alertSettings(), state: first.state, now: Date(timeIntervalSince1970: 5_000), suppressDelivery: false)
        let recoveredResult = NotificationEvaluator.evaluate(snapshots: [recovered], settings: alertSettings(), state: notRecovered.state, now: Date(timeIntervalSince1970: 5_100), suppressDelivery: false)
        let second = NotificationEvaluator.evaluate(snapshots: [critical], settings: alertSettings(), state: recoveredResult.state, now: Date(timeIntervalSince1970: 5_200), suppressDelivery: false)

        #expect(notRecovered.intents.isEmpty)
        #expect(recoveredResult.intents.isEmpty)
        #expect(second.intents.count == 1)
    }

    @Test func codexDedupeUsesStablePoolKeyAcrossRotatingBucketKeys() {
        let firstSnapshot = UsageSnapshotFixture.codexIncludedSample(remaining: 8, utilization: 0.92, bucketKey: "codex_bucket_a")
        let rotatedSnapshot = UsageSnapshotFixture.codexIncludedSample(remaining: 7, utilization: 0.93, bucketKey: "codex_bucket_b")
        let first = NotificationEvaluator.evaluate(
            snapshots: [firstSnapshot],
            settings: alertSettings(),
            state: .empty,
            now: Date(timeIntervalSince1970: 1_000),
            suppressDelivery: false
        )
        let second = NotificationEvaluator.evaluate(
            snapshots: [rotatedSnapshot],
            settings: alertSettings(),
            state: first.state,
            now: Date(timeIntervalSince1970: 1_060),
            suppressDelivery: false
        )

        #expect(first.intents.count == 1)
        #expect(second.intents.isEmpty)
    }
}

private func alertSettings() -> AppSettings {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    settings.connectors.codex.isEnabled = true
    settings.notifications.isEnabled = true
    settings.notifications.providerAlerts.claudeCode.isEnabled = true
    settings.notifications.providerAlerts.codex.isEnabled = true
    return settings
}
