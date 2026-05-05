import Foundation
import Testing
@testable import WhatTheTokenMac

@Test func mapsPrimaryWindowToUtilizationSnapshot() throws {
    let response = CodexRateLimitsResponse(
        rateLimits: CodexRateLimitSnapshot(
            credits: nil,
            limitId: "codex",
            limitName: nil,
            planType: "plus",
            primary: CodexRateLimitWindow(resetsAt: 1730947200, usedPercent: 25, windowDurationMins: 15),
            rateLimitReachedType: nil,
            secondary: nil
        ),
        rateLimitsByLimitId: nil
    )
    let source = ConnectorSource(
        connector: "mac_connector",
        state: .connected,
        label: "Mac connector",
        parserVersion: "codex-app-server-rate-limits-v1",
        deviceId: "device_mac_01"
    )

    let snapshots = CodexUsageMapper.map(
        response,
        userAccountId: "local_user",
        deviceId: "device_mac_01",
        observedAt: "2026-05-05T10:00:00.000Z",
        source: source
    )

    let snapshot = try #require(snapshots.first)
    #expect(snapshot.provider == "openai")
    #expect(snapshot.product == "codex")
    #expect(snapshot.surface == "aggregate")
    #expect(snapshot.poolKey == "openai_codex_codex_d4cde064")
    #expect(snapshot.windowKey == "primary_rolling_15m")
    #expect(snapshot.unit == "utilization")
    #expect(snapshot.used == 25)
    #expect(snapshot.limit == 100)
    #expect(snapshot.remaining == 75)
    #expect(snapshot.utilization == 0.25)
    #expect(snapshot.resetAt == "2024-11-07T02:40:00Z")
    #expect(snapshot.confidence == "observed")
    #expect(snapshot.undercountRisk == "possible")
}

@Test func mapsPrimaryAndSecondaryWindowsSeparately() throws {
    let response = CodexRateLimitsResponse(
        rateLimits: CodexRateLimitSnapshot(
            credits: nil,
            limitId: "codex_other",
            limitName: "codex_other",
            planType: "business",
            primary: CodexRateLimitWindow(resetsAt: nil, usedPercent: 42, windowDurationMins: 60),
            rateLimitReachedType: nil,
            secondary: CodexRateLimitWindow(resetsAt: nil, usedPercent: 10, windowDurationMins: 1440)
        ),
        rateLimitsByLimitId: nil
    )
    let source = ConnectorSource(
        connector: "mac_connector",
        state: .connected,
        label: "Mac connector",
        parserVersion: "codex-app-server-rate-limits-v1",
        deviceId: "device_mac_01"
    )

    let snapshots = CodexUsageMapper.map(
        response,
        userAccountId: "local_user",
        deviceId: "device_mac_01",
        observedAt: "2026-05-05T10:00:00.000Z",
        source: source
    )

    #expect(snapshots.map(\.windowKey) == ["primary_rolling_60m", "secondary_rolling_1440m"])
}

@Test func mapsCodexBucketLabelsFromLimitNameAndWindowDuration() throws {
    let response = CodexRateLimitsResponse(
        rateLimits: CodexRateLimitSnapshot(
            credits: nil,
            limitId: "codex",
            limitName: nil,
            planType: "prolite",
            primary: CodexRateLimitWindow(resetsAt: nil, usedPercent: 1, windowDurationMins: 300),
            rateLimitReachedType: nil,
            secondary: CodexRateLimitWindow(resetsAt: nil, usedPercent: 6, windowDurationMins: 10_080)
        ),
        rateLimitsByLimitId: [
            "codex": CodexRateLimitSnapshot(
                credits: nil,
                limitId: "codex",
                limitName: nil,
                planType: "prolite",
                primary: CodexRateLimitWindow(resetsAt: nil, usedPercent: 1, windowDurationMins: 300),
                rateLimitReachedType: nil,
                secondary: CodexRateLimitWindow(resetsAt: nil, usedPercent: 6, windowDurationMins: 10_080)
            ),
            "codex_bengalfox": CodexRateLimitSnapshot(
                credits: nil,
                limitId: "codex_bengalfox",
                limitName: "GPT-5.3-Codex-Spark",
                planType: "prolite",
                primary: CodexRateLimitWindow(resetsAt: nil, usedPercent: 0, windowDurationMins: 300),
                rateLimitReachedType: nil,
                secondary: CodexRateLimitWindow(resetsAt: nil, usedPercent: 0, windowDurationMins: 10_080)
            )
        ]
    )

    let snapshots = CodexUsageMapper.map(
        response,
        userAccountId: "local_user",
        deviceId: "device_mac_01",
        observedAt: "2026-05-05T10:00:00.000Z",
        source: codexMapperSource
    )

    let aggregatePrimary = try #require(snapshots.first {
        $0.poolKey.hasPrefix("openai_codex_codex_") && $0.windowKey == "primary_rolling_300m"
    })
    let aggregateSecondary = try #require(snapshots.first {
        $0.poolKey.hasPrefix("openai_codex_codex_") && $0.windowKey == "secondary_rolling_10080m"
    })
    let modelPrimary = try #require(snapshots.first {
        $0.poolKey.hasPrefix("openai_codex_codex_bengalfox_") && $0.windowKey == "primary_rolling_300m"
    })
    let modelSecondary = try #require(snapshots.first {
        $0.poolKey.hasPrefix("openai_codex_codex_bengalfox_") && $0.windowKey == "secondary_rolling_10080m"
    })

    #expect(aggregatePrimary.display?.poolLabel == nil)
    #expect(aggregatePrimary.display?.windowLabel == "5 hour usage limit")
    #expect(aggregateSecondary.display?.windowLabel == "Weekly usage limit")
    #expect(modelPrimary.display?.poolLabel == "GPT-5.3-Codex-Spark")
    #expect(modelPrimary.display?.windowLabel == "5 hour usage limit")
    #expect(modelSecondary.display?.poolLabel == "GPT-5.3-Codex-Spark")
    #expect(modelSecondary.display?.windowLabel == "Weekly usage limit")
}

