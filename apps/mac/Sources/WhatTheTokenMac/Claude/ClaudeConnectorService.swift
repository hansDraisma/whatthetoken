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
    let currentDate: @Sendable () -> Date

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

        let outcome = await fetchUsageOutcome(credential: credential)

        switch outcome {
        case let .failure(state):
            return ClaudeConnectorResult(
                snapshots: [],
                status: ConnectorStatus(
                    product: "claude_code",
                    source: source(state: state),
                    message: message(for: state)
                )
            )
        case let .success(response):
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
    }

    private enum FetchOutcome {
        case success(ClaudeUsageResponse)
        case failure(ConnectorSourceState)
    }

    private func fetchUsageOutcome(credential: ClaudeStoredCredential) async -> FetchOutcome {
        do {
            let response = try await usageFetcher.fetchUsage(
                accessToken: credential.accessToken,
                claudeVersion: claudeVersionProvider.claudeVersion
            )
            return .success(response)
        } catch let error as ClaudeUsageClientError {
            switch error {
            case .tokenInvalid:
                return .failure(tokenFailureState(credential: credential))
            case .rateLimited:
                return .failure(.rateLimited)
            case .networkError:
                return .failure(.networkError)
            case .schemaChanged:
                return .failure(.schemaChanged)
            }
        } catch {
            return .failure(.networkError)
        }
    }

    private func tokenFailureState(credential: ClaudeStoredCredential) -> ConnectorSourceState {
        if let expiresAt = credential.expiresAt, expiresAt <= currentDate() {
            return .sessionExpired
        }
        return .tokenInvalid
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

    private func message(for state: ConnectorSourceState) -> String {
        switch state {
        case .tokenInvalid:
            return "Claude Code credentials are invalid"
        case .sessionExpired:
            return "Claude Code session expired"
        case .rateLimited:
            return "Claude usage is rate limited"
        case .schemaChanged:
            return "Claude usage response changed"
        case .connected, .notConnected, .missingCredentials, .permissionDenied, .networkError, .stale:
            return "Claude Code usage could not be refreshed"
        }
    }
}
