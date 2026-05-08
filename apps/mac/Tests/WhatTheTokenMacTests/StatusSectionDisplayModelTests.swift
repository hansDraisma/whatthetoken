import Foundation
import Testing
@testable import WhatTheTokenMac

private let sectionDisplayFixedNow = ISO8601DateFormatter().date(from: "2026-05-05T09:44:00Z")!

private let sectionMacConnector = ConnectorSource(
    connector: "mac_connector",
    state: .connected,
    label: "Mac connector",
    parserVersion: "v1",
    deviceId: "d"
)

private func sectionDisplaySnapshot(
    windowKey: String,
    provider: String = "anthropic",
    product: String = "claude_code",
    surface: String = "cli",
    poolKey: String = "anthropic_claude_subscription",
    unit: String = "utilization",
    remaining: Double?,
    utilization: Double? = nil,
    confidence: String = "verified",
    undercountRisk: String = "none",
    source: ConnectorSource = sectionMacConnector,
    lastUpdatedAt: String = "2026-05-05T09:44:00.000Z"
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
        used: nil,
        limit: 100,
        remaining: remaining,
        utilization: utilization,
        resetAt: nil,
        lastUpdatedAt: lastUpdatedAt,
        confidence: confidence,
        undercountRisk: undercountRisk,
        staleReason: nil,
        display: nil,
        source: source
    )
}

@Test func sectionWithUniformTrustHoistsLine() {
    let snapshots = [
        sectionDisplaySnapshot(windowKey: "five_hour", remaining: 87, utilization: 0.13),
        sectionDisplaySnapshot(windowKey: "seven_day", remaining: 27, utilization: 0.73),
        sectionDisplaySnapshot(windowKey: "seven_day_sonnet", remaining: 95, utilization: 0.05)
    ]

    let section = StatusSectionDisplayModel(snapshots: snapshots, now: sectionDisplayFixedNow)

    #expect(section.brandTitle == "Anthropic · Claude Code")
    #expect(section.trustLine == "Verified by Mac connector")
    #expect(section.rows.count == 3)
    #expect(section.compareLink?.title == "Compare in Claude →")
    #expect(section.compareLink?.url.absoluteString == "https://claude.ai/settings/usage")
}

@Test func codexSectionLinksToCodexUsageDashboard() {
    let snapshots = [
        sectionDisplaySnapshot(
            windowKey: "primary_rolling_300m",
            provider: "openai",
            product: "codex",
            surface: "aggregate",
            poolKey: "openai_codex_codex_abcd1234",
            remaining: 71,
            utilization: 0.29,
            confidence: "observed",
            undercountRisk: "possible"
        )
    ]

    let section = StatusSectionDisplayModel(snapshots: snapshots, now: sectionDisplayFixedNow)

    #expect(section.brandTitle == "Openai · Codex")
    #expect(section.compareLink?.title == "Open Codex usage →")
    #expect(section.compareLink?.url.absoluteString == "https://chatgpt.com/codex/settings/usage")
}

@Test func sectionTrustLineOmitsUpdatedTime() {
    let snapshots = [
        sectionDisplaySnapshot(
            windowKey: "five_hour",
            remaining: 87,
            utilization: 0.13,
            lastUpdatedAt: "2026-05-05T09:43:00.000Z"
        ),
        sectionDisplaySnapshot(
            windowKey: "seven_day",
            remaining: 27,
            utilization: 0.73,
            lastUpdatedAt: "2026-05-05T09:45:00Z"
        )
    ]

    let section = StatusSectionDisplayModel(snapshots: snapshots, now: sectionDisplayFixedNow)

    #expect(section.trustLine == "Verified by Mac connector")
    #expect(section.trustLine?.contains("Updated") == false)
}

@Test func sectionWithDivergentConfidenceOmitsTrustLineAndAddsBadge() {
    let snapshots = [
        sectionDisplaySnapshot(windowKey: "five_hour", remaining: 87, utilization: 0.13, confidence: "verified"),
        sectionDisplaySnapshot(windowKey: "seven_day", remaining: 27, utilization: 0.73, confidence: "inferred")
    ]

    let section = StatusSectionDisplayModel(snapshots: snapshots, now: sectionDisplayFixedNow)

    #expect(section.trustLine == nil)
    let weekly = section.rows.first { $0.name == "Weekly · all models" }
    #expect(weekly?.badges.contains(.inferred) == true)
}

