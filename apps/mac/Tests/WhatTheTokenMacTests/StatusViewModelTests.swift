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

@Test func sectionTrustLineHoistsConfidenceConnectorLabelOnly() throws {
    let snapshot = try StatusViewModel.loadFixtureSnapshot()
    let section = StatusSectionDisplayModel(snapshots: [snapshot], now: Date())

    #expect(section.trustLine == "Verified by Fixture")
    #expect(section.trustLine?.contains("Updated") == false)
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
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    settings.connectors.codex.isEnabled = true
    final class CallRecorder: @unchecked Sendable {
        var calls: [String] = []
        func record(_ name: String) { calls.append(name) }
    }
    let recorder = CallRecorder()

    let claude = RecordingClaudeRefresher { recorder.record("claude") }
    let codex = RecordingCodexRefresher { recorder.record("codex") }
    let vm = StatusViewModel(
        snapshots: [],
        settings: settings,
        claudeRefresher: claude,
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        codexRefresher: codex
    )

    await vm.refreshAll(reason: .manual)

    #expect(recorder.calls == ["claude", "codex"])
}

@MainActor
@Test func refreshAll_setsBothTimestamps() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    settings.connectors.codex.isEnabled = true
    let vm = StatusViewModel(
        snapshots: [],
        settings: settings,
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
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    let counter = Counter()
    let claude = SlowClaudeRefresher(counter: counter)
    let codex = NoopCodexRefresher()

    let vm = StatusViewModel(
        snapshots: [],
        settings: settings,
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
@Test func loadPersistedStateRestoresCachedRefreshTimestamps() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    settings.connectors.codex.isEnabled = true
    var cache = SnapshotCache.empty
    let claudeAt = Date(timeIntervalSince1970: 1_000)
    let codexAt = Date(timeIntervalSince1970: 2_000)
    cache.replaceSnapshots([UsageSnapshotFixture.claudeSample()], for: .claude, at: claudeAt)
    cache.replaceSnapshots([UsageSnapshotFixture.codexSample()], for: .codex, at: codexAt)

    let vm = StatusViewModel(
        settingsStore: InMemoryAppSettingsStore(data: try! JSONEncoder.prettyStable.encode(settings)),
        cacheStore: InMemorySnapshotCacheStore(data: try! JSONEncoder.cacheEncoder.encode(cache))
    )

    await vm.loadPersistedState()

    #expect(vm.lastRefreshAt(for: .claude) == claudeAt)
    #expect(vm.lastRefreshAt(for: .codex) == codexAt)
    #expect(vm.lastUpdatedAt == claudeAt)
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
@Test func saveSettingsPreservesCheckingStateDuringRefresh() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    let counter = Counter()
    let vm = StatusViewModel(
        settings: settings,
        claudeRefresher: SlowClaudeRefresher(counter: counter),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0")
    )

    let task = Task { await vm.refreshAll(reason: .manual) }
    for _ in 0..<20 {
        if vm.connectorState == .checking { break }
        await Task.yield()
    }

    settings.refresh.autoRefreshEnabled = true
    await vm.saveSettings(settings)

    #expect(vm.connectorState == .checking)

    task.cancel()
    _ = await task.value
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

@MainActor
@Test func disconnectClearsProviderNotificationState() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    settings.connectors.codex.isEnabled = true
    let codexKey = NotificationDedupeKey(provider: .codex, poolKey: "openai_codex_included", windowKey: "rolling_5h")
    let claudeKey = NotificationDedupeKey(provider: .claude, poolKey: "anthropic_claude_subscription", windowKey: "rolling_5h")
    var state = NotificationState.empty
    state.records[codexKey.storageKey] = NotificationRecord(
        key: codexKey,
        lastNotifiedLevel: .critical,
        lastNotifiedAt: Date(timeIntervalSince1970: 1),
        lastObservedLevel: .critical,
        recoveredAt: nil
    )
    state.records[claudeKey.storageKey] = NotificationRecord(
        key: claudeKey,
        lastNotifiedLevel: .warning,
        lastNotifiedAt: Date(timeIntervalSince1970: 1),
        lastObservedLevel: .warning,
        recoveredAt: nil
    )
    let stateStore = InMemoryNotificationStateStore(data: try! JSONEncoder.notificationStateEncoder.encode(state))
    let settingsStore = InMemoryAppSettingsStore(data: try! JSONEncoder.prettyStable.encode(settings))
    let vm = StatusViewModel(settingsStore: settingsStore, notificationStateStore: stateStore)

    await vm.loadPersistedState()
    await vm.disconnect(.codex)

    let persisted = await stateStore.load()
    #expect(persisted.records[codexKey.storageKey] == nil)
    #expect(persisted.records[claudeKey.storageKey] != nil)
}

@MainActor
@Test func disconnectKeepsConsentWhenNotificationStateCannotBePersisted() async {
    var settings = AppSettings.defaults
    settings.connectors.codex.isEnabled = true
    var cache = SnapshotCache.empty
    cache.replaceSnapshots([UsageSnapshotFixture.codexSample()], for: .codex, at: Date(timeIntervalSince1970: 1_000))
    let codexKey = NotificationDedupeKey(provider: .codex, poolKey: "openai_codex_included", windowKey: "rolling_5h")
    var state = NotificationState.empty
    state.records[codexKey.storageKey] = NotificationRecord(
        key: codexKey,
        lastNotifiedLevel: .critical,
        lastNotifiedAt: Date(timeIntervalSince1970: 1),
        lastObservedLevel: .critical,
        recoveredAt: nil
    )
    let settingsStore = InMemoryAppSettingsStore(data: try! JSONEncoder.prettyStable.encode(settings))
    let cacheStore = InMemorySnapshotCacheStore(data: try! JSONEncoder.cacheEncoder.encode(cache))
    let stateStore = FailingSaveNotificationStateStore(state: state)
    let vm = StatusViewModel(
        settingsStore: settingsStore,
        cacheStore: cacheStore,
        notificationStateStore: stateStore
    )

    await vm.loadPersistedState()
    await vm.disconnect(.codex)

    let persistedSettings = await settingsStore.load()
    let persistedCache = await cacheStore.load()
    #expect(vm.settings.connectors.codex.isEnabled == true)
    #expect(persistedSettings.connectors.codex.isEnabled == true)
    #expect(vm.snapshots.contains(where: CachedProviderID.codex.snapshotPredicate))
    #expect(persistedCache.snapshots.contains(where: CachedProviderID.codex.snapshotPredicate))
    #expect(vm.codexConnectorState == .connected)
}

@MainActor
@Test func pauseConnectorKeepsCachedSnapshotsButSkipsRefresh() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    var cache = SnapshotCache.empty
    cache.replaceSnapshots([UsageSnapshotFixture.claudeSample()], for: .claude, at: Date(timeIntervalSince1970: 1))
    let counter = Counter()
    let vm = StatusViewModel(
        settings: settings,
        cache: cache,
        claudeRefresher: SlowClaudeRefresher(counter: counter),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        settingsStore: InMemoryAppSettingsStore(data: try! JSONEncoder.prettyStable.encode(settings)),
        cacheStore: InMemorySnapshotCacheStore(data: try! JSONEncoder.cacheEncoder.encode(cache))
    )

    await vm.loadPersistedState()
    await vm.setConnector(.claude, paused: true)
    await vm.refreshAll(reason: .manual)

    #expect(vm.snapshots.contains(where: CachedProviderID.claude.snapshotPredicate))
    #expect(counter.value == 0)
}

