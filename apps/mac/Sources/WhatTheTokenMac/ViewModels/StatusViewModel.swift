import Foundation
import Observation

@MainActor
@Observable
final class StatusViewModel {
    var snapshots: [UsageSnapshot]
    var settings: AppSettings
    var connectorState: ClaudeConnectorSetupState
    var connectorStatusMessage: String
    var codexConnectorState: CodexConnectorSetupState
    var codexConnectorStatusMessage: String
    private var cache: SnapshotCache
    private let settingsStore: AppSettingsStore
    private let cacheStore: SnapshotCacheStore
    private let now: @MainActor () -> Date
    private let claudeRefresher: ClaudeConnectorRefreshing?
    private let claudeVersionProvider: ClaudeVersionProviding?
    private let codexRefresher: CodexConnectorRefreshing?
    private(set) var lastClaudeRefreshAt: Date?
    private(set) var lastCodexRefreshAt: Date?
    private(set) var isRefreshAllInFlight = false
    private(set) var hasLoadedPersistedState = false

    var isAnyRefreshing: Bool {
        connectorState == .checking
            || codexConnectorState == .checking
            || isRefreshAllInFlight
    }

    var lastUpdatedAt: Date? {
        switch (lastClaudeRefreshAt, lastCodexRefreshAt) {
        case let (claude?, codex?):
            return min(claude, codex)
        case let (claude?, nil):
            return claude
        case let (nil, codex?):
            return codex
        case (nil, nil):
            return nil
        }
    }

    func lastRefreshAt(for tab: ProviderTab) -> Date? {
        switch tab {
        case .claude:
            return lastClaudeRefreshAt
        case .codex:
            return lastCodexRefreshAt
        }
    }

    func isRefreshing(_ tab: ProviderTab) -> Bool {
        switch tab {
        case .claude:
            return connectorState == .checking
        case .codex:
            return codexConnectorState == .checking
        }
    }

    #if DEBUG
    func testSet_lastClaudeRefreshAt(_ date: Date?) { lastClaudeRefreshAt = date }
    func testSet_lastCodexRefreshAt(_ date: Date?) { lastCodexRefreshAt = date }
    func testSet_isRefreshAllInFlight(_ value: Bool) { isRefreshAllInFlight = value }
    func testSet_connectorStateToChecking() { connectorState = .checking }
    func testSet_codexConnectorStateToChecking() { codexConnectorState = .checking }
    #endif

    enum RefreshReason: Equatable, Sendable {
        case popoverOpened
        case manual
        case timerTick
        case retry
    }

    var snapshotSections: [UsageSnapshotSection] {
        Self.snapshotSections(for: snapshots)
    }

    init(
        snapshots: [UsageSnapshot] = [],
        settings: AppSettings = .defaults,
        cache: SnapshotCache = .empty,
        claudeRefresher: ClaudeConnectorRefreshing? = nil,
        claudeVersionProvider: ClaudeVersionProviding? = nil,
        codexRefresher: CodexConnectorRefreshing? = nil,
        settingsStore: AppSettingsStore = InMemoryAppSettingsStore(),
        cacheStore: SnapshotCacheStore = InMemorySnapshotCacheStore(),
        now: @escaping @MainActor () -> Date = { Date() },
        connectorState: ClaudeConnectorSetupState = .notConnected,
        connectorStatusMessage: String = "Claude Code is not connected",
        codexConnectorState: CodexConnectorSetupState = .notConnected,
        codexConnectorStatusMessage: String = "Codex is not connected"
    ) {
        self.snapshots = snapshots
        self.settings = settings
        self.cache = cache
        self.claudeRefresher = claudeRefresher
        self.claudeVersionProvider = claudeVersionProvider
        self.codexRefresher = codexRefresher
        self.settingsStore = settingsStore
        self.cacheStore = cacheStore
        self.now = now
        self.connectorState = connectorState
        self.connectorStatusMessage = connectorStatusMessage
        self.codexConnectorState = codexConnectorState
        self.codexConnectorStatusMessage = codexConnectorStatusMessage
    }

    func loadPersistedState() async {
        settings = await settingsStore.load()
        cache = await cacheStore.load()
        applyCachedRefreshTimestamps()
        applyCachedSnapshots()
        applyConnectorStatesFromSettings()
        hasLoadedPersistedState = true
    }

    func loadPersistedStateIfNeeded() async {
        guard !hasLoadedPersistedState else { return }
        await loadPersistedState()
    }

    func setConnector(_ provider: CachedProviderID, enabled: Bool) async {
        switch provider {
        case .claude:
            settings.connectors.claudeCode.isEnabled = enabled
        case .codex:
            settings.connectors.codex.isEnabled = enabled
        }

        await settingsStore.save(settings)
        applyCachedSnapshots()
        applyConnectorStatesFromSettings()
    }

