import Foundation
import Testing
@testable import WhatTheTokenMac

private let rowDisplayFixedNow = ISO8601DateFormatter().date(from: "2026-05-05T09:44:00Z")!

private func rowDisplaySnapshot(
    windowKey: String = "five_hour",
    poolKey: String = "anthropic_claude_subscription",
    unit: String = "utilization",
    used: Double? = 13,
    limit: Double? = 100,
    remaining: Double? = 87,
    utilization: Double? = 0.13,
    resetAt: String? = "2026-05-05T13:00:00Z",
    confidence: String = "verified",
    undercountRisk: String = "none",
    staleReason: String? = nil
) -> UsageSnapshot {
    UsageSnapshot(
        id: "s_\(windowKey)",
        userAccountId: "u",
        provider: "anthropic",
        product: "claude_code",
        surface: "cli",
        poolKey: poolKey,
        windowKey: windowKey,
        unit: unit,
        used: used,
        limit: limit,
        remaining: remaining,
        utilization: utilization,
        resetAt: resetAt,
        lastUpdatedAt: "2026-05-05T09:44:00.000Z",
        confidence: confidence,
        undercountRisk: undercountRisk,
        staleReason: staleReason,
        source: ConnectorSource(
            connector: "mac_connector",
            state: .connected,
            label: "Mac connector",
            parserVersion: "v1",
            deviceId: "d"
        )
    )
}

@Test func currentSessionRowAtThirteenPercentUsed() {
    let row = StatusRowDisplayModel(
        snapshot: rowDisplaySnapshot(),
        sectionDefault: nil,
        now: rowDisplayFixedNow
    )

    #expect(row.name == "Current session")
    #expect(row.resetHint == "Resets in 3h 16m")
    #expect(row.heroText == "87% remaining")
    #expect(row.echoText == "13% used")
    #expect(row.progressValue == 0.13)
    #expect(row.state == .healthy)
    #expect(row.statusWord == "Plenty left")
    #expect(row.heroTintsRed == false)
    #expect(row.showsBar == true)
    #expect(row.badges.isEmpty)
    #expect(row.staleReason == nil)
}

@Test func weeklyAllModelsAtSeventyThreePercentUsedIsLow() {
    let row = StatusRowDisplayModel(
        snapshot: rowDisplaySnapshot(
            windowKey: "seven_day",
            remaining: 27,
            utilization: 0.73,
            resetAt: "2026-05-07T19:00:00Z"
        ),
        sectionDefault: nil,
        now: rowDisplayFixedNow
    )

    #expect(row.name == "Weekly · all models")
    #expect(row.heroText == "27% remaining")
    #expect(row.echoText == "73% used")
    #expect(row.state == .low)
    #expect(row.heroTintsRed == false)
}

@Test func criticalUtilizationKeepsNumberHeroButTintsRed() {
    let row = StatusRowDisplayModel(
        snapshot: rowDisplaySnapshot(
            windowKey: "five_hour",
            remaining: 5,
            utilization: 0.95
        ),
        sectionDefault: nil,
        now: rowDisplayFixedNow
    )

    #expect(row.heroText == "5% remaining")
    #expect(row.state == .critical)
    #expect(row.statusWord == "Almost empty")
    #expect(row.heroTintsRed == true)
    #expect(row.showsBar == true)
}

@Test func extraUsageCreditsEmptyHidesBarAndShowsSentence() {
    let row = StatusRowDisplayModel(
        snapshot: rowDisplaySnapshot(
            windowKey: "monthly_extra_usage",
            poolKey: "anthropic_claude_extra_usage",
            unit: "credits",
            used: 0,
            limit: 0,
            remaining: 0,
            utilization: nil,
            resetAt: nil
        ),
        sectionDefault: nil,
        now: rowDisplayFixedNow
    )

    #expect(row.name == "Extra usage credits")
    #expect(row.heroText == "Out of credits")
    #expect(row.echoText == nil)
    #expect(row.state == .empty)
    #expect(row.heroTintsRed == true)
    #expect(row.showsBar == false)
    #expect(row.statusWord == "Empty")
}

@Test func badgeAddedWhenUndercountLikelyDivergesFromSection() {
    let sectionDefault = StatusSectionDefault(confidence: "verified", undercountRisk: "none")
    let row = StatusRowDisplayModel(
        snapshot: rowDisplaySnapshot(undercountRisk: "likely"),
        sectionDefault: sectionDefault,
        now: rowDisplayFixedNow
    )

    #expect(row.badges.contains(.undercountLikely))
}

@Test func badgeAddedWhenUndercountPossibleDivergesFromSection() {
    let sectionDefault = StatusSectionDefault(confidence: "verified", undercountRisk: "none")
    let row = StatusRowDisplayModel(
        snapshot: rowDisplaySnapshot(undercountRisk: "possible"),
        sectionDefault: sectionDefault,
        now: rowDisplayFixedNow
    )

    #expect(row.badges.contains(.undercountPossible))
}

@Test func badgeAddedWhenConfidenceDivergesFromSection() {
    let sectionDefault = StatusSectionDefault(confidence: "verified", undercountRisk: "none")
    let row = StatusRowDisplayModel(
        snapshot: rowDisplaySnapshot(confidence: "inferred"),
        sectionDefault: sectionDefault,
        now: rowDisplayFixedNow
    )

    #expect(row.badges.contains(.inferred))
}

@Test func noBadgeWhenSectionDefaultIsNil() {
    let row = StatusRowDisplayModel(
        snapshot: rowDisplaySnapshot(confidence: "inferred", undercountRisk: "likely"),
        sectionDefault: nil,
        now: rowDisplayFixedNow
    )

    #expect(row.badges.isEmpty)
}
