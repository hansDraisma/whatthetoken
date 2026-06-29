import Darwin
import Foundation

protocol ClaudeConnectorSmokeRunning: Sendable {
    func run(claudeVersion: String) async -> ClaudeConnectorSmokeReport
}

struct ClaudeConnectorSmokeReport: Equatable, Sendable {
    let exitCode: Int32
    let outputLines: [String]
}

struct ClaudeConnectorSmokeCommand: Sendable {
    private let refresher: ClaudeConnectorRefreshing

    init(refresher: ClaudeConnectorRefreshing) {
        self.refresher = refresher
    }

    static func shouldRun(arguments: [String]) -> Bool {
        arguments.contains("--claude-connector-smoke")
    }

    func run() async -> ClaudeConnectorSmokeReport {
        do {
            let result = try await refresher.refresh()
            let connected = result.status.source.state == .connected && !result.snapshots.isEmpty
            var lines = [
                "Claude connector smoke: \(result.status.source.state.rawValue)",
                "Status: \(result.status.message)",
                "Snapshots: \(result.snapshots.count)"
            ]

            lines.append(contentsOf: result.snapshots.map(Self.snapshotLine))

            return ClaudeConnectorSmokeReport(
                exitCode: connected ? 0 : 2,
                outputLines: lines
            )
        } catch {
            return ClaudeConnectorSmokeReport(
                exitCode: 1,
                outputLines: [
                    "Claude connector smoke: failed",
                    "Status: Claude connector smoke failed"
                ]
            )
        }
    }

    static func runLive(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        runner: ClaudeConnectorSmokeRunning = LiveClaudeConnectorSmokeRunner()
    ) async -> ClaudeConnectorSmokeReport {
        guard let claudeVersion = environment["CLAUDE_CODE_VERSION"], !claudeVersion.isEmpty else {
            return ClaudeConnectorSmokeReport(
                exitCode: 2,
                outputLines: [
                    "Claude connector smoke: missing_claude_version",
                    "Status: CLAUDE_CODE_VERSION is required before reading Claude Code credentials"
                ]
            )
        }

        return await runner.run(claudeVersion: claudeVersion)
    }

    @discardableResult
    static func startCommandLineSmoke(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        runner: ClaudeConnectorSmokeRunning = LiveClaudeConnectorSmokeRunner(),
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

private struct LiveClaudeConnectorSmokeRunner: ClaudeConnectorSmokeRunning {
    func run(claudeVersion: String) async -> ClaudeConnectorSmokeReport {
        await ClaudeConnectorSmokeCommand(
            refresher: ClaudeConnectorService(
                settings: ClaudeConnectorSettings(isEnabled: true),
                credentialStore: MacOSClaudeCredentialStore(),
                usageFetcher: ClaudeUsageClient(),
                claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: claudeVersion),
                deviceId: "local_mac",
                userAccountId: "local_user",
                now: { ISO8601DateFormatter().string(from: Date()) },
                currentDate: { Date() }
            )
        ).run()
    }
}
