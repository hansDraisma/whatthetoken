import Foundation
import Testing
@testable import WhatTheTokenMac

@Test func disabledConnectorDoesNotReadCredentials() async throws {
    let credentialStore = StubClaudeCredentialStore(accessToken: "synthetic-access-token")
    let usageFetcher = StubClaudeUsageFetcher(response: ClaudeUsageResponse(
        fiveHour: ClaudeWindowUsage(utilization: 42.5, resetsAt: "2026-05-04T15:00:00Z"),
        sevenDay: nil,
        sevenDayOpus: nil,
        sevenDaySonnet: nil,
        extraUsage: nil
    ))

    let service = ClaudeConnectorService(
        settings: ClaudeConnectorSettings(isEnabled: false),
        credentialStore: credentialStore,
        usageFetcher: usageFetcher,
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "2.2.0-test"),
        deviceId: "device_mac_01",
        userAccountId: "local_user",
        now: { "2026-05-04T10:00:00.000Z" },
        currentDate: { Date(timeIntervalSince1970: 2000) }
    )

    let result = try await service.refresh()

    #expect(result.snapshots.isEmpty)
    #expect(result.status.source.state == .notConnected)
    #expect(credentialStore.readCount == 0)
}

@Test func enabledConnectorWithoutCredentialsReturnsMissingCredentials() async throws {
    let credentialStore = StubClaudeCredentialStore(accessToken: nil)
    let usageFetcher = StubClaudeUsageFetcher(response: ClaudeUsageResponse(
        fiveHour: ClaudeWindowUsage(utilization: 42.5, resetsAt: "2026-05-04T15:00:00Z"),
        sevenDay: nil,
        sevenDayOpus: nil,
        sevenDaySonnet: nil,
        extraUsage: nil
    ))

    let service = ClaudeConnectorService(
        settings: ClaudeConnectorSettings(isEnabled: true),
        credentialStore: credentialStore,
        usageFetcher: usageFetcher,
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "2.2.0-test"),
        deviceId: "device_mac_01",
        userAccountId: "local_user",
        now: { "2026-05-04T10:00:00.000Z" },
        currentDate: { Date(timeIntervalSince1970: 2000) }
    )

    let result = try await service.refresh()

    #expect(result.snapshots.isEmpty)
    #expect(result.status.source.state == .missingCredentials)
    #expect(credentialStore.readCount == 1)
    #expect(usageFetcher.fetchCount == 0)
}

@Test func enabledConnectorWithValidUsageReturnsConnectedSnapshots() async throws {
    let credentialStore = StubClaudeCredentialStore(accessToken: "synthetic-access-token")
    let usageFetcher = StubClaudeUsageFetcher(response: ClaudeUsageResponse(
        fiveHour: ClaudeWindowUsage(utilization: 42.5, resetsAt: "2026-05-04T15:00:00Z"),
        sevenDay: nil,
        sevenDayOpus: nil,
        sevenDaySonnet: nil,
        extraUsage: nil
    ))

    let service = ClaudeConnectorService(
        settings: ClaudeConnectorSettings(isEnabled: true),
        credentialStore: credentialStore,
        usageFetcher: usageFetcher,
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "2.2.0-test"),
        deviceId: "device_mac_01",
        userAccountId: "local_user",
        now: { "2026-05-04T10:00:00.000Z" },
        currentDate: { Date(timeIntervalSince1970: 2000) }
    )

    let result = try await service.refresh()

    #expect(result.status.source.state == .connected)
    #expect(result.snapshots.count == 1)
    let snapshot = try #require(result.snapshots.first)
    #expect(snapshot.windowKey == "five_hour")
    #expect(snapshot.remaining == 57.5)
    #expect(snapshot.source.state == .connected)
    #expect(credentialStore.readCount == 1)
    #expect(usageFetcher.fetchCount == 1)
    #expect(usageFetcher.lastAccessToken == "synthetic-access-token")
    #expect(usageFetcher.lastClaudeVersion == "2.2.0-test")
}

