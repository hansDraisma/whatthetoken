import Foundation
import Testing
@testable import WhatTheTokenMac

@Test func smokeCommandReportsSanitizedConnectedSnapshots() async throws {
    let source = ConnectorSource(
        connector: "mac_connector",
        state: .connected,
        label: "Mac connector",
        parserVersion: "claude-code-oauth-usage-v1",
        deviceId: "device_mac_01"
    )
    let snapshot = UsageSnapshot(
        id: "snap_claude_five_hour",
        userAccountId: "local_user",
        provider: "anthropic",
        product: "claude_code",
        surface: "cli",
        poolKey: "anthropic_claude_subscription",
        windowKey: "five_hour",
        unit: "utilization",
        used: 42.5,
        limit: 100,
        remaining: 57.5,
        utilization: 0.425,
        resetAt: "2026-05-04T15:00:00Z",
        lastUpdatedAt: "2026-05-04T10:00:00.000Z",
        confidence: "verified",
        undercountRisk: "possible",
        staleReason: nil,
        source: source
    )
    let refresher = StubClaudeConnectorRefresher(result: .success(ClaudeConnectorResult(
        snapshots: [snapshot],
        status: ConnectorStatus(
            product: "claude_code",
            source: source,
            message: "Claude Code connected"
        )
    )))
    let command = ClaudeConnectorSmokeCommand(refresher: refresher)

    let report = await command.run()
    let output = report.outputLines.joined(separator: "\n")

    #expect(report.exitCode == 0)
    #expect(output.contains("Claude connector smoke: connected"))
    #expect(output.contains("Status: Claude Code connected"))
    #expect(output.contains("Snapshot: claude_code five_hour utilization used=42.5 limit=100.0 remaining=57.5 source=mac_connector/connected parser=claude-code-oauth-usage-v1 updated=2026-05-04T10:00:00.000Z"))
    #expect(!output.contains("synthetic-access-token"))
    #expect(!output.contains("Authorization"))
    #expect(!output.contains("five_hour\":"))
}

@Test func smokeCommandReturnsNonZeroWhenConnectorIsNotConnected() async {
    let source = ConnectorSource(
        connector: "mac_connector",
        state: .missingCredentials,
        label: "Mac connector",
        parserVersion: "claude-code-oauth-usage-v1",
        deviceId: "device_mac_01"
    )
    let refresher = StubClaudeConnectorRefresher(result: .success(ClaudeConnectorResult(
        snapshots: [],
        status: ConnectorStatus(
            product: "claude_code",
            source: source,
            message: "Claude Code credentials were not found"
        )
    )))
    let command = ClaudeConnectorSmokeCommand(refresher: refresher)

    let report = await command.run()
    let output = report.outputLines.joined(separator: "\n")

    #expect(report.exitCode == 2)
    #expect(output.contains("Claude connector smoke: missing_credentials"))
    #expect(output.contains("Snapshots: 0"))
}

@Test func smokeCommandDetectsExplicitCommandLineFlag() {
    #expect(ClaudeConnectorSmokeCommand.shouldRun(arguments: ["WhatTheTokenMac", "--claude-connector-smoke"]))
    #expect(!ClaudeConnectorSmokeCommand.shouldRun(arguments: ["WhatTheTokenMac"]))
}

@Test func liveSmokeSetupFailsBeforeCredentialReadWhenClaudeVersionIsMissing() async {
    let runner = StubLiveSmokeRunner(result: .success(ClaudeConnectorResult(
        snapshots: [],
        status: ConnectorStatus(
            product: "claude_code",
            source: ConnectorSource(
                connector: "mac_connector",
                state: .connected,
                label: "Mac connector",
                parserVersion: "claude-code-oauth-usage-v1",
                deviceId: "local_mac"
            ),
            message: "Claude Code connected"
        )
    )))

    let report = await ClaudeConnectorSmokeCommand.runLive(
        environment: [:],
        runner: runner
    )

    let output = report.outputLines.joined(separator: "\n")
    #expect(report.exitCode == 2)
    #expect(output.contains("Claude connector smoke: missing_claude_version"))
    #expect(runner.runCount == 0)
}

@MainActor
@Test func commandLineSmokeCompletesWhileMainActorCallerWaits() {
    let capture = SmokeStartCapture()
    let finished = DispatchSemaphore(value: 0)

    let started = ClaudeConnectorSmokeCommand.startCommandLineSmoke(
        environment: ["CLAUDE_CODE_VERSION": "2.2.0-test"],
        runner: StubLiveSmokeRunner(result: .success(ClaudeConnectorResult(
            snapshots: [],
            status: ConnectorStatus(
                product: "claude_code",
                source: ConnectorSource(
                    connector: "mac_connector",
                    state: .missingCredentials,
                    label: "Mac connector",
                    parserVersion: "claude-code-oauth-usage-v1",
                    deviceId: "local_mac"
                ),
                message: "Claude Code credentials were not found"
            )
        ))),
        output: { line in
            capture.append(line)
        },
        exit: { code in
            capture.exitCode = code
            finished.signal()
        }
    )

    #expect(started)
    #expect(finished.wait(timeout: .now() + 2) == .success)
    #expect(capture.exitCode == 2)
    #expect(capture.lines.contains("Claude connector smoke: missing_credentials"))
}

private struct StubClaudeConnectorRefresher: ClaudeConnectorRefreshing {
    let result: Result<ClaudeConnectorResult, Error>

    func refresh() async throws -> ClaudeConnectorResult {
        try result.get()
    }
}

private final class StubLiveSmokeRunner: ClaudeConnectorSmokeRunning, @unchecked Sendable {
    private(set) var runCount = 0
    let result: Result<ClaudeConnectorResult, Error>

    init(result: Result<ClaudeConnectorResult, Error>) {
        self.result = result
    }

    func run(claudeVersion: String) async -> ClaudeConnectorSmokeReport {
        runCount += 1
        return await ClaudeConnectorSmokeCommand(
            refresher: StubClaudeConnectorRefresher(result: result)
        ).run()
    }
}

private final class SmokeStartCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var capturedLines: [String] = []
    private var capturedExitCode: Int32?

    var lines: [String] {
        lock.withLock {
            capturedLines
        }
    }

    var exitCode: Int32? {
        get {
            lock.withLock {
                capturedExitCode
            }
        }
        set {
            lock.withLock {
                capturedExitCode = newValue
            }
        }
    }

    func append(_ line: String) {
        lock.withLock {
            capturedLines.append(line)
        }
    }
}
