import Testing
@testable import WhatTheTokenMac

@Suite struct ConnectorRecoveryCopyTests {
    @Test func claudeCopyCoversEveryState() {
        #expect(ConnectorRecoveryCopy.claude(.notConnected) == ConnectorCopy(
            headline: "Claude Code is not connected",
            advice: "Connect Claude Code in Settings to see remaining usage.",
            recovery: .connect
        ))
        #expect(ConnectorRecoveryCopy.claude(.checking) == ConnectorCopy(
            headline: "Checking Claude Code",
            advice: "",
            recovery: .checking
        ))
        #expect(ConnectorRecoveryCopy.claude(.connected) == ConnectorCopy(
            headline: "Claude Code connected",
            advice: "",
            recovery: .none
        ))
        #expect(ConnectorRecoveryCopy.claude(.missingCredentials) == ConnectorCopy(
            headline: "Claude Code credentials were not found",
            advice: "Sign in by opening Claude Code, then retry.",
            recovery: .signInLocally
        ))
        #expect(ConnectorRecoveryCopy.claude(.missingClaudeCli) == ConnectorCopy(
            headline: "Claude Code CLI was not found",
            advice: "Install Claude Code, sign in locally, then retry.",
            recovery: .installCLI
        ))
        #expect(ConnectorRecoveryCopy.claude(.tokenInvalid) == ConnectorCopy(
            headline: "Claude Code credentials are invalid",
            advice: "Sign in again in Claude Code, then retry.",
            recovery: .signInLocally
        ))
        #expect(ConnectorRecoveryCopy.claude(.sessionExpired) == ConnectorCopy(
            headline: "Claude Code session expired",
            advice: "Open Claude Code to refresh your session, then retry.",
            recovery: .retry
        ))
        #expect(ConnectorRecoveryCopy.claude(.rateLimited) == ConnectorCopy(
            headline: "Claude usage is rate limited",
            advice: "Wait for the provider limit to reset, then retry.",
            recovery: .waitForReset
        ))
        #expect(ConnectorRecoveryCopy.claude(.networkError) == ConnectorCopy(
            headline: "Claude Code usage could not be refreshed",
            advice: "Check your connection, then retry.",
            recovery: .retry
        ))
        #expect(ConnectorRecoveryCopy.claude(.schemaChanged) == ConnectorCopy(
            headline: "Claude usage response changed",
            advice: "Check for a WhatTheToken update with support for the latest response.",
            recovery: .checkForUpdates
        ))
    }

    @Test func codexCopyCoversEveryState() {
        #expect(ConnectorRecoveryCopy.codex(.notConnected) == ConnectorCopy(
            headline: "Codex is not connected",
            advice: "Connect Codex in Settings to see remaining usage and rate-limit status.",
            recovery: .connect
        ))
        #expect(ConnectorRecoveryCopy.codex(.checking) == ConnectorCopy(
            headline: "Checking Codex",
            advice: "",
            recovery: .checking
        ))
        #expect(ConnectorRecoveryCopy.codex(.connected) == ConnectorCopy(
            headline: "Codex connected",
            advice: "",
            recovery: .none
        ))
        #expect(ConnectorRecoveryCopy.codex(.missingCredentials) == ConnectorCopy(
            headline: "Sign in to Codex locally",
            advice: "Sign in by running Codex locally, then retry.",
            recovery: .signInLocally
        ))
        #expect(ConnectorRecoveryCopy.codex(.permissionDenied) == ConnectorCopy(
            headline: "Codex app-server could not be started",
            advice: "Check local permissions for Codex, then retry.",
            recovery: .retry
        ))
        #expect(ConnectorRecoveryCopy.codex(.networkError) == ConnectorCopy(
            headline: "Codex usage could not be refreshed",
            advice: "Check your connection, then retry.",
            recovery: .retry
        ))
        #expect(ConnectorRecoveryCopy.codex(.schemaChanged) == ConnectorCopy(
            headline: "Codex usage response changed",
            advice: "Check for a WhatTheToken update with support for the latest response.",
            recovery: .checkForUpdates
        ))
    }

    @Test func onlyHealthyStatesHaveNoRecovery() {
        let claudeRecoveries = [
            ConnectorRecoveryCopy.claude(.notConnected).recovery,
            ConnectorRecoveryCopy.claude(.checking).recovery,
            ConnectorRecoveryCopy.claude(.connected).recovery,
            ConnectorRecoveryCopy.claude(.missingCredentials).recovery,
            ConnectorRecoveryCopy.claude(.missingClaudeCli).recovery,
            ConnectorRecoveryCopy.claude(.tokenInvalid).recovery,
            ConnectorRecoveryCopy.claude(.sessionExpired).recovery,
            ConnectorRecoveryCopy.claude(.rateLimited).recovery,
            ConnectorRecoveryCopy.claude(.networkError).recovery,
            ConnectorRecoveryCopy.claude(.schemaChanged).recovery
        ]
        let codexRecoveries = [
            ConnectorRecoveryCopy.codex(.notConnected).recovery,
            ConnectorRecoveryCopy.codex(.checking).recovery,
            ConnectorRecoveryCopy.codex(.connected).recovery,
            ConnectorRecoveryCopy.codex(.missingCredentials).recovery,
            ConnectorRecoveryCopy.codex(.permissionDenied).recovery,
            ConnectorRecoveryCopy.codex(.networkError).recovery,
            ConnectorRecoveryCopy.codex(.schemaChanged).recovery
        ]

        #expect(claudeRecoveries.filter { $0 == .none }.count == 1)
        #expect(codexRecoveries.filter { $0 == .none }.count == 1)
    }
}