    func saveSettings(_ newSettings: AppSettings) async {
        let previousConnectorSettings = settings.connectors
        settings = newSettings
        await settingsStore.save(settings)
        applyCachedSnapshots()
        if previousConnectorSettings != settings.connectors {
            applyConnectorStatesFromSettings()
        }
    }

    func disconnect(_ provider: CachedProviderID) async {
        var nextCache = cache
        nextCache.removeProvider(provider)
        guard await cacheStore.save(nextCache) else { return }
        cache = nextCache
        await setConnector(provider, enabled: false)
        applyCachedSnapshots()
        applyConnectorStatesFromSettings()
    }

    func connectClaudeCode() async {
        guard connectorState != .checking else { return }

        if !settings.connectors.claudeCode.isEnabled {
            settings.connectors.claudeCode.isEnabled = true
            await settingsStore.save(settings)
            connectorState = .connected
            connectorStatusMessage = ClaudeConnectorSetupCopy.title(for: .connected)
        }

        await refreshClaude(reason: .manual)
    }

    func connectCodex() async {
        guard codexConnectorState != .checking else { return }

        if !settings.connectors.codex.isEnabled {
            settings.connectors.codex.isEnabled = true
            await settingsStore.save(settings)
            codexConnectorState = .connected
            codexConnectorStatusMessage = CodexConnectorSetupCopy.title(for: .connected)
        }

        await refreshCodex(reason: .manual)
    }

    func refreshAll(reason: RefreshReason) async {
        guard !isRefreshAllInFlight else { return }
        isRefreshAllInFlight = true
        defer { isRefreshAllInFlight = false }

        await refreshClaude(reason: reason)
        guard !Task.isCancelled else { return }
        await refreshCodex(reason: reason)
    }

    private func refreshClaude(reason: RefreshReason) async {
        guard settings.connectors.claudeCode.isEnabled else { return }
        guard connectorState != .checking else { return }
        guard reason.isManual || cache.allowsAutomaticRefresh(for: .claude, now: now()) else { return }

        if let claudeVersionProvider, claudeVersionProvider.claudeVersion == "unknown" {
            replaceSnapshots(matching: CachedProviderID.claude.snapshotPredicate, with: [])
            cache.removeProvider(.claude)
            _ = await cacheStore.save(cache)
            connectorState = .missingClaudeCli
            connectorStatusMessage = ClaudeConnectorSetupCopy.title(for: .missingClaudeCli)
            lastClaudeRefreshAt = now()
            return
        }

        let previousState = connectorState
        let previousMessage = connectorStatusMessage
        connectorState = .checking
        connectorStatusMessage = "Checking Claude Code"

        do {
            let result = try await requireClaudeRefreshResult()
            guard !Task.isCancelled else {
                connectorState = previousState
                connectorStatusMessage = previousMessage
                return
            }

            replaceSnapshots(matching: CachedProviderID.claude.snapshotPredicate, with: result.snapshots)
            connectorState = Self.setupState(for: result.status.source.state)
            connectorStatusMessage = result.status.message
            lastClaudeRefreshAt = now()
            cache.replaceSnapshots(result.snapshots, for: .claude, at: lastClaudeRefreshAt!)
            _ = await cacheStore.save(cache)
        } catch {
            guard !Task.isCancelled else {
                connectorState = previousState
                connectorStatusMessage = previousMessage
                return
            }

            connectorState = .networkError
            connectorStatusMessage = "Claude Code usage could not be refreshed"
            cache.recordFailure(for: .claude, code: .network, message: connectorStatusMessage, now: now())
            _ = await cacheStore.save(cache)
            applyCachedSnapshots()
        }
    }

    private func refreshCodex(reason: RefreshReason) async {
        guard settings.connectors.codex.isEnabled else { return }
        guard codexConnectorState != .checking else { return }
        guard reason.isManual || cache.allowsAutomaticRefresh(for: .codex, now: now()) else { return }

        let previousState = codexConnectorState
        let previousMessage = codexConnectorStatusMessage
        codexConnectorState = .checking
        codexConnectorStatusMessage = "Checking Codex"

        do {
            let result = try await requireCodexRefreshResult()
            guard !Task.isCancelled else {
                codexConnectorState = previousState
                codexConnectorStatusMessage = previousMessage
                return
            }

            replaceSnapshots(matching: CachedProviderID.codex.snapshotPredicate, with: result.snapshots)
            codexConnectorState = Self.codexSetupState(for: result.status.source.state)
            codexConnectorStatusMessage = result.status.message
            lastCodexRefreshAt = now()
            cache.replaceSnapshots(result.snapshots, for: .codex, at: lastCodexRefreshAt!)
            _ = await cacheStore.save(cache)
        } catch {
            guard !Task.isCancelled else {
                codexConnectorState = previousState
                codexConnectorStatusMessage = previousMessage
                return
            }

            codexConnectorState = .networkError
            codexConnectorStatusMessage = "Codex usage could not be refreshed"
            cache.recordFailure(for: .codex, code: .network, message: codexConnectorStatusMessage, now: now())
            _ = await cacheStore.save(cache)
            applyCachedSnapshots()
        }
    }

