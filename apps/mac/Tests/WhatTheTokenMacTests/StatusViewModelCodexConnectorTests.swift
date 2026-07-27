import Foundation
import Testing
@testable import WhatTheTokenMac

@MainActor
@Test func liveViewModelDoesNotRefreshCodexConnectorOnInit() {
    let refresher = CountingCodexConnectorRefresher(result: .success(.connected(snapshots: [.codexUsage()])))
    let viewModel = StatusViewModel(codexRefresher: refresher)

    #expect(refresher.refreshCount == 0)
    #expect(viewModel.codexConnectorState == .notConnected)
    #expect(viewModel.snapshots.isEmpty)
}

@MainActor
@Test func connectCodexLoadsSnapshotsAfterUserAction() async {
    let result = CodexConnectorResult.connected(snapshots: [.codexUsage()])
    let refresher = CountingCodexConnectorRefresher(result: .success(result))
    let viewModel = StatusViewModel(codexRefresher: refresher)

    await viewModel.connectCodex()

    #expect(refresher.refreshCount == 1)
    #expect(viewModel.codexConnectorState == .connected)
    #expect(viewModel.snapshots.count == 1)
    #expect(viewModel.codexConnectorStatusMessage == "Codex connected")
}

@MainActor
@Test func codexAuthRequiredShowsCodexLoginCopyWithoutSnapshots() async {
    let refresher = CountingCodexConnectorRefresher(result: .success(.missingCredentials()))
    let viewModel = StatusViewModel(codexRefresher: refresher)

    await viewModel.connectCodex()

    #expect(refresher.refreshCount == 1)
    #expect(viewModel.codexConnectorState == .missingCredentials)
    #expect(viewModel.snapshots.isEmpty)
    #expect(viewModel.codexConnectorStatusMessage == "Sign in to Codex locally")
}

@MainActor
@Test func thrownCodexRefreshErrorShowsSanitizedNetworkError() async {
    let refresher = CountingCodexConnectorRefresher(result: .failure(SyntheticCodexRefreshError()))
    let viewModel = StatusViewModel(codexRefresher: refresher)

    await viewModel.connectCodex()

    #expect(refresher.refreshCount == 1)
    #expect(viewModel.codexConnectorState == .networkError)
    #expect(viewModel.codexConnectorStatusMessage == "Codex usage could not be refreshed")
    #expect(!viewModel.codexConnectorStatusMessage.contains(SyntheticCodexRefreshError.description))
}

@MainActor
@Test func persistedCodexPermissionDeniedRestoresPermissionDeniedNotMissingCredentials() async {
    var settings = AppSettings.defaults
    settings.connectors.codex.isEnabled = true
    let settingsStore = InMemoryAppSettingsStore(
        data: try! JSONEncoder.prettyStable.encode(settings)
    )
    let cacheStore = InMemorySnapshotCacheStore()
    let firstViewModel = StatusViewModel(
        settings: settings,
        codexRefresher: CountingCodexConnectorRefresher(
            result: .success(.permissionDenied())
        ),
        settingsStore: settingsStore,
        cacheStore: cacheStore
    )

    await firstViewModel.refreshAll(reason: .manual)

    let restoredViewModel = StatusViewModel(
        settingsStore: settingsStore,
        cacheStore: cacheStore
    )
    await restoredViewModel.loadPersistedState()

    #expect(restoredViewModel.codexConnectorState == .permissionDenied)
    #expect(
        restoredViewModel.codexConnectorStatusMessage
            == "Codex app-server could not be started"
    )
}

@MainActor
@Test func duplicateCodexConnectsWhileCheckingStartOnlyOneRefresh() async {
    let refresher = SuspendedCodexConnectorRefresher(result: .connected(snapshots: [.codexUsage()]))
    let viewModel = StatusViewModel(codexRefresher: refresher)

    let firstConnect = Task {
        await viewModel.connectCodex()
    }
    await refresher.waitForRefreshCount(1)

    let secondConnect = Task {
        await viewModel.connectCodex()
    }
    await Task.yield()

    #expect(refresher.refreshCount == 1)

    refresher.complete()
    await firstConnect.value
    await secondConnect.value
}

@MainActor
@Test func connectCodexPreservesExistingClaudeSnapshots() async {
    let refresher = CountingCodexConnectorRefresher(result: .success(.connected(snapshots: [.codexUsage()])))
    let viewModel = StatusViewModel(
        snapshots: [.claudeUsageForCodexTests()],
        codexRefresher: refresher
    )

    await viewModel.connectCodex()

    #expect(viewModel.snapshots.map(\.product).sorted() == ["claude_code", "codex"])
}

@MainActor
@Test func snapshotSectionsSeparateClaudeAndCodexProducts() async {
    let refresher = CountingCodexConnectorRefresher(result: .success(.connected(snapshots: [.codexUsage()])))
    let viewModel = StatusViewModel(
        snapshots: [.claudeUsageForCodexTests()],
        codexRefresher: refresher
    )

    await viewModel.connectCodex()

    #expect(viewModel.snapshotSections.count == 2)
    #expect(viewModel.snapshotSections[0].id == "anthropic_claude_code")
    #expect(viewModel.snapshotSections[0].snapshots.map(\.product) == ["claude_code"])
    #expect(viewModel.snapshotSections[1].id == "openai_codex")
    #expect(viewModel.snapshotSections[1].snapshots.map(\.product) == ["codex"])
}

