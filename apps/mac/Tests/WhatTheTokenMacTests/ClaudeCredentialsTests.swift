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
