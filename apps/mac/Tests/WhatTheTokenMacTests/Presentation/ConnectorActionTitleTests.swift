import Testing
@testable import WhatTheTokenMac

@Suite struct ConnectorActionTitleTests {
    @Test func claude_notConnected_isConnect() {
        #expect(claudeActionTitle(for: .notConnected) == "Connect")
    }

    @Test func claude_checking_isCheckingEllipsis() {
        #expect(claudeActionTitle(for: .checking) == "Checking...")
    }

    @Test func claude_connected_isRefresh() {
        #expect(claudeActionTitle(for: .connected) == "Refresh")
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

    @Test func codex_connected_isRefresh() {
        #expect(codexActionTitle(for: .connected) == "Refresh")
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
}
