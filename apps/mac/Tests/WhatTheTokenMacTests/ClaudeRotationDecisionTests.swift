import Foundation
import Testing
@testable import WhatTheTokenMac

private let rotationDecisionNow = Date(timeIntervalSince1970: 3_000_000)

private func foundCredential(
    _ token: String,
    expiresAt: Date?
) -> ClaudeCredentialProbeResult {
    .found(ClaudeCredentialFingerprint(tokenDigest: token, expiresAt: expiresAt))
}

@Test
func unchangedTokenDoesNotRefresh() {
    let sample = foundCredential(
        "a",
        expiresAt: rotationDecisionNow.addingTimeInterval(-100)
    )

    #expect(!ClaudeRotationDecision.shouldRefresh(
        previous: sample,
        current: sample,
        now: rotationDecisionNow
    ))
}

@Test
func rotatedTokenRefreshes() {
    #expect(ClaudeRotationDecision.shouldRefresh(
        previous: foundCredential(
            "a",
            expiresAt: rotationDecisionNow.addingTimeInterval(-100)
        ),
        current: foundCredential(
            "b",
            expiresAt: rotationDecisionNow.addingTimeInterval(3_600)
        ),
        now: rotationDecisionNow
    ))
}

@Test
func credentialAppearingRefreshes() {
    #expect(ClaudeRotationDecision.shouldRefresh(
        previous: .absent,
        current: foundCredential(
            "a",
            expiresAt: rotationDecisionNow.addingTimeInterval(3_600)
        ),
        now: rotationDecisionNow
    ))
}

@Test
func sameTokenWithExpiryMovedIntoFutureRefreshes() {
    #expect(ClaudeRotationDecision.shouldRefresh(
        previous: foundCredential(
            "a",
            expiresAt: rotationDecisionNow.addingTimeInterval(-100)
        ),
        current: foundCredential(
            "a",
            expiresAt: rotationDecisionNow.addingTimeInterval(3_600)
        ),
        now: rotationDecisionNow
    ))
}

@Test
func unavailableNeverRefreshes() {
    #expect(!ClaudeRotationDecision.shouldRefresh(
        previous: foundCredential(
            "a",
            expiresAt: rotationDecisionNow.addingTimeInterval(-100)
        ),
        current: .unavailable,
        now: rotationDecisionNow
    ))
}

@Test
func recoveredKeychainReadWithoutBaselineDoesNotRefresh() {
    #expect(!ClaudeRotationDecision.shouldRefresh(
        previous: .unavailable,
        current: foundCredential(
            "a",
            expiresAt: rotationDecisionNow.addingTimeInterval(3_600)
        ),
        now: rotationDecisionNow
    ))
}

@Test
func credentialDisappearingDoesNotRefresh() {
    #expect(!ClaudeRotationDecision.shouldRefresh(
        previous: foundCredential(
            "a",
            expiresAt: rotationDecisionNow.addingTimeInterval(-100)
        ),
        current: .absent,
        now: rotationDecisionNow
    ))
}
