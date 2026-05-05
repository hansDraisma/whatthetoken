import Foundation
import Testing
@testable import WhatTheTokenMac

private func rowCopySnapshot(
    unit: String,
    remaining: Double?,
    utilization: Double? = nil,
    used: Double? = nil,
    limit: Double? = nil
) -> UsageSnapshot {
    UsageSnapshot(
        id: "s",
        userAccountId: "u",
        provider: "anthropic",
        product: "claude_code",
        surface: "cli",
        poolKey: "p",
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

@Test func heroPercentRemainingForUtilization() {
    let snapshot = rowCopySnapshot(unit: "utilization", remaining: 87, utilization: 0.13)

    #expect(StatusRowCopy.heroText(snapshot: snapshot, state: .healthy) == "87% remaining")
}

@Test func heroPercentRemainingRoundsFromUtilizationSoEchoSumsToOneHundred() {
    let snapshot = rowCopySnapshot(unit: "utilization", remaining: 86.6, utilization: 0.134)

    #expect(StatusRowCopy.heroText(snapshot: snapshot, state: .healthy) == "87% remaining")
    #expect(StatusRowCopy.echoText(snapshot: snapshot) == "13% used")
}

@Test func heroPercentRemainingForLowState() {
    let snapshot = rowCopySnapshot(unit: "utilization", remaining: 27, utilization: 0.73)

    #expect(StatusRowCopy.heroText(snapshot: snapshot, state: .low) == "27% remaining")
}

@Test func heroSentenceForUtilizationEmpty() {
    let snapshot = rowCopySnapshot(unit: "utilization", remaining: 0, utilization: 1.0)

    #expect(StatusRowCopy.heroText(snapshot: snapshot, state: .empty) == "Out of capacity")
}

@Test func heroCountForUtilizationCriticalButNotEmpty() {
    let snapshot = rowCopySnapshot(unit: "utilization", remaining: 5, utilization: 0.95)

    #expect(StatusRowCopy.heroText(snapshot: snapshot, state: .critical) == "5% remaining")
}

@Test func heroSentenceForCreditsEmpty() {
    let snapshot = rowCopySnapshot(unit: "credits", remaining: 0, limit: 100)

    #expect(StatusRowCopy.heroText(snapshot: snapshot, state: .empty) == "Out of credits")
}

@Test func heroCountForCreditsHealthy() {
    let snapshot = rowCopySnapshot(unit: "credits", remaining: 42, limit: 100)

    #expect(StatusRowCopy.heroText(snapshot: snapshot, state: .healthy) == "42 credits remaining")
}

@Test func heroCountForTokensLow() {
    let snapshot = rowCopySnapshot(unit: "tokens", remaining: 1500, limit: 10_000)

    #expect(StatusRowCopy.heroText(snapshot: snapshot, state: .low) == "1500 tokens remaining")
}

@Test func heroFallbackWhenRemainingMissing() {
    let snapshot = rowCopySnapshot(unit: "utilization", remaining: nil, utilization: nil)

    #expect(StatusRowCopy.heroText(snapshot: snapshot, state: .healthy) == "Usage observed")
}

@Test func echoRoundsUtilizationToInteger() {
    let snapshot = rowCopySnapshot(unit: "utilization", remaining: 87, utilization: 0.13)

    #expect(StatusRowCopy.echoText(snapshot: snapshot) == "13% used")
}

@Test func echoRoundsHalfUp() {
    let snapshot = rowCopySnapshot(unit: "utilization", remaining: 27, utilization: 0.7349)

    #expect(StatusRowCopy.echoText(snapshot: snapshot) == "73% used")
}

@Test func echoNilForNonPercentageUnit() {
    let snapshot = rowCopySnapshot(unit: "credits", remaining: 0, limit: 100)

    #expect(StatusRowCopy.echoText(snapshot: snapshot) == nil)
}

@Test func statusWordHealthy() {
    #expect(StatusRowCopy.statusWord(state: .healthy) == "Plenty left")
}

@Test func statusWordLow() {
    #expect(StatusRowCopy.statusWord(state: .low) == "Running low")
}

@Test func statusWordCritical() {
    #expect(StatusRowCopy.statusWord(state: .critical) == "Almost empty")
}

@Test func statusWordEmpty() {
    #expect(StatusRowCopy.statusWord(state: .empty) == "Empty")
}

@Test func resetHintRelativeUnderTwentyFourHours() {
    let now = ISO8601DateFormatter().date(from: "2026-05-05T09:44:00Z")!
    let resetAt = "2026-05-05T13:00:00Z"

    #expect(StatusRowCopy.resetHint(resetAt: resetAt, now: now) == "Resets in 3h 16m")
}

@Test func resetHintLessThanOneMinute() {
    let now = ISO8601DateFormatter().date(from: "2026-05-05T09:44:00Z")!
    let resetAt = "2026-05-05T09:44:30Z"

    #expect(StatusRowCopy.resetHint(resetAt: resetAt, now: now) == "Resets in <1m")
}

@Test func resetHintParsesFractionalSeconds() {
    let now = ISO8601DateFormatter().date(from: "2026-05-05T09:44:00Z")!
    let resetAt = "2026-05-05T13:00:00.000Z"

    #expect(StatusRowCopy.resetHint(resetAt: resetAt, now: now) == "Resets in 3h 16m")
}

@Test func resetHintAbsoluteOverTwentyFourHours() {
    let now = ISO8601DateFormatter().date(from: "2026-05-05T09:44:00Z")!
    let resetAt = "2026-05-06T19:00:00Z"
    let result = StatusRowCopy.resetHint(resetAt: resetAt, now: now)

    #expect(result?.hasPrefix("Resets ") == true)
    #expect(result?.contains(":") == true)
}

@Test func resetHintNilWhenResetAtNil() {
    let now = ISO8601DateFormatter().date(from: "2026-05-05T09:44:00Z")!

    #expect(StatusRowCopy.resetHint(resetAt: nil, now: now) == nil)
}
