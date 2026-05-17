import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct SnapshotEntryBuilderTests {
    @Test func buildsEntryFromConnectedClaudeOnlySnapshot() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = SnapshotCache(
            schemaVersion: 1,
            snapshots: [
                usageSnapshot(provider: "anthropic", product: "claude_code", utilization: 0.47),
                usageSnapshot(provider: "anthropic", product: "claude_code", poolKey: "7d", utilization: 0.20)
            ],
            updatedAtByProvider: [CachedProviderID.claude.rawValue: now.addingTimeInterval(-60)],
            lastSuccessfulRefreshAtByProvider: [:],
            lastErrorByProvider: [:]
        )

        let entry = SnapshotEntryBuilder.entry(from: cache, now: now)

        #expect(entry.rows.count == 2)
        #expect(entry.rows[0].provider == .claude)
        #expect(entry.rows[0].state == .connected(percentage: 47))
        #expect(entry.rows[1].provider == .codex)
        #expect(entry.rows[1].state == .notConnected)
        #expect(entry.isStale == false)
    }

    @Test func picksMostConstrainingPoolPerProvider() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = SnapshotCache(
            schemaVersion: 1,
            snapshots: [
                usageSnapshot(provider: "anthropic", product: "claude_code", poolKey: "5h", utilization: 0.30),
                usageSnapshot(provider: "anthropic", product: "claude_code", poolKey: "7d", utilization: 0.85)
            ],
            updatedAtByProvider: [CachedProviderID.claude.rawValue: now],
            lastSuccessfulRefreshAtByProvider: [:],
            lastErrorByProvider: [:]
        )

        let entry = SnapshotEntryBuilder.entry(from: cache, now: now)

        // 7d at 85% is more constraining than 5h at 30%.
        #expect(entry.rows[0].state == .connected(percentage: 85))
    }

    @Test func marksEntryStaleWhenProviderAgeExceedsThreshold() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = SnapshotCache(
            schemaVersion: 1,
            snapshots: [usageSnapshot(provider: "anthropic", product: "claude_code", utilization: 0.10)],
            updatedAtByProvider: [CachedProviderID.claude.rawValue: now.addingTimeInterval(-20 * 60)],
            lastSuccessfulRefreshAtByProvider: [:],
            lastErrorByProvider: [:]
        )

        let entry = SnapshotEntryBuilder.entry(from: cache, now: now)
        #expect(entry.isStale == true)
    }

    @Test func returnsPlaceholderEntryWhenCacheIsEmpty() {
        let entry = SnapshotEntryBuilder.placeholder()

        #expect(entry.rows.count == 2)
        #expect(entry.rows.allSatisfy { $0.state == .notConnected })
        #expect(entry.isStale == true)
    }

    @Test func emptyCacheReturnsNotConnectedForBothProviders() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = SnapshotEntryBuilder.entry(from: SnapshotCache.empty, now: now)

        #expect(entry.rows.allSatisfy { $0.state == .notConnected })
        #expect(entry.isStale == true)
    }

    private func usageSnapshot(
        provider: String,
        product: String,
        poolKey: String = "5h",
        utilization: Double
    ) -> UsageSnapshot {
        UsageSnapshot(
            id: "\(provider)-\(product)-\(poolKey)",
            userAccountId: "u",
            provider: provider,
            product: product,
            surface: "test",
            poolKey: poolKey,
            windowKey: poolKey,
            unit: "messages",
            used: nil,
            limit: nil,
            remaining: nil,
            utilization: utilization,
            resetAt: nil,
            lastUpdatedAt: "2026-05-09T00:00:00Z",
            confidence: "verified",
            undercountRisk: "none",
            staleReason: nil,
            display: nil,
            source: ConnectorSource(
                connector: "test",
                state: .connected,
                label: "test",
                parserVersion: "1",
                deviceId: "test-device"
            )
        )
    }
}
