import Testing
@testable import WhatTheTokenMac

@Suite struct ConnectorActionTitleTests {
    @Test func claude_notConnected_isConnect() {
        #expect(claudeActionTitle(for: .notConnected) == "Connect")
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
        #expect(claudeActionTitle(for: .schemaChanged) == "Retry")
    }

    @Test func claude_rateLimited_isRetry() {
        #expect(claudeActionTitle(for: .rateLimited) == "Retry")
    }

    @Test func claude_missingCredentials_isConnect() {
        #expect(claudeActionTitle(for: .missingCredentials) == "Connect")
    }

    @Test func claude_missingClaudeCli_isConnect() {
        #expect(claudeActionTitle(for: .missingClaudeCli) == "Connect")
    }

    @Test func claude_tokenInvalid_isConnect() {
        #expect(claudeActionTitle(for: .tokenInvalid) == "Connect")
    }

    @Test func codex_notConnected_isConnect() {
        #expect(codexActionTitle(for: .notConnected) == "Connect")
    }

    @Test func codex_connected_isRefreshNow() {
        #expect(codexActionTitle(for: .connected) == "Refresh Now")
    }

    @Test func codex_networkError_isRetry() {
        #expect(codexActionTitle(for: .networkError) == "Retry")
    }

    @Test func codex_schemaChanged_isRetry() {
        #expect(codexActionTitle(for: .schemaChanged) == "Retry")
    }

    @Test func codex_permissionDenied_isConnect() {
        #expect(codexActionTitle(for: .permissionDenied) == "Connect")
    }

    @Test func codex_missingCredentials_isConnect() {
        #expect(codexActionTitle(for: .missingCredentials) == "Connect")
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
        #expect(connectorConnectionActionTitle(for: .claude, isEnabled: false) == "Connect Claude Code")
        #expect(connectorConnectionActionTitle(for: .codex, isEnabled: false) == "Connect Codex")
    }

    @Test func connectorConnectionActionTitleNamesDisconnectForEnabledProviders() {
        #expect(connectorConnectionActionTitle(for: .claude, isEnabled: true) == "Disconnect Claude Code...")
        #expect(connectorConnectionActionTitle(for: .codex, isEnabled: true) == "Disconnect Codex...")
    }
}
