import Foundation
import Testing
@testable import WhatTheTokenMac

@Test func decodesClaudeUsageResponseWithoutSensitiveFields() throws {
    let json = """
    {
      "five_hour": { "utilization": 42.5, "resets_at": "2026-05-04T15:00:00Z" },
      "seven_day": { "utilization": 15.2, "resets_at": "2026-05-11T10:00:00Z" },
      "seven_day_opus": { "utilization": 20.0, "resets_at": null },
      "seven_day_sonnet": { "utilization": 10.0, "resets_at": null },
      "extra_usage": {
        "is_enabled": true,
        "utilization": 30.0,
        "used_credits": 422.0,
        "monthly_limit": 1000.0
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(ClaudeUsageResponse.self, from: json)

    #expect(response.fiveHour?.utilization == 42.5)
    #expect(response.sevenDay?.utilization == 15.2)
    #expect(response.extraUsage?.usedCredits == 422.0)
}

@Test func decodesClaudeModelWindowsWithoutACompiledKeyList() throws {
    let json = """
    {
      "five_hour": { "utilization": 35.0, "resets_at": "2026-07-18T10:00:00Z" },
      "seven_day": { "utilization": 44.0, "resets_at": "2026-07-22T17:00:00Z" },
      "seven_day_fable": { "utilization": 57.0, "resets_at": "2026-07-22T17:00:00Z" },
      "seven_day_future_model": { "utilization": 12.0, "resets_at": null },
      "metadata": { "plan": "max" }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(ClaudeUsageResponse.self, from: json)

    #expect(response.windows.keys.sorted() == [
        "five_hour",
        "seven_day",
        "seven_day_fable",
        "seven_day_future_model"
    ])
    #expect(response.windows["seven_day_fable"]?.utilization == 57)
    #expect(response.malformedUsageKeys.isEmpty)
}

@Test func mapsFiveHourClaudeUsageToSanitizedSnapshot() throws {
    let response = ClaudeUsageResponse(
        fiveHour: ClaudeWindowUsage(utilization: 42.5, resetsAt: "2026-05-04T15:00:00Z"),
        sevenDay: nil,
        sevenDayOpus: nil,
        sevenDaySonnet: nil,
        extraUsage: nil
    )

    let source = ConnectorSource(
        connector: "mac_connector",
        state: .connected,
        label: "Mac connector",
        parserVersion: "claude-code-oauth-usage-v1",
        deviceId: "device_mac_01"
    )

    let snapshots = ClaudeUsageMapper.map(
        response,
        userAccountId: "local_user",
        deviceId: "device_mac_01",
        observedAt: "2026-05-04T10:00:00.000Z",
        source: source
    )

    #expect(snapshots.count == 1)
    #expect(snapshots[0].provider == "anthropic")
    #expect(snapshots[0].product == "claude_code")
    #expect(snapshots[0].poolKey == "anthropic_claude_subscription")
    #expect(snapshots[0].windowKey == "five_hour")
    #expect(snapshots[0].unit == "utilization")
    #expect(snapshots[0].used == 42.5)
    #expect(snapshots[0].limit == 100)
    #expect(snapshots[0].remaining == 57.5)
    #expect(snapshots[0].confidence == "verified")
    #expect(snapshots[0].source == source)
}

@Test func mapsClaudeModelWindowsToSeparateSanitizedSnapshots() throws {
    let response = ClaudeUsageResponse(
        fiveHour: nil,
        sevenDay: nil,
        sevenDayOpus: ClaudeWindowUsage(utilization: 80.0, resetsAt: "2026-05-11T10:00:00Z"),
        sevenDaySonnet: ClaudeWindowUsage(utilization: 35.0, resetsAt: "2026-05-11T10:00:00Z"),
        extraUsage: nil
    )

    let source = ConnectorSource(
        connector: "mac_connector",
        state: .connected,
        label: "Mac connector",
        parserVersion: "claude-code-oauth-usage-v1",
        deviceId: "device_mac_01"
    )

    let snapshots = ClaudeUsageMapper.map(
        response,
        userAccountId: "local_user",
        deviceId: "device_mac_01",
        observedAt: "2026-05-04T10:00:00.000Z",
        source: source
    )

    #expect(snapshots.map(\.windowKey) == ["seven_day_opus", "seven_day_sonnet"])
    #expect(snapshots[0].used == 80)
    #expect(snapshots[0].remaining == 20)
    #expect(snapshots[1].used == 35)
    #expect(snapshots[1].remaining == 65)
}

@Test func mapsFableAndFutureClaudeWindowsInStableOrder() {
    let response = ClaudeUsageResponse(
        windows: [
            "seven_day_zebra": ClaudeWindowUsage(utilization: 20, resetsAt: nil),
            "seven_day_fable": ClaudeWindowUsage(utilization: 57, resetsAt: "2026-07-22T17:00:00Z"),
            "seven_day": ClaudeWindowUsage(utilization: 44, resetsAt: "2026-07-22T17:00:00Z"),
            "five_hour": ClaudeWindowUsage(utilization: 35, resetsAt: "2026-07-18T10:00:00Z")
        ]
    )
    let source = ConnectorSource(
        connector: "mac_connector",
        state: .connected,
        label: "Mac connector",
        parserVersion: "claude-code-oauth-usage-v2",
        deviceId: "device_mac_01"
    )

    let snapshots = ClaudeUsageMapper.map(
        response,
        userAccountId: "local_user",
        deviceId: "device_mac_01",
        observedAt: "2026-07-18T08:00:00.000Z",
        source: source
    )

    #expect(snapshots.map(\.windowKey) == [
        "five_hour",
        "seven_day",
        "seven_day_fable",
        "seven_day_zebra"
    ])
    #expect(snapshots[2].remaining == 43)
}

@Test func mapsEnabledClaudeExtraUsageCreditsToSanitizedSnapshot() throws {
    let response = ClaudeUsageResponse(
        fiveHour: nil,
        sevenDay: nil,
        sevenDayOpus: nil,
        sevenDaySonnet: nil,
        extraUsage: ClaudeExtraUsage(
            isEnabled: true,
            utilization: 30.0,
            usedCredits: 422.0,
            monthlyLimit: 1000.0
        )
    )

    let source = ConnectorSource(
        connector: "mac_connector",
        state: .connected,
        label: "Mac connector",
        parserVersion: "claude-code-oauth-usage-v1",
        deviceId: "device_mac_01"
    )

    let snapshots = ClaudeUsageMapper.map(
        response,
        userAccountId: "local_user",
        deviceId: "device_mac_01",
        observedAt: "2026-05-04T10:00:00.000Z",
        source: source
    )

    let snapshot = try #require(snapshots.first)
    #expect(snapshot.poolKey == "anthropic_claude_extra_usage")
    #expect(snapshot.windowKey == "monthly_extra_usage")
    #expect(snapshot.unit == "credits")
    #expect(snapshot.used == 422)
    #expect(snapshot.limit == 1000)
    #expect(snapshot.remaining == 578)
    #expect(snapshot.utilization == 0.422)
    #expect(snapshot.source == source)
}
