import Foundation

struct NotificationIntent: Equatable, Sendable {
    var id: String
    var provider: CachedProviderID
    var level: NotificationLevel
    var title: String
    var body: String
}

struct NotificationEvaluationResult: Equatable, Sendable {
    var intents: [NotificationIntent]
    var state: NotificationState
}

enum NotificationEvaluator {
    static func evaluate(
        snapshots: [UsageSnapshot],
        settings: AppSettings,
        state: NotificationState,
        now: Date,
        suppressDelivery: Bool,
        scopedTo scopedProvider: CachedProviderID? = nil
    ) -> NotificationEvaluationResult {
        guard settings.notifications.isEnabled else {
            return NotificationEvaluationResult(intents: [], state: state)
        }

        var nextState = state
        var intents: [NotificationIntent] = []

        for snapshot in snapshots {
            guard let provider = provider(for: snapshot) else { continue }
            if let scopedProvider, provider != scopedProvider { continue }
            guard isProviderEnabled(provider, settings: settings) else { continue }
            guard !isProviderPaused(provider, settings: settings) else { continue }
            guard settings.notifications.providerAlerts.isEnabled(for: provider) else { continue }
            guard snapshot.staleReason == nil else { continue }
            guard isIncludedQuota(snapshot) else { continue }
            guard let remainingRatio = remainingRatio(snapshot) else { continue }

            let level = levelFor(remainingRatio: remainingRatio, settings: settings)
            let key = NotificationDedupeKey(
                provider: provider,
                poolKey: normalizedPoolKey(snapshot, provider: provider),
                windowKey: normalizedWindowKey(snapshot.windowKey)
            )
            let storageKey = key.storageKey
            let previous = nextState.records[storageKey]
            let recovered = hasRecovered(
                previous: previous,
                remainingRatio: remainingRatio,
                settings: settings,
                now: now,
                windowKey: key.windowKey
            )
            let effectivePrevious = recovered ? nil : previous
            let shouldNotify = !recovered && shouldNotify(
                previous: effectivePrevious,
                level: level
            )

            nextState.records[storageKey] = NotificationRecord(
                key: key,
                lastNotifiedLevel: shouldNotify && !suppressDelivery ? level : effectivePrevious?.lastNotifiedLevel,
                lastNotifiedAt: shouldNotify && !suppressDelivery ? now : effectivePrevious?.lastNotifiedAt,
                lastObservedLevel: level,
                recoveredAt: recovered ? now : effectivePrevious?.recoveredAt
            )

            if shouldNotify && !suppressDelivery {
                intents.append(intent(provider: provider, level: level, snapshot: snapshot, key: key))
            }
        }

        return NotificationEvaluationResult(intents: intents, state: nextState)
    }

    private static func provider(for snapshot: UsageSnapshot) -> CachedProviderID? {
        if CachedProviderID.claude.snapshotPredicate(snapshot) { return .claude }
        if CachedProviderID.codex.snapshotPredicate(snapshot) { return .codex }
        return nil
    }

    private static func isProviderEnabled(_ provider: CachedProviderID, settings: AppSettings) -> Bool {
        switch provider {
        case .claude: return settings.connectors.claudeCode.isEnabled
        case .codex: return settings.connectors.codex.isEnabled
        }
    }

    private static func isProviderPaused(_ provider: CachedProviderID, settings: AppSettings) -> Bool {
        switch provider {
        case .claude: return settings.connectors.claudeCode.isPaused
        case .codex: return settings.connectors.codex.isPaused
        }
    }

    private static func isIncludedQuota(_ snapshot: UsageSnapshot) -> Bool {
        snapshot.unit == "utilization"
    }

    private static func remainingRatio(_ snapshot: UsageSnapshot) -> Double? {
        if let remaining = snapshot.remaining, let limit = snapshot.limit, limit > 0 {
            return remaining / limit
        }
        if let utilization = snapshot.utilization {
            return max(1 - utilization, 0)
        }
        return nil
    }

    private static func levelFor(remainingRatio: Double, settings: AppSettings) -> NotificationLevel {
        if remainingRatio < settings.notifications.criticalThreshold { return .critical }
        if remainingRatio < settings.notifications.warningThreshold { return .warning }
        return .healthy
    }

    private static func shouldNotify(previous: NotificationRecord?, level: NotificationLevel) -> Bool {
        guard level == .warning || level == .critical else { return false }
        if previous?.lastNotifiedLevel == level {
            return false
        }
        if previous?.lastNotifiedLevel == .warning && level == .critical {
            return true
        }
        return previous?.lastNotifiedLevel == nil
    }

    private static func hasRecovered(
        previous: NotificationRecord?,
        remainingRatio: Double,
        settings: AppSettings,
        now: Date,
        windowKey: String
    ) -> Bool {
        guard let previousLevel = previous?.lastNotifiedLevel else { return false }
        let recoveryMargin = 0.05
        let recovered: Bool
        switch previousLevel {
        case .critical:
            recovered = remainingRatio >= settings.notifications.criticalThreshold + recoveryMargin
        case .warning:
            recovered = remainingRatio >= settings.notifications.warningThreshold + recoveryMargin
        case .healthy:
            recovered = false
        }
        guard recovered else { return false }
        guard isRollingWindow(windowKey), let lastNotifiedAt = previous?.lastNotifiedAt else {
            return true
        }
        return now.timeIntervalSince(lastNotifiedAt) >= 3_600
    }

    private static func normalizedPoolKey(_ snapshot: UsageSnapshot, provider: CachedProviderID) -> String {
        switch provider {
        case .claude:
            if isIncludedQuota(snapshot) { return "anthropic_claude_subscription" }
        case .codex:
            if isIncludedQuota(snapshot) { return "openai_codex_included" }
        }
        return snapshot.poolKey
    }

    private static func normalizedWindowKey(_ windowKey: String) -> String {
        if windowKey == "five_hour" || windowKey.contains("300m") {
            return "rolling_5h"
        }
        if windowKey.contains("10080m") || windowKey.contains("seven_day") {
            return "rolling_7d"
        }
        return windowKey
    }

    private static func isRollingWindow(_ windowKey: String) -> Bool {
        windowKey.hasPrefix("rolling_")
    }

    private static func intent(
        provider: CachedProviderID,
        level: NotificationLevel,
        snapshot: UsageSnapshot,
        key: NotificationDedupeKey
    ) -> NotificationIntent {
        let percent = level == .critical ? "10%" : "20%"
        let title = "\(provider.displayName) is below \(percent) remaining"
        let provenance: String = snapshot.confidence == "verified"
            ? "Verified from local \(provider.displayName) usage status."
            : "Based on observed local \(provider.displayName) status."
        return NotificationIntent(
            id: "\(key.storageKey)|\(level.rawValue)",
            provider: provider,
            level: level,
            title: title,
            body: "\(title). \(provenance)"
        )
    }
}
