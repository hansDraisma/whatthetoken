import Testing
@testable import WhatTheTokenMac

private func usageStateSnapshot(
    unit: String = "utilization",
    used: Double? = nil,
    limit: Double? = 100,
    remaining: Double?,
    utilization: Double? = nil
) -> UsageSnapshot {
    UsageSnapshot(
        id: "snap",
        userAccountId: "u",
        provider: "anthropic",
        product: "claude_code",
        surface: "cli",
        poolKey: "anthropic_claude_subscription",
        windowKey: "five_hour",
        unit: unit,
        used: used,
        limit: limit,
        remaining: remaining,
        utilization: utilization,
        resetAt: nil,
        lastUpdatedAt: "2026-05-05T09:44:00.000Z",
        confidence: "verified",
        undercountRisk: "none",
        staleReason: nil,
        display: nil,
        source: ConnectorSource(
            connector: "mac_connector",
            state: .connected,
            label: "Mac connector",
            parserVersion: "v1",
            deviceId: "d"
        )
    )
}

@Test func healthyAtThirtyPercentRemaining() {
    let snapshot = usageStateSnapshot(remaining: 30, utilization: 0.70)

    #expect(StatusUsageState(snapshot: snapshot) == .healthy)
}

@Test func lowJustUnderThirtyPercentRemaining() {
    let snapshot = usageStateSnapshot(remaining: 29, utilization: 0.71)

    #expect(StatusUsageState(snapshot: snapshot) == .low)
}

@Test func lowAtTenPercentRemaining() {
    let snapshot = usageStateSnapshot(remaining: 10, utilization: 0.90)

    #expect(StatusUsageState(snapshot: snapshot) == .low)
}

@Test func criticalJustUnderTenPercentRemaining() {
    let snapshot = usageStateSnapshot(remaining: 9, utilization: 0.91)

    #expect(StatusUsageState(snapshot: snapshot) == .critical)
}

@Test func utilizationWinsWhenRemainingDisagrees() {
    let snapshot = usageStateSnapshot(remaining: 90, utilization: 0.95)

    #expect(StatusUsageState(snapshot: snapshot) == .critical)
}

@Test func emptyAtZero() {
    let snapshot = usageStateSnapshot(remaining: 0, utilization: 1.0)

    #expect(StatusUsageState(snapshot: snapshot) == .empty)
}

@Test func creditsEmptyWhenRemainingIsNegative() {
    let snapshot = usageStateSnapshot(unit: "credits", limit: 100, remaining: -1)

    #expect(StatusUsageState(snapshot: snapshot) == .empty)
}

@Test func creditsHealthyWhenRemainingPositiveAndLimitMissing() {
    let snapshot = usageStateSnapshot(unit: "credits", limit: nil, remaining: 5)

    #expect(StatusUsageState(snapshot: snapshot) == .healthy)
}

@Test func creditsEmptyWhenZero() {
    let snapshot = usageStateSnapshot(unit: "credits", limit: 100, remaining: 0)

    #expect(StatusUsageState(snapshot: snapshot) == .empty)
}

@Test func creditsLowAtFifteenOfHundred() {
    let snapshot = usageStateSnapshot(unit: "credits", limit: 100, remaining: 15)

    #expect(StatusUsageState(snapshot: snapshot) == .low)
}

@Test func unknownRemainingTreatedAsHealthy() {
    let snapshot = usageStateSnapshot(remaining: nil, utilization: nil)

    #expect(StatusUsageState(snapshot: snapshot) == .healthy)
}
