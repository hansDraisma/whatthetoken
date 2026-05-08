import Foundation
import Testing
@testable import WhatTheTokenMac

@Test func loadsFixtureSnapshot() throws {
    let snapshot = try StatusViewModel.loadFixtureSnapshot()

    #expect(snapshot.product == "claude_code")
    #expect(snapshot.confidence == "verified")
    #expect(snapshot.remaining == 38)
    #expect(snapshot.staleReason == nil)
    #expect(snapshot.source.connector == "manual_fixture")
    #expect(snapshot.source.state == .connected)
    #expect(snapshot.source.parserVersion == "fixture-v1")
}

@Test func sectionTrustLineHoistsConfidenceConnectorLabelAndUpdatedTime() throws {
    let snapshot = try StatusViewModel.loadFixtureSnapshot()
    let section = StatusSectionDisplayModel(snapshots: [snapshot], now: Date())
    let expected = localUpdatedLabel(for: snapshot.lastUpdatedAt)

    #expect(section.trustLine == "Verified by Fixture · \(expected)")
}

@Test func fixtureJSONDoesNotContainSensitiveKeys() throws {
    let data = try StatusViewModel.loadFixtureData()
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let disallowedKeys = [
        "prompt",
        "completion",
        "conversation",
        "conversationUrl",
        "cookie",
        "authHeader",
        "bearerToken",
        "sessionToken"
    ]

    #expect(sensitiveKeyMatches(in: object, disallowedKeys: disallowedKeys).isEmpty)
}

@Test func sensitiveKeyScanFindsNestedMatches() {
    let object: [String: Any] = [
        "provider": "anthropic",
        "metadata": [
            "conversation": "should not be collected",
            "usage": [
                ["remaining": 38],
                ["sessionToken": "should not be collected"]
            ]
        ]
    ]

    #expect(sensitiveKeyMatches(in: object, disallowedKeys: ["conversation", "sessionToken"]) == [
        "metadata.conversation",
        "metadata.usage[1].sessionToken"
    ])
}

private func sensitiveKeyMatches(
    in value: Any,
    disallowedKeys: [String],
    path: String = ""
) -> [String] {
    if let dictionary = value as? [String: Any] {
        return dictionary.keys.sorted().flatMap { key -> [String] in
            let childPath = path.isEmpty ? key : "\(path).\(key)"
            let currentMatch = disallowedKeys.contains(key) ? [childPath] : []
            return currentMatch + sensitiveKeyMatches(
                in: dictionary[key] as Any,
                disallowedKeys: disallowedKeys,
                path: childPath
            )
        }
    }

    if let array = value as? [Any] {
        return array.indices.flatMap { index in
            sensitiveKeyMatches(
                in: array[index],
                disallowedKeys: disallowedKeys,
                path: "\(path)[\(index)]"
            )
        }
    }

    return []
}

private func localUpdatedLabel(for isoString: String) -> String {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    let date = fractional.date(from: isoString) ?? plain.date(from: isoString)!
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return "Updated \(formatter.string(from: date))"
}

@MainActor
@Test func newViewModel_hasNilTimestamps_andIsNotRefreshing() {
    let vm = StatusViewModel()
    #expect(vm.lastClaudeRefreshAt == nil)
    #expect(vm.lastCodexRefreshAt == nil)
    #expect(vm.isRefreshAllInFlight == false)
}

@MainActor
@Test func lastRefreshAt_isPerTab() {
    let vm = StatusViewModel()

    let claudeAt = Date(timeIntervalSince1970: 1_000)
    let codexAt = Date(timeIntervalSince1970: 2_000)

    #expect(vm.lastRefreshAt(for: .claude) == nil)
    #expect(vm.lastRefreshAt(for: .codex) == nil)

    vm.testSet_lastClaudeRefreshAt(claudeAt)
    vm.testSet_lastCodexRefreshAt(codexAt)

    #expect(vm.lastRefreshAt(for: .claude) == claudeAt)
    #expect(vm.lastRefreshAt(for: .codex) == codexAt)
}

@MainActor
@Test func isAnyRefreshing_reflectsAllPaths() {
    let vm = StatusViewModel()
    #expect(vm.isAnyRefreshing == false)

    vm.testSet_isRefreshAllInFlight(true)
    #expect(vm.isAnyRefreshing == true)
}

@MainActor
@Test func refreshAll_runsBothProvidersInOrder() async {
    final class CallRecorder: @unchecked Sendable {
        var calls: [String] = []
        func record(_ name: String) { calls.append(name) }
    }
    let recorder = CallRecorder()

    let claude = RecordingClaudeRefresher { recorder.record("claude") }
    let codex = RecordingCodexRefresher { recorder.record("codex") }
    let vm = StatusViewModel(
        snapshots: [],
        claudeRefresher: claude,
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        codexRefresher: codex
    )

    await vm.refreshAll(reason: .manual)

    #expect(recorder.calls == ["claude", "codex"])
}

