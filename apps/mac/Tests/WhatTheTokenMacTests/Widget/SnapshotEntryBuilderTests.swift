import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct SnapshotEntryBuilderTests {
    @Test func buildsEntryFromConnectedClaudeOnlySnapshot() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = SnapshotCache(
            schemaVersion: 1,
            snapshots: [
                usageSnapshot(provider: "anthropic", product: "claude_code", poolKey: "anthropic_claude_subscription", windowKey: "five_hour", utilization: 0.47),
                usageSnapshot(provider: "anthropic", product: "claude_code", poolKey: "anthropic_claude_subscription", windowKey: "seven_day", utilization: 0.20)
            ],
            updatedAtByProvider: [CachedProviderID.claude.rawValue: now.addingTimeInterval(-60)],
            lastSuccessfulRefreshAtByProvider: [:],
            lastErrorByProvider: [:]
        )

        let entry = SnapshotEntryBuilder.entry(from: cache, now: now)

        #expect(entry.rows.count == 2)
        #expect(entry.rows[0].provider == .claude)
        #expect(entry.rows[0].state == .connected(percentage: 53))
        #expect(entry.rows[1].provider == .codex)
        #expect(entry.rows[1].state == .notConnected)
        #expect(entry.isStale == false)
    }

    @Test func picksLowestRemainingIncludedQuotaPerProvider() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = SnapshotCache(
            schemaVersion: 1,
            snapshots: [
                usageSnapshot(provider: "anthropic", product: "claude_code", poolKey: "anthropic_claude_subscription", windowKey: "5h", utilization: 0.30),
                usageSnapshot(provider: "anthropic", product: "claude_code", poolKey: "anthropic_claude_subscription", windowKey: "7d", utilization: 0.85)
            ],
            updatedAtByProvider: [CachedProviderID.claude.rawValue: now],
            lastSuccessfulRefreshAtByProvider: [:],
            lastErrorByProvider: [:]
        )

        let entry = SnapshotEntryBuilder.entry(from: cache, now: now)

        #expect(entry.rows[0].state == .connected(percentage: 15))
    }

    @Test func ignoresFallbackCreditsWhenChoosingProviderPercentage() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = SnapshotCache(
            schemaVersion: 1,
            snapshots: [
                usageSnapshot(provider: "anthropic", product: "claude_code", poolKey: "anthropic_claude_subscription", windowKey: "five_hour", utilization: 0.46),
                usageSnapshot(provider: "anthropic", product: "claude_code", poolKey: "anthropic_claude_extra_usage", windowKey: "monthly_extra_usage", unit: "credits", remaining: 0, limit: 2_000, utilization: 1.0005)
            ],
            updatedAtByProvider: [CachedProviderID.claude.rawValue: now],
            lastSuccessfulRefreshAtByProvider: [:],
            lastErrorByProvider: [:]
        )

        let entry = SnapshotEntryBuilder.entry(from: cache, now: now)

        #expect(entry.rows[0].state == .connected(percentage: 54))
    }

    @Test func buildsEntryFromLiveCacheShapeAsRemainingQuota() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = SnapshotCache(
            schemaVersion: 1,
            snapshots: [
                usageSnapshot(provider: "anthropic", product: "claude_code", poolKey: "anthropic_claude_subscription", windowKey: "five_hour", remaining: 54, limit: 100, utilization: 0.46),
                usageSnapshot(provider: "anthropic", product: "claude_code", poolKey: "anthropic_claude_subscription", windowKey: "seven_day", remaining: 79, limit: 100, utilization: 0.21),
                usageSnapshot(provider: "anthropic", product: "claude_code", poolKey: "anthropic_claude_extra_usage", windowKey: "monthly_extra_usage", unit: "credits", remaining: 0, limit: 2_000, utilization: 1.0005),
                usageSnapshot(provider: "openai", product: "codex", poolKey: "openai_codex_codex_d4cde064", windowKey: "primary_rolling_300m", remaining: 91, limit: 100, utilization: 0.09),
                usageSnapshot(provider: "openai", product: "codex", poolKey: "openai_codex_codex_d4cde064", windowKey: "secondary_rolling_10080m", remaining: 90, limit: 100, utilization: 0.10),
                usageSnapshot(provider: "openai", product: "codex", poolKey: "openai_codex_credits", windowKey: "credits_remaining", unit: "credits", remaining: 0, limit: nil, utilization: nil)
            ],
            updatedAtByProvider: [
                CachedProviderID.claude.rawValue: now,
                CachedProviderID.codex.rawValue: now
            ],
            lastSuccessfulRefreshAtByProvider: [:],
            lastErrorByProvider: [:]
        )

        let entry = SnapshotEntryBuilder.entry(from: cache, now: now)

        #expect(entry.rows[0].state == .connected(percentage: 54))
        #expect(entry.rows[1].state == .connected(percentage: 90))
    }

    @Test func marksEntryStaleWhenProviderAgeExceedsThreshold() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cache = SnapshotCache(
            schemaVersion: 1,
            snapshots: [usageSnapshot(provider: "anthropic", product: "claude_code", poolKey: "anthropic_claude_subscription", utilization: 0.10)],
            updatedAtByProvider: [CachedProviderID.claude.rawValue: now.addingTimeInterval(-20 * 60)],
            lastSuccessfulRefreshAtByProvider: [:],
            lastErrorByProvider: [:]
        )

        let entry = SnapshotEntryBuilder.entry(from: cache, now: now)
        #expect(entry.isStale == true)
    }

    @Test func marksEntryStaleWhenProviderHasARecentCachedFailure() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var cache = SnapshotCache(
            schemaVersion: 1,
            snapshots: [
                usageSnapshot(
                    provider: "anthropic",
                    product: "claude_code",
                    poolKey: "anthropic_claude_subscription",
                    utilization: 0.10
                )
            ],
            updatedAtByProvider: [CachedProviderID.claude.rawValue: now],
            lastSuccessfulRefreshAtByProvider: [
                CachedProviderID.claude.rawValue: now
            ],
            lastErrorByProvider: [:]
        )
        cache.recordFailure(
            for: .claude,
            code: .sessionExpired,
            message: "Claude Code session expired",
            now: now
        )

        let entry = SnapshotEntryBuilder.entry(from: cache, now: now)

        #expect(entry.rows[0].state == .connected(percentage: 90))
        #expect(entry.isStale == true)
    }

    @Test func returnsPlaceholderEntryWhenCacheIsEmpty() {
        let entry = SnapshotEntryBuilder.placeholder()

        #expect(entry.rows.count == 2)
        #expect(entry.rows.allSatisfy { $0.state == .notConnected })
        #expect(entry.isStale == false)
    }

    @Test func emptyCacheReturnsNotConnectedForBothProviders() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = SnapshotEntryBuilder.entry(from: SnapshotCache.empty, now: now)

        #expect(entry.rows.allSatisfy { $0.state == .notConnected })
        #expect(entry.isStale == false)
    }

    @Test func entryWithAllRowsNotConnectedIsNotMarkedStale() {
        let entry = SnapshotEntryBuilder.entry(from: SnapshotCache.empty, now: Date())

        #expect(entry.rows.allSatisfy { $0.state == .notConnected })
        #expect(entry.isStale == false)
    }

    private func usageSnapshot(
        provider: String,
        product: String,
        poolKey: String = "5h",
        windowKey: String? = nil,
        unit: String = "utilization",
        remaining: Double? = nil,
        limit: Double? = nil,
        utilization: Double?
    ) -> UsageSnapshot {
        UsageSnapshot(
            id: "\(provider)-\(product)-\(poolKey)",
            userAccountId: "u",
            provider: provider,
            product: product,
            surface: "test",
            poolKey: poolKey,
            windowKey: windowKey ?? poolKey,
            unit: unit,
            used: nil,
            limit: limit,
            remaining: remaining,
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