@Test func codexConnectorSetupCopyCoversProductStates() {
    #expect(CodexConnectorSetupCopy.title(for: .notConnected) == "Codex is not connected")
    #expect(CodexConnectorSetupCopy.title(for: .checking) == "Checking Codex")
    #expect(CodexConnectorSetupCopy.title(for: .connected) == "Codex connected")
    #expect(CodexConnectorSetupCopy.title(for: .missingCredentials) == "Sign in to Codex locally")
    #expect(CodexConnectorSetupCopy.title(for: .permissionDenied) == "Codex app-server could not be started")
    #expect(CodexConnectorSetupCopy.title(for: .networkError) == "Codex usage could not be refreshed")
    #expect(CodexConnectorSetupCopy.title(for: .schemaChanged) == "Codex usage response changed")
    #expect(CodexConnectorSetupCopy.trustMessage == "Codex auth stays inside Codex. WhatTheToken reads only local rate-limit status after you connect.")
}

private final class CountingCodexConnectorRefresher: CodexConnectorRefreshing, @unchecked Sendable {
    private let lock = NSLock()
    private var storedRefreshCount = 0
    let result: Result<CodexConnectorResult, Error>

    var refreshCount: Int {
        lock.withLock {
            storedRefreshCount
        }
    }

    init(result: Result<CodexConnectorResult, Error>) {
        self.result = result
    }

    func refresh() async throws -> CodexConnectorResult {
        lock.withLock {
            storedRefreshCount += 1
        }

        return try result.get()
    }
}

private final class SuspendedCodexConnectorRefresher: CodexConnectorRefreshing, @unchecked Sendable {
    private let lock = NSLock()
    private let result: CodexConnectorResult
    private var storedRefreshCount = 0
    private var refreshWaiters: [CheckedContinuation<Void, Never>] = []
    private var completions: [CheckedContinuation<CodexConnectorResult, Never>] = []

    init(result: CodexConnectorResult) {
        self.result = result
    }

    var refreshCount: Int {
        lock.withLock {
            storedRefreshCount
        }
    }

    func refresh() async throws -> CodexConnectorResult {
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
        let completions: [CheckedContinuation<CodexConnectorResult, Never>] = lock.withLock {
            let completions = self.completions
            self.completions = []
            return completions
        }

        for completion in completions {
            completion.resume(returning: result)
        }
    }
}

private struct SyntheticCodexRefreshError: Error, CustomStringConvertible {
    static let description = "synthetic Codex refresh failure with provider details"

    var description: String {
        Self.description
    }
}

private extension CodexConnectorResult {
    static func connected(snapshots: [UsageSnapshot] = []) -> CodexConnectorResult {
        let source = ConnectorSource.codex(state: .connected)
        return CodexConnectorResult(
            snapshots: snapshots,
            status: ConnectorStatus(
                product: "codex",
                source: source,
                message: "Codex connected"
            )
        )
    }

    static func missingCredentials() -> CodexConnectorResult {
        let source = ConnectorSource.codex(state: .missingCredentials)
        return CodexConnectorResult(
            snapshots: [],
            status: ConnectorStatus(
                product: "codex",
                source: source,
                message: "Sign in to Codex locally"
            )
        )
    }

    static func permissionDenied() -> CodexConnectorResult {
        let source = ConnectorSource.codex(state: .permissionDenied)
        return CodexConnectorResult(
            snapshots: [],
            status: ConnectorStatus(
                product: "codex",
                source: source,
                message: "Codex app-server could not be started"
            )
        )
    }
}

private extension UsageSnapshot {
    static func codexUsage() -> UsageSnapshot {
        UsageSnapshot(
            id: "snap_openai_codex",
            userAccountId: "local_user",
            provider: "openai",
            product: "codex",
            surface: "aggregate",
            poolKey: "openai_codex_codex_d4cde064",
            windowKey: "primary_rolling_15m",
            unit: "utilization",
            used: 25,
            limit: 100,
            remaining: 75,
            utilization: 0.25,
            resetAt: "2024-11-07T02:40:00Z",
            lastUpdatedAt: "2026-05-05T10:00:00.000Z",
            confidence: "observed",
            undercountRisk: "possible",
            staleReason: nil,
            display: nil,
            source: .codex(state: .connected)
        )
    }

    static func claudeUsageForCodexTests() -> UsageSnapshot {
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
            source: .claudeForCodexTests(state: .connected)
        )
    }
}

private extension ConnectorSource {
    static func codex(state: ConnectorSourceState) -> ConnectorSource {
        ConnectorSource(
            connector: "mac_connector",
            state: state,
            label: "Mac connector",
            parserVersion: "codex-app-server-rate-limits-v1",
            deviceId: "device_mac_01"
        )
    }

    static func claudeForCodexTests(state: ConnectorSourceState) -> ConnectorSource {
        ConnectorSource(
            connector: "mac_connector",
            state: state,
            label: "Mac connector",
            parserVersion: "claude-code-oauth-usage-v1",
            deviceId: "device_mac_01"
        )
    }
}
