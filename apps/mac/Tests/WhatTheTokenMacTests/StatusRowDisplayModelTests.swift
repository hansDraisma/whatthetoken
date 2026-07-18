import Foundation
import Testing
@testable import WhatTheTokenMac

private let rowDisplayFixedNow = ISO8601DateFormatter().date(from: "2026-05-05T09:44:00Z")!

private func rowDisplaySnapshot(
    provider: String = "anthropic",
    product: String = "claude_code",
    surface: String = "cli",
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
    staleReason: String? = nil,
    display: UsageSnapshotDisplay? = nil
) -> UsageSnapshot {
    UsageSnapshot(
        id: "s_\(windowKey)",
        userAccountId: "u",
        provider: provider,
        product: product,
        surface: surface,
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
        display: display,
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

@Test func claudeModelWindowUsesDynamicWeeklyLabel() {
    let fable = StatusRowDisplayModel(
        snapshot: rowDisplaySnapshot(windowKey: "seven_day_fable"),
        sectionDefault: nil,
        now: rowDisplayFixedNow
    )
    let futureModel = StatusRowDisplayModel(
        snapshot: rowDisplaySnapshot(windowKey: "weekly_future_model"),
        sectionDefault: nil,
        now: rowDisplayFixedNow
    )

    #expect(fable.name == "Weekly · Fable")
    #expect(futureModel.name == "Weekly · Future Model")
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

@Test func extraUsageCreditsEmptyUsesNeutralCopyWhenProviderIsAvailable() {
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
    #expect(row.heroText == "No extra credits available")
    #expect(row.echoText == nil)
    #expect(row.state == .empty)
    #expect(row.heroTintsRed == false)
    #expect(row.showsBar == false)
    #expect(row.showsStatus == false)
    #expect(row.statusWord == "Empty")
}

@Test func codexRowsUseDisplayLabelsFromConnectorMetadata() {
    let aggregatePrimary = StatusRowDisplayModel(
        snapshot: rowDisplaySnapshot(
            provider: "openai",
            product: "codex",
            surface: "aggregate",
            windowKey: "primary_rolling_300m",
            poolKey: "openai_codex_codex_d4cde064",
            display: UsageSnapshotDisplay(poolLabel: nil, windowLabel: "5 hour usage limit")
        ),
        sectionDefault: nil,
        now: rowDisplayFixedNow
    )
    let aggregateWeekly = StatusRowDisplayModel(
        snapshot: rowDisplaySnapshot(
            provider: "openai",
            product: "codex",
            surface: "aggregate",
            windowKey: "secondary_rolling_10080m",
            poolKey: "openai_codex_codex_d4cde064",
            display: UsageSnapshotDisplay(poolLabel: nil, windowLabel: "Weekly usage limit")
        ),
        sectionDefault: nil,
        now: rowDisplayFixedNow
    )
    let modelPrimary = StatusRowDisplayModel(
        snapshot: rowDisplaySnapshot(
            provider: "openai",
            product: "codex",
            surface: "aggregate",
            windowKey: "primary_rolling_300m",
            poolKey: "openai_codex_codex_bengalfox_316417ff",
            display: UsageSnapshotDisplay(poolLabel: "GPT-5.3-Codex-Spark", windowLabel: "5 hour usage limit")
        ),
        sectionDefault: nil,
        now: rowDisplayFixedNow
    )
    let modelWeekly = StatusRowDisplayModel(
        snapshot: rowDisplaySnapshot(
            provider: "openai",
            product: "codex",
            surface: "aggregate",
            windowKey: "secondary_rolling_10080m",
            poolKey: "openai_codex_codex_bengalfox_316417ff",
            display: UsageSnapshotDisplay(poolLabel: "GPT-5.3-Codex-Spark", windowLabel: "Weekly usage limit")
        ),
        sectionDefault: nil,
        now: rowDisplayFixedNow
    )

    #expect(aggregatePrimary.name == "5 hour usage limit")
    #expect(aggregateWeekly.name == "Weekly usage limit")
    #expect(modelPrimary.name == "GPT-5.3-Codex-Spark 5 hour usage limit")
    #expect(modelWeekly.name == "GPT-5.3-Codex-Spark Weekly usage limit")
}

@Test func codexCreditsDisplayAsDashboardBalanceRow() {
    let row = StatusRowDisplayModel(
        snapshot: rowDisplaySnapshot(
            provider: "openai",
            product: "codex",
            surface: "aggregate",
            windowKey: "credits_remaining",
            poolKey: "openai_codex_credits",
            unit: "credits",
            used: nil,
            limit: nil,
            remaining: 0,
            utilization: nil,
            resetAt: nil,
            confidence: "observed",
            undercountRisk: "possible",
            display: UsageSnapshotDisplay(poolLabel: "Codex", windowLabel: "Credits remaining")
        ),
        sectionDefault: nil,
        now: rowDisplayFixedNow
    )

    #expect(row.name == "Credits remaining")
    #expect(row.heroText == "No extra credits available")
    #expect(row.echoText == nil)
    #expect(row.showsBar == false)
    #expect(row.heroTintsRed == false)
    #expect(row.showsStatus == false)
}

@Test func emptyFallbackCredits_doNotTintRed_whenProviderIsAvailable() {
    let row = StatusRowDisplayModel(
        snapshot: rowDisplaySnapshot(
            windowKey: "monthly_extra_usage",
            poolKey: "anthropic_claude_extra_usage",
            unit: "credits",
            used: 100,
            limit: 100,
            remaining: 0,
            utilization: nil,
            resetAt: nil
        ),
        sectionDefault: nil,
        now: rowDisplayFixedNow,
        providerAvailability: .available
    )

    #expect(row.heroText == "No extra credits available")
    #expect(row.heroTintsRed == false)
    #expect(row.showsStatus == false)
    #expect(row.showsBar == false)
}

@Test func emptyFallbackCredits_doNotTintRed_whenProviderIsFallbackOnly() {
    let row = StatusRowDisplayModel(
        snapshot: rowDisplaySnapshot(
            windowKey: "monthly_extra_usage",
            poolKey: "anthropic_claude_extra_usage",
            unit: "credits",
            used: 100,
            limit: 100,
            remaining: 0,
            utilization: nil,
            resetAt: nil
        ),
        sectionDefault: nil,
        now: rowDisplayFixedNow,
        providerAvailability: .fallbackOnly
    )

    #expect(row.heroText == "No extra credits available")
    #expect(row.heroTintsRed == false)
    #expect(row.showsStatus == false)
    #expect(row.showsBar == false)
}

@Test func emptyFallbackCredits_tintRed_whenProviderIsCritical() {
    let row = StatusRowDisplayModel(
        snapshot: rowDisplaySnapshot(
            windowKey: "monthly_extra_usage",
            poolKey: "anthropic_claude_extra_usage",
            unit: "credits",
            used: 100,
            limit: 100,
            remaining: 0,
            utilization: nil,
            resetAt: nil
        ),
        sectionDefault: nil,
        now: rowDisplayFixedNow,
        providerAvailability: .critical
    )

    #expect(row.heroText == "No extra credits available")
    #expect(row.heroTintsRed == true)
    #expect(row.showsStatus == true)
    #expect(row.showsBar == true)
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
