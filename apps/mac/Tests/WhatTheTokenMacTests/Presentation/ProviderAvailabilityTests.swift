import Testing
@testable import WhatTheTokenMac

@Suite struct ProviderAvailabilityTests {
    @Test func claude_includedHealthy_fallbackMissing_isAvailable() {
        let snapshots = [UsageSnapshotFixture.claudeIncludedSample(remaining: 62, utilization: 0.38)]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .available)
    }

    @Test func claude_includedHealthy_fallbackZero_isAvailable() {
        let snapshots = [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 62, utilization: 0.38),
            UsageSnapshotFixture.claudeCreditsSample(remaining: 0)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .available)
    }

    @Test func claude_includedHealthy_fallbackPositive_isAvailable() {
        let snapshots = [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 88, utilization: 0.12, windowKey: "seven_day"),
            UsageSnapshotFixture.claudeCreditsSample(remaining: 20)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .available)
    }

    @Test func claude_includedLow_fallbackZero_isLow() {
        let snapshots = [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 20, utilization: 0.80, windowKey: "seven_day"),
            UsageSnapshotFixture.claudeCreditsSample(remaining: 0)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .low)
    }

    @Test func claude_includedCritical_fallbackPositive_isCriticalWithFallback() {
        let snapshots = [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 5, utilization: 0.95),
            UsageSnapshotFixture.claudeCreditsSample(remaining: 20)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .criticalWithFallback)
    }

    @Test func claude_includedCritical_fallbackZero_isCritical() {
        let snapshots = [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 5, utilization: 0.95),
            UsageSnapshotFixture.claudeCreditsSample(remaining: 0)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .critical)
    }

    @Test func claude_includedEmpty_fallbackPositive_isFallbackOnly() {
        let snapshots = [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 0, utilization: 1.0),
            UsageSnapshotFixture.claudeCreditsSample(remaining: 20)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .fallbackOnly)
    }

    @Test func claude_includedEmpty_fallbackMissing_isCritical() {
        let snapshots = [UsageSnapshotFixture.claudeIncludedSample(remaining: 0, utilization: 1.0)]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .critical)
    }

    @Test func claude_includedEmpty_fallbackZero_isCritical() {
        let snapshots = [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 0, utilization: 1.0),
            UsageSnapshotFixture.claudeCreditsSample(remaining: 0)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .critical)
    }

    @Test func codex_includedHealthy_creditsMissing_isAvailable() {
        let snapshots = [
            UsageSnapshotFixture.codexIncludedSample(remaining: 75, utilization: 0.25)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .codex) == .available)
    }

    @Test func codex_includedHealthy_creditsZero_isAvailable() {
        let snapshots = [
            UsageSnapshotFixture.codexIncludedSample(remaining: 75, utilization: 0.25),
            UsageSnapshotFixture.codexCreditsSample(remaining: 0)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .codex) == .available)
    }

    @Test func codex_includedHealthy_creditsPositive_isAvailable() {
        let snapshots = [
            UsageSnapshotFixture.codexIncludedSample(remaining: 75, utilization: 0.25),
            UsageSnapshotFixture.codexCreditsSample(remaining: 25)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .codex) == .available)
    }

    @Test func codex_includedLow_creditsZero_isLow() {
        let snapshots = [
            UsageSnapshotFixture.codexIncludedSample(remaining: 20, utilization: 0.80),
            UsageSnapshotFixture.codexCreditsSample(remaining: 0)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .codex) == .low)
    }

    @Test func codex_includedCritical_creditsPositive_isCriticalWithFallback() {
        let snapshots = [
            UsageSnapshotFixture.codexIncludedSample(remaining: 5, utilization: 0.95),
            UsageSnapshotFixture.codexCreditsSample(remaining: 25)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .codex) == .criticalWithFallback)
    }

    @Test func codex_includedCritical_creditsZero_isCritical() {
        let snapshots = [
            UsageSnapshotFixture.codexIncludedSample(remaining: 5, utilization: 0.95),
            UsageSnapshotFixture.codexCreditsSample(remaining: 0)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .codex) == .critical)
    }

    @Test func codex_includedEmpty_creditsPositive_isFallbackOnly() {
        let snapshots = [
            UsageSnapshotFixture.codexIncludedSample(remaining: 0, utilization: 1.0),
            UsageSnapshotFixture.codexCreditsSample(remaining: 25)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .codex) == .fallbackOnly)
    }

    @Test func codex_includedEmpty_creditsMissing_isCritical() {
        let snapshots = [
            UsageSnapshotFixture.codexIncludedSample(remaining: 0, utilization: 1.0)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .codex) == .critical)
    }

    @Test func codex_includedEmpty_creditsZero_isCritical() {
        let snapshots = [
            UsageSnapshotFixture.codexIncludedSample(remaining: 0, utilization: 1.0),
            UsageSnapshotFixture.codexCreditsSample(remaining: 0)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .codex) == .critical)
    }

    @Test func codex_creditsRowDoesNotLeakIntoIncludedLane() {
        let snapshots = [
            UsageSnapshotFixture.codexIncludedSample(remaining: 75, utilization: 0.25),
            UsageSnapshotFixture.codexCreditsSample(
                remaining: 0,
                unit: "utilization",
                used: 100,
                limit: 100,
                utilization: 1.0
            )
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .codex) == .available)
    }

    @Test func staleOverridesAvailableLowCriticalWithFallbackFallbackOnlyAndCritical() {
        #expect(ProviderAvailability.from(snapshots: [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 62, utilization: 0.38, staleReason: "old")
        ], tab: .claude) == .stale)

        #expect(ProviderAvailability.from(snapshots: [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 20, utilization: 0.80, windowKey: "seven_day", staleReason: "old")
        ], tab: .claude) == .stale)

        #expect(ProviderAvailability.from(snapshots: [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 5, utilization: 0.95, staleReason: "old"),
            UsageSnapshotFixture.claudeCreditsSample(remaining: 20)
        ], tab: .claude) == .stale)

        #expect(ProviderAvailability.from(snapshots: [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 0, utilization: 1.0, staleReason: "old"),
            UsageSnapshotFixture.claudeCreditsSample(remaining: 20)
        ], tab: .claude) == .stale)

        #expect(ProviderAvailability.from(snapshots: [
            UsageSnapshotFixture.codexIncludedSample(remaining: 0, utilization: 1.0, staleReason: "old"),
            UsageSnapshotFixture.codexCreditsSample(remaining: 0)
        ], tab: .codex) == .stale)
    }
}
