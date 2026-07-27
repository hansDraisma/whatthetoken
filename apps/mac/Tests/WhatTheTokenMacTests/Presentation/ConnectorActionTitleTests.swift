import Testing
@testable import WhatTheTokenMac

/// Titles for an enabled, unpaused connector — the state-driven part of the row
/// action, with the enabled/paused overrides covered separately below.
private func claudeRowTitle(_ state: ClaudeConnectorSetupState) -> String {
    connectorRowAction(for: .claude(state), isEnabled: true, isPaused: false).title
}

private func codexRowTitle(_ state: CodexConnectorSetupState) -> String {
    connectorRowAction(for: .codex(state), isEnabled: true, isPaused: false).title
}

@Suite struct ConnectorActionTitleTests {
    @Test func claude_notConnected_isConnect() {
        #expect(claudeRowTitle(.notConnected) == "Connect Claude Code")
    }

    @Test func claude_checking_isCheckingEllipsis() {
        #expect(claudeRowTitle(.checking) == "Checking...")
    }

    @Test func claude_connected_isRefreshNow() {
        #expect(claudeRowTitle(.connected) == "Refresh Now")
    }

    @Test func claude_networkError_isRetry() {
        #expect(claudeRowTitle(.networkError) == "Retry")
    }

    @Test func claude_schemaChanged_isCheckForUpdates() {
        #expect(claudeRowTitle(.schemaChanged) == "Check for Updates")
    }

    @Test func claude_rateLimited_isRetry() {
        #expect(claudeRowTitle(.rateLimited) == "Retry")
    }

    @Test func claude_missingCredentials_isRetry() {
        #expect(claudeRowTitle(.missingCredentials) == "Retry")
    }

    @Test func claude_missingClaudeCli_isRetry() {
        #expect(claudeRowTitle(.missingClaudeCli) == "Retry")
    }

    @Test func claude_tokenInvalid_isRetry() {
        #expect(claudeRowTitle(.tokenInvalid) == "Retry")
    }

    @Test func codex_notConnected_isConnect() {
        #expect(codexRowTitle(.notConnected) == "Connect Codex")
    }

    @Test func codex_connected_isRefreshNow() {
        #expect(codexRowTitle(.connected) == "Refresh Now")
    }

    @Test func codex_networkError_isRetry() {
        #expect(codexRowTitle(.networkError) == "Retry")
    }

    @Test func codex_schemaChanged_isCheckForUpdates() {
        #expect(codexRowTitle(.schemaChanged) == "Check for Updates")
    }

    @Test func codex_permissionDenied_isRetry() {
        #expect(codexRowTitle(.permissionDenied) == "Retry")
    }

    @Test func codex_missingCredentials_isRetry() {
        #expect(codexRowTitle(.missingCredentials) == "Retry")
    }

    @Test func codex_checking_isCheckingEllipsis() {
        #expect(codexRowTitle(.checking) == "Checking...")
    }

    @Test func connectorConsentCopyStatesStoredDataBoundary() {
        let claude = ConnectorConsentCopy.claude.lowercased()
        let codex = ConnectorConsentCopy.codex.lowercased()

        #expect(claude.contains("credentials"))
        #expect(claude.contains("claude code storage"))
        #expect(claude.contains("connect claude code"))
        #expect(!claude.contains("enable it"))
        #expect(claude.contains("sanitized usage status"))
        #expect(codex.contains("auth"))
        #expect(codex.contains("inside codex"))
        #expect(codex.contains("connect codex"))
        #expect(!codex.contains("enable it"))
        #expect(codex.contains("sanitized usage status"))
    }

    @Test func disabledConnectorOffersConnectRegardlessOfState() {
        #expect(
            connectorRowAction(for: .claude(.sessionExpired), isEnabled: false, isPaused: false)
                == .connect(title: "Connect Claude Code")
        )
        #expect(
            connectorRowAction(for: .codex(.networkError), isEnabled: false, isPaused: false)
                == .connect(title: "Connect Codex")
        )
    }

    @Test func pausedConnectorOffersResumeRegardlessOfState() {
        #expect(
            connectorRowAction(for: .claude(.sessionExpired), isEnabled: true, isPaused: true)
                == .resume(title: "Resume Claude Code")
        )
        #expect(
            connectorRowAction(for: .codex(.networkError), isEnabled: true, isPaused: true)
                == .resume(title: "Resume Codex")
        )
    }

    @Test func connectorDisconnectActionTitleNamesDisconnectForProviders() {
        #expect(connectorDisconnectActionTitle(for: .claude) == "Disconnect Claude Code...")
        #expect(connectorDisconnectActionTitle(for: .codex) == "Disconnect Codex...")
    }

    @Test func enabledFailingClaudeOffersRecoveryInsteadOfPauseAsPrimary() {
        let action = connectorRowAction(
            for: .claude(.sessionExpired),
            isEnabled: true,
            isPaused: false
        )

        #expect(action == .retry)
        #expect(action.title == "Retry")
    }

    @Test func healthyEnabledClaudeKeepsRefreshPrimaryAndPauseSecondary() {
        let action = connectorRowAction(
            for: .claude(.connected),
            isEnabled: true,
            isPaused: false
        )

        #expect(action == .refresh)
        #expect(action.title == "Refresh Now")
        #expect(
            connectorPauseActionTitle(
                for: .claude,
                isEnabled: true,
                isPaused: false
            ) == "Pause Claude Code"
        )
    }

    @Test func schemaDriftChecksForUpdatesInsteadOfRetryingSameParser() {
        #expect(
            connectorRowAction(
                for: .claude(.schemaChanged),
                isEnabled: true,
                isPaused: false
            ) == .checkForUpdates
        )
        #expect(
            connectorRowAction(
                for: .codex(.schemaChanged),
                isEnabled: true,
                isPaused: false
            ) == .checkForUpdates
        )
    }

    @Test func pausedConnectorOffersResumeAsPrimaryWithoutPauseSecondary() {
        #expect(
            connectorRowAction(
                for: .claude(.connected),
                isEnabled: true,
                isPaused: true
            ) == .resume(title: "Resume Claude Code")
        )
        #expect(
            connectorPauseActionTitle(
                for: .claude,
                isEnabled: true,
                isPaused: true
            ) == nil
        )
    }
}
