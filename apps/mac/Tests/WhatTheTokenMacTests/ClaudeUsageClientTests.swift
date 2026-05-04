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

    let client = ClaudeUsageClient(loader: loader)

    await #expect(throws: ClaudeUsageClientError.schemaChanged) {
        try await client.fetchUsage(accessToken: "synthetic-access-token", claudeVersion: "2.1.126")
    }
}

private struct StubClaudeURLLoader: ClaudeURLLoading {
    let result: (Data, URLResponse)

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        result
    }
}
