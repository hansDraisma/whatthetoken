import Foundation
import Testing
@testable import WhatTheTokenMac

@Test func loadsFixtureSnapshot() throws {
    let snapshot = try StatusViewModel.loadFixtureSnapshot()

    #expect(snapshot.product == "claude_code")
    #expect(snapshot.confidence == "verified")
    #expect(snapshot.remaining == 38)
    #expect(snapshot.staleReason == nil)
}

@Test func fixtureJSONDoesNotContainSensitiveKeys() throws {
    let data = try StatusViewModel.loadFixtureData()
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let disallowedKeys = [
        "prompt",
        "completion",
        "conversation",
        "conversationUrl",
        "cookie",
        "authHeader",
        "bearerToken",
        "sessionToken"
    ]

    for key in disallowedKeys {
        #expect(object[key] == nil)
    }
}
