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
        claudeAiOauth: ClaudeOAuthCredential(accessToken: "synthetic-access-token", expiresAt: nil)
    )

    #expect(String(describing: credentials) == "ClaudeCredentials(accessToken: redacted)")
}

@Test func decodesExpiresAtMillisAsDate() throws {
    let json = """
    {
      "claudeAiOauth": {
        "accessToken": "synthetic-access-token",
        "expiresAt": 1782707138578
      }
    }
    """.data(using: .utf8)!

    let credentials = try JSONDecoder().decode(ClaudeCredentials.self, from: json)

    #expect(credentials.accessToken == "synthetic-access-token")
    #expect(credentials.expiresAt == Date(timeIntervalSince1970: 1782707138.578))
}

@Test func missingExpiresAtYieldsNilDate() throws {
    let json = """
    { "claudeAiOauth": { "accessToken": "synthetic-access-token" } }
    """.data(using: .utf8)!

    let credentials = try JSONDecoder().decode(ClaudeCredentials.self, from: json)

    #expect(credentials.expiresAt == nil)
}

@Test func unexpectedExpiresAtTypeStillDecodesAccessToken() throws {
    // expiresAt is non-essential: an upstream format change must not break
    // extraction of the essential access token.
    let json = """
    {
      "claudeAiOauth": {
        "accessToken": "synthetic-access-token",
        "expiresAt": "2026-06-29T07:05:38Z"
      }
    }
    """.data(using: .utf8)!

    let credentials = try JSONDecoder().decode(ClaudeCredentials.self, from: json)

    #expect(credentials.accessToken == "synthetic-access-token")
    #expect(credentials.expiresAt == nil)
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

    let credential = try store.readCredential()

    #expect(credential?.accessToken == "synthetic-access-token")
    #expect(runner.lastServiceName == "Claude Code-credentials")
}

@Test func macOSCredentialStoreReadsExpiryFromSecurityOutput() throws {
    let json = """
    {
      "claudeAiOauth": {
        "accessToken": "synthetic-access-token",
        "expiresAt": 1782707138578
      }
    }
    """.data(using: .utf8)!
    let runner = StubClaudeCredentialCommandRunner(
        result: .success(ClaudeCredentialCommandResult(terminationStatus: 0, standardOutput: json))
    )
    let store = MacOSClaudeCredentialStore(commandRunner: runner)

    let credential = try store.readCredential()

    #expect(credential?.accessToken == "synthetic-access-token")
    #expect(credential?.expiresAt == Date(timeIntervalSince1970: 1782707138.578))
}

@Test func macOSCredentialStoreReturnsNilWhenSecurityItemIsMissing() throws {
    let runner = StubClaudeCredentialCommandRunner(
        result: .success(ClaudeCredentialCommandResult(terminationStatus: 44, standardOutput: Data()))
    )
    let store = MacOSClaudeCredentialStore(commandRunner: runner)

    let credential = try store.readCredential()

    #expect(credential == nil)
}

@Test func macOSCredentialStoreTreatsOtherSecurityFailuresAsUnavailable() throws {
    let runner = StubClaudeCredentialCommandRunner(
        result: .success(
            ClaudeCredentialCommandResult(
                terminationStatus: 36,
                standardOutput: Data()
            )
        )
    )
    let store = MacOSClaudeCredentialStore(commandRunner: runner)

    #expect(throws: ClaudeCredentialStoreError.commandFailed) {
        _ = try store.readCredential()
    }
}

@Test func macOSCredentialStoreMapsRunnerFailuresToCommandFailed() throws {
    let runner = StubClaudeCredentialCommandRunner(result: .failure(ClaudeCredentialStoreError.commandFailed))
    let store = MacOSClaudeCredentialStore(commandRunner: runner)

    #expect(throws: ClaudeCredentialStoreError.commandFailed) {
        _ = try store.readCredential()
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
