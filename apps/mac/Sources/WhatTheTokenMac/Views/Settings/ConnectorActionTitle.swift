import Foundation

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