@MainActor
@Test func refreshAll_setsBothTimestamps() async {
    let vm = StatusViewModel(
        snapshots: [],
        claudeRefresher: NoopClaudeRefresher(),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        codexRefresher: NoopCodexRefresher()
    )
    #expect(vm.lastClaudeRefreshAt == nil)
    #expect(vm.lastCodexRefreshAt == nil)

    await vm.refreshAll(reason: .manual)

    #expect(vm.lastClaudeRefreshAt != nil)
    #expect(vm.lastCodexRefreshAt != nil)
}

@MainActor
@Test func refreshAll_dropsOverlappingChromeRefresh() async {
    let counter = Counter()
    let claude = SlowClaudeRefresher(counter: counter)
    let codex = NoopCodexRefresher()

    let vm = StatusViewModel(
        snapshots: [],
        claudeRefresher: claude,
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        codexRefresher: codex
    )

    async let first: Void = vm.refreshAll(reason: .manual)
    async let second: Void = vm.refreshAll(reason: .timerTick)
    _ = await (first, second)

    #expect(counter.value == 1, "Second overlapping refreshAll should be dropped by the outer guard.")
}

@MainActor
@Test func connectClaudeCode_stampsTimestamp_onMissingCLIPath() async {
    let vm = StatusViewModel(
        snapshots: [],
        claudeRefresher: NoopClaudeRefresher(),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "unknown")
    )
    #expect(vm.lastClaudeRefreshAt == nil)
    await vm.connectClaudeCode()
    #expect(vm.lastClaudeRefreshAt != nil)
    #expect(vm.connectorState == .missingClaudeCli)
}

@MainActor
@Test func connectClaudeCode_stampsTimestamp_onNoRefresherPath() async {
    let vm = StatusViewModel(snapshots: [])
    #expect(vm.lastClaudeRefreshAt == nil)
    await vm.connectClaudeCode()
    #expect(vm.lastClaudeRefreshAt != nil)
    #expect(vm.connectorState == .notConnected)
}

@MainActor
@Test func connectClaudeCode_doesNotStamp_onCheckingGuardReentry() async {
    let vm = StatusViewModel(snapshots: [])
    vm.testSet_connectorStateToChecking()
    #expect(vm.lastClaudeRefreshAt == nil)
    await vm.connectClaudeCode()
    #expect(vm.lastClaudeRefreshAt == nil)
}

@MainActor
@Test func connectClaudeCode_cancelledMidRefresh_doesNotStampTimestamp() async {
    let counter = Counter()
    let vm = StatusViewModel(
        snapshots: [],
        claudeRefresher: SlowClaudeRefresher(counter: counter),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0")
    )
    #expect(vm.lastClaudeRefreshAt == nil)

    let task = Task { await vm.connectClaudeCode() }
    try? await Task.sleep(nanoseconds: 5_000_000)
    task.cancel()
    _ = await task.value

    #expect(vm.lastClaudeRefreshAt == nil)
}

@MainActor
@Test func connectClaudeCode_cancelledMidRefresh_restoresPreviousState() async {
    let counter = Counter()
    let vm = StatusViewModel(
        snapshots: [UsageSnapshotFixture.claudeSample()],
        claudeRefresher: SlowClaudeRefresher(counter: counter),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        connectorState: .connected,
        connectorStatusMessage: "Claude Code connected"
    )

    let task = Task { await vm.connectClaudeCode() }
    for _ in 0..<20 {
        if vm.connectorState == .checking { break }
        await Task.yield()
    }
    #expect(vm.connectorState == .checking)

    task.cancel()
    _ = await task.value

    #expect(vm.connectorState == .connected)
    #expect(vm.connectorStatusMessage == "Claude Code connected")
}

@MainActor
@Test func connectClaudeCode_missingCLI_preservesCodexSnapshots() async {
    let codexSnapshot = UsageSnapshotFixture.codexSample()
    let claudeSnapshot = UsageSnapshotFixture.claudeSample()
    let vm = StatusViewModel(
        snapshots: [claudeSnapshot, codexSnapshot],
        claudeRefresher: NoopClaudeRefresher(),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "unknown")
    )

    await vm.connectClaudeCode()

    #expect(vm.snapshots.contains(where: { $0.id == codexSnapshot.id }))
    #expect(!vm.snapshots.contains(where: { $0.id == claudeSnapshot.id }))
    #expect(vm.connectorState == .missingClaudeCli)
}

@MainActor
@Test func connectCodex_stampsTimestamp_onNoRefresherPath() async {
    let vm = StatusViewModel(snapshots: [])
    #expect(vm.lastCodexRefreshAt == nil)
    await vm.connectCodex()
    #expect(vm.lastCodexRefreshAt != nil)
    #expect(vm.codexConnectorState == .notConnected)
}

@MainActor
@Test func connectCodex_doesNotStamp_onCheckingGuardReentry() async {
    let vm = StatusViewModel(snapshots: [])
    vm.testSet_codexConnectorStateToChecking()
    #expect(vm.lastCodexRefreshAt == nil)
    await vm.connectCodex()
    #expect(vm.lastCodexRefreshAt == nil)
}

