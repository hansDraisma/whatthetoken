import Foundation
import Testing
@testable import WhatTheTokenMac

@Test func buildsClaudeUsageRequestWithoutPersistingToken() throws {
    let request = ClaudeUsageRequestFactory.makeRequest(
        accessToken: "synthetic-access-token",
        claudeVersion: "2.1.126"
    )

    #expect(request.url?.absoluteString == "https://api.anthropic.com/api/oauth/usage")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-access-token")
    #expect(request.value(forHTTPHeaderField: "anthropic-beta") == "oauth-2025-04-20")
    #expect(request.value(forHTTPHeaderField: "User-Agent") == "claude-code/2.1.126")
    #expect(request.httpBody == nil)
}

@Test func mapsUnauthorizedToTokenInvalid() async throws {
    let loader = StubClaudeURLLoader(result: (
        Data(),
        HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/api/oauth/usage")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )!
    ))

    let client = ClaudeUsageClient(loader: loader)

    await #expect(throws: ClaudeUsageClientError.tokenInvalid) {
        try await client.fetchUsage(accessToken: "synthetic-access-token", claudeVersion: "2.1.126")
    }
}

@Test func decodesSuccessfulUsageResponse() async throws {
    let json = """
    { "five_hour": { "utilization": 42.5, "resets_at": "2026-05-04T15:00:00Z" } }
    """.data(using: .utf8)!

    let loader = StubClaudeURLLoader(result: (
        json,
        HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/api/oauth/usage")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
    ))

    let client = ClaudeUsageClient(loader: loader)
    let response = try await client.fetchUsage(
        accessToken: "synthetic-access-token",
        claudeVersion: "2.1.126"
    )

    #expect(response.fiveHour?.utilization == 42.5)
}

@Test func decodesFableWindowWithoutReportingSchemaDrift() async throws {
    let json = """
    {
      "seven_day": { "utilization": 44.0, "resets_at": "2026-07-22T17:00:00Z" },
      "seven_day_fable": { "utilization": 57.0, "resets_at": "2026-07-22T17:00:00Z" }
    }
    """.data(using: .utf8)!
    let loader = StubClaudeURLLoader(result: (
        json,
        HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/api/oauth/usage")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
    ))
    let reporter = RecordingClaudeUsageSchemaReporter()

    let response = try await ClaudeUsageClient(
        loader: loader,
        schemaReporter: reporter
    ).fetchUsage(
        accessToken: "synthetic-access-token",
        claudeVersion: "2.1.126"
    )

    #expect(response.windows["seven_day_fable"]?.utilization == 57)
    #expect(reporter.incidents.isEmpty)
}

@Test func decodesSuccessfulExtraUsageOnlyResponse() async throws {
    let json = """
    {
      "extra_usage": {
        "is_enabled": true,
        "used_credits": 422.0,
        "monthly_limit": 1000.0
      }
    }
    """.data(using: .utf8)!

    let loader = StubClaudeURLLoader(result: (
        json,
        HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/api/oauth/usage")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
    ))

    let client = ClaudeUsageClient(loader: loader)
    let response = try await client.fetchUsage(
        accessToken: "synthetic-access-token",
        claudeVersion: "2.1.126"
    )

    #expect(response.extraUsage?.usedCredits == 422)
}

@Test func mapsEmptySuccessfulResponseToSchemaChanged() async throws {
    let loader = StubClaudeURLLoader(result: (
        "{}".data(using: .utf8)!,
        HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/api/oauth/usage")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
    ))

    let reporter = RecordingClaudeUsageSchemaReporter()
    let client = ClaudeUsageClient(loader: loader, schemaReporter: reporter)

    await #expect(throws: ClaudeUsageClientError.schemaChanged) {
        try await client.fetchUsage(accessToken: "synthetic-access-token", claudeVersion: "2.1.126")
    }

    #expect(reporter.incidents == [ClaudeUsageSchemaIncident(
        reason: .noUsageSignals,
        topLevelKeys: [],
        affectedKeys: []
    )])
}

