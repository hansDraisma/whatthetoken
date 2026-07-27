import Foundation
import Testing
@testable import WhatTheTokenMac

private struct ProbeStubCredentialStore: ClaudeCredentialStore {
    let result: Result<ClaudeStoredCredential?, ClaudeCredentialStoreError>

    func readCredential() throws -> ClaudeStoredCredential? {
        switch result {
        case let .success(credential):
            return credential
        case let .failure(error):
            throw error
        }
    }
}

@Test
func probeReturnsFoundWithDigestForPresentCredential() async {
    let expiry = Date(timeIntervalSince1970: 1_000_000)
    let store = ProbeStubCredentialStore(
        result: .success(ClaudeStoredCredential(accessToken: "token-a", expiresAt: expiry))
    )

    let result = await ClaudeCredentialProbe(credentialStore: store).probe()

    #expect(result == .found(
        ClaudeCredentialFingerprint(
            tokenDigest: ClaudeCredentialProbe.digest(of: "token-a"),
            expiresAt: expiry
        )
    ))
}

@Test
func probeNeverExposesRawToken() async {
    let store = ProbeStubCredentialStore(
        result: .success(ClaudeStoredCredential(accessToken: "super-secret", expiresAt: nil))
    )

    guard case let .found(fingerprint) = await ClaudeCredentialProbe(credentialStore: store).probe() else {
        Issue.record("expected .found")
        return
    }

    #expect(fingerprint.tokenDigest != "super-secret")
    #expect(!fingerprint.tokenDigest.contains("super-secret"))
    #expect(fingerprint.tokenDigest.count == 64)
}

@Test
func probeReturnsAbsentWhenNoCredentialStored() async {
    let probe = ClaudeCredentialProbe(
        credentialStore: ProbeStubCredentialStore(result: .success(nil))
    )

    #expect(await probe.probe() == .absent)
}

@Test
func probeReturnsUnavailableWhenReadFails() async {
    let probe = ClaudeCredentialProbe(
        credentialStore: ProbeStubCredentialStore(result: .failure(.commandFailed))
    )

    #expect(await probe.probe() == .unavailable)
}

@Test
func digestIsStableAndDistinguishesTokens() {
    #expect(
        ClaudeCredentialProbe.digest(of: "token-a")
            == ClaudeCredentialProbe.digest(of: "token-a")
    )
    #expect(
        ClaudeCredentialProbe.digest(of: "token-a")
            != ClaudeCredentialProbe.digest(of: "token-b")
    )
}
