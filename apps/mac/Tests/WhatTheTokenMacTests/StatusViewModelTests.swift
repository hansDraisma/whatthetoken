import Testing
@testable import WhatTheTokenMac

@Test func loadsFixtureSnapshotWithoutSensitiveContent() throws {
    let snapshot = try StatusViewModel.loadFixtureSnapshot()

    #expect(snapshot.product == "claude_code")
    #expect(snapshot.confidence == "verified")
    #expect(snapshot.remaining == 38)
    #expect(snapshot.staleReason == nil)
    #expect(snapshot.source.connector == "manual_fixture")
    #expect(snapshot.source.state == .connected)
    #expect(snapshot.source.parserVersion == "fixture-v1")
}

@Test func statusCardCopyIncludesConnectorAndConfidence() throws {
    let snapshot = try StatusViewModel.loadFixtureSnapshot()

    #expect(StatusCardCopy.sourceLine(for: snapshot) == "Verified by Fixture")
    #expect(StatusCardCopy.riskLine(for: snapshot) == "Undercount possible")
}
