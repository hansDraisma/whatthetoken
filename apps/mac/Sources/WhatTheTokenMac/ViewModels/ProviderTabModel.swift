import Foundation

struct ProviderTabModel: Equatable, Sendable {
    enum Body: Equatable, Sendable {
        case connected(snapshots: [UsageSnapshot], worst: StatusUsageState, isRefreshing: Bool)
        case empty
        case loading
        case disconnected(reason: DisconnectedReason)
        case error(kind: ErrorKind, lastSnapshots: [UsageSnapshot], isRefreshing: Bool)
    }

    enum DisconnectedReason: Equatable, Sendable {
        case claude(ClaudeDisconnectedReason)
        case codex(CodexDisconnectedReason)
    }

    enum ClaudeDisconnectedReason: Equatable, Sendable {
        case notConnected
        case missingCredentials
        case missingCLI
        case tokenInvalid
        case rateLimited
    }

    enum CodexDisconnectedReason: Equatable, Sendable {
        case notConnected
        case missingCredentials
        case permissionDenied
    }

    enum ErrorKind: Equatable, Sendable {
        case network
        case schemaChanged
    }

    let tab: ProviderTab
    let body: Body
}

extension ProviderTabModel {
    @MainActor
    static func from(viewModel: StatusViewModel, tab: ProviderTab) -> ProviderTabModel {
        switch tab {
        case .claude:
            return fromClaude(viewModel: viewModel)
        case .codex:
            return fromCodex(viewModel: viewModel)
        }
    }

    @MainActor
    private static func fromClaude(viewModel: StatusViewModel) -> ProviderTabModel {
        let claudeSnapshots = viewModel.snapshots.filter {
            $0.provider == "anthropic" && $0.product == "claude_code"
        }

        let body: Body
        switch viewModel.connectorState {
        case .checking:
            if claudeSnapshots.isEmpty {
                body = .loading
            } else {
                body = .connected(
                    snapshots: claudeSnapshots,
                    worst: claudeSnapshots.worstUsageState(),
                    isRefreshing: true
                )
            }
        case .connected:
            if claudeSnapshots.isEmpty {
                body = .empty
            } else {
                body = .connected(
                    snapshots: claudeSnapshots,
                    worst: claudeSnapshots.worstUsageState(),
                    isRefreshing: false
                )
            }
        case .notConnected:
            body = .disconnected(reason: .claude(.notConnected))
        case .missingCredentials:
            body = .disconnected(reason: .claude(.missingCredentials))
        case .missingClaudeCli:
            body = .disconnected(reason: .claude(.missingCLI))
        case .tokenInvalid:
            body = .disconnected(reason: .claude(.tokenInvalid))
        case .rateLimited:
            body = .disconnected(reason: .claude(.rateLimited))
        case .networkError:
            body = .error(kind: .network, lastSnapshots: claudeSnapshots, isRefreshing: false)
        case .schemaChanged:
            body = .error(kind: .schemaChanged, lastSnapshots: claudeSnapshots, isRefreshing: false)
        }

        return ProviderTabModel(tab: .claude, body: body)
    }

    @MainActor
    private static func fromCodex(viewModel: StatusViewModel) -> ProviderTabModel {
        let codexSnapshots = viewModel.snapshots.filter {
            $0.provider == "openai" && $0.product == "codex"
        }

        let body: Body
        switch viewModel.codexConnectorState {
        case .checking:
            if codexSnapshots.isEmpty {
                body = .loading
            } else {
                body = .connected(
                    snapshots: codexSnapshots,
                    worst: codexSnapshots.worstUsageState(),
                    isRefreshing: true
                )
            }
        case .connected:
            if codexSnapshots.isEmpty {
                body = .empty
            } else {
                body = .connected(
                    snapshots: codexSnapshots,
                    worst: codexSnapshots.worstUsageState(),
                    isRefreshing: false
                )
            }
        case .notConnected:
            body = .disconnected(reason: .codex(.notConnected))
        case .missingCredentials:
            body = .disconnected(reason: .codex(.missingCredentials))
        case .permissionDenied:
            body = .disconnected(reason: .codex(.permissionDenied))
        case .networkError:
            body = .error(kind: .network, lastSnapshots: codexSnapshots, isRefreshing: false)
        case .schemaChanged:
            body = .error(kind: .schemaChanged, lastSnapshots: codexSnapshots, isRefreshing: false)
        }

        return ProviderTabModel(tab: .codex, body: body)
    }
}

private extension Array where Element == UsageSnapshot {
    func worstUsageState() -> StatusUsageState {
        map { StatusUsageState(snapshot: $0) }.worstCase()
    }
}

private extension Array where Element == StatusUsageState {
    func worstCase() -> StatusUsageState {
        if contains(.empty) { return .empty }
        if contains(.critical) { return .critical }
        if contains(.low) { return .low }
        return .healthy
    }
}
