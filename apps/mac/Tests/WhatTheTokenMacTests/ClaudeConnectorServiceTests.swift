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
        deviceId: "device_mac_01",
        userAccountId: "local_user",
        now: { "2026-05-04T10:00:00.000Z" }
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
        deviceId: "device_mac_01",
        userAccountId: "local_user",
        now: { "2026-05-04T10:00:00.000Z" }
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
        deviceId: "device_mac_01",
        userAccountId: "local_user",
        now: { "2026-05-04T10:00:00.000Z" }
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
}

@Test func tokenInvalidErrorReturnsTokenInvalidStatus() async throws {
    let credentialStore = StubClaudeCredentialStore(accessToken: "synthetic-access-token")
    let usageFetcher = StubClaudeUsageFetcher(error: ClaudeUsageClientError.tokenInvalid)

    let service = ClaudeConnectorService(
        settings: ClaudeConnectorSettings(isEnabled: true),
        credentialStore: credentialStore,
        usageFetcher: usageFetcher,
        deviceId: "device_mac_01",
        userAccountId: "local_user",
        now: { "2026-05-04T10:00:00.000Z" }
    )

    let result = try await service.refresh()

    #expect(result.snapshots.isEmpty)
    #expect(result.status.source.state == .tokenInvalid)
    #expect(credentialStore.readCount == 1)
    #expect(usageFetcher.fetchCount == 1)
}

private final class StubClaudeCredentialStore: ClaudeCredentialStore, @unchecked Sendable {
    private(set) var readCount = 0
    var accessToken: String?

    init(accessToken: String?) {
        self.accessToken = accessToken
    }

    func readAccessToken() throws -> String? {
        readCount += 1
        return accessToken
    }
}

private final class StubClaudeUsageFetcher: ClaudeUsageFetching, @unchecked Sendable {
    private(set) var fetchCount = 0
    private(set) var lastAccessToken: String?
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
        return try result.get()
    }
}
