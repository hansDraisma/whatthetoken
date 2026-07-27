import Foundation
import Testing
@testable import WhatTheTokenMac

@Test func disabledCodexConnectorDoesNotReadRateLimits() async throws {
    let fetcher = StubCodexRateLimitsFetcher(response: codexRateLimitsResponse())
    let service = CodexConnectorService(
        settings: CodexConnectorSettings(isEnabled: false),
        rateLimitsFetcher: fetcher,
        deviceId: "device_mac_01",
        userAccountId: "local_user",
        now: { "2026-05-05T10:00:00.000Z" }
    )

    let result = try await service.refresh()

    #expect(result.snapshots.isEmpty)
    #expect(result.status.source.state == .notConnected)
    #expect(fetcher.readCount == 0)
}

@Test func enabledCodexConnectorMapsRateLimitsToConnectedSnapshots() async throws {
    let fetcher = StubCodexRateLimitsFetcher(response: codexRateLimitsResponse())
    let service = CodexConnectorService(
        settings: CodexConnectorSettings(isEnabled: true),
        rateLimitsFetcher: fetcher,
        deviceId: "device_mac_01",
        userAccountId: "local_user",
        now: { "2026-05-05T10:00:00.000Z" }
    )

    let result = try await service.refresh()

    #expect(result.status.source.state == .connected)
    #expect(result.status.message == "Codex connected")
    #expect(result.snapshots.count == 1)
    #expect(result.snapshots.first?.product == "codex")
    #expect(result.snapshots.first?.source.parserVersion == "codex-app-server-rate-limits-v1")
    #expect(fetcher.readCount == 1)
}

@Test func codexAuthRequiredMapsToMissingCredentialsWithLoginCopy() async throws {
    let result = try await refreshWithCodexError(.authRequired)

    #expect(result.snapshots.isEmpty)
    #expect(result.status.source.state == .missingCredentials)
    #expect(result.status.message == "Sign in to Codex locally")
}

@Test func codexPermissionDeniedMapsToPermissionDenied() async throws {
    let result = try await refreshWithCodexError(.permissionDenied)

    #expect(result.snapshots.isEmpty)
    #expect(result.status.source.state == .permissionDenied)
    #expect(result.status.message == "Codex app-server could not be started")
}

@Test func codexNetworkErrorMapsToNetworkError() async throws {
    let result = try await refreshWithCodexError(.networkError)

    #expect(result.snapshots.isEmpty)
    #expect(result.status.source.state == .networkError)
    #expect(result.status.message == "Codex usage could not be refreshed")
}

@Test func codexSchemaChangedMapsToSchemaChanged() async throws {
    let result = try await refreshWithCodexError(.schemaChanged)

    #expect(result.snapshots.isEmpty)
    #expect(result.status.source.state == .schemaChanged)
    #expect(result.status.message == "Codex usage response changed")
}

private func refreshWithCodexError(_ error: CodexAppServerClientError) async throws -> CodexConnectorResult {
    let fetcher = StubCodexRateLimitsFetcher(error: error)
    let service = CodexConnectorService(
        settings: CodexConnectorSettings(isEnabled: true),
        rateLimitsFetcher: fetcher,
        deviceId: "device_mac_01",
        userAccountId: "local_user",
        now: { "2026-05-05T10:00:00.000Z" }
    )

    return try await service.refresh()
}

private func codexRateLimitsResponse() -> CodexRateLimitsResponse {
    CodexRateLimitsResponse(
        rateLimits: CodexRateLimitSnapshot(
            credits: nil,
            limitId: "codex",
            limitName: nil,
            planType: "plus",
            primary: CodexRateLimitWindow(resetsAt: nil, usedPercent: 25, windowDurationMins: 15),
            rateLimitReachedType: nil,
            secondary: nil
        ),
        rateLimitsByLimitId: nil
    )
}

private final class StubCodexRateLimitsFetcher: CodexRateLimitsFetching, @unchecked Sendable {
    private(set) var readCount = 0
    let result: Result<CodexRateLimitsResponse, Error>

    init(response: CodexRateLimitsResponse) {
        self.result = .success(response)
    }

    init(error: Error) {
        self.result = .failure(error)
    }

    func readRateLimits() async throws -> CodexRateLimitsResponse {
        readCount += 1
        return try result.get()
    }
}
