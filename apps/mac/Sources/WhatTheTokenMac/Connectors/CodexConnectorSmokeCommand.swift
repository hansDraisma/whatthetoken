import Darwin
import Foundation

protocol CodexConnectorSmokeRunning: Sendable {
    func run() async -> CodexConnectorSmokeReport
}

struct CodexConnectorSmokeReport: Equatable, Sendable {
    let exitCode: Int32
    let outputLines: [String]
}

struct CodexConnectorSmokeCommand: Sendable {
    private let refresher: CodexConnectorRefreshing

    init(refresher: CodexConnectorRefreshing) {
        self.refresher = refresher
    }

    static func shouldRun(arguments: [String]) -> Bool {
        arguments.contains("--codex-connector-smoke")
    }

    func run() async -> CodexConnectorSmokeReport {
        do {
            let result = try await refresher.refresh()
            let connected = result.status.source.state == .connected && !result.snapshots.isEmpty
            var lines = [
                "Codex connector smoke: \(result.status.source.state.rawValue)",
                "Status: \(result.status.message)",
                "Snapshots: \(result.snapshots.count)"
            ]

            lines.append(contentsOf: result.snapshots.map(Self.snapshotLine))

            return CodexConnectorSmokeReport(
                exitCode: connected ? 0 : 2,
                outputLines: lines
            )
        } catch {
            return CodexConnectorSmokeReport(
                exitCode: 1,
                outputLines: [
                    "Codex connector smoke: failed",
                    "Status: Codex connector smoke failed"
                ]
            )
        }
    }

    static func runLive(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        runner: CodexConnectorSmokeRunning = LiveCodexConnectorSmokeRunner()
    ) async -> CodexConnectorSmokeReport {
        guard environment["CODEX_CONNECTOR_SMOKE"] == "1" else {
            return CodexConnectorSmokeReport(
                exitCode: 2,
                outputLines: [
                    "Codex connector smoke: missing_explicit_opt_in",
                    "Status: CODEX_CONNECTOR_SMOKE=1 is required before starting Codex app-server"
                ]
            )
        }

        return await runner.run()
    }

    @discardableResult
    static func startCommandLineSmoke(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        runner: CodexConnectorSmokeRunning = LiveCodexConnectorSmokeRunner(),
        output: @escaping @Sendable (String) -> Void = { line in
            FileHandle.standardOutput.write(Data("\(line)\n".utf8))
        },
        exit: @escaping @Sendable (Int32) -> Void = { code in
            Darwin.exit(code)
        }
    ) -> Bool {
        Task.detached {
            let report = await runLive(environment: environment, runner: runner)
            for line in report.outputLines {
                output(line)
            }

            exit(report.exitCode)
        }

        return true
    }

    private static func snapshotLine(_ snapshot: UsageSnapshot) -> String {
        [
            "Snapshot:",
            snapshot.product,
            snapshot.windowKey,
            snapshot.unit,
            "used=\(format(snapshot.used))",
            "limit=\(format(snapshot.limit))",
            "remaining=\(format(snapshot.remaining))",
            "source=\(snapshot.source.connector)/\(snapshot.source.state.rawValue)",
            "parser=\(snapshot.source.parserVersion)",
            "updated=\(snapshot.lastUpdatedAt)"
        ].joined(separator: " ")
    }

    private static func format(_ value: Double?) -> String {
        guard let value else {
            return "null"
        }

        return String(value)
    }
}

private struct LiveCodexConnectorSmokeRunner: CodexConnectorSmokeRunning {
    func run() async -> CodexConnectorSmokeReport {
        await CodexConnectorSmokeCommand(
            refresher: CodexConnectorService(
                settings: CodexConnectorSettings(isEnabled: true),
                rateLimitsFetcher: CodexAppServerClient(transport: LiveCodexAppServerTransport()),
                deviceId: "local_mac",
                userAccountId: "local_user",
                now: { ISO8601DateFormatter().string(from: Date()) }
            )
        ).run()
    }
}