@MainActor
@Test func connectCodex_cancelledMidRefresh_restoresPreviousState() async {
    let counter = Counter()
    let vm = StatusViewModel(
        snapshots: [UsageSnapshotFixture.codexSample()],
        codexRefresher: SlowCodexRefresher(counter: counter),
        codexConnectorState: .connected,
        codexConnectorStatusMessage: "Codex connected"
    )

    let task = Task { await vm.connectCodex() }
    for _ in 0..<20 {
        if vm.codexConnectorState == .checking { break }
        await Task.yield()
    }
    #expect(vm.codexConnectorState == .checking)

    task.cancel()
    _ = await task.value

    #expect(vm.codexConnectorState == .connected)
    #expect(vm.codexConnectorStatusMessage == "Codex connected")
}

@MainActor
@Test func loadPersistedStateAppliesSettingsAndEnabledCachedSnapshots() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    var cache = SnapshotCache.empty
    cache.replaceSnapshots([UsageSnapshotFixture.claudeSample()], for: .claude, at: Date(timeIntervalSince1970: 1_000))

    let vm = StatusViewModel(
        settingsStore: InMemoryAppSettingsStore(data: try! JSONEncoder.prettyStable.encode(settings)),
        cacheStore: InMemorySnapshotCacheStore(data: try! JSONEncoder.cacheEncoder.encode(cache)),
        now: { ISO8601DateFormatter().date(from: "2026-05-07T00:10:00Z")! }
    )

    await vm.loadPersistedState()

    #expect(vm.settings.connectors.claudeCode.isEnabled == true)
    #expect(vm.connectorState == .connected)
    #expect(vm.snapshots.map(\.id) == [UsageSnapshotFixture.claudeSample().id])
}

@MainActor
@Test func loadPersistedStateDoesNotRenderDisabledProviderCache() async {
    var cache = SnapshotCache.empty
    cache.replaceSnapshots([UsageSnapshotFixture.codexSample()], for: .codex, at: Date(timeIntervalSince1970: 1_000))
    let vm = StatusViewModel(
        settingsStore: InMemoryAppSettingsStore(),
        cacheStore: InMemorySnapshotCacheStore(data: try! JSONEncoder.cacheEncoder.encode(cache))
    )

    await vm.loadPersistedState()

    #expect(vm.settings.connectors.codex.isEnabled == false)
    #expect(vm.snapshots.isEmpty)
    #expect(vm.codexConnectorState == .notConnected)
}

@MainActor
@Test func loadPersistedStateRestoresSanitizedErrorStateWithCachedSnapshots() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    var cache = SnapshotCache.empty
    cache.replaceSnapshots([UsageSnapshotFixture.claudeSample()], for: .claude, at: Date(timeIntervalSince1970: 1_000))
    cache.recordFailure(
        for: .claude,
        code: .network,
        message: "Claude Code usage could not be refreshed",
        now: Date(timeIntervalSince1970: 1_100)
    )
    let vm = StatusViewModel(
        settingsStore: InMemoryAppSettingsStore(data: try! JSONEncoder.prettyStable.encode(settings)),
        cacheStore: InMemorySnapshotCacheStore(data: try! JSONEncoder.cacheEncoder.encode(cache)),
        now: { Date(timeIntervalSince1970: 1_120) }
    )

    await vm.loadPersistedState()

    #expect(vm.connectorState == .networkError)
    #expect(vm.connectorStatusMessage == "Claude Code usage could not be refreshed")
    #expect(vm.snapshots.map(\.id) == [UsageSnapshotFixture.claudeSample().id])
}

@MainActor
@Test func setConnectorEnabledPersistsConsentWithoutRefreshing() async {
    let settingsStore = InMemoryAppSettingsStore()
    let refresher = RecordingClaudeRefresher()
    let vm = StatusViewModel(
        claudeRefresher: refresher,
        settingsStore: settingsStore,
        cacheStore: InMemorySnapshotCacheStore()
    )

    await vm.setConnector(.claude, enabled: true)
    let persisted = await settingsStore.load()

    #expect(persisted.connectors.claudeCode.isEnabled == true)
    #expect(vm.connectorState == .connected)
    #expect(vm.snapshots.isEmpty)
}

@MainActor
@Test func disconnectClearsConsentAndProviderCache() async {
    var settings = AppSettings.defaults
    settings.connectors.codex.isEnabled = true
    var cache = SnapshotCache.empty
    cache.replaceSnapshots([UsageSnapshotFixture.codexSample()], for: .codex, at: Date(timeIntervalSince1970: 1_000))
    let cacheStore = InMemorySnapshotCacheStore(data: try! JSONEncoder.cacheEncoder.encode(cache))
    let settingsStore = InMemoryAppSettingsStore(data: try! JSONEncoder.prettyStable.encode(settings))
    let vm = StatusViewModel(settingsStore: settingsStore, cacheStore: cacheStore)

    await vm.loadPersistedState()
    await vm.disconnect(.codex)

    let persistedSettings = await settingsStore.load()
    let persistedCache = await cacheStore.load()
    #expect(persistedSettings.connectors.codex.isEnabled == false)
    #expect(!persistedCache.snapshots.contains { $0.provider == "openai" })
    #expect(vm.codexConnectorState == .notConnected)
}