    private func requireClaudeRefreshResult() async throws -> ClaudeConnectorResult {
        guard let claudeRefresher else {
            return ClaudeConnectorResult(
                snapshots: [],
                status: ConnectorStatus(
                    product: "claude_code",
                    source: ConnectorSource(
                        connector: "claude_code",
                        state: .notConnected,
                        label: "Claude Code",
                        parserVersion: "unknown",
                        deviceId: "local_mac"
                    ),
                    message: "Claude Code is not connected"
                )
            )
        }

        return try await claudeRefresher.refresh()
    }

    private func requireCodexRefreshResult() async throws -> CodexConnectorResult {
        guard let codexRefresher else {
            return CodexConnectorResult(
                snapshots: [],
                status: ConnectorStatus(
                    product: "codex",
                    source: ConnectorSource(
                        connector: "codex",
                        state: .notConnected,
                        label: "Codex",
                        parserVersion: "unknown",
                        deviceId: "local_mac"
                    ),
                    message: "Codex is not connected"
                )
            )
        }

        return try await codexRefresher.refresh()
    }

    nonisolated static func loadFixtureData() throws -> Data {
        guard let url = Bundle.module.url(forResource: "usage-snapshot.fixture", withExtension: "json") else {
            throw FixtureError.missingFixture
        }

        return try Data(contentsOf: url)
    }

    nonisolated static func loadFixtureSnapshot() throws -> UsageSnapshot {
        let data = try loadFixtureData()
        return try JSONDecoder().decode(UsageSnapshot.self, from: data)
    }

    static func fixture() -> StatusViewModel {
        do {
            return StatusViewModel(snapshots: [try loadFixtureSnapshot()])
        } catch {
            return StatusViewModel(snapshots: [])
        }
    }

    static func live(
        settingsStore: AppSettingsStore = InMemoryAppSettingsStore(),
        cacheStore: SnapshotCacheStore = InMemorySnapshotCacheStore()
    ) -> StatusViewModel {
        let versionProvider = InstalledClaudeVersionProvider()
        return StatusViewModel(
            claudeRefresher: ClaudeConnectorService(
                settings: ClaudeConnectorSettings(isEnabled: true),
                credentialStore: MacOSClaudeCredentialStore(),
                usageFetcher: ClaudeUsageClient(),
                claudeVersionProvider: versionProvider,
                deviceId: "local_mac",
                userAccountId: "local_user",
                now: { ISO8601DateFormatter().string(from: Date()) }
            ),
            claudeVersionProvider: versionProvider,
            codexRefresher: CodexConnectorService(
                settings: CodexConnectorSettings(isEnabled: true),
                rateLimitsFetcher: CodexAppServerClient(transport: LiveCodexAppServerTransport()),
                deviceId: "local_mac",
                userAccountId: "local_user",
                now: { ISO8601DateFormatter().string(from: Date()) }
            ),
            settingsStore: settingsStore,
            cacheStore: cacheStore
        )
    }

    private static func setupState(for sourceState: ConnectorSourceState) -> ClaudeConnectorSetupState {
        switch sourceState {
        case .connected:
            return .connected
        case .missingCredentials:
            return .missingCredentials
        case .tokenInvalid, .permissionDenied:
            return .tokenInvalid
        case .rateLimited:
            return .rateLimited
        case .schemaChanged:
            return .schemaChanged
        case .networkError:
            return .networkError
        case .notConnected, .stale:
            return .notConnected
        }
    }

    private static func codexSetupState(for sourceState: ConnectorSourceState) -> CodexConnectorSetupState {
        switch sourceState {
        case .connected:
            return .connected
        case .missingCredentials, .tokenInvalid:
            return .missingCredentials
        case .permissionDenied:
            return .permissionDenied
        case .schemaChanged:
            return .schemaChanged
        case .networkError, .rateLimited:
            return .networkError
        case .notConnected, .stale:
            return .notConnected
        }
    }

    private func replaceSnapshots(
        matching predicate: (UsageSnapshot) -> Bool,
        with replacement: [UsageSnapshot]
    ) {
        snapshots = snapshots.filter { !predicate($0) } + replacement
    }

