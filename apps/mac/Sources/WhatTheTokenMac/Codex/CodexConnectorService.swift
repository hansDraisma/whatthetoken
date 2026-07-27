import Foundation

struct CodexConnectorSettings: Equatable, Sendable {
    let isEnabled: Bool
}

struct CodexConnectorResult: Equatable, Sendable {
    let snapshots: [UsageSnapshot]
    let status: ConnectorStatus
}

struct CodexConnectorService: Sendable {
    let settings: CodexConnectorSettings
    let rateLimitsFetcher: CodexRateLimitsFetching
    let deviceId: String
    let userAccountId: String
    let now: @Sendable () -> String

    func refresh() async throws -> CodexConnectorResult {
        if !settings.isEnabled {
            return CodexConnectorResult(
                snapshots: [],
                status: ConnectorStatus(
                    product: "codex",
                    source: source(state: .notConnected),
                    message: ConnectorRecoveryCopy.codex(.notConnected).headline
                )
            )
        }

        let response: CodexRateLimitsResponse
        do {
            response = try await rateLimitsFetcher.readRateLimits()
        } catch let error as CodexAppServerClientError {
            return CodexConnectorResult(
                snapshots: [],
                status: ConnectorStatus(
                    product: "codex",
                    source: source(state: sourceState(for: error)),
                    message: message(for: error)
                )
            )
        } catch {
            return CodexConnectorResult(
                snapshots: [],
                status: ConnectorStatus(
                    product: "codex",
                    source: source(state: .networkError),
                    message: ConnectorRecoveryCopy.codex(.networkError).headline
                )
            )
        }

        let connectedSource = source(state: .connected)
        let snapshots = CodexUsageMapper.map(
            response,
            userAccountId: userAccountId,
            deviceId: deviceId,
            observedAt: now(),
            source: connectedSource
        )

        return CodexConnectorResult(
            snapshots: snapshots,
            status: ConnectorStatus(
                product: "codex",
                source: connectedSource,
                message: ConnectorRecoveryCopy.codex(.connected).headline
            )
        )
    }

    private func source(state: ConnectorSourceState) -> ConnectorSource {
        ConnectorSource(
            connector: "mac_connector",
            state: state,
            label: "Mac connector",
            parserVersion: "codex-app-server-rate-limits-v1",
            deviceId: deviceId
        )
    }

    private func sourceState(for error: CodexAppServerClientError) -> ConnectorSourceState {
        switch error {
        case .authRequired:
            return .missingCredentials
        case .permissionDenied:
            return .permissionDenied
        case .networkError:
            return .networkError
        case .schemaChanged:
            return .schemaChanged
        }
    }

    private func message(for error: CodexAppServerClientError) -> String {
        switch error {
        case .authRequired:
            return ConnectorRecoveryCopy.codex(.missingCredentials).headline
        case .permissionDenied:
            return ConnectorRecoveryCopy.codex(.permissionDenied).headline
        case .networkError:
            return ConnectorRecoveryCopy.codex(.networkError).headline
        case .schemaChanged:
            return ConnectorRecoveryCopy.codex(.schemaChanged).headline
        }
    }
}
