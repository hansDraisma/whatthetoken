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
