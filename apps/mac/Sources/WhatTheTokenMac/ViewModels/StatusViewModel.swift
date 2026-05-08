import Foundation
import Observation

@MainActor
@Observable
final class StatusViewModel {
    var snapshots: [UsageSnapshot]
    var connectorState: ClaudeConnectorSetupState
    var connectorStatusMessage: String
    var codexConnectorState: CodexConnectorSetupState
    var codexConnectorStatusMessage: String
    private let claudeRefresher: ClaudeConnectorRefreshing?
    private let claudeVersionProvider: ClaudeVersionProviding?
    private let codexRefresher: CodexConnectorRefreshing?
    private(set) var lastClaudeRefreshAt: Date?
    private(set) var lastCodexRefreshAt: Date?
    private(set) var isRefreshAllInFlight = false

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
        claudeRefresher: ClaudeConnectorRefreshing? = nil,
        claudeVersionProvider: ClaudeVersionProviding? = nil,
        codexRefresher: CodexConnectorRefreshing? = nil,
        connectorState: ClaudeConnectorSetupState = .notConnected,
        connectorStatusMessage: String = "Claude Code is not connected",
        codexConnectorState: CodexConnectorSetupState = .notConnected,
        codexConnectorStatusMessage: String = "Codex is not connected"
    ) {
        self.snapshots = snapshots
        self.claudeRefresher = claudeRefresher
        self.claudeVersionProvider = claudeVersionProvider
        self.codexRefresher = codexRefresher
        self.connectorState = connectorState
        self.connectorStatusMessage = connectorStatusMessage
        self.codexConnectorState = codexConnectorState
        self.codexConnectorStatusMessage = codexConnectorStatusMessage
    }

    func connectClaudeCode() async {
        guard connectorState != .checking else { return }

        var attempted = false
        var didEnterChecking = false
        let previousState = connectorState
        let previousMessage = connectorStatusMessage
        defer {
            if attempted && Task.isCancelled {
                if didEnterChecking && connectorState == .checking {
                    connectorState = previousState
                    connectorStatusMessage = previousMessage
                }
            } else if attempted {
                lastClaudeRefreshAt = Date()
            }
        }
        attempted = true

        guard let claudeRefresher else {
            connectorState = .notConnected
            connectorStatusMessage = "Claude Code is not connected"
            return
        }

        if let claudeVersionProvider, claudeVersionProvider.claudeVersion == "unknown" {
            replaceSnapshots(matching: { $0.provider == "anthropic" && $0.product == "claude_code" }, with: [])
            connectorState = .missingClaudeCli
            connectorStatusMessage = ClaudeConnectorSetupCopy.title(for: .missingClaudeCli)
            return
        }

        connectorState = .checking
        connectorStatusMessage = "Checking Claude Code"
        didEnterChecking = true

        do {
            let result = try await claudeRefresher.refresh()
            guard !Task.isCancelled else { return }
            replaceSnapshots(matching: { $0.provider == "anthropic" && $0.product == "claude_code" }, with: result.snapshots)
            connectorState = Self.setupState(for: result.status.source.state)
            connectorStatusMessage = result.status.message
        } catch {
            guard !Task.isCancelled else { return }
            replaceSnapshots(matching: { $0.provider == "anthropic" && $0.product == "claude_code" }, with: [])
            connectorState = .networkError
            connectorStatusMessage = "Claude Code usage could not be refreshed"
        }
    }

    func connectCodex() async {
        guard codexConnectorState != .checking else { return }

        var attempted = false
        var didEnterChecking = false
        let previousState = codexConnectorState
        let previousMessage = codexConnectorStatusMessage
        defer {
            if attempted && Task.isCancelled {
                if didEnterChecking && codexConnectorState == .checking {
                    codexConnectorState = previousState
                    codexConnectorStatusMessage = previousMessage
                }
            } else if attempted {
                lastCodexRefreshAt = Date()
            }
        }
        attempted = true

        guard let codexRefresher else {
            codexConnectorState = .notConnected
            codexConnectorStatusMessage = "Codex is not connected"
            return
        }

        codexConnectorState = .checking
        codexConnectorStatusMessage = "Checking Codex"
        didEnterChecking = true

        do {
            let result = try await codexRefresher.refresh()
            guard !Task.isCancelled else { return }
            replaceSnapshots(matching: { $0.provider == "openai" && $0.product == "codex" }, with: result.snapshots)
            codexConnectorState = Self.codexSetupState(for: result.status.source.state)
            codexConnectorStatusMessage = result.status.message
        } catch {
            guard !Task.isCancelled else { return }
            replaceSnapshots(matching: { $0.provider == "openai" && $0.product == "codex" }, with: [])
            codexConnectorState = .networkError
            codexConnectorStatusMessage = "Codex usage could not be refreshed"
        }
    }

    func refreshAll(reason: RefreshReason) async {
        guard !isRefreshAllInFlight else { return }
        isRefreshAllInFlight = true
        defer { isRefreshAllInFlight = false }

        await connectClaudeCode()
        guard !Task.isCancelled else { return }
        await connectCodex()
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

    static func live() -> StatusViewModel {
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
            )
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
