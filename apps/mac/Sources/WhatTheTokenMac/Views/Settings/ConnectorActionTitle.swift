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
    switch state {
    case .notConnected, .missingCredentials, .missingClaudeCli, .tokenInvalid:
        return "Connect"
    case .checking:
        return "Checking..."
    case .connected:
        return "Refresh Now"
    case .networkError, .schemaChanged, .rateLimited:
        return "Retry"
    }
}

func codexActionTitle(for state: CodexConnectorSetupState) -> String {
    switch state {
    case .notConnected, .missingCredentials, .permissionDenied:
        return "Connect"
    case .checking:
        return "Checking..."
    case .connected:
        return "Refresh Now"
    case .networkError, .schemaChanged:
        return "Retry"
    }
}
