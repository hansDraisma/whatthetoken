import Foundation
import Testing
@testable import WhatTheTokenMac

@MainActor
@Test func liveViewModelDoesNotRefreshClaudeConnectorOnInit() {
    let refresher = CountingClaudeConnectorRefresher(result: .success(.connected()))
    let viewModel = StatusViewModel(claudeRefresher: refresher)

    #expect(refresher.refreshCount == 0)
    #expect(viewModel.connectorState == .notConnected)
    #expect(viewModel.snapshots.isEmpty)
}

@MainActor
@Test func liveFactoryStartsDisconnectedWithoutSnapshots() {
    let viewModel = StatusViewModel.live()

    #expect(viewModel.connectorState == .notConnected)
    #expect(viewModel.connectorStatusMessage == "Claude Code is not connected")
    #expect(viewModel.snapshots.isEmpty)
}

@MainActor
@Test func connectClaudeCodeLoadsSnapshotsAfterUserAction() async {
    let result = ClaudeConnectorResult.connected(snapshots: [.claudeUsage()])
    let refresher = CountingClaudeConnectorRefresher(result: .success(result))
    let viewModel = StatusViewModel(claudeRefresher: refresher)

    await viewModel.connectClaudeCode()

    #expect(refresher.refreshCount == 1)
    #expect(viewModel.connectorState == .connected)
    #expect(viewModel.snapshots.count == 1)
    #expect(viewModel.connectorStatusMessage == "Claude Code connected")
}

@MainActor
@Test func missingCredentialsShowsStatusWithoutSnapshots() async {
    let refresher = CountingClaudeConnectorRefresher(result: .success(.missingCredentials()))
    let viewModel = StatusViewModel(claudeRefresher: refresher)

    await viewModel.connectClaudeCode()

    #expect(refresher.refreshCount == 1)
    #expect(viewModel.connectorState == .missingCredentials)
    #expect(viewModel.snapshots.isEmpty)
    #expect(viewModel.connectorStatusMessage == "Claude Code credentials were not found")
}

@MainActor
@Test func thrownRefreshErrorShowsSanitizedNetworkError() async {
    let refresher = CountingClaudeConnectorRefresher(result: .failure(SyntheticRefreshError()))
    let viewModel = StatusViewModel(claudeRefresher: refresher)

    await viewModel.connectClaudeCode()

    #expect(refresher.refreshCount == 1)
    #expect(viewModel.connectorState == .networkError)
    #expect(viewModel.connectorStatusMessage == "Claude Code usage could not be refreshed")
    #expect(!viewModel.connectorStatusMessage.contains(SyntheticRefreshError.description))
}

@MainActor
@Test func duplicateConnectsWhileCheckingStartOnlyOneRefresh() async {
    let refresher = SuspendedClaudeConnectorRefresher(result: .connected(snapshots: [.claudeUsage()]))
    let viewModel = StatusViewModel(claudeRefresher: refresher)

    let firstConnect = Task {
        await viewModel.connectClaudeCode()
    }
    await refresher.waitForRefreshCount(1)

    let secondConnect = Task {
        await viewModel.connectClaudeCode()
    }
    await Task.yield()

    #expect(refresher.refreshCount == 1)

    refresher.complete()
    await firstConnect.value
    await secondConnect.value
}

@Test func connectorSetupCopyCoversProductStates() {
    #expect(ClaudeConnectorSetupCopy.title(for: .notConnected) == "Claude Code is not connected")
    #expect(ClaudeConnectorSetupCopy.title(for: .checking) == "Checking Claude Code")
    #expect(ClaudeConnectorSetupCopy.title(for: .connected) == "Claude Code connected")
    #expect(ClaudeConnectorSetupCopy.title(for: .missingCredentials) == "Claude Code credentials were not found")
    #expect(ClaudeConnectorSetupCopy.title(for: .missingClaudeCli) == "Claude Code CLI was not found")
    #expect(ClaudeConnectorSetupCopy.title(for: .tokenInvalid) == "Claude Code credentials are invalid")
    #expect(ClaudeConnectorSetupCopy.title(for: .sessionExpired) == "Claude Code session expired")
    #expect(ClaudeConnectorSetupCopy.title(for: .rateLimited) == "Claude usage is rate limited")
    #expect(ClaudeConnectorSetupCopy.title(for: .networkError) == "Claude Code usage could not be refreshed")
    #expect(ClaudeConnectorSetupCopy.title(for: .schemaChanged) == "Claude usage response changed")
    #expect(ClaudeConnectorSetupCopy.trustMessage == "Reads Claude Code credentials locally only after you connect.")
}