@Test func mapsCodexCreditsRemainingFromAggregateBucket() throws {
    let response = CodexRateLimitsResponse(
        rateLimits: CodexRateLimitSnapshot(
            credits: CodexCreditsSnapshot(balance: "0", hasCredits: false, unlimited: false),
            limitId: "codex",
            limitName: nil,
            planType: "prolite",
            primary: CodexRateLimitWindow(resetsAt: nil, usedPercent: 1, windowDurationMins: 300),
            rateLimitReachedType: nil,
            secondary: nil
        ),
        rateLimitsByLimitId: nil
    )

    let snapshots = CodexUsageMapper.map(
        response,
        userAccountId: "local_user",
        deviceId: "device_mac_01",
        observedAt: "2026-05-05T10:00:00.000Z",
        source: codexMapperSource
    )

    let creditsSnapshot = try #require(snapshots.first { $0.windowKey == "credits_remaining" })
    #expect(creditsSnapshot.poolKey == "openai_codex_credits")
    #expect(creditsSnapshot.unit == "credits")
    #expect(creditsSnapshot.used == nil)
    #expect(creditsSnapshot.limit == nil)
    #expect(creditsSnapshot.remaining == 0)
    #expect(creditsSnapshot.utilization == nil)
    #expect(creditsSnapshot.display?.poolLabel == "Codex")
    #expect(creditsSnapshot.display?.windowLabel == "Credits remaining")
}

@Test func ignoresCodexCreditsWhenBalanceCannotBeDisplayed() {
    let response = CodexRateLimitsResponse(
        rateLimits: CodexRateLimitSnapshot(
            credits: CodexCreditsSnapshot(balance: "unlimited", hasCredits: true, unlimited: false),
            limitId: "codex",
            limitName: nil,
            planType: "prolite",
            primary: CodexRateLimitWindow(resetsAt: nil, usedPercent: 1, windowDurationMins: 300),
            rateLimitReachedType: nil,
            secondary: nil
        ),
        rateLimitsByLimitId: nil
    )

    let snapshots = CodexUsageMapper.map(
        response,
        userAccountId: "local_user",
        deviceId: "device_mac_01",
        observedAt: "2026-05-05T10:00:00.000Z",
        source: codexMapperSource
    )

    #expect(!snapshots.contains { $0.windowKey == "credits_remaining" })
}

@Test func ignoresBucketWithoutLimitIdOrWindows() {
    let response = CodexRateLimitsResponse(
        rateLimits: CodexRateLimitSnapshot(
            credits: nil,
            limitId: nil,
            limitName: nil,
            planType: nil,
            primary: nil,
            rateLimitReachedType: nil,
            secondary: nil
        ),
        rateLimitsByLimitId: nil
    )
    let source = ConnectorSource(
        connector: "mac_connector",
        state: .connected,
        label: "Mac connector",
        parserVersion: "codex-app-server-rate-limits-v1",
        deviceId: "device_mac_01"
    )

    let snapshots = CodexUsageMapper.map(
        response,
        userAccountId: "local_user",
        deviceId: "device_mac_01",
        observedAt: "2026-05-05T10:00:00.000Z",
        source: source
    )

    #expect(snapshots.isEmpty)
}

@Test func sanitizedLimitIdsIncludeStableHashToAvoidCollisions() throws {
    let response = CodexRateLimitsResponse(
        rateLimits: CodexRateLimitSnapshot(
            credits: nil,
            limitId: "codex.other",
            limitName: nil,
            planType: nil,
            primary: CodexRateLimitWindow(resetsAt: nil, usedPercent: 1, windowDurationMins: 15),
            rateLimitReachedType: nil,
            secondary: nil
        ),
        rateLimitsByLimitId: [
            "codex/other": CodexRateLimitSnapshot(
                credits: nil,
                limitId: "codex/other",
                limitName: nil,
                planType: nil,
                primary: CodexRateLimitWindow(resetsAt: nil, usedPercent: 2, windowDurationMins: 15),
                rateLimitReachedType: nil,
                secondary: nil
            ),
            "codex.other": CodexRateLimitSnapshot(
                credits: nil,
                limitId: "codex.other",
                limitName: nil,
                planType: nil,
                primary: CodexRateLimitWindow(resetsAt: nil, usedPercent: 1, windowDurationMins: 15),
                rateLimitReachedType: nil,
                secondary: nil
            )
        ]
    )
    let source = ConnectorSource(
        connector: "mac_connector",
        state: .connected,
        label: "Mac connector",
        parserVersion: "codex-app-server-rate-limits-v1",
        deviceId: "device_mac_01"
    )

    let snapshots = CodexUsageMapper.map(
        response,
        userAccountId: "local_user",
        deviceId: "device_mac_01",
        observedAt: "2026-05-05T10:00:00.000Z",
        source: source
    )

    #expect(Set(snapshots.map(\.poolKey)).count == 2)
}

private let codexMapperSource = ConnectorSource(
    connector: "mac_connector",
    state: .connected,
    label: "Mac connector",
    parserVersion: "codex-app-server-rate-limits-v1",
    deviceId: "device_mac_01"
)
