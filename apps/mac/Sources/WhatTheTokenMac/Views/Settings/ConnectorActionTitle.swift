import Foundation

enum ConnectorConsentCopy {
    static let claude = "Reads Claude Code local usage status only after you enable it. Provider credentials stay in Claude Code storage. WhatTheToken stores only sanitized usage status. Disconnect removes cached Claude Code usage from WhatTheToken."
    static let codex = "Reads Codex local rate-limit status only after you enable it. Codex auth stays inside Codex. WhatTheToken stores only sanitized usage status. Disconnect removes cached Codex usage from WhatTheToken."
}

func claudeActionTitle(for state: ClaudeConnectorSetupState) -> String {
    switch state {
    case .notConnected, .missingCredentials, .missingClaudeCli, .tokenInvalid:
        return "Connect"
    case .checking:
        return "Checking..."
    case .connected:
        return "Refresh"
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
        return "Refresh"
    case .networkError, .schemaChanged:
        return "Retry"
    }
}
