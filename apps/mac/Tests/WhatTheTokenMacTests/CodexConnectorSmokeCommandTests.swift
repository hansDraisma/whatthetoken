import Foundation
import Testing
@testable import WhatTheTokenMac

@Test func codexSmokeCommandReportsSanitizedConnectedSnapshots() async throws {
    let source = ConnectorSource(
        connector: "mac_connector",
        state: .connected,
        label: "Mac connector",
        parserVersion: "codex-app-server-rate-limits-v1",
        deviceId: "device_mac_01"
    )
    let snapshot = UsageSnapshot(
        id: "snap_openai_codex",
        userAccountId: "local_user",
        provider: "openai",
        product: "codex",
        surface: "aggregate",
        poolKey: "openai_codex_codex_d4cde064",
        windowKey: "primary_rolling_15m",
        unit: "utilization",
        used: 25,
        limit: 100,
        remaining: 75,
        utilization: 0.25,
        resetAt: "2024-11-07T02:40:00Z",
        lastUpdatedAt: "2026-05-05T10:00:00.000Z",
        confidence: "observed",
        undercountRisk: "possible",
        staleReason: nil,
        display: nil,
        source: source
    )
    let refresher = StubCodexConnectorRefresher(result: .success(CodexConnectorResult(
        snapshots: [snapshot],
        status: ConnectorStatus(
            product: "codex",
            source: source,
            message: "Codex connected"
        )
    )))
    let command = CodexConnectorSmokeCommand(refresher: refresher)

    let report = await command.run()
    let output = report.outputLines.joined(separator: "\n")

    #expect(report.exitCode == 0)
    #expect(output.contains("Codex connector smoke: connected"))
    #expect(output.contains("Status: Codex connected"))
    #expect(output.contains("Snapshot: codex primary_rolling_15m utilization used=25.0 limit=100.0 remaining=75.0 source=mac_connector/connected parser=codex-app-server-rate-limits-v1 updated=2026-05-05T10:00:00.000Z"))
    #expect(!output.contains("Authorization"))
    #expect(!output.contains("accessToken"))
    #expect(!output.contains("refresh"))
    #expect(!output.contains("email"))
    #expect(!output.contains("prompt"))
    #expect(!output.contains("response"))
    #expect(!output.contains("eyJ"))
    #expect(!output.contains("\"rateLimits\""))
}

@Test func codexSmokeCommandReturnsNonZeroWhenConnectorIsNotConnected() async {
    let source = ConnectorSource(
        connector: "mac_connector",
        state: .missingCredentials,
        label: "Mac connector",
        parserVersion: "codex-app-server-rate-limits-v1",
        deviceId: "device_mac_01"
    )
    let refresher = StubCodexConnectorRefresher(result: .success(CodexConnectorResult(
        snapshots: [],
        status: ConnectorStatus(
            product: "codex",
            source: source,
            message: "Sign in to Codex locally with codex login, then retry."
        )
    )))
    let command = CodexConnectorSmokeCommand(refresher: refresher)

    let report = await command.run()
    let output = report.outputLines.joined(separator: "\n")

    #expect(report.exitCode == 2)
    #expect(output.contains("Codex connector smoke: missing_credentials"))
    #expect(output.contains("Snapshots: 0"))
}

@Test func codexSmokeCommandDetectsExplicitCommandLineFlag() {
    #expect(CodexConnectorSmokeCommand.shouldRun(arguments: ["WhatTheTokenMac", "--codex-connector-smoke"]))
    #expect(!CodexConnectorSmokeCommand.shouldRun(arguments: ["WhatTheTokenMac"]))
}

@Test func codexLiveSmokeSetupFailsBeforeAppServerAccessWithoutExplicitOptIn() async {
    let runner = StubLiveCodexSmokeRunner(result: .success(CodexConnectorResult(
        snapshots: [],
        status: ConnectorStatus(
            product: "codex",
            source: ConnectorSource(
                connector: "mac_connector",
                state: .connected,
                label: "Mac connector",
                parserVersion: "codex-app-server-rate-limits-v1",
                deviceId: "local_mac"
            ),
            message: "Codex connected"
        )
    )))

    let report = await CodexConnectorSmokeCommand.runLive(
        environment: [:],
        runner: runner
    )

    let output = report.outputLines.joined(separator: "\n")
    #expect(report.exitCode == 2)
    #expect(output.contains("Codex connector smoke: missing_explicit_opt_in"))
    #expect(runner.runCount == 0)
}

@MainActor
@Test func codexCommandLineSmokeCompletesWhileMainActorCallerWaits() {
    let capture = CodexSmokeStartCapture()
    let finished = DispatchSemaphore(value: 0)

    let started = CodexConnectorSmokeCommand.startCommandLineSmoke(
        environment: ["CODEX_CONNECTOR_SMOKE": "1"],
        runner: StubLiveCodexSmokeRunner(result: .success(CodexConnectorResult(
            snapshots: [],
            status: ConnectorStatus(
                product: "codex",
                source: ConnectorSource(
                    connector: "mac_connector",
                    state: .missingCredentials,
                    label: "Mac connector",
                    parserVersion: "codex-app-server-rate-limits-v1",
                    deviceId: "local_mac"
                ),
                message: "Sign in to Codex locally with codex login, then retry."
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
    #expect(capture.lines.contains("Codex connector smoke: missing_credentials"))
}

private struct StubCodexConnectorRefresher: CodexConnectorRefreshing {
    let result: Result<CodexConnectorResult, Error>

    func refresh() async throws -> CodexConnectorResult {
        try result.get()
    }
}

private final class StubLiveCodexSmokeRunner: CodexConnectorSmokeRunning, @unchecked Sendable {
    private(set) var runCount = 0
    let result: Result<CodexConnectorResult, Error>

    init(result: Result<CodexConnectorResult, Error>) {
        self.result = result
    }

    func run() async -> CodexConnectorSmokeReport {
        runCount += 1
        return await CodexConnectorSmokeCommand(
            refresher: StubCodexConnectorRefresher(result: result)
        ).run()
    }
}

private final class CodexSmokeStartCapture: @unchecked Sendable {
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
