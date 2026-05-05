import Foundation

enum CodexUsageMapper {
    static func map(
        _ response: CodexRateLimitsResponse,
        userAccountId: String,
        deviceId: String,
        observedAt: String,
        source: ConnectorSource
    ) -> [UsageSnapshot] {
        var snapshots = response.buckets.flatMap { bucket in
            map(
                bucket,
                userAccountId: userAccountId,
                deviceId: deviceId,
                observedAt: observedAt,
                source: source
            )
        }

        if let creditsSnapshot = makeCreditsSnapshot(
            response.rateLimits.credits,
            userAccountId: userAccountId,
            deviceId: deviceId,
            observedAt: observedAt,
            source: source
        ) {
            snapshots.append(creditsSnapshot)
        }

        return snapshots
    }

    private static func map(
        _ bucket: CodexRateLimitSnapshot,
        userAccountId: String,
        deviceId: String,
        observedAt: String,
        source: ConnectorSource
    ) -> [UsageSnapshot] {
        guard let rawLimitId = bucket.limitId,
              let limitId = sanitizedKey(rawLimitId) else {
            return []
        }

        var snapshots: [UsageSnapshot] = []

        if let primary = bucket.primary {
            snapshots.append(makeSnapshot(
                bucket: bucket,
                bucketKey: limitId,
                windowPrefix: "primary",
                window: primary,
                userAccountId: userAccountId,
                deviceId: deviceId,
                observedAt: observedAt,
                source: source
            ))
        }

        if let secondary = bucket.secondary {
            snapshots.append(makeSnapshot(
                bucket: bucket,
                bucketKey: limitId,
                windowPrefix: "secondary",
                window: secondary,
                userAccountId: userAccountId,
                deviceId: deviceId,
                observedAt: observedAt,
                source: source
            ))
        }

        return snapshots
    }

    private static func makeSnapshot(
        bucket: CodexRateLimitSnapshot,
        bucketKey: String,
        windowPrefix: String,
        window: CodexRateLimitWindow,
        userAccountId: String,
        deviceId: String,
        observedAt: String,
        source: ConnectorSource
    ) -> UsageSnapshot {
        let used = Double(window.usedPercent)
        let limit = 100.0
        let windowKey: String
        if let duration = window.windowDurationMins {
            windowKey = "\(windowPrefix)_rolling_\(duration)m"
        } else {
            windowKey = "\(windowPrefix)_window_unknown"
        }

        return UsageSnapshot(
            id: "snap_openai_codex_\(bucketKey)_\(windowKey)_\(deviceId)",
            userAccountId: userAccountId,
            provider: "openai",
            product: "codex",
            surface: "aggregate",
            poolKey: "openai_codex_\(bucketKey)",
            windowKey: windowKey,
            unit: "utilization",
            used: used,
            limit: limit,
            remaining: max(limit - used, 0),
            utilization: used / limit,
            resetAt: isoString(fromUnixSeconds: window.resetsAt),
            lastUpdatedAt: observedAt,
            confidence: "observed",
            undercountRisk: "possible",
            staleReason: nil,
            display: display(for: bucket, window: window),
            source: source
        )
    }

    private static func makeCreditsSnapshot(
        _ credits: CodexCreditsSnapshot?,
        userAccountId: String,
        deviceId: String,
        observedAt: String,
        source: ConnectorSource
    ) -> UsageSnapshot? {
        guard let credits else {
            return nil
        }

        guard !credits.unlimited,
              let rawBalance = credits.balance,
              let balance = Double(rawBalance),
              balance >= 0 else {
            return nil
        }

        return UsageSnapshot(
            id: "snap_openai_codex_credits_\(deviceId)",
            userAccountId: userAccountId,
            provider: "openai",
            product: "codex",
            surface: "aggregate",
            poolKey: "openai_codex_credits",
            windowKey: "credits_remaining",
            unit: "credits",
            used: nil,
            limit: nil,
            remaining: balance,
            utilization: nil,
            resetAt: nil,
            lastUpdatedAt: observedAt,
            confidence: "observed",
            undercountRisk: "possible",
            staleReason: nil,
            display: UsageSnapshotDisplay(poolLabel: "Codex", windowLabel: "Credits remaining"),
            source: source
        )
    }

    private static func display(for bucket: CodexRateLimitSnapshot, window: CodexRateLimitWindow) -> UsageSnapshotDisplay? {
        UsageSnapshotDisplay(
            poolLabel: normalizedLabel(bucket.limitName),
            windowLabel: windowLabel(durationMins: window.windowDurationMins)
        )
    }

    private static func normalizedLabel(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        return value
    }

    private static func windowLabel(durationMins: Int?) -> String? {
        switch durationMins {
        case 300:
            return "5 hour usage limit"
        case 10_080:
            return "Weekly usage limit"
        case let minutes? where minutes % 60 == 0:
            return "\(minutes / 60) hour usage limit"
        case let minutes?:
            return "\(minutes) minute usage limit"
        case nil:
            return nil
        }
    }

    private static func sanitizedKey(_ value: String) -> String? {
        let allowed = value.lowercased().map { character -> Character in
            if character.isLetter || character.isNumber || character == "_" || character == "-" {
                return character
            }
            return "_"
        }
        let key = String(allowed).trimmingCharacters(in: CharacterSet(charactersIn: "_-"))
        guard !key.isEmpty else {
            return nil
        }

        return "\(key)_\(stableHash(value))"
    }

    private static func stableHash(_ value: String) -> String {
        let hash = value.utf8.reduce(UInt32(2_166_136_261)) { partial, byte in
            (partial ^ UInt32(byte)) &* 16_777_619
        }
        return String(hash, radix: 16)
    }

    private static func isoString(fromUnixSeconds seconds: Int?) -> String? {
        guard let seconds else {
            return nil
        }

        return ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: TimeInterval(seconds)))
    }
}