@Test func verifiedRowInMostlyInferredSectionDoesNotGetInferredBadge() {
    let snapshots = [
        sectionDisplaySnapshot(windowKey: "five_hour", remaining: 87, utilization: 0.13, confidence: "inferred"),
        sectionDisplaySnapshot(windowKey: "seven_day", remaining: 27, utilization: 0.73, confidence: "inferred"),
        sectionDisplaySnapshot(windowKey: "seven_day_sonnet", remaining: 95, utilization: 0.05, confidence: "verified")
    ]

    let section = StatusSectionDisplayModel(snapshots: snapshots, now: sectionDisplayFixedNow)
    let sonnet = section.rows.first { $0.name == "Weekly · Sonnet" }

    #expect(sonnet?.badges.contains(.inferred) == false)
}

@Test func inferredRowsInMostlyInferredSectionKeepInferredBadge() {
    let snapshots = [
        sectionDisplaySnapshot(windowKey: "five_hour", remaining: 87, utilization: 0.13, confidence: "inferred"),
        sectionDisplaySnapshot(windowKey: "seven_day", remaining: 27, utilization: 0.73, confidence: "inferred"),
        sectionDisplaySnapshot(windowKey: "seven_day_sonnet", remaining: 95, utilization: 0.05, confidence: "verified")
    ]

    let section = StatusSectionDisplayModel(snapshots: snapshots, now: sectionDisplayFixedNow)
    let session = section.rows.first { $0.name == "Current session" }
    let weekly = section.rows.first { $0.name == "Weekly · all models" }

    #expect(session?.badges.contains(.inferred) == true)
    #expect(weekly?.badges.contains(.inferred) == true)
}

@Test func sectionWithOneLikelyRowAddsUndercountBadgeOnlyOnThatRow() {
    let snapshots = [
        sectionDisplaySnapshot(windowKey: "five_hour", remaining: 87, utilization: 0.13, undercountRisk: "none"),
        sectionDisplaySnapshot(windowKey: "seven_day", remaining: 27, utilization: 0.73, undercountRisk: "likely"),
        sectionDisplaySnapshot(windowKey: "seven_day_sonnet", remaining: 95, utilization: 0.05, undercountRisk: "none")
    ]

    let section = StatusSectionDisplayModel(snapshots: snapshots, now: sectionDisplayFixedNow)
    let weekly = section.rows.first { $0.name == "Weekly · all models" }
    let session = section.rows.first { $0.name == "Current session" }

    #expect(weekly?.badges.contains(.undercountLikely) == true)
    #expect(session?.badges.isEmpty == true)
}

@Test func sectionPassesCriticalProviderAvailabilityToFallbackCreditsRows() {
    let snapshots = [
        sectionDisplaySnapshot(
            windowKey: "five_hour",
            poolKey: "anthropic_claude_subscription",
            unit: "utilization",
            remaining: 0,
            utilization: 1.0
        ),
        sectionDisplaySnapshot(
            windowKey: "monthly_extra_usage",
            poolKey: "anthropic_claude_extra_usage",
            unit: "credits",
            remaining: 0,
            utilization: nil
        )
    ]

    let section = StatusSectionDisplayModel(snapshots: snapshots, now: sectionDisplayFixedNow)
    let credits = section.rows.first { $0.name == "Extra usage credits" }

    #expect(credits?.heroText == "No extra credits available")
    #expect(credits?.heroTintsRed == true)
    #expect(credits?.showsStatus == true)
    #expect(credits?.showsBar == true)
}

@Test func emptySnapshotsProducesNilTrustAndNoRows() {
    let section = StatusSectionDisplayModel(snapshots: [], now: sectionDisplayFixedNow)

    #expect(section.brandTitle == nil)
    #expect(section.trustLine == nil)
    #expect(section.rows.isEmpty)
}