    private func applyCachedSnapshots() {
        let evaluated = cache.snapshotsEvaluatingStaleness(now: now())
        snapshots = evaluated.filter { snapshot in
            if CachedProviderID.claude.snapshotPredicate(snapshot) {
                return settings.connectors.claudeCode.isEnabled
            }
            if CachedProviderID.codex.snapshotPredicate(snapshot) {
                return settings.connectors.codex.isEnabled
            }
            return false
        }
    }

    private func applyCachedRefreshTimestamps() {
        lastClaudeRefreshAt = settings.connectors.claudeCode.isEnabled
            ? cache.lastSuccessfulRefreshAtByProvider[CachedProviderID.claude.rawValue]
            : nil
        lastCodexRefreshAt = settings.connectors.codex.isEnabled
            ? cache.lastSuccessfulRefreshAtByProvider[CachedProviderID.codex.rawValue]
            : nil
    }

    private func applyConnectorStatesFromSettings() {
        if !settings.connectors.claudeCode.isEnabled {
            connectorState = .notConnected
            connectorStatusMessage = ClaudeConnectorSetupCopy.title(for: .notConnected)
        } else if let error = cache.lastErrorByProvider[CachedProviderID.claude.rawValue] {
            connectorState = error.code == .schemaChanged ? .schemaChanged : .networkError
            connectorStatusMessage = error.message
        } else {
            connectorState = .connected
            connectorStatusMessage = ClaudeConnectorSetupCopy.title(for: .connected)
        }

        if !settings.connectors.codex.isEnabled {
            codexConnectorState = .notConnected
            codexConnectorStatusMessage = CodexConnectorSetupCopy.title(for: .notConnected)
        } else if let error = cache.lastErrorByProvider[CachedProviderID.codex.rawValue] {
            codexConnectorState = error.code == .schemaChanged ? .schemaChanged : .networkError
            codexConnectorStatusMessage = error.message
        } else {
            codexConnectorState = .connected
            codexConnectorStatusMessage = CodexConnectorSetupCopy.title(for: .connected)
        }
    }

    private static func snapshotSections(for snapshots: [UsageSnapshot]) -> [UsageSnapshotSection] {
        var order: [String] = []
        var grouped: [String: [UsageSnapshot]] = [:]

        for snapshot in snapshots {
            let id = "\(snapshot.provider)_\(snapshot.product)"
            if grouped[id] == nil {
                order.append(id)
                grouped[id] = []
            }

            grouped[id]?.append(snapshot)
        }

        return order.compactMap { id in
            guard let snapshots = grouped[id] else {
                return nil
            }

            return UsageSnapshotSection(id: id, snapshots: snapshots)
        }
    }
}

enum FixtureError: Error {
    case missingFixture
}

extension StatusViewModel.RefreshReason {
    var isManual: Bool {
        switch self {
        case .manual, .retry:
            return true
        case .popoverOpened, .timerTick:
            return false
        }
    }
}

struct UsageSnapshotSection: Identifiable, Equatable, Sendable {
    let id: String
    let snapshots: [UsageSnapshot]
}

enum ClaudeConnectorSetupState: Equatable, Sendable {
    case notConnected
    case checking
    case connected
    case missingCredentials
    case missingClaudeCli
    case tokenInvalid
    case rateLimited
    case networkError
    case schemaChanged
}

enum ClaudeConnectorSetupCopy {
    static let trustMessage = "Reads Claude Code credentials locally only after you connect."

    static func title(for state: ClaudeConnectorSetupState) -> String {
        switch state {
        case .notConnected:
            return "Claude Code is not connected"
        case .checking:
            return "Checking Claude Code"
        case .connected:
            return "Claude Code connected"
        case .missingCredentials:
            return "Claude Code credentials were not found"
        case .missingClaudeCli:
            return "Claude Code CLI was not found"
        case .tokenInvalid:
            return "Claude Code credentials are invalid"
        case .rateLimited:
            return "Claude usage is rate limited"
        case .networkError:
            return "Claude Code usage could not be refreshed"
        case .schemaChanged:
            return "Claude usage response changed"
        }
    }
}

enum CodexConnectorSetupState: Equatable, Sendable {
    case notConnected
    case checking
    case connected
    case missingCredentials
    case permissionDenied
    case networkError
    case schemaChanged
}

enum CodexConnectorSetupCopy {
    static let trustMessage = "Codex auth stays inside Codex. WhatTheToken reads only local rate-limit status after you connect."

    static func title(for state: CodexConnectorSetupState) -> String {
        switch state {
        case .notConnected:
            return "Codex is not connected"
        case .checking:
            return "Checking Codex"
        case .connected:
            return "Codex connected"
        case .missingCredentials:
            return "Sign in to Codex locally"
        case .permissionDenied:
            return "Codex app-server could not be started"
        case .networkError:
            return "Codex usage could not be refreshed"
        case .schemaChanged:
            return "Codex usage response changed"
        }
    }
}