@Test func tokenInvalidErrorReturnsTokenInvalidStatus() async throws {
    let credentialStore = StubClaudeCredentialStore(accessToken: "synthetic-access-token")
    let usageFetcher = StubClaudeUsageFetcher(error: ClaudeUsageClientError.tokenInvalid)

    let service = ClaudeConnectorService(
        settings: ClaudeConnectorSettings(isEnabled: true),
        credentialStore: credentialStore,
        usageFetcher: usageFetcher,
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "2.2.0-test"),
        deviceId: "device_mac_01",
        userAccountId: "local_user",
        now: { "2026-05-04T10:00:00.000Z" },
        currentDate: { Date(timeIntervalSince1970: 2000) }
    )

    let result = try await service.refresh()

    #expect(result.snapshots.isEmpty)
    #expect(result.status.source.state == .tokenInvalid)
    // A 401 triggers one extra keychain re-read to detect token rotation; the
    // token is unchanged here, so no retry fetch is made.
    #expect(credentialStore.readCount == 2)
    #expect(usageFetcher.fetchCount == 1)
}

@Test func tokenInvalidWithExpiredCredentialReturnsSessionExpired() async throws {
    let credentialStore = StubClaudeCredentialStore(
        accessToken: "synthetic-access-token",
        expiresAt: Date(timeIntervalSince1970: 1900)
    )
    let usageFetcher = StubClaudeUsageFetcher(error: ClaudeUsageClientError.tokenInvalid)

    let service = ClaudeConnectorService(
        settings: ClaudeConnectorSettings(isEnabled: true),
        credentialStore: credentialStore,
        usageFetcher: usageFetcher,
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "2.2.0-test"),
        deviceId: "device_mac_01",
        userAccountId: "local_user",
        now: { "2026-05-04T10:00:00.000Z" },
        currentDate: { Date(timeIntervalSince1970: 2000) }
    )

    let result = try await service.refresh()

    #expect(result.status.source.state == .sessionExpired)
    #expect(result.status.message == "Waiting for Claude Code")
    #expect(usageFetcher.fetchCount == 1)
    #expect(credentialStore.readCount == 2)
}

@Test func credentialExpiredBeyondSkewSkipsGuaranteedFailingUsageCall() async throws {
    let credentialStore = StubClaudeCredentialStore(
        accessToken: "synthetic-access-token",
        expiresAt: Date(timeIntervalSince1970: 1600)
    )
    let usageFetcher = StubClaudeUsageFetcher(
        response: ClaudeUsageResponse(
            fiveHour: ClaudeWindowUsage(
                utilization: 42.5,
                resetsAt: "2026-05-04T15:00:00Z"
            ),
            sevenDay: nil,
            sevenDayOpus: nil,
            sevenDaySonnet: nil,
            extraUsage: nil
        )
    )
    let service = ClaudeConnectorService(
        settings: ClaudeConnectorSettings(isEnabled: true),
        credentialStore: credentialStore,
        usageFetcher: usageFetcher,
        claudeVersionProvider: StaticClaudeVersionProvider(
            claudeVersion: "2.2.0-test"
        ),
        deviceId: "device_mac_01",
        userAccountId: "local_user",
        now: { "2026-05-04T10:00:00.000Z" },
        currentDate: { Date(timeIntervalSince1970: 2000) }
    )

    let result = try await service.refresh()

    #expect(result.status.source.state == .sessionExpired)
    #expect(usageFetcher.fetchCount == 0)
}

@Test func credentialExpiredExactlyAtSkewBoundaryStillAttemptsUsageCall() async throws {
    let credentialStore = StubClaudeCredentialStore(
        accessToken: "synthetic-access-token",
        expiresAt: Date(timeIntervalSince1970: 1700)
    )
    let usageFetcher = StubClaudeUsageFetcher(error: ClaudeUsageClientError.tokenInvalid)
    let service = ClaudeConnectorService(
        settings: ClaudeConnectorSettings(isEnabled: true),
        credentialStore: credentialStore,
        usageFetcher: usageFetcher,
        claudeVersionProvider: StaticClaudeVersionProvider(
            claudeVersion: "2.2.0-test"
        ),
        deviceId: "device_mac_01",
        userAccountId: "local_user",
        now: { "2026-05-04T10:00:00.000Z" },
        currentDate: { Date(timeIntervalSince1970: 2000) }
    )

    let result = try await service.refresh()

    #expect(result.status.source.state == .sessionExpired)
    #expect(usageFetcher.fetchCount == 1)
}

