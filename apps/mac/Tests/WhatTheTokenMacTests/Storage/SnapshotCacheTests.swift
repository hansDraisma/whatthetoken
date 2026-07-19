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

    @Test func decoderAcceptsFractionalIso8601Dates() throws {
        let json = #"{"schemaVersion":1,"snapshots":[],"updatedAtByProvider":{"anthropic_claude_code":"2026-05-18T12:34:56.789Z"},"lastSuccessfulRefreshAtByProvider":{},"lastErrorByProvider":{}}"#
            .data(using: .utf8)!

        let cache = try SnapshotCache.decodeValidated(from: json)

        #expect(cache.updatedAtByProvider[CachedProviderID.claude.rawValue] != nil)
    }

    @Test func fractionalIso8601DatesRoundTripThroughCacheEncoder() throws {
        let json = #"{"schemaVersion":1,"snapshots":[],"updatedAtByProvider":{"anthropic_claude_code":"2026-05-18T12:34:56.789Z"},"lastSuccessfulRefreshAtByProvider":{},"lastErrorByProvider":{}}"#
            .data(using: .utf8)!
        let cache = try SnapshotCache.decodeValidated(from: json)

        let encoded = try JSONEncoder.cacheEncoder.encode(cache)
        let decoded = try SnapshotCache.decodeValidated(from: encoded)

        #expect(decoded == cache)
    }

    @Test func cacheEncoderUsesSharedPrettyStableFormattingConvention() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/WhatTheTokenMac/Storage/SnapshotCacheStore.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("let encoder = JSONEncoder.prettyStable"))
    }

    @Test func mirroringStoreWritesWidgetReadableCacheCopy() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WhatTheTokenSnapshotCacheTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let primaryURL = root.appendingPathComponent("primary/snapshot-cache.json")
        let mirrorURL = root.appendingPathComponent("widget/Data/Library/Application Support/WhatTheToken/snapshot-cache.json")
        let store = MirroringSnapshotCacheStore(
            primary: JSONFileSnapshotCacheStore(url: primaryURL),
            mirrors: [JSONFileSnapshotCacheStore(url: mirrorURL)]
        )
        var cache = SnapshotCache.empty
        cache.replaceSnapshots([UsageSnapshotFixture.claudeSample()], for: .claude, at: Date(timeIntervalSince1970: 1_000))

        let saved = await store.save(cache)

        #expect(saved)
        #expect(try SnapshotCache.decodeValidated(from: Data(contentsOf: primaryURL)) == cache)
        #expect(try SnapshotCache.decodeValidated(from: Data(contentsOf: mirrorURL)) == cache)
    }

    @Test func mirroringStoreBackfillsWidgetReadableCacheCopyOnLoad() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WhatTheTokenSnapshotCacheTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let primaryURL = root.appendingPathComponent("primary/snapshot-cache.json")
        let mirrorURL = root.appendingPathComponent("widget/Data/Library/Application Support/WhatTheToken/snapshot-cache.json")
        var cache = SnapshotCache.empty
        cache.replaceSnapshots([UsageSnapshotFixture.claudeSample()], for: .claude, at: Date(timeIntervalSince1970: 1_000))
        _ = await JSONFileSnapshotCacheStore(url: primaryURL).save(cache)
        let store = MirroringSnapshotCacheStore(
            primary: JSONFileSnapshotCacheStore(url: primaryURL),
            mirrors: [JSONFileSnapshotCacheStore(url: mirrorURL)]
        )

        let loaded = await store.load()

        #expect(loaded == cache)
        #expect(try SnapshotCache.decodeValidated(from: Data(contentsOf: mirrorURL)) == cache)
    }

    @Test func mirroringStoreBackfillsEmptyCacheToClearStaleMirrorOnLoad() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WhatTheTokenSnapshotCacheTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let primaryURL = root.appendingPathComponent("primary/snapshot-cache.json")
        let mirrorURL = root.appendingPathComponent("widget/Data/Library/Application Support/WhatTheToken/snapshot-cache.json")
        var staleMirror = SnapshotCache.empty
        staleMirror.replaceSnapshots([UsageSnapshotFixture.claudeSample()], for: .claude, at: Date(timeIntervalSince1970: 1_000))
        _ = await JSONFileSnapshotCacheStore(url: primaryURL).save(.empty)
        _ = await JSONFileSnapshotCacheStore(url: mirrorURL).save(staleMirror)
        let store = MirroringSnapshotCacheStore(
            primary: JSONFileSnapshotCacheStore(url: primaryURL),
            mirrors: [JSONFileSnapshotCacheStore(url: mirrorURL)]
        )

        let loaded = await store.load()

        #expect(loaded == .empty)
        #expect(try SnapshotCache.decodeValidated(from: Data(contentsOf: mirrorURL)) == .empty)
    }

    @Test func localAppGroupURLUsesExpectedDevelopmentContainerPath() {
        let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)

        let url = WidgetSnapshotCacheFile.localAppGroupURL(homeDirectory: home)

        #expect(url.path == "/Users/example/Library/Group Containers/3U98C8T3DT.com.whatthetoken.mac/snapshot-cache.json")
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
            policy: SnapshotStalePolicy(staleAfterMinutes: 60)
        )

        #expect(stale.first?.confidence == "stale")
        #expect(stale.first?.staleReason == "Last update was 61 minutes ago.")
    }

    @Test func stalePolicyForAutoRefreshUsesMaxOfTwoIntervalsAndFifteenMinutes() {
        var fiveMinuteSettings = AppSettings.defaults
        fiveMinuteSettings.refresh.autoRefreshEnabled = true
        fiveMinuteSettings.refresh.intervalSeconds = 300

        var twentyMinuteSettings = AppSettings.defaults
        twentyMinuteSettings.refresh.autoRefreshEnabled = true
        twentyMinuteSettings.refresh.intervalSeconds = 1_200

        #expect(SnapshotStalePolicy.from(settings: fiveMinuteSettings).staleAfterMinutes == 15)
        #expect(SnapshotStalePolicy.from(settings: twentyMinuteSettings).staleAfterMinutes == 40)
    }

    @Test func stalePolicyForManualOnlyUsesSixtyMinutes() {
        var settings = AppSettings.defaults
        settings.refresh.autoRefreshEnabled = false

        #expect(SnapshotStalePolicy.from(settings: settings).staleAfterMinutes == 60)
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
