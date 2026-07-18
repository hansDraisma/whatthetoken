import Foundation
import Testing
@testable import WhatTheTokenMac

@Test func sendsRateLimitsReadJsonRPCRequestAndDecodesResult() async throws {
    let response = """
    {
      "jsonrpc": "2.0",
      "id": 1,
      "result": {
        "rateLimits": {
          "limitId": "codex",
          "primary": { "usedPercent": 25, "windowDurationMins": 15, "resetsAt": 1730947200 }
        }
      }
    }
    """.data(using: .utf8)!
    let transport = RecordingCodexTransport(result: .success(response))
    let client = CodexAppServerClient(transport: transport)

    let decoded = try await client.readRateLimits()

    #expect(transport.sentJSON == [
        #"{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"clientInfo":{"name":"whatthetoken","version":"0.0.0"},"capabilities":{"experimentalApi":true}}}"#,
        #"{"jsonrpc":"2.0","method":"initialized","params":null}"#,
        #"{"jsonrpc":"2.0","method":"account/rateLimits/read","id":1}"#
    ])
    #expect(transport.expectedResponseId == 1)
    #expect(decoded.rateLimits.limitId == "codex")
    #expect(decoded.rateLimits.primary?.usedPercent == 25)
}

@Test func selectsExpectedResponseByIdAndIgnoresNotifications() throws {
    let lines = [
        #"{"jsonrpc":"2.0","id":0,"result":{"serverInfo":{"name":"codex-app-server"}}}"#.data(using: .utf8)!,
        #"{"jsonrpc":"2.0","method":"remoteControl/status/changed","params":{"status":"disconnected"}}"#.data(using: .utf8)!,
        """
        {
          "jsonrpc": "2.0",
          "id": 1,
          "result": {
            "rateLimits": {
              "limitId": "codex",
              "primary": { "usedPercent": 25, "windowDurationMins": 15, "resetsAt": 1730947200 }
            }
          }
        }
        """.data(using: .utf8)!
    ]

    let selected = try CodexJSONRPCResponseSelector.response(withId: 1, from: lines)
    let decoded = try CodexJSONRPCDecoder.decodeRateLimitsResponse(from: selected)

    #expect(decoded.rateLimits.limitId == "codex")
}

@Test func mapsJsonRPCAuthErrorToAuthRequired() async {
    let response = """
    {
      "jsonrpc": "2.0",
      "id": 1,
      "error": { "code": 401, "message": "OpenAI auth required" }
    }
    """.data(using: .utf8)!
    let client = CodexAppServerClient(transport: RecordingCodexTransport(result: .success(response)))

    await #expect(throws: CodexAppServerClientError.authRequired) {
        try await client.readRateLimits()
    }
}

@Test func mapsMissingRateLimitsResultToSchemaChanged() async {
    let response = """
    {
      "jsonrpc": "2.0",
      "id": 1,
      "result": { "other": true }
    }
    """.data(using: .utf8)!
    let client = CodexAppServerClient(transport: RecordingCodexTransport(result: .success(response)))

    await #expect(throws: CodexAppServerClientError.schemaChanged) {
        try await client.readRateLimits()
    }
}

@Test func mapsTransportFailureToNetworkError() async {
    let client = CodexAppServerClient(transport: RecordingCodexTransport(result: .failure(SyntheticTransportError())))

    await #expect(throws: CodexAppServerClientError.networkError) {
        try await client.readRateLimits()
    }
}

@Test func codexExecutableResolverFindsHomebrewCodexWhenPathIsRestricted() throws {
    let resolver = CodexAppServerExecutableResolver(
        environment: ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"],
        homeDirectory: URL(fileURLWithPath: "/Users/example"),
        fileExists: { path in
            path == "/opt/homebrew/bin/codex"
        }
    )

    let executableURL = try #require(resolver.executableURL())

    #expect(executableURL.path == "/opt/homebrew/bin/codex")
}

@Test func codexExecutableResolverFindsCodexAppWhenPathIsRestricted() throws {
    let resolver = CodexAppServerExecutableResolver(
        environment: ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"],
        homeDirectory: URL(fileURLWithPath: "/Users/example"),
        fileExists: { path in
            path == "/Applications/Codex.app/Contents/Resources/codex"
        }
    )

    let executableURL = try #require(resolver.executableURL())

    #expect(executableURL.path == "/Applications/Codex.app/Contents/Resources/codex")
}

@Test func codexExecutableResolverFindsConductorCodexWhenPathIsRestricted() throws {
    let resolver = CodexAppServerExecutableResolver(
        environment: ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"],
        homeDirectory: URL(fileURLWithPath: "/Users/example"),
        fileExists: { path in
            path == "/Users/example/Library/Application Support/com.conductor.app/bin/codex"
        }
    )

    let executableURL = try #require(resolver.executableURL())

    #expect(executableURL.path == "/Users/example/Library/Application Support/com.conductor.app/bin/codex")
}

@Test func codexExecutableResolverPrefersKnownLocationOverPath() throws {
    // Hardening: a poisoned $PATH entry must not preempt a real install location.
    let resolver = CodexAppServerExecutableResolver(
        environment: ["PATH": "/tmp/evil:/usr/bin"],
        homeDirectory: URL(fileURLWithPath: "/Users/example"),
        fileExists: { path in
            path == "/tmp/evil/codex" || path == "/opt/homebrew/bin/codex"
        }
    )

    let executableURL = try #require(resolver.executableURL())

    #expect(executableURL.path == "/opt/homebrew/bin/codex")
}

private struct SyntheticTransportError: Error {}

private final class RecordingCodexTransport: CodexAppServerTransport, @unchecked Sendable {
    private(set) var sentJSON: [String] = []
    private(set) var expectedResponseId: Int?
    let result: Result<Data, Error>

    init(result: Result<Data, Error>) {
        self.result = result
    }

    func transact(_ requests: [Data], expecting responseId: Int) async throws -> Data {
        sentJSON = requests.compactMap { String(data: $0, encoding: .utf8) }
        expectedResponseId = responseId
        return try result.get()
    }
}