@Test func sessionExpiredActionTitleIsRetry() {
    #expect(claudeActionTitle(for: .sessionExpired) == "Retry")
}

@MainActor
@Test func sessionExpiredResultSurfacesSessionExpiredState() async {
    let refresher = CountingClaudeConnectorRefresher(result: .success(.sessionExpired()))
    let viewModel = StatusViewModel(claudeRefresher: refresher)

    await viewModel.connectClaudeCode()

    #expect(viewModel.connectorState == .sessionExpired)
    #expect(viewModel.connectorStatusMessage == "Claude Code session expired")

    let tabModel = ProviderTabModel.from(viewModel: viewModel, tab: .claude)
    #expect(tabModel.body == .disconnected(reason: .claude(.sessionExpired)))
}

@MainActor
@Test func sessionExpiredDoesNotStampASuccessfulRefreshTimestamp() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    let previousRefreshAt = Date(timeIntervalSince1970: 1_000)
    let failedAt = Date(timeIntervalSince1970: 2_000)
    var cache = SnapshotCache.empty
    cache.replaceSnapshots([.claudeUsage()], for: .claude, at: previousRefreshAt)
    let cacheStore = InMemorySnapshotCacheStore(
        data: try! JSONEncoder.cacheEncoder.encode(cache)
    )
    let refresher = CountingClaudeConnectorRefresher(result: .success(.sessionExpired()))
    let viewModel = StatusViewModel(
        snapshots: [.claudeUsage()],
        settings: settings,
        cache: cache,
        claudeRefresher: refresher,
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        cacheStore: cacheStore,
        now: { failedAt }
    )
    viewModel.testSet_lastClaudeRefreshAt(previousRefreshAt)

    await viewModel.refreshAll(reason: .manual)
    let persisted = await cacheStore.load()

    #expect(viewModel.lastClaudeRefreshAt == previousRefreshAt)
    #expect(viewModel.snapshots.map(\.id) == [UsageSnapshot.claudeUsage().id])
    #expect(
        persisted.lastSuccessfulRefreshAtByProvider[CachedProviderID.claude.rawValue]
            == previousRefreshAt
    )
    #expect(
        persisted.lastErrorByProvider[CachedProviderID.claude.rawValue]?.code
            == .sessionExpired
    )
}

@MainActor
@Test func persistedSessionExpiredErrorRestoresSessionExpiredStateNotConnected() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    var cache = SnapshotCache.empty
    cache.recordFailure(
        for: .claude,
        code: .sessionExpired,
        message: "Claude Code session expired",
        now: Date(timeIntervalSince1970: 1_000)
    )
    let viewModel = StatusViewModel(
        settingsStore: InMemoryAppSettingsStore(
            data: try! JSONEncoder.prettyStable.encode(settings)
        ),
        cacheStore: InMemorySnapshotCacheStore(
            data: try! JSONEncoder.cacheEncoder.encode(cache)
        )
    )

    await viewModel.loadPersistedState()

    #expect(viewModel.connectorState == .sessionExpired)
    #expect(viewModel.connectorStatusMessage == "Claude Code session expired")
}