@MainActor
@Test func disconnectWhilePausedRemovesProviderCache() async {
    var settings = AppSettings.defaults
    settings.connectors.codex.isEnabled = true
    settings.connectors.codex.isPaused = true
    var cache = SnapshotCache.empty
    cache.replaceSnapshots([UsageSnapshotFixture.codexSample()], for: .codex, at: Date(timeIntervalSince1970: 1))
    let cacheStore = InMemorySnapshotCacheStore(data: try! JSONEncoder.cacheEncoder.encode(cache))
    let settingsStore = InMemoryAppSettingsStore(data: try! JSONEncoder.prettyStable.encode(settings))
    let vm = StatusViewModel(settingsStore: settingsStore, cacheStore: cacheStore)

    await vm.loadPersistedState()
    await vm.disconnect(.codex)

    #expect(vm.settings.connectors.codex.isEnabled == false)
    #expect(vm.settings.connectors.codex.isPaused == false)
    #expect(vm.snapshots.contains(where: CachedProviderID.codex.snapshotPredicate) == false)
}

@MainActor
@Test func pausedConnectorShowsPausedStatusWhileKeepingCachedSnapshots() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    settings.connectors.claudeCode.isPaused = true
    var cache = SnapshotCache.empty
    cache.replaceSnapshots([UsageSnapshotFixture.claudeSample()], for: .claude, at: Date(timeIntervalSince1970: 1))
    let vm = StatusViewModel(
        settings: settings,
        cache: cache,
        settingsStore: InMemoryAppSettingsStore(data: try! JSONEncoder.prettyStable.encode(settings)),
        cacheStore: InMemorySnapshotCacheStore(data: try! JSONEncoder.cacheEncoder.encode(cache))
    )

    await vm.loadPersistedState()

    #expect(vm.snapshots.contains(where: CachedProviderID.claude.snapshotPredicate))
    #expect(vm.connectorState == .connected)
    #expect(vm.connectorStatusMessage == "Claude Code paused")
}

