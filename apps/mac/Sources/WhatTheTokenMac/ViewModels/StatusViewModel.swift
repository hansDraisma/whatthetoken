import Foundation
import Observation

@Observable
final class StatusViewModel {
    var snapshots: [UsageSnapshot]
    var connectorState: ClaudeConnectorSetupState
    var connectorStatusMessage: String
    private let claudeRefresher: ClaudeConnectorRefreshing?
    private let claudeVersionProvider: ClaudeVersionProviding?

    init(
        snapshots: [UsageSnapshot] = [],
        claudeRefresher: ClaudeConnectorRefreshing? = nil,
        claudeVersionProvider: ClaudeVersionProviding? = nil,
        connectorState: ClaudeConnectorSetupState = .notConnected,
        connectorStatusMessage: String = "Claude Code is not connected"
    ) {
        self.snapshots = snapshots
        self.claudeRefresher = claudeRefresher
        self.claudeVersionProvider = claudeVersionProvider
        self.connectorState = connectorState
        self.connectorStatusMessage = connectorStatusMessage
    }

    @MainActor
    func connectClaudeCode() async {
        guard connectorState != .checking else {
            return
        }

        guard let claudeRefresher else {
            connectorState = .notConnected
            connectorStatusMessage = "Claude Code is not connected"
            return
        }

        if let claudeVersionProvider, claudeVersionProvider.claudeVersion == "unknown" {
            snapshots = []
            connectorState = .missingClaudeCli
            connectorStatusMessage = ClaudeConnectorSetupCopy.title(for: .missingClaudeCli)
            return
        }

        connectorState = .checking
        connectorStatusMessage = "Checking Claude Code"

        do {
            let result = try await claudeRefresher.refresh()
            snapshots = result.snapshots
            connectorState = Self.setupState(for: result.status.source.state)
            connectorStatusMessage = result.status.message
        } catch {
            snapshots = []
            connectorState = .networkError
            connectorStatusMessage = "Claude Code usage could not be refreshed"
        }
    }

    static func loadFixtureData() throws -> Data {
        guard let url = Bundle.module.url(forResource: "usage-snapshot.fixture", withExtension: "json") else {
            throw FixtureError.missingFixture
        }

        return try Data(contentsOf: url)
    }

    static func loadFixtureSnapshot() throws -> UsageSnapshot {
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
            claudeVersionProvider: versionProvider
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
}

enum FixtureError: Error {
    case missingFixture
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