@Test func tokenInvalidWithUnexpiredCredentialReturnsTokenInvalid() async throws {
    let credentialStore = StubClaudeCredentialStore(
        accessToken: "synthetic-access-token",
        expiresAt: Date(timeIntervalSince1970: 9999)
    )
    let usageFetcher = StubClaudeUsageFetcher(error: ClaudeUsageClientError.tokenInvalid)

    let service = ClaudeConnectorService(
        settings: ClaudeConnectorSettings(isEnabled: true),
        credentialStore: credentialStore,
        usageFetcher: usageFetcher,
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "2.2.0-test"),
        deviceId: "device_mac_01",
        userAccountId: "local_user",
        now: { "2026-05-04T10:00:00.000Z" },
        currentDate: { Date(timeIntervalSince1970: 2000) }
    )

    let result = try await service.refresh()

    #expect(result.status.source.state == .tokenInvalid)
    #expect(result.status.message == "Claude Code credentials are invalid")
}

@Test func rateLimitedErrorReturnsRateLimitedStatus() async throws {
    let result = try await refreshWithFetcherError(ClaudeUsageClientError.rateLimited)

    #expect(result.snapshots.isEmpty)
    #expect(result.status.source.state == .rateLimited)
    #expect(result.status.message == "Claude usage is rate limited")
}

@Test func networkErrorReturnsNetworkErrorStatus() async throws {
    let result = try await refreshWithFetcherError(ClaudeUsageClientError.networkError)

    #expect(result.snapshots.isEmpty)
    #expect(result.status.source.state == .networkError)
    #expect(result.status.message == "Claude Code usage could not be refreshed")
}

@Test func schemaChangedErrorReturnsSchemaChangedStatus() async throws {
    let result = try await refreshWithFetcherError(ClaudeUsageClientError.schemaChanged)

    #expect(result.snapshots.isEmpty)
    #expect(result.status.source.state == .schemaChanged)
    #expect(result.status.message == "Claude usage response changed")
}

@Test func rotatedTokenIsRetriedOnceAndConnects() async throws {
    let store = SequencedClaudeCredentialStore([
        ClaudeStoredCredential(accessToken: "old-token", expiresAt: nil),
        ClaudeStoredCredential(accessToken: "new-token", expiresAt: nil)
    ])
    let usageFetcher = TokenAwareUsageFetcher(
        validToken: "new-token",
        response: ClaudeUsageResponse(
            fiveHour: ClaudeWindowUsage(utilization: 42.5, resetsAt: "2026-05-04T15:00:00Z"),
            sevenDay: nil,
            sevenDayOpus: nil,
            sevenDaySonnet: nil,
            extraUsage: nil
        )
    )

    let service = ClaudeConnectorService(
        settings: ClaudeConnectorSettings(isEnabled: true),
        credentialStore: store,
        usageFetcher: usageFetcher,
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "2.2.0-test"),
        deviceId: "device_mac_01",
        userAccountId: "local_user",
        now: { "2026-05-04T10:00:00.000Z" },
        currentDate: { Date(timeIntervalSince1970: 2000) }
    )

    let result = try await service.refresh()

    #expect(result.status.source.state == .connected)
    #expect(usageFetcher.fetchCount == 2)
    #expect(store.readCount == 2)
}