@MainActor
@Test func successfulManualRefreshClearsProviderBackoff() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    var cache = SnapshotCache.empty
    cache.recordFailure(for: .claude, code: .network, message: "Network", now: Date(timeIntervalSince1970: 1))
    let cacheStore = InMemorySnapshotCacheStore(data: try! JSONEncoder.cacheEncoder.encode(cache))
    let vm = StatusViewModel(
        settings: settings,
        claudeRefresher: NoopClaudeRefresher(),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        cacheStore: cacheStore,
        now: { Date(timeIntervalSince1970: 2) }
    )

    await vm.refreshAll(reason: .manual)
    let saved = await cacheStore.load()

    #expect(saved.lastErrorByProvider[CachedProviderID.claude.rawValue] == nil)
}

@MainActor
@Test func disconnectKeepsConsentWhenCacheWipeCannotBePersisted() async throws {
    var settings = AppSettings.defaults
    settings.connectors.codex.isEnabled = true
    var cache = SnapshotCache.empty
    cache.replaceSnapshots([UsageSnapshotFixture.codexSample()], for: .codex, at: Date(timeIntervalSince1970: 1_000))
    let settingsStore = InMemoryAppSettingsStore(data: try JSONEncoder.prettyStable.encode(settings))

    let invalidParent = FileManager.default.temporaryDirectory
        .appendingPathComponent("whatthetoken-cache-parent-\(UUID().uuidString)")
    try Data("not a directory".utf8).write(to: invalidParent)
    defer { try? FileManager.default.removeItem(at: invalidParent) }

    let vm = StatusViewModel(
        snapshots: [UsageSnapshotFixture.codexSample()],
        settings: settings,
        cache: cache,
        settingsStore: settingsStore,
        cacheStore: JSONFileSnapshotCacheStore(
            url: invalidParent.appendingPathComponent("snapshot-cache.json")
        ),
        codexConnectorState: .connected,
        codexConnectorStatusMessage: "Codex connected"
    )

    await vm.disconnect(.codex)
    let persistedSettings = await settingsStore.load()

    #expect(vm.settings.connectors.codex.isEnabled == true)
    #expect(persistedSettings.connectors.codex.isEnabled == true)
    #expect(vm.snapshots.contains(where: CachedProviderID.codex.snapshotPredicate))
    #expect(vm.codexConnectorState == .connected)
}

@MainActor
@Test func disconnectKeepsConsentWhenSettingsDisableCannotBePersisted() async throws {
    var settings = AppSettings.defaults
    settings.connectors.codex.isEnabled = true
    var cache = SnapshotCache.empty
    cache.replaceSnapshots([UsageSnapshotFixture.codexSample()], for: .codex, at: Date(timeIntervalSince1970: 1_000))
    let cacheStore = InMemorySnapshotCacheStore(data: try JSONEncoder.cacheEncoder.encode(cache))

    let invalidParent = FileManager.default.temporaryDirectory
        .appendingPathComponent("whatthetoken-settings-parent-\(UUID().uuidString)")
    try Data("not a directory".utf8).write(to: invalidParent)
    defer { try? FileManager.default.removeItem(at: invalidParent) }

    let vm = StatusViewModel(
        snapshots: [UsageSnapshotFixture.codexSample()],
        settings: settings,
        cache: cache,
        settingsStore: JSONFileAppSettingsStore(
            url: invalidParent.appendingPathComponent("settings.json")
        ),
        cacheStore: cacheStore,
        codexConnectorState: .connected,
        codexConnectorStatusMessage: "Codex connected"
    )

    await vm.disconnect(.codex)
    let persistedCache = await cacheStore.load()

    #expect(vm.settings.connectors.codex.isEnabled == true)
    #expect(vm.snapshots.contains(where: CachedProviderID.codex.snapshotPredicate))
    #expect(vm.codexConnectorState == .connected)
    #expect(persistedCache.snapshots.contains(where: CachedProviderID.codex.snapshotPredicate))
}

