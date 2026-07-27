import Foundation

enum ConnectorConsentCopy {
    static let claude = "Connect Claude Code to read local usage status. Provider credentials stay in Claude Code storage. WhatTheToken stores only sanitized usage status. Disconnect removes cached Claude Code usage from WhatTheToken."
    static let codex = "Connect Codex to read local rate-limit status. Codex auth stays inside Codex. WhatTheToken stores only sanitized usage status. Disconnect removes cached Codex usage from WhatTheToken."
}

func connectorConnectionActionTitle(for provider: CachedProviderID, isEnabled: Bool, isPaused: Bool) -> String {
    if isEnabled && isPaused {
        return "Resume \(provider.displayName)"
    }
    if isEnabled {
        return "Pause \(provider.displayName)"
    }
    return "Connect \(provider.displayName)"
}

func connectorDisconnectActionTitle(for provider: CachedProviderID) -> String {
    "Disconnect \(provider.displayName)..."
}

enum ConnectorRowState: Equatable, Sendable {
    case claude(ClaudeConnectorSetupState)
    case codex(CodexConnectorSetupState)
}

enum ConnectorRowAction: Equatable, Sendable {
    case connect(title: String)
    case checking
    case refresh
    case retry
    case checkForUpdates
    case resume(title: String)

    var title: String {
        switch self {
        case let .connect(title), let .resume(title):
            return title
        case .checking:
            return "Checking..."
        case .refresh:
            return "Refresh Now"
        case .retry:
            return "Retry"
        case .checkForUpdates:
            return "Check for Updates"
        }
    }

    var isDisabledByState: Bool {
        self == .checking
    }
}

func connectorRowAction(
    for state: ConnectorRowState,
    isEnabled: Bool,
    isPaused: Bool
) -> ConnectorRowAction {
    let provider: CachedProviderID
    let recovery: ConnectorRecovery
    switch state {
    case let .claude(claudeState):
        provider = .claude
        recovery = ConnectorRecoveryCopy.claude(claudeState).recovery
    case let .codex(codexState):
        provider = .codex
        recovery = ConnectorRecoveryCopy.codex(codexState).recovery
    }

    guard isEnabled else {
        return .connect(title: "Connect \(provider.displayName)")
    }
    if isPaused {
        return .resume(title: "Resume \(provider.displayName)")
    }

    switch recovery {
    case .none:
        return .refresh
    case .checking:
        return .checking
    case .connect:
        return .connect(title: "Connect \(provider.displayName)")
    case .retry, .waitForClaudeCode, .signInLocally, .installCLI, .waitForReset:
        return .retry
    case .checkForUpdates:
        return .checkForUpdates
    }
}

func connectorPauseActionTitle(
    for provider: CachedProviderID,
    isEnabled: Bool,
    isPaused: Bool
) -> String? {
    guard isEnabled, !isPaused else { return nil }
    return "Pause \(provider.displayName)"
}

extension CachedProviderID {
    var displayName: String {
        switch self {
        case .claude:
            return "Claude Code"
        case .codex:
            return "Codex"
        }
    }
}

func claudeActionTitle(for state: ClaudeConnectorSetupState) -> String {
    connectorRowAction(
        for: .claude(state),
        isEnabled: true,
        isPaused: false
    ).title
}

func codexActionTitle(for state: CodexConnectorSetupState) -> String {
    connectorRowAction(
        for: .codex(state),
        isEnabled: true,
        isPaused: false
    ).title
}
