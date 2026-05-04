import Testing
@testable import WhatTheTokenMac

@Test func loadsFixtureSnapshotWithoutSensitiveContent() throws {
    let snapshot = try StatusViewModel.loadFixtureSnapshot()

    #expect(snapshot.product == "claude_code")
    #expect(snapshot.confidence == "verified")
    #expect(snapshot.remaining == 38)
    #expect(snapshot.staleReason == nil)
}