@Test func tokenInvalidWithoutRotationDoesNotRetry() async throws {
    let store = SequencedClaudeCredentialStore([
        ClaudeStoredCredential(accessToken: "same-token", expiresAt: nil),
        ClaudeStoredCredential(accessToken: "same-token", expiresAt: nil)
    ])
    let usageFetcher = TokenAwareUsageFetcher(
        validToken: "never-valid",
        response: ClaudeUsageResponse(
            fiveHour: ClaudeWindowUsage(utilization: 42.5, resetsAt: "2026-05-04T15:00:00Z"),
            sevenDay: nil,
            sevenDayOpus: nil,
            sevenDaySonnet: nil,
            extraUsage: nil
        )
    )

    let service = ClaudeConnectorService(
        settings: ClaudeConnectorSettings(isEnabled: true),
        credentialStore: store,
        usageFetcher: usageFetcher,
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "2.2.0-test"),
        deviceId: "device_mac_01",
        userAccountId: "local_user",
        now: { "2026-05-04T10:00:00.000Z" },
        currentDate: { Date(timeIntervalSince1970: 2000) }
    )

    let result = try await service.refresh()

    #expect(result.status.source.state == .tokenInvalid)
    #expect(usageFetcher.fetchCount == 1)
    #expect(store.readCount == 2)
}

private func refreshWithFetcherError(_ error: ClaudeUsageClientError) async throws -> ClaudeConnectorResult {
    let credentialStore = StubClaudeCredentialStore(accessToken: "synthetic-access-token")
    let usageFetcher = StubClaudeUsageFetcher(error: error)

    let service = ClaudeConnectorService(
        settings: ClaudeConnectorSettings(isEnabled: true),
        credentialStore: credentialStore,
        usageFetcher: usageFetcher,
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "2.2.0-test"),
        deviceId: "device_mac_01",
        userAccountId: "local_user",
        now: { "2026-05-04T10:00:00.000Z" },
        currentDate: { Date(timeIntervalSince1970: 2000) }
    )

    return try await service.refresh()
}

private final class StubClaudeCredentialStore: ClaudeCredentialStore, @unchecked Sendable {
    private(set) var readCount = 0
    var credential: ClaudeStoredCredential?

    init(accessToken: String?, expiresAt: Date? = nil) {
        self.credential = accessToken.map { ClaudeStoredCredential(accessToken: $0, expiresAt: expiresAt) }
    }

    func readCredential() throws -> ClaudeStoredCredential? {
        readCount += 1
        return credential
    }
}

private final class StubClaudeUsageFetcher: ClaudeUsageFetching, @unchecked Sendable {
    private(set) var fetchCount = 0
    private(set) var lastAccessToken: String?
    private(set) var lastClaudeVersion: String?
    let result: Result<ClaudeUsageResponse, Error>

    init(response: ClaudeUsageResponse) {
        self.result = .success(response)
    }

    init(error: Error) {
        self.result = .failure(error)
    }

    func fetchUsage(accessToken: String, claudeVersion: String) async throws -> ClaudeUsageResponse {
        fetchCount += 1
        lastAccessToken = accessToken
        lastClaudeVersion = claudeVersion
        return try result.get()
    }
}

private final class SequencedClaudeCredentialStore: ClaudeCredentialStore, @unchecked Sendable {
    private(set) var readCount = 0
    private let credentials: [ClaudeStoredCredential?]

    init(_ credentials: [ClaudeStoredCredential?]) {
        self.credentials = credentials
    }

    func readCredential() throws -> ClaudeStoredCredential? {
        defer { readCount += 1 }
        return credentials[min(readCount, credentials.count - 1)]
    }
}

private final class TokenAwareUsageFetcher: ClaudeUsageFetching, @unchecked Sendable {
    private(set) var fetchCount = 0
    let validToken: String
    let response: ClaudeUsageResponse

    init(validToken: String, response: ClaudeUsageResponse) {
        self.validToken = validToken
        self.response = response
    }

    func fetchUsage(accessToken: String, claudeVersion: String) async throws -> ClaudeUsageResponse {
        fetchCount += 1
        guard accessToken == validToken else {
            throw ClaudeUsageClientError.tokenInvalid
        }
        return response
    }
}
