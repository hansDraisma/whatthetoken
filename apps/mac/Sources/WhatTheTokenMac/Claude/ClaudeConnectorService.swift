import Foundation

protocol ClaudeUsageFetching: Sendable {
    func fetchUsage(accessToken: String, claudeVersion: String) async throws -> ClaudeUsageResponse
}

protocol ClaudeVersionProviding: Sendable {
    var claudeVersion: String { get }
}

struct StaticClaudeVersionProvider: ClaudeVersionProviding {
    let claudeVersion: String
}

struct ClaudeConnectorSettings: Equatable, Sendable {
    let isEnabled: Bool
}

struct ClaudeConnectorResult: Equatable, Sendable {
    let snapshots: [UsageSnapshot]
    let status: ConnectorStatus
}

struct ClaudeConnectorService: Sendable {
    let settings: ClaudeConnectorSettings
    let credentialStore: ClaudeCredentialStore
    let usageFetcher: ClaudeUsageFetching
    let claudeVersionProvider: ClaudeVersionProviding
    let deviceId: String
    let userAccountId: String
    let now: @Sendable () -> String

    func refresh() async throws -> ClaudeConnectorResult {
        if !settings.isEnabled {
            return ClaudeConnectorResult(
                snapshots: [],
                status: ConnectorStatus(
                    product: "claude_code",
                    source: source(state: .notConnected),
                    message: "Claude Code is not connected"
                )
            )
        }

        guard let credential = try credentialStore.readCredential() else {
            return ClaudeConnectorResult(
                snapshots: [],
                status: ConnectorStatus(
                    product: "claude_code",
                    source: source(state: .missingCredentials),
                    message: "Claude Code credentials were not found"
                )
            )
        }

        let response: ClaudeUsageResponse
        do {
            response = try await usageFetcher.fetchUsage(
                accessToken: credential.accessToken,
                claudeVersion: claudeVersionProvider.claudeVersion
            )
        } catch let error as ClaudeUsageClientError {
            return ClaudeConnectorResult(
                snapshots: [],
                status: ConnectorStatus(
                    product: "claude_code",
                    source: source(state: sourceState(for: error)),
                    message: message(for: error)
                )
            )
        } catch {
            return ClaudeConnectorResult(
                snapshots: [],
                status: ConnectorStatus(
                    product: "claude_code",
                    source: source(state: .networkError),
                    message: "Claude Code usage could not be refreshed"
                )
            )
        }

        let connectedSource = source(state: .connected)
        let snapshots = ClaudeUsageMapper.map(
            response,
            userAccountId: userAccountId,
            deviceId: deviceId,
            observedAt: now(),
            source: connectedSource
        )

        return ClaudeConnectorResult(
            snapshots: snapshots,
            status: ConnectorStatus(
                product: "claude_code",
                source: connectedSource,
                message: "Claude Code connected"
            )
        )
    }

    private func source(state: ConnectorSourceState) -> ConnectorSource {
        ConnectorSource(
            connector: "mac_connector",
            state: state,
            label: "Mac connector",
            parserVersion: "claude-code-oauth-usage-v1",
            deviceId: deviceId
        )
    }

    private func sourceState(for error: ClaudeUsageClientError) -> ConnectorSourceState {
        switch error {
        case .tokenInvalid:
            return .tokenInvalid
        case .rateLimited:
            return .rateLimited
        case .networkError:
            return .networkError
        case .schemaChanged:
            return .schemaChanged
        }
    }

    private func message(for error: ClaudeUsageClientError) -> String {
        switch error {
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
