import Testing
@testable import WhatTheTokenMac

@Suite struct ConnectorActionTitleTests {
    @Test func claude_notConnected_isConnect() {
        #expect(claudeActionTitle(for: .notConnected) == "Connect Claude Code")
    }

    @Test func claude_checking_isCheckingEllipsis() {
        #expect(claudeActionTitle(for: .checking) == "Checking...")
    }

    @Test func claude_connected_isRefreshNow() {
        #expect(claudeActionTitle(for: .connected) == "Refresh Now")
    }

    @Test func claude_networkError_isRetry() {
        #expect(claudeActionTitle(for: .networkError) == "Retry")
    }

    @Test func claude_schemaChanged_isRetry() {
        #expect(claudeActionTitle(for: .schemaChanged) == "Check for Updates")
    }

    @Test func claude_rateLimited_isRetry() {
        #expect(claudeActionTitle(for: .rateLimited) == "Retry")
    }

    @Test func claude_missingCredentials_isConnect() {
        #expect(claudeActionTitle(for: .missingCredentials) == "Retry")
    }

    @Test func claude_missingClaudeCli_isConnect() {
        #expect(claudeActionTitle(for: .missingClaudeCli) == "Retry")
    }

    @Test func claude_tokenInvalid_isConnect() {
        #expect(claudeActionTitle(for: .tokenInvalid) == "Retry")
    }

    @Test func codex_notConnected_isConnect() {
        #expect(codexActionTitle(for: .notConnected) == "Connect Codex")
    }

    @Test func codex_connected_isRefreshNow() {
        #expect(codexActionTitle(for: .connected) == "Refresh Now")
    }

    @Test func codex_networkError_isRetry() {
        #expect(codexActionTitle(for: .networkError) == "Retry")
    }

    @Test func codex_schemaChanged_isRetry() {
        #expect(codexActionTitle(for: .schemaChanged) == "Check for Updates")
    }

    @Test func codex_permissionDenied_isConnect() {
        #expect(codexActionTitle(for: .permissionDenied) == "Retry")
    }

    @Test func codex_missingCredentials_isConnect() {
        #expect(codexActionTitle(for: .missingCredentials) == "Retry")
    }

    @Test func codex_checking_isCheckingEllipsis() {
        #expect(codexActionTitle(for: .checking) == "Checking...")
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

    @Test func connectorConnectionActionTitleNamesConnectForDisabledProviders() {
        #expect(connectorConnectionActionTitle(for: .claude, isEnabled: false, isPaused: false) == "Connect Claude Code")
        #expect(connectorConnectionActionTitle(for: .codex, isEnabled: false, isPaused: false) == "Connect Codex")
    }

    @Test func connectorConnectionActionTitleNamesPauseForEnabledActiveProviders() {
        #expect(connectorConnectionActionTitle(for: .claude, isEnabled: true, isPaused: false) == "Pause Claude Code")
        #expect(connectorConnectionActionTitle(for: .codex, isEnabled: true, isPaused: false) == "Pause Codex")
    }

    @Test func connectorConnectionActionTitleNamesResumeForEnabledPausedProviders() {
        #expect(connectorConnectionActionTitle(for: .claude, isEnabled: true, isPaused: true) == "Resume Claude Code")
        #expect(connectorConnectionActionTitle(for: .codex, isEnabled: true, isPaused: true) == "Resume Codex")
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
