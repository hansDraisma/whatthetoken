import Foundation

enum ClaudeUsageMapper {
    static func map(
        _ response: ClaudeUsageResponse,
        userAccountId: String,
        deviceId: String,
        observedAt: String,
        source: ConnectorSource
    ) -> [UsageSnapshot] {
        var snapshots = response.windows
            .sorted { windowOrder($0.key) < windowOrder($1.key) }
            .map { windowKey, usage in
                makeUtilizationSnapshot(
                    id: "snap_anthropic_claude_code_\(windowKey)_\(deviceId)",
                    windowKey: windowKey,
                    usage: usage,
                    userAccountId: userAccountId,
                    observedAt: observedAt,
                    source: source
                )
            }

        if let extraUsage = response.extraUsage,
           let extraUsageSnapshot = makeExtraUsageSnapshot(
            extraUsage,
            deviceId: deviceId,
            userAccountId: userAccountId,
            observedAt: observedAt,
            source: source
           ) {
            snapshots.append(extraUsageSnapshot)
        }

        return snapshots
    }

    private static func windowOrder(_ key: String) -> String {
        switch key {
        case "five_hour":
            return "0"
        case "seven_day":
            return "1"
        default:
            return "2_\(key)"
        }
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
            display: nil,
            source: source
        )
    }

    private static func makeExtraUsageSnapshot(
        _ usage: ClaudeExtraUsage,
        deviceId: String,
        userAccountId: String,
        observedAt: String,
        source: ConnectorSource
    ) -> UsageSnapshot? {
        guard usage.isEnabled,
              let used = usage.usedCredits,
              let limit = usage.monthlyLimit,
              limit > 0 else {
            return nil
        }

        let remaining = max(limit - used, 0)

        return UsageSnapshot(
            id: "snap_anthropic_claude_code_extra_usage_\(deviceId)",
            userAccountId: userAccountId,
            provider: "anthropic",
            product: "claude_code",
            surface: "cli",
            poolKey: "anthropic_claude_extra_usage",
            windowKey: "monthly_extra_usage",
            unit: "credits",
            used: used,
            limit: limit,
            remaining: remaining,
            utilization: used / limit,
            resetAt: nil,
            lastUpdatedAt: observedAt,
            confidence: "verified",
            undercountRisk: "possible",
            staleReason: nil,
            display: nil,
            source: source
        )
    }
}
