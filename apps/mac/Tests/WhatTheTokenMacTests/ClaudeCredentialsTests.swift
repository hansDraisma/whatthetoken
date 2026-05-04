import Foundation
import Testing
@testable import WhatTheTokenMac

@Test func extractsAccessTokenFromClaudeCodeCredentialJson() throws {
    let json = """
    {
      "claudeAiOauth": {
        "accessToken": "synthetic-access-token"
      }
    }
    """.data(using: .utf8)!

    let credentials = try JSONDecoder().decode(ClaudeCredentials.self, from: json)

    #expect(credentials.accessToken == "synthetic-access-token")
}

@Test func missingClaudeOauthEntryHasNoAccessToken() throws {
    let json = "{}".data(using: .utf8)!

    let credentials = try JSONDecoder().decode(ClaudeCredentials.self, from: json)

    #expect(credentials.accessToken == nil)
}

@Test func syntheticTokenIsRedactedForDescriptions() {
    let credentials = ClaudeCredentials(
        claudeAiOauth: ClaudeOAuthCredential(accessToken: "synthetic-access-token")
    )

    #expect(String(describing: credentials) == "ClaudeCredentials(accessToken: redacted)")
}

@Test func macOSCredentialStoreReadsAccessTokenFromSecurityOutput() throws {
    let json = """
    {
      "claudeAiOauth": {
        "accessToken": "synthetic-access-token"
      }
    }
    """.data(using: .utf8)!
    let runner = StubClaudeCredentialCommandRunner(
        result: .success(ClaudeCredentialCommandResult(terminationStatus: 0, standardOutput: json))
    )
    let store = MacOSClaudeCredentialStore(commandRunner: runner)

    let accessToken = try store.readAccessToken()

    #expect(accessToken == "synthetic-access-token")
    #expect(runner.lastServiceName == "Claude Code-credentials")
}

@Test func macOSCredentialStoreReturnsNilWhenSecurityItemIsMissing() throws {
    let runner = StubClaudeCredentialCommandRunner(
        result: .success(ClaudeCredentialCommandResult(terminationStatus: 44, standardOutput: Data()))
    )
    let store = MacOSClaudeCredentialStore(commandRunner: runner)

    let accessToken = try store.readAccessToken()

    #expect(accessToken == nil)
}

@Test func macOSCredentialStoreMapsRunnerFailuresToCommandFailed() throws {
    let runner = StubClaudeCredentialCommandRunner(result: .failure(ClaudeCredentialStoreError.commandFailed))
    let store = MacOSClaudeCredentialStore(commandRunner: runner)

    #expect(throws: ClaudeCredentialStoreError.commandFailed) {
        _ = try store.readAccessToken()
    }
}

private final class StubClaudeCredentialCommandRunner: ClaudeCredentialCommandRunning, @unchecked Sendable {
    private(set) var lastServiceName: String?
    let result: Result<ClaudeCredentialCommandResult, Error>

    init(result: Result<ClaudeCredentialCommandResult, Error>) {
        self.result = result
    }

    func readGenericPassword(serviceName: String) throws -> ClaudeCredentialCommandResult {
        lastServiceName = serviceName
        return try result.get()
    }
}
