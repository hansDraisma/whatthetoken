import Foundation

enum SnapshotEntryBuilder {
    static func entry(from cache: SnapshotCache, now: Date) -> WidgetEntry {
        let rows = WidgetProvider.allCases.map { row(for: $0, in: cache) }
        let allNotConnected = rows.allSatisfy { $0.state == .notConnected }
        let isStale = allNotConnected
            ? false
            : WidgetProvider.allCases.contains { provider in
                isProviderStale(provider, in: cache, now: now)
            }
        let mostRecent = cache.updatedAtByProvider.values.max() ?? .distantPast
        return WidgetEntry(rows: rows, isStale: isStale, asOf: mostRecent)
    }

    static func placeholder() -> WidgetEntry {
        WidgetEntry(
            rows: WidgetProvider.allCases.map { WidgetRow(provider: $0, state: .notConnected) },
            isStale: false,
            asOf: .distantPast
        )
    }

    private static func row(for provider: WidgetProvider, in cache: SnapshotCache) -> WidgetRow {
        let snapshots = cache.snapshots
            .filter(provider.cacheID.snapshotPredicate)
            .filter { isIncludedQuota($0, provider: provider) }
        guard let lowestRemaining = snapshots.compactMap(remainingPercentage).min() else {
            return WidgetRow(provider: provider, state: .notConnected)
        }
        return WidgetRow(provider: provider, state: .connected(percentage: lowestRemaining))
    }

    private static func isProviderStale(_ provider: WidgetProvider, in cache: SnapshotCache, now: Date) -> Bool {
        if cache.lastErrorByProvider[provider.cacheID.rawValue] != nil {
            return true
        }
        guard let updatedAt = cache.updatedAtByProvider[provider.cacheID.rawValue] else {
            return cache.updatedAtByProvider.isEmpty
        }
        let age = Duration.seconds(Int64(now.timeIntervalSince(updatedAt)))
        return StalenessThreshold.isStale(snapshotAge: age)
    }

    private static func isIncludedQuota(_ snapshot: UsageSnapshot, provider: WidgetProvider) -> Bool {
        guard snapshot.unit == "utilization" else { return false }
        switch provider {
        case .claude:
            return snapshot.poolKey == "anthropic_claude_subscription"
        case .codex:
            return snapshot.poolKey != "openai_codex_credits"
        }
    }

    private static func remainingPercentage(snapshot: UsageSnapshot) -> Int? {
        if let remaining = snapshot.remaining,
           let limit = snapshot.limit,
           limit > 0 {
            return percent(for: remaining / limit)
        }
        if let remaining = snapshot.remaining {
            return percent(for: remaining / 100)
        }
        if let utilization = snapshot.utilization {
            return percent(for: 1 - utilization)
        }
        return nil
    }

    static func percent(for fraction: Double) -> Int {
        min(max(Int((fraction * 100).rounded()), 0), 100)
    }
}
