import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct SnapshotCacheTests {
    @Test func emptyCacheUsesCurrentSchema() {
        #expect(SnapshotCache.empty.schemaVersion == 1)
        #expect(SnapshotCache.empty.snapshots.isEmpty)
        #expect(SnapshotCache.empty.lastErrorByProvider.isEmpty)
    }

    @Test func roundTripPreservesSanitizedSnapshotsAndBackoff() throws {
        var cache = SnapshotCache.empty
        let provider = CachedProviderID.claude
        let updatedAt = Date(timeIntervalSince1970: 1_000)
        cache.replaceSnapshots([UsageSnapshotFixture.claudeSample()], for: provider, at: updatedAt)
        cache.recordFailure(
            for: provider,
            code: .network,
            message: "Claude Code usage could not be refreshed",
            now: updatedAt
        )

        let data = try JSONEncoder.cacheEncoder.encode(cache)
        let decoded = try SnapshotCache.decodeValidated(from: data)

        #expect(decoded.snapshots.count == 1)
        #expect(decoded.lastSuccessfulRefreshAtByProvider[provider.rawValue] == updatedAt)
        #expect(decoded.lastErrorByProvider[provider.rawValue]?.consecutiveFailureCount == 1)
        #expect(decoded.lastErrorByProvider[provider.rawValue]?.nextAutomaticRefreshAt == Date(timeIntervalSince1970: 1_300))
    }

    @Test func unknownSchemaFallsBackThroughStoreLoad() async {
        let data = #"{"schemaVersion":999}"#.data(using: .utf8)!
        let store = InMemorySnapshotCacheStore(data: data)

        let loaded = await store.load()

        #expect(loaded == .empty)
    }

    @Test func replaceSnapshotsOnlyReplacesMatchingProvider() {
        var cache = SnapshotCache.empty
        cache.replaceSnapshots([UsageSnapshotFixture.claudeSample()], for: .claude, at: Date(timeIntervalSince1970: 1))
        cache.replaceSnapshots([UsageSnapshotFixture.codexSample()], for: .codex, at: Date(timeIntervalSince1970: 2))

        let replacement = UsageSnapshotFixture.claudeLowSample()
        cache.replaceSnapshots([replacement], for: .claude, at: Date(timeIntervalSince1970: 3))

        #expect(cache.snapshots.map(\.id).sorted() == [replacement.id, UsageSnapshotFixture.codexSample().id].sorted())
    }

    @Test func removeSnapshotsClearsProviderOnly() {
        var cache = SnapshotCache.empty
        cache.replaceSnapshots([UsageSnapshotFixture.claudeSample()], for: .claude, at: Date(timeIntervalSince1970: 1))
        cache.replaceSnapshots([UsageSnapshotFixture.codexSample()], for: .codex, at: Date(timeIntervalSince1970: 2))

        cache.removeProvider(.claude)

        #expect(cache.snapshots.map(\.provider) == ["openai"])
        #expect(cache.lastSuccessfulRefreshAtByProvider[CachedProviderID.claude.rawValue] == nil)
    }

    @Test func staleEvaluationMarksExpiredSnapshots() {
        var cache = SnapshotCache.empty
        cache.replaceSnapshots([UsageSnapshotFixture.claudeSample()], for: .claude, at: Date(timeIntervalSince1970: 1))

        let stale = cache.snapshotsEvaluatingStaleness(
            now: ISO8601DateFormatter().date(from: "2026-05-07T01:01:00Z")!,
            staleAfterMinutes: 60
        )

        #expect(stale.first?.confidence == "stale")
        #expect(stale.first?.staleReason == "Last update was 61 minutes ago.")
    }

    @Test func cachedJSONDoesNotContainSensitiveKeys() throws {
        var cache = SnapshotCache.empty
        cache.replaceSnapshots([UsageSnapshotFixture.codexSample()], for: .codex, at: Date(timeIntervalSince1970: 1))

        let json = String(decoding: try JSONEncoder.cacheEncoder.encode(cache), as: UTF8.self)

        #expect(!json.contains("authHeader"))
        #expect(!json.contains("bearerToken"))
        #expect(!json.contains("sessionToken"))
        #expect(!json.contains("cookie"))
        #expect(!json.contains("prompt"))
        #expect(!json.contains("completion"))
        #expect(!json.contains("conversation"))
    }
}