@MainActor
@Test func persistedMissingCredentialsRestoresMissingCredentialsNotTokenInvalid() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    let settingsStore = InMemoryAppSettingsStore(
        data: try! JSONEncoder.prettyStable.encode(settings)
    )
    let cacheStore = InMemorySnapshotCacheStore()
    let firstViewModel = StatusViewModel(
        settings: settings,
        claudeRefresher: CountingClaudeConnectorRefresher(
            result: .success(.missingCredentials())
        ),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        settingsStore: settingsStore,
        cacheStore: cacheStore
    )

    await firstViewModel.refreshAll(reason: .manual)

    let restoredViewModel = StatusViewModel(
        settingsStore: settingsStore,
        cacheStore: cacheStore
    )
    await restoredViewModel.loadPersistedState()

    #expect(restoredViewModel.connectorState == .missingCredentials)
    #expect(
        restoredViewModel.connectorStatusMessage
            == "Claude Code credentials were not found"
    )
}

@MainActor
@Test func persistedMissingClaudeCLIRestoresMissingClaudeCLINotTokenInvalid() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    let settingsStore = InMemoryAppSettingsStore(
        data: try! JSONEncoder.prettyStable.encode(settings)
    )
    let cacheStore = InMemorySnapshotCacheStore()
    let firstViewModel = StatusViewModel(
        settings: settings,
        claudeRefresher: CountingClaudeConnectorRefresher(result: .success(.connected())),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "unknown"),
        settingsStore: settingsStore,
        cacheStore: cacheStore
    )

    await firstViewModel.refreshAll(reason: .manual)

    let restoredViewModel = StatusViewModel(
        settingsStore: settingsStore,
        cacheStore: cacheStore
    )
    await restoredViewModel.loadPersistedState()

    #expect(restoredViewModel.connectorState == .missingClaudeCli)
    #expect(restoredViewModel.connectorStatusMessage == "Claude Code CLI was not found")
}

@MainActor
@Test func persistedRateLimitRestoresRateLimitedNotNetworkError() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    let settingsStore = InMemoryAppSettingsStore(
        data: try! JSONEncoder.prettyStable.encode(settings)
    )
    let cacheStore = InMemorySnapshotCacheStore()
    let firstViewModel = StatusViewModel(
        settings: settings,
        claudeRefresher: CountingClaudeConnectorRefresher(
            result: .success(.rateLimited())
        ),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        settingsStore: settingsStore,
        cacheStore: cacheStore
    )

    await firstViewModel.refreshAll(reason: .manual)

    let restoredViewModel = StatusViewModel(
        settingsStore: settingsStore,
        cacheStore: cacheStore
    )
    await restoredViewModel.loadPersistedState()

    #expect(restoredViewModel.connectorState == .rateLimited)
    #expect(restoredViewModel.connectorStatusMessage == "Claude usage is rate limited")
}

@MainActor
@Test func connectClaudeCodeFailsBeforeCredentialReadWhenCliVersionIsUnknown() async {
    let refresher = CountingClaudeConnectorRefresher(result: .success(.connected()))
    let viewModel = StatusViewModel(
        claudeRefresher: refresher,
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "unknown")
    )

    await viewModel.connectClaudeCode()

    #expect(refresher.refreshCount == 0)
    #expect(viewModel.connectorState == .missingClaudeCli)
    #expect(viewModel.connectorStatusMessage == "Claude Code CLI was not found")
    #expect(viewModel.snapshots.isEmpty)
}

private final class CountingClaudeConnectorRefresher: ClaudeConnectorRefreshing, @unchecked Sendable {
    private let lock = NSLock()
    private var storedRefreshCount = 0
    let result: Result<ClaudeConnectorResult, Error>

    var refreshCount: Int {
        lock.withLock {
            storedRefreshCount
        }
    }

    init(result: Result<ClaudeConnectorResult, Error>) {
        self.result = result
    }

    func refresh() async throws -> ClaudeConnectorResult {
        lock.withLock {
            storedRefreshCount += 1
        }

        return try result.get()
    }
}

private final class SuspendedClaudeConnectorRefresher: ClaudeConnectorRefreshing, @unchecked Sendable {
    private let lock = NSLock()
    private let result: ClaudeConnectorResult
    private var storedRefreshCount = 0
    private var refreshWaiters: [CheckedContinuation<Void, Never>] = []
    private var completions: [CheckedContinuation<ClaudeConnectorResult, Never>] = []