@MainActor
@Test func refreshAllSkipsDisabledConnectors() async {
    let claudeCounter = Counter()
    let codexCounter = Counter()
    let vm = StatusViewModel(
        claudeRefresher: SlowClaudeRefresher(counter: claudeCounter),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        codexRefresher: SlowCodexRefresher(counter: codexCounter)
    )

    await vm.refreshAll(reason: .manual)

    #expect(claudeCounter.value == 0)
    #expect(codexCounter.value == 0)
}

@MainActor
@Test func refreshAllRefreshesOnlyEnabledConnector() async {
    var settings = AppSettings.defaults
    settings.connectors.codex.isEnabled = true
    let codexCounter = Counter()
    let vm = StatusViewModel(
        settings: settings,
        codexRefresher: SlowCodexRefresher(counter: codexCounter)
    )

    await vm.refreshAll(reason: .manual)

    #expect(codexCounter.value == 1)
}

@MainActor
@Test func successfulRefreshPersistsProviderSnapshotsToCache() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    let cacheStore = InMemorySnapshotCacheStore()
    let vm = StatusViewModel(
        settings: settings,
        claudeRefresher: SnapshotClaudeRefresher(snapshots: [UsageSnapshotFixture.claudeLowSample()]),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        cacheStore: cacheStore,
        now: { Date(timeIntervalSince1970: 2_000) }
    )

    await vm.refreshAll(reason: .manual)
    let cache = await cacheStore.load()

    #expect(cache.snapshots.map(\.id) == [UsageSnapshotFixture.claudeLowSample().id])
    #expect(cache.lastSuccessfulRefreshAtByProvider[CachedProviderID.claude.rawValue] == Date(timeIntervalSince1970: 2_000))
}

@MainActor
@Test func successfulRefreshEvaluatesAndDeliversNotifications() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    settings.notifications.isEnabled = true
    settings.notifications.providerAlerts.claudeCode.isEnabled = true
    let delivery = RecordingNotificationDelivery(permissionResult: .granted)
    let vm = StatusViewModel(
        settings: settings,
        claudeRefresher: SnapshotClaudeRefresher(snapshots: [UsageSnapshotFixture.claudeIncludedSample(remaining: 8, utilization: 0.92)]),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        notificationStateStore: InMemoryNotificationStateStore(),
        notificationDelivery: delivery
    )

    await vm.refreshAll(reason: .manual)

    #expect(await delivery.deliveredIntents.count == 1)
    #expect(await delivery.deliveredIntents.first?.level == .critical)
}

@MainActor
@Test func claudeRefreshEvaluatorIgnoresCachedCodexCriticalSnapshot() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    settings.connectors.codex.isEnabled = true
    settings.notifications.isEnabled = true
    settings.notifications.providerAlerts.claudeCode.isEnabled = true
    settings.notifications.providerAlerts.codex.isEnabled = true
    let cachedCodex = UsageSnapshotFixture.codexIncludedSample(remaining: 8, utilization: 0.92)
    let claudeCritical = UsageSnapshotFixture.claudeIncludedSample(remaining: 5, utilization: 0.95)
    let delivery = RecordingNotificationDelivery(permissionResult: .granted)
    let vm = StatusViewModel(
        snapshots: [cachedCodex],
        settings: settings,
        claudeRefresher: SnapshotClaudeRefresher(snapshots: [claudeCritical]),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        notificationStateStore: InMemoryNotificationStateStore(),
        notificationDelivery: delivery
    )

    await vm.refreshAll(reason: .manual)

    let intents = await delivery.deliveredIntents
    #expect(intents.contains(where: { $0.provider == .codex }) == false)
    #expect(intents.contains(where: { $0.provider == .claude && $0.level == .critical }))
}