@Test func reportsMalformedModelWindowWithoutDiscardingHealthyWindows() async throws {
    let json = """
    {
      "five_hour": { "utilization": 42.5, "resets_at": "2026-05-04T15:00:00Z" },
      "seven_day_fable": { "utilization": "changed-type", "resets_at": null }
    }
    """.data(using: .utf8)!
    let loader = StubClaudeURLLoader(result: (
        json,
        HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/api/oauth/usage")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
    ))
    let reporter = RecordingClaudeUsageSchemaReporter()

    let response = try await ClaudeUsageClient(
        loader: loader,
        schemaReporter: reporter
    ).fetchUsage(
        accessToken: "synthetic-access-token",
        claudeVersion: "2.1.126"
    )

    #expect(response.fiveHour?.utilization == 42.5)
    #expect(response.windows["seven_day_fable"] == nil)
    #expect(reporter.incidents == [ClaudeUsageSchemaIncident(
        reason: .malformedUsageFields,
        topLevelKeys: ["five_hour", "seven_day_fable"],
        affectedKeys: ["seven_day_fable"]
    )])
}

@Test func reportsMalformedDynamicallyNamedWindowByItsShape() async throws {
    let json = """
    {
      "five_hour": { "utilization": 42.5, "resets_at": "2026-05-04T15:00:00Z" },
      "future_pool_name": { "utilization": "changed-type", "resets_at": null }
    }
    """.data(using: .utf8)!
    let loader = StubClaudeURLLoader(result: (
        json,
        HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/api/oauth/usage")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
    ))
    let reporter = RecordingClaudeUsageSchemaReporter()

    _ = try await ClaudeUsageClient(
        loader: loader,
        schemaReporter: reporter
    ).fetchUsage(
        accessToken: "synthetic-access-token",
        claudeVersion: "2.1.126"
    )

    #expect(reporter.incidents.first?.affectedKeys == ["future_pool_name"])
}

@Test func schemaReporterRedactsUnsafeProviderFieldNames() async throws {
    let json = """
    {
      "five_hour": { "utilization": 42.5, "resets_at": null },
      "unsafe field name": { "utilization": "changed-type", "resets_at": null }
    }
    """.data(using: .utf8)!
    let loader = StubClaudeURLLoader(result: (
        json,
        HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/api/oauth/usage")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
    ))
    let reporter = RecordingClaudeUsageSchemaReporter()

    _ = try await ClaudeUsageClient(
        loader: loader,
        schemaReporter: reporter
    ).fetchUsage(
        accessToken: "synthetic-access-token",
        claudeVersion: "2.1.126"
    )

    #expect(reporter.incidents.first?.topLevelKeys == ["<redacted>", "five_hour"])
    #expect(reporter.incidents.first?.affectedKeys == ["<redacted>"])
}

@Test func reportsInvalidTopLevelPayloadAsSchemaDrift() async throws {
    let loader = StubClaudeURLLoader(result: (
        "[]".data(using: .utf8)!,
        HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/api/oauth/usage")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
    ))
    let reporter = RecordingClaudeUsageSchemaReporter()
    let client = ClaudeUsageClient(loader: loader, schemaReporter: reporter)

    await #expect(throws: ClaudeUsageClientError.schemaChanged) {
        try await client.fetchUsage(accessToken: "synthetic-access-token", claudeVersion: "2.1.126")
    }

    #expect(reporter.incidents == [ClaudeUsageSchemaIncident(
        reason: .responseDecodingFailed,
        topLevelKeys: [],
        affectedKeys: []
    )])
}

private struct StubClaudeURLLoader: ClaudeURLLoading {
    let result: (Data, URLResponse)

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        result
    }
}

private final class RecordingClaudeUsageSchemaReporter: ClaudeUsageSchemaReporting, @unchecked Sendable {
    private(set) var incidents: [ClaudeUsageSchemaIncident] = []

    func report(_ incident: ClaudeUsageSchemaIncident) {
        incidents.append(incident)
    }
}
