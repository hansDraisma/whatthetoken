import Testing
@testable import WhatTheTokenMac

@Test func formatsFixtureBackedStatusCardStrings() throws {
    let snapshot = try StatusViewModel.loadFixtureSnapshot()
    let display = StatusCardDisplayModel(snapshot: snapshot)

    #expect(display.title == "Anthropic / claude code")
    #expect(display.primaryMetric == "38% remaining")
    #expect(display.confidenceLabel == "Verified")
    #expect(display.updatedLabel == "Updated 2026-05-04T10:00:00.000Z")
    #expect(display.progressValue == 0.62)
}

@Test func formatsObservedUsageWhenRemainingIsUnknown() {
    let snapshot = UsageSnapshot(
        id: "snap_observed",
        userAccountId: "fixture_user",
        provider: "openai",
        product: "codex",
        surface: "cli",
        poolKey: "openai_codex",
        windowKey: "daily",
        unit: "requests",
        used: nil,
        limit: nil,
        remaining: nil,
        utilization: nil,
        resetAt: nil,
        lastUpdatedAt: "2026-05-04T10:00:00.000Z",
        confidence: "observed",
        undercountRisk: "possible",
        staleReason: nil,
        source: ConnectorSource(
            connector: "manual_fixture",
            state: .connected,
            label: "Fixture",
            parserVersion: "fixture-v1",
            deviceId: "device_fixture"
        )
    )

    let display = StatusCardDisplayModel(snapshot: snapshot)

    #expect(display.title == "Openai / codex")
    #expect(display.primaryMetric == "Usage observed")
    #expect(display.confidenceLabel == "Observed")
    #expect(display.updatedLabel == "Updated 2026-05-04T10:00:00.000Z")
    #expect(display.progressValue == 0)
}