@MainActor
@Test func loadPersistedStateSuppressesNotificationsWhenNotificationStateDecodeFails() async {
    var settings = AppSettings.defaults
    settings.connectors.codex.isEnabled = true
    settings.notifications.isEnabled = true
    settings.notifications.providerAlerts.codex.isEnabled = true
    var cache = SnapshotCache.empty
    cache.replaceSnapshots([UsageSnapshotFixture.codexIncludedSample(remaining: 8, utilization: 0.92)], for: .codex, at: Date())
    let delivery = RecordingNotificationDelivery(permissionResult: .granted)
    let vm = StatusViewModel(
        settingsStore: InMemoryAppSettingsStore(data: try! JSONEncoder.prettyStable.encode(settings)),
        cacheStore: InMemorySnapshotCacheStore(data: try! JSONEncoder.cacheEncoder.encode(cache)),
        notificationStateStore: InMemoryNotificationStateStore(data: Data("bad json".utf8)),
        notificationDelivery: delivery
    )

    await vm.loadPersistedState()

    #expect(await delivery.deliveredIntents.isEmpty)
}

@MainActor
@Test func enableNotificationsRequestsPermissionBeforeSavingEnabledState() async {
    let delivery = RecordingNotificationDelivery(permissionResult: .granted)
    let store = InMemoryAppSettingsStore()
    let vm = StatusViewModel(settingsStore: store, notificationDelivery: delivery)

    let result = await vm.setNotificationsEnabled(true)

    #expect(result == .granted)
    #expect(vm.settings.notifications.isEnabled == true)
}

@MainActor
@Test func enableNotificationsPreservesUserDisabledProviderAlerts() async {
    let delivery = RecordingNotificationDelivery(permissionResult: .granted)
    var settings = AppSettings.defaults
    settings.notifications.providerAlerts.claudeCode.isEnabled = false
    settings.notifications.providerAlerts.codex.isEnabled = false
    let vm = StatusViewModel(settings: settings, notificationDelivery: delivery)

    let result = await vm.setNotificationsEnabled(true)

    #expect(result == .granted)
    #expect(vm.settings.notifications.isEnabled == true)
    #expect(vm.settings.notifications.providerAlerts.claudeCode.isEnabled == false)
    #expect(vm.settings.notifications.providerAlerts.codex.isEnabled == false)
}

@MainActor
@Test func deniedNotificationPermissionKeepsNotificationsDisabled() async {
    let delivery = RecordingNotificationDelivery(permissionResult: .denied)
    let vm = StatusViewModel(notificationDelivery: delivery)

    let result = await vm.setNotificationsEnabled(true)

    #expect(result == .denied)
    #expect(vm.settings.notifications.isEnabled == false)
}

@MainActor
@Test func disablingNotificationsDoesNotReportDeniedPermission() async {
    let delivery = RecordingNotificationDelivery(permissionResult: .granted)
    var settings = AppSettings.defaults
    settings.notifications.isEnabled = true
    let vm = StatusViewModel(settings: settings, notificationDelivery: delivery)

    let result = await vm.setNotificationsEnabled(false)

    #expect(result == .notDetermined)
    #expect(vm.settings.notifications.isEnabled == false)
}

@MainActor
@Test func failedRefreshKeepsLastKnownGoodSnapshotsAndStoresSanitizedError() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    var cache = SnapshotCache.empty
    cache.replaceSnapshots([UsageSnapshotFixture.claudeSample()], for: .claude, at: Date(timeIntervalSince1970: 1_000))
    let cacheStore = InMemorySnapshotCacheStore(data: try! JSONEncoder.cacheEncoder.encode(cache))
    let vm = StatusViewModel(
        settings: settings,
        cache: cache,
        claudeRefresher: ThrowingClaudeRefresher(),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        cacheStore: cacheStore,
        now: { Date(timeIntervalSince1970: 2_000) }
    )

    await vm.refreshAll(reason: .manual)
    let persisted = await cacheStore.load()

    #expect(vm.snapshots.map(\.id) == [UsageSnapshotFixture.claudeSample().id])
    #expect(persisted.lastErrorByProvider[CachedProviderID.claude.rawValue]?.code == .network)
    #expect(persisted.lastErrorByProvider[CachedProviderID.claude.rawValue]?.message == "Claude Code usage could not be refreshed")
}

