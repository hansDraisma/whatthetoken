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
    var launchAtLoginStatusMessage: String?
    private var cache: SnapshotCache
    private var notificationState: NotificationState
    private let settingsStore: AppSettingsStore
    private let cacheStore: SnapshotCacheStore
    private let notificationStateStore: NotificationStateStore
    private let notificationDelivery: NotificationDelivery
    private let launchAtLoginService: LaunchAtLoginServicing
    private let now: @MainActor () -> Date
    private let claudeRefresher: ClaudeConnectorRefreshing?
    private let claudeVersionProvider: ClaudeVersionProviding?
    private let codexRefresher: CodexConnectorRefreshing?
    private(set) var lastClaudeRefreshAt: Date?
    private(set) var lastCodexRefreshAt: Date?
    private(set) var isRefreshAllInFlight = false
    private(set) var hasLoadedPersistedState = false
    private var suppressCacheLoadNotifications = false
    private var lastBackgroundRefreshAtByProvider: [CachedProviderID: Date] = [:]
    private var unsavedNotificationState = false
    private var lastFailedNotificationStateSaveAt: Date?
    var onSettingsChanged: (@MainActor () -> Void)?

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

    var currentDate: Date { now() }

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
        notificationState: NotificationState = .empty,
        notificationStateStore: NotificationStateStore = InMemoryNotificationStateStore(),
        notificationDelivery: NotificationDelivery = RecordingNotificationDelivery(permissionResult: .denied),
        launchAtLoginService: LaunchAtLoginServicing = InMemoryLaunchAtLoginService(),
        now: @escaping @MainActor () -> Date = { Date() },
        connectorState: ClaudeConnectorSetupState = .notConnected,
        connectorStatusMessage: String = "Claude Code is not connected",
        codexConnectorState: CodexConnectorSetupState = .notConnected,
        codexConnectorStatusMessage: String = "Codex is not connected",
        launchAtLoginStatusMessage: String? = nil
    ) {
        self.snapshots = snapshots
        self.settings = settings
        self.cache = cache
        self.claudeRefresher = claudeRefresher
        self.claudeVersionProvider = claudeVersionProvider
        self.codexRefresher = codexRefresher
        self.settingsStore = settingsStore
        self.cacheStore = cacheStore
        self.notificationState = notificationState
        self.notificationStateStore = notificationStateStore
        self.notificationDelivery = notificationDelivery
        self.launchAtLoginService = launchAtLoginService
        self.now = now
        self.connectorState = connectorState
        self.connectorStatusMessage = connectorStatusMessage
        self.codexConnectorState = codexConnectorState
        self.codexConnectorStatusMessage = codexConnectorStatusMessage
        self.launchAtLoginStatusMessage = launchAtLoginStatusMessage
    }

    func loadPersistedState() async {
        settings = await settingsStore.load()
        cache = await cacheStore.load()
        notificationState = await notificationStateStore.load()
        suppressCacheLoadNotifications = await notificationStateStore.didFallbackOnLoad
        applyCachedRefreshTimestamps()
        applyCachedSnapshots()
        applyConnectorStatesFromSettings()
        await evaluateNotifications(suppressDelivery: true)
        hasLoadedPersistedState = true
    }

    func loadPersistedStateIfNeeded() async {
        guard !hasLoadedPersistedState else { return }
        await loadPersistedState()
    }

    @discardableResult
    func setConnector(_ provider: CachedProviderID, enabled: Bool) async -> Bool {
        var nextSettings = settings
        switch provider {
        case .claude:
            nextSettings.connectors.claudeCode.isEnabled = enabled
            nextSettings.connectors.claudeCode.isPaused = false
        case .codex:
            nextSettings.connectors.codex.isEnabled = enabled
            nextSettings.connectors.codex.isPaused = false
        }

        guard await settingsStore.save(nextSettings) else { return false }
        settings = nextSettings
        applyCachedSnapshots()
        applyConnectorStatesFromSettings()
        onSettingsChanged?()
        return true
    }

    @discardableResult
    func setConnector(_ provider: CachedProviderID, paused: Bool) async -> Bool {
        var nextSettings = settings
        switch provider {
        case .claude:
            guard nextSettings.connectors.claudeCode.isEnabled else { return false }
            nextSettings.connectors.claudeCode.isPaused = paused
        case .codex:
            guard nextSettings.connectors.codex.isEnabled else { return false }
            nextSettings.connectors.codex.isPaused = paused
        }

        guard await settingsStore.save(nextSettings) else { return false }
        settings = nextSettings
        applyCachedSnapshots()
        applyConnectorStatesFromSettings()
        onSettingsChanged?()
        return true
    }

    @discardableResult
    func saveSettings(_ newSettings: AppSettings) async -> Bool {
        let previousConnectorSettings = settings.connectors
        guard await settingsStore.save(newSettings) else { return false }
        settings = newSettings
        applyCachedSnapshots()
        if previousConnectorSettings != settings.connectors {
            applyConnectorStatesFromSettings()
        }
        onSettingsChanged?()
        return true
    }

    @discardableResult
    func setNotificationsEnabled(_ enabled: Bool) async -> NotificationAuthorizationStatus {
        if enabled {
            let status = await notificationDelivery.requestAuthorization()
            guard status == .granted else {
                var disabled = settings
                disabled.notifications.isEnabled = false
                _ = await saveSettings(disabled)
                return status
            }
        }

        var nextSettings = settings
        nextSettings.notifications.isEnabled = enabled
        _ = await saveSettings(nextSettings)
        return enabled ? .granted : await notificationDelivery.authorizationStatus()
    }

    @discardableResult
    func setLaunchAtLoginEnabled(_ enabled: Bool) async -> Bool {
        do {
            try launchAtLoginService.setEnabled(enabled)
        } catch {
            launchAtLoginStatusMessage = "Launch at Login could not be updated"
            return false
        }

        var nextSettings = settings
        nextSettings.launchAtLogin.isEnabled = enabled
        guard await settingsStore.save(nextSettings) else {
            try? launchAtLoginService.setEnabled(settings.launchAtLogin.isEnabled)
            launchAtLoginStatusMessage = "Launch at Login could not be saved"
            return false
        }

        settings = nextSettings
        launchAtLoginStatusMessage = nil
        return true
    }

    func disconnect(_ provider: CachedProviderID) async {
        var nextSettings = settings
        switch provider {
        case .claude:
            nextSettings.connectors.claudeCode.isEnabled = false
            nextSettings.connectors.claudeCode.isPaused = false
        case .codex:
            nextSettings.connectors.codex.isEnabled = false
            nextSettings.connectors.codex.isPaused = false
        }

        var nextCache = cache
        nextCache.removeProvider(provider)
        var nextNotificationState = notificationState
        nextNotificationState.records = nextNotificationState.records.filter { $0.value.key.provider != provider }
        guard await cacheStore.save(nextCache) else { return }
        guard await settingsStore.save(nextSettings) else {
            _ = await cacheStore.save(cache)
            return
        }
        guard await notificationStateStore.save(nextNotificationState) else {
            _ = await settingsStore.save(settings)
            _ = await cacheStore.save(cache)
            return
        }

        settings = nextSettings
        cache = nextCache
        notificationState = nextNotificationState
        applyCachedSnapshots()
        applyConnectorStatesFromSettings()
        onSettingsChanged?()
    }

    func connectClaudeCode() async {
        guard connectorState != .checking else { return }

        if !settings.connectors.claudeCode.isEnabled {
            var nextSettings = settings
            nextSettings.connectors.claudeCode.isEnabled = true
            nextSettings.connectors.claudeCode.isPaused = false
            guard await settingsStore.save(nextSettings) else { return }
            settings = nextSettings
            onSettingsChanged?()
            connectorState = .connected
            connectorStatusMessage = ClaudeConnectorSetupCopy.title(for: .connected)
        }

        await refreshClaude(reason: .manual)
    }

    func connectCodex() async {
        guard codexConnectorState != .checking else { return }

        if !settings.connectors.codex.isEnabled {
            var nextSettings = settings
            nextSettings.connectors.codex.isEnabled = true
            nextSettings.connectors.codex.isPaused = false
            guard await settingsStore.save(nextSettings) else { return }
            settings = nextSettings
            onSettingsChanged?()
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
        guard settings.connectors.claudeCode.isEnabled && !settings.connectors.claudeCode.isPaused else { return }
        guard connectorState != .checking else { return }
        if reason == .popoverOpened && recentlyBackgroundRefreshed(.claude) { return }
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
            if reason == .timerTick {
                lastBackgroundRefreshAtByProvider[.claude] = lastClaudeRefreshAt
            }
            await evaluateNotifications(suppressDelivery: false, scopedTo: .claude)
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
        guard settings.connectors.codex.isEnabled && !settings.connectors.codex.isPaused else { return }
        guard codexConnectorState != .checking else { return }
        if reason == .popoverOpened && recentlyBackgroundRefreshed(.codex) { return }
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
            if reason == .timerTick {
                lastBackgroundRefreshAtByProvider[.codex] = lastCodexRefreshAt
            }
            await evaluateNotifications(suppressDelivery: false, scopedTo: .codex)
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
        cacheStore: SnapshotCacheStore = InMemorySnapshotCacheStore(),
        notificationStateStore: NotificationStateStore = InMemoryNotificationStateStore(),
        notificationDelivery: NotificationDelivery = UserNotificationDelivery()
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
            cacheStore: cacheStore,
            notificationStateStore: notificationStateStore,
            notificationDelivery: notificationDelivery,
            launchAtLoginService: SystemLaunchAtLoginService()
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
        let evaluated = cache.snapshotsEvaluatingStaleness(
            now: now(),
            policy: SnapshotStalePolicy.from(settings: settings)
        )
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

    private func evaluateNotifications(
        suppressDelivery: Bool,
        scopedTo scopedProvider: CachedProviderID? = nil
    ) async {
        let previousState = notificationState
        let result = NotificationEvaluator.evaluate(
            snapshots: snapshots,
            settings: settings,
            state: notificationState,
            now: now(),
            suppressDelivery: suppressDelivery || suppressCacheLoadNotifications,
            scopedTo: scopedProvider
        )
        notificationState = result.state
        let stateChanged = result.state != previousState
        let evaluatedAt = now()
        let retryAllowed = lastFailedNotificationStateSaveAt.map { evaluatedAt.timeIntervalSince($0) >= 60 } ?? true
        let shouldAttemptSave = stateChanged || (unsavedNotificationState && retryAllowed)
        if shouldAttemptSave {
            let saved = await notificationStateStore.save(result.state)
            unsavedNotificationState = !saved
            lastFailedNotificationStateSaveAt = saved ? nil : evaluatedAt
        }
        if !result.intents.isEmpty {
            await notificationDelivery.deliver(result.intents)
        }
        suppressCacheLoadNotifications = false
    }

    private func recentlyBackgroundRefreshed(_ provider: CachedProviderID) -> Bool {
        guard let last = lastBackgroundRefreshAtByProvider[provider] else { return false }
        return now().timeIntervalSince(last) < 60
    }

    private func applyConnectorStatesFromSettings() {
        if !settings.connectors.claudeCode.isEnabled {
            connectorState = .notConnected
            connectorStatusMessage = ClaudeConnectorSetupCopy.title(for: .notConnected)
        } else if settings.connectors.claudeCode.isPaused {
            connectorState = .connected
            connectorStatusMessage = "Claude Code paused"
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
        } else if settings.connectors.codex.isPaused {
            codexConnectorState = .connected
            codexConnectorStatusMessage = "Codex paused"
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

@MainActor
private final class InMemoryLaunchAtLoginService: LaunchAtLoginServicing {
    private(set) var isEnabled = false

    func setEnabled(_ enabled: Bool) throws {
        isEnabled = enabled
    }
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
