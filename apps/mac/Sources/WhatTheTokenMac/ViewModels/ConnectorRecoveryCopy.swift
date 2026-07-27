import Foundation

/// What the user must do to recover a connector state.
enum ConnectorRecovery: Equatable, Sendable {
    case none
    case checking
    case connect
    case retry
    case waitForClaudeCode
    case signInLocally
    case installCLI
    case waitForReset
    case checkForUpdates
}

struct ConnectorCopy: Equatable, Sendable {
    let headline: String
    let advice: String
    let recovery: ConnectorRecovery
}

enum ConnectorRecoveryCopy {
    static func claude(_ state: ClaudeConnectorSetupState) -> ConnectorCopy {
        switch state {
        case .notConnected:
            return ConnectorCopy(
                headline: "Claude Code is not connected",
                advice: "Connect Claude Code in Settings to see remaining usage.",
                recovery: .connect
            )
        case .checking:
            return ConnectorCopy(
                headline: "Checking Claude Code",
                advice: "",
                recovery: .checking
            )
        case .connected:
            return ConnectorCopy(
                headline: "Claude Code connected",
                advice: "",
                recovery: .none
            )
        case .missingCredentials:
            return ConnectorCopy(
                headline: "Claude Code credentials were not found",
                advice: "Sign in by opening Claude Code, then retry.",
                recovery: .signInLocally
            )
        case .missingClaudeCli:
            return ConnectorCopy(
                headline: "Claude Code CLI was not found",
                advice: "Install Claude Code, sign in locally, then retry.",
                recovery: .installCLI
            )
        case .tokenInvalid:
            return ConnectorCopy(
                headline: "Claude Code credentials are invalid",
                advice: "Sign in again in Claude Code, then retry.",
                recovery: .signInLocally
            )
        case .sessionExpired:
            return ConnectorCopy(
                headline: "Claude Code session expired",
                advice: "Open Claude Code to refresh your session, then retry.",
                recovery: .retry
            )
        case .rateLimited:
            return ConnectorCopy(
                headline: "Claude usage is rate limited",
                advice: "Wait for the provider limit to reset, then retry.",
                recovery: .waitForReset
            )
        case .networkError:
            return ConnectorCopy(
                headline: "Claude Code usage could not be refreshed",
                advice: "Check your connection, then retry.",
                recovery: .retry
            )
        case .schemaChanged:
            return ConnectorCopy(
                headline: "Claude usage response changed",
                advice: "Check for a WhatTheToken update with support for the latest response.",
                recovery: .checkForUpdates
            )
        }
    }

    static func codex(_ state: CodexConnectorSetupState) -> ConnectorCopy {
        switch state {
        case .notConnected:
            return ConnectorCopy(
                headline: "Codex is not connected",
                advice: "Connect Codex in Settings to see remaining usage and rate-limit status.",
                recovery: .connect
            )
        case .checking:
            return ConnectorCopy(
                headline: "Checking Codex",
                advice: "",
                recovery: .checking
            )
        case .connected:
            return ConnectorCopy(
                headline: "Codex connected",
                advice: "",
                recovery: .none
            )
        case .missingCredentials:
            return ConnectorCopy(
                headline: "Sign in to Codex locally",
                advice: "Sign in by running Codex locally, then retry.",
                recovery: .signInLocally
            )
        case .permissionDenied:
            return ConnectorCopy(
                headline: "Codex app-server could not be started",
                advice: "Check local permissions for Codex, then retry.",
                recovery: .retry
            )
        case .networkError:
            return ConnectorCopy(
                headline: "Codex usage could not be refreshed",
                advice: "Check your connection, then retry.",
                recovery: .retry
            )
        case .schemaChanged:
            return ConnectorCopy(
                headline: "Codex usage response changed",
                advice: "Check for a WhatTheToken update with support for the latest response.",
                recovery: .checkForUpdates
            )
        }
    }
}