@MainActor
@Test func popoverOpenRefreshRespectsPersistedBackoff() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    var cache = SnapshotCache.empty
    cache.recordFailure(
        for: .claude,
        code: .network,
        message: "Claude Code usage could not be refreshed",
        now: Date(timeIntervalSince1970: 1_000)
    )
    let counter = Counter()
    let vm = StatusViewModel(
        settings: settings,
        cache: cache,
        claudeRefresher: SlowClaudeRefresher(counter: counter),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        now: { Date(timeIntervalSince1970: 1_100) }
    )

    await vm.refreshAll(reason: .popoverOpened)

    #expect(counter.value == 0)
}

@MainActor
@Test func manualRefreshBypassesBackoff() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    var cache = SnapshotCache.empty
    cache.recordFailure(
        for: .claude,
        code: .network,
        message: "Claude Code usage could not be refreshed",
        now: Date(timeIntervalSince1970: 1_000)
    )
    let counter = Counter()
    let vm = StatusViewModel(
        settings: settings,
        cache: cache,
        claudeRefresher: SlowClaudeRefresher(counter: counter),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        now: { Date(timeIntervalSince1970: 1_100) }
    )

    await vm.refreshAll(reason: .manual)

    #expect(counter.value == 1)
}

@MainActor
@Test func repeatedFailuresProgressBackoffToSixtyMinutes() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    let cacheStore = InMemorySnapshotCacheStore()
    let vm = StatusViewModel(
        settings: settings,
        claudeRefresher: ThrowingClaudeRefresher(),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        cacheStore: cacheStore,
        now: { Date(timeIntervalSince1970: 1_000) }
    )

    await vm.refreshAll(reason: .manual)
    await vm.refreshAll(reason: .manual)
    await vm.refreshAll(reason: .manual)
    let cache = await cacheStore.load()
    let error = cache.lastErrorByProvider[CachedProviderID.claude.rawValue]

    #expect(error?.consecutiveFailureCount == 3)
    #expect(error?.nextAutomaticRefreshAt == Date(timeIntervalSince1970: 4_600))
}

private final class FailingSaveNotificationStateStore: NotificationStateStore, @unchecked Sendable {
    private let state: NotificationState

    init(state: NotificationState) {
        self.state = state
    }

    var didFallbackOnLoad: Bool {
        get async { false }
    }

    func load() async -> NotificationState {
        state
    }

    func save(_ state: NotificationState) async -> Bool {
        return false
    }
}

final class FlakyNotificationStateStore: NotificationStateStore, @unchecked Sendable {
    private let lock = NSLock()
    private var failNextSaves: Int
    private var savedState = NotificationState.empty
    private(set) var saveCallCount = 0

    init(failingSaves: Int) {
        self.failNextSaves = failingSaves
    }

    var didFallbackOnLoad: Bool {
        get async { false }
    }

    func load() async -> NotificationState {
        lock.withLock { savedState }
    }

    func save(_ state: NotificationState) async -> Bool {
        lock.withLock {
            saveCallCount += 1
            if failNextSaves > 0 {
                failNextSaves -= 1
                return false
            }
            savedState = state
            return true
        }
    }
}

@MainActor
@Test func notificationStateSaveRetriesAfterTransientFailure() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    settings.notifications.isEnabled = true
    settings.notifications.providerAlerts.claudeCode.isEnabled = true
    let stateStore = FlakyNotificationStateStore(failingSaves: 1)
    let delivery = RecordingNotificationDelivery(permissionResult: .granted)
    var current = Date(timeIntervalSince1970: 1_000)
    let vm = StatusViewModel(
        settings: settings,
        claudeRefresher: SnapshotClaudeRefresher(snapshots: [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 8, utilization: 0.92)
        ]),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        notificationStateStore: stateStore,
        notificationDelivery: delivery,
        now: { current }
    )

    await vm.refreshAll(reason: StatusViewModel.RefreshReason.manual)
    let firstPersisted = await stateStore.load()
    #expect(firstPersisted.records.isEmpty)

    current = Date(timeIntervalSince1970: 1_120)
    await vm.refreshAll(reason: StatusViewModel.RefreshReason.manual)
    let secondPersisted = await stateStore.load()
    #expect(secondPersisted.records.isEmpty == false)
}

