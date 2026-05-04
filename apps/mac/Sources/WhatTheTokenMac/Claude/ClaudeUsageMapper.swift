import Foundation

enum ClaudeUsageMapper {
    static func map(
        _ response: ClaudeUsageResponse,
        userAccountId: String,
        deviceId: String,
        observedAt: String,
        source: ConnectorSource
    ) -> [UsageSnapshot] {
        var snapshots: [UsageSnapshot] = []

        if let fiveHour = response.fiveHour {
            snapshots.append(makeUtilizationSnapshot(
                id: "snap_anthropic_claude_code_five_hour_\(deviceId)",
                windowKey: "five_hour",
                usage: fiveHour,
                userAccountId: userAccountId,
                observedAt: observedAt,
                source: source
            ))
        }

        if let sevenDay = response.sevenDay {
            snapshots.append(makeUtilizationSnapshot(
                id: "snap_anthropic_claude_code_seven_day_\(deviceId)",
                windowKey: "seven_day",
                usage: sevenDay,
                userAccountId: userAccountId,
                observedAt: observedAt,
                source: source
            ))
        }

        return snapshots
    }

    private static func makeUtilizationSnapshot(
        id: String,
        windowKey: String,
        usage: ClaudeWindowUsage,
        userAccountId: String,
        observedAt: String,
        source: ConnectorSource
    ) -> UsageSnapshot {
        let used = usage.utilization
        let limit = 100.0
        let remaining = max(limit - used, 0)

        return UsageSnapshot(
            id: id,
            userAccountId: userAccountId,
            provider: "anthropic",
            product: "claude_code",
            surface: "cli",
            poolKey: "anthropic_claude_subscription",
            windowKey: windowKey,
            unit: "utilization",
            used: used,
            limit: limit,
            remaining: remaining,
            utilization: used / limit,
            resetAt: usage.resetsAt,
            lastUpdatedAt: observedAt,
            confidence: "verified",
            undercountRisk: "possible",
            staleReason: nil,
            source: source
        )
    }
}