    init(result: ClaudeConnectorResult) {
        self.result = result
    }

    var refreshCount: Int {
        lock.withLock {
            storedRefreshCount
        }
    }

    func refresh() async throws -> ClaudeConnectorResult {
        await withCheckedContinuation { continuation in
            let waiters: [CheckedContinuation<Void, Never>] = lock.withLock {
                storedRefreshCount += 1
                completions.append(continuation)
                let waiters = refreshWaiters
                refreshWaiters = []
                return waiters
            }

            for waiter in waiters {
                waiter.resume()
            }
        }
    }

    func waitForRefreshCount(_ count: Int) async {
        if refreshCount >= count {
            return
        }

        await withCheckedContinuation { continuation in
            let shouldResume = lock.withLock {
                if storedRefreshCount >= count {
                    return true
                }

                refreshWaiters.append(continuation)
                return false
            }

            if shouldResume {
                continuation.resume()
            }
        }
    }

    func complete() {
        let completions: [CheckedContinuation<ClaudeConnectorResult, Never>] = lock.withLock {
            let completions = self.completions
            self.completions = []
            return completions
        }

        for completion in completions {
            completion.resume(returning: result)
        }
    }
}

private struct SyntheticRefreshError: Error, CustomStringConvertible {
    static let description = "synthetic refresh failure with provider details"

    var description: String {
        Self.description
    }
}

private extension ClaudeConnectorResult {
    static func connected(snapshots: [UsageSnapshot] = []) -> ClaudeConnectorResult {
        let source = ConnectorSource.claude(state: .connected)
        return ClaudeConnectorResult(
            snapshots: snapshots,
            status: ConnectorStatus(
                product: "claude_code",
                source: source,
                message: "Claude Code connected"
            )
        )
    }

    static func missingCredentials() -> ClaudeConnectorResult {
        let source = ConnectorSource.claude(state: .missingCredentials)
        return ClaudeConnectorResult(
            snapshots: [],
            status: ConnectorStatus(
                product: "claude_code",
                source: source,
                message: "Claude Code credentials were not found"
            )
        )
    }

    static func sessionExpired() -> ClaudeConnectorResult {
        let source = ConnectorSource.claude(state: .sessionExpired)
        return ClaudeConnectorResult(
            snapshots: [],
            status: ConnectorStatus(
                product: "claude_code",
                source: source,
                message: "Claude Code session expired"
            )
        )
    }

    static func rateLimited() -> ClaudeConnectorResult {
        let source = ConnectorSource.claude(state: .rateLimited)
        return ClaudeConnectorResult(
            snapshots: [],
            status: ConnectorStatus(
                product: "claude_code",
                source: source,
                message: "Claude usage is rate limited"
            )
        )
    }
}

private extension UsageSnapshot {
    static func claudeUsage() -> UsageSnapshot {
        UsageSnapshot(
            id: "snap_claude_five_hour",
            userAccountId: "local_user",
            provider: "anthropic",
            product: "claude_code",
            surface: "cli",
            poolKey: "anthropic_claude_subscription",
            windowKey: "five_hour",
            unit: "utilization",
            used: 42.5,
            limit: 100,
            remaining: 57.5,
            utilization: 0.425,
            resetAt: "2026-05-04T15:00:00Z",
            lastUpdatedAt: "2026-05-04T10:00:00.000Z",
            confidence: "verified",
            undercountRisk: "possible",
            staleReason: nil,
            display: nil,
            source: .claude(state: .connected)
        )
    }
}

private extension ConnectorSource {
    static func claude(state: ConnectorSourceState) -> ConnectorSource {
        ConnectorSource(
            connector: "mac_connector",
            state: state,
            label: "Mac connector",
            parserVersion: "claude-code-oauth-usage-v1",
            deviceId: "device_mac_01"
        )
    }
}