@MainActor
@Test func notificationStateSaveDoesNotRetryWithinBackoffWindow() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    settings.notifications.isEnabled = true
    settings.notifications.providerAlerts.claudeCode.isEnabled = true
    let stateStore = FlakyNotificationStateStore(failingSaves: 5)
    let delivery = RecordingNotificationDelivery(permissionResult: .granted)
    var current = Date(timeIntervalSince1970: 1_000)
    let vm = StatusViewModel(
        settings: settings,
        claudeRefresher: SnapshotClaudeRefresher(snapshots: [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 8, utilization: 0.92)
        ]),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        notificationStateStore: stateStore,
        notificationDelivery: delivery,
        now: { current }
    )

    await vm.refreshAll(reason: StatusViewModel.RefreshReason.manual)
    let initialCount = stateStore.saveCallCount
    current = Date(timeIntervalSince1970: 1_010)
    await vm.refreshAll(reason: StatusViewModel.RefreshReason.manual)

    #expect(stateStore.saveCallCount == initialCount)
}

@MainActor
@Test func setShowInDockPersists() async {
    let viewModel = StatusViewModel()

    await viewModel.setShowInDock(false)

    #expect(viewModel.settings.appearance.showInDock == false)
}

@MainActor
@Test func markOnboardingStepRecordsStateButDoesNotFlipFirstLaunchOnPartialProgress() async {
    let viewModel = StatusViewModel()
    #expect(viewModel.settings.onboarding.firstLaunchCompleted == false)

    await viewModel.markOnboardingStep(.connectProviders, as: .done)

    #expect(viewModel.settings.onboarding.steps.connectProviders == .done)
    #expect(viewModel.settings.onboarding.firstLaunchCompleted == false)
}

@MainActor
@Test func bannerDismissAlsoFlipsFirstLaunchCompleted() async {
    let viewModel = StatusViewModel()

    await viewModel.markOnboardingStep(.connectProviders, as: .done)
    await viewModel.markOnboardingStep(.findMenuBar, as: .done)
    await viewModel.markOnboardingStep(.addWidget, as: .done)
    await viewModel.markOnboardingStep(.allowNotifications, as: .done)
    await viewModel.markOnboardingStep(.setHotkey, as: .done)
    await viewModel.markOnboardingStep(.launchAtLogin, as: .done)

    #expect(viewModel.settings.onboarding.firstLaunchCompleted == true)
}

@MainActor
@Test func skipAllFlipsFirstLaunchAndSkipsRemaining() async {
    let viewModel = StatusViewModel()

    await viewModel.skipAllOnboarding()

    #expect(viewModel.settings.onboarding.firstLaunchCompleted == true)
    #expect(viewModel.settings.onboarding.steps.connectProviders == .skipped)
}

@MainActor
@Test func replayOnboardingResetsStepsButLeavesFirstLaunchCompleted() async {
    let viewModel = StatusViewModel()
    await viewModel.skipAllOnboarding()

    await viewModel.replayOnboarding()

    #expect(viewModel.settings.onboarding.firstLaunchCompleted == true)
    #expect(viewModel.settings.onboarding.steps == .allPending)
}

@MainActor
@Test func registerCurrentHotkeyUsesLoadedPersistedCombination() async {
    let registrar = SpyHotkeyRegistrar()
    let hotkeyService = GlobalHotkeyService(registrar: registrar)
    let viewModel = StatusViewModel()
    let custom = HotkeyCombination(modifiers: [.command, .shift], keyCode: 40)
    var settings = viewModel.settings
    settings.hotkey.combination = custom
    await viewModel.saveSettings(settings)
    viewModel.bindHotkeyService(hotkeyService) { }

    await viewModel.registerCurrentHotkey()

    #expect(registrar.lastKeyCode == 40)
    #expect(registrar.lastModifierMask == GlobalHotkeyService.carbonModifierMask(for: [.command, .shift]))
}

@MainActor
private final class SpyHotkeyRegistrar: HotkeyRegistering {
    var lastKeyCode: UInt32?
    var lastModifierMask: UInt32?

    func register(keyCode: UInt32, modifierMask: UInt32, onTrigger: @escaping () -> Void) -> Bool {
        lastKeyCode = keyCode
        lastModifierMask = modifierMask
        return true
    }

    func unregister() { }
}
