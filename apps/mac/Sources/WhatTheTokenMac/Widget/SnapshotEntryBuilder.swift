import Foundation

enum SnapshotEntryBuilder {
    static func entry(from cache: SnapshotCache, now: Date) -> WidgetEntry {
        let rows = WidgetProvider.allCases.map { row(for: $0, in: cache) }
        let isStale = WidgetProvider.allCases.contains { provider in
            isProviderStale(provider, in: cache, now: now)
        }
        let mostRecent = cache.updatedAtByProvider.values.max() ?? .distantPast
        return WidgetEntry(rows: rows, isStale: isStale, asOf: mostRecent)
    }

    static func placeholder() -> WidgetEntry {
        WidgetEntry(
            rows: WidgetProvider.allCases.map { WidgetRow(provider: $0, state: .notConnected) },
            isStale: true,
            asOf: .distantPast
        )
    }

    private static func row(for provider: WidgetProvider, in cache: SnapshotCache) -> WidgetRow {
        let snapshots = cache.snapshots.filter(provider.cacheID.snapshotPredicate)
        guard let mostConstraining = snapshots.compactMap(\.utilization).max() else {
            return WidgetRow(provider: provider, state: .notConnected)
        }
        let percentage = Int((mostConstraining * 100).rounded())
        return WidgetRow(provider: provider, state: .connected(percentage: percentage))
    }

    private static func isProviderStale(_ provider: WidgetProvider, in cache: SnapshotCache, now: Date) -> Bool {
        guard let updatedAt = cache.updatedAtByProvider[provider.cacheID.rawValue] else {
            return cache.updatedAtByProvider.isEmpty
        }
        let age = Duration.seconds(Int64(now.timeIntervalSince(updatedAt)))
        return StalenessThreshold.isStale(snapshotAge: age)
    }
}
