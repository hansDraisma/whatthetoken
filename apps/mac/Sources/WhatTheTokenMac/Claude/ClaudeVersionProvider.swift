import Foundation

protocol ClaudeVersionCommandRunning: Sendable {
    func runClaudeVersion() throws -> ClaudeVersionCommandResult
}

struct ClaudeVersionCommandResult: Equatable, Sendable {
    let terminationStatus: Int32
    let standardOutput: Data
}

enum ClaudeVersionProviderError: Error {
    case commandFailed
}

protocol ClaudeVersionExecutableResolving: Sendable {
    func executableURL() -> URL?
}

struct ClaudeVersionExecutableResolver: ClaudeVersionExecutableResolving {
    private let environment: [String: String]
    private let homeDirectory: URL
    private let fileExists: @Sendable (String) -> Bool

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileExists: @escaping @Sendable (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) {
        self.environment = environment
        self.homeDirectory = homeDirectory
        self.fileExists = fileExists
    }

    func executableURL() -> URL? {
        for path in candidatePaths() where fileExists(path) {
            return URL(fileURLWithPath: path)
        }

        return nil
    }

    private func candidatePaths() -> [String] {
        // Prefer known install locations over the inherited $PATH so a poisoned
        // PATH entry cannot preempt the real binary (the main app is not sandboxed).
        let knownLocations = [
            homeDirectory.appendingPathComponent(".local/bin/claude").path,
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude"
        ]
        let pathCandidates = environment["PATH", default: ""]
            .split(separator: ":")
            .map { "\($0)/claude" }

        return Array(NSOrderedSet(array: knownLocations + pathCandidates)) as? [String] ?? []
    }
}

struct InstalledClaudeVersionProvider: ClaudeVersionProviding {
    let commandRunner: ClaudeVersionCommandRunning

    init(commandRunner: ClaudeVersionCommandRunning = ProcessClaudeVersionCommandRunner()) {
        self.commandRunner = commandRunner
    }

    var claudeVersion: String {
        guard
            let result = try? commandRunner.runClaudeVersion(),
            result.terminationStatus == 0,
            let output = String(data: result.standardOutput, encoding: .utf8),
            let version = output.split(separator: " ").first,
            !version.isEmpty
        else {
            return "unknown"
        }

        return String(version)
    }
}

struct ProcessClaudeVersionCommandRunner: ClaudeVersionCommandRunning {
    private let executableResolver: ClaudeVersionExecutableResolving
    private let timeoutSeconds: Double

    init(
        executableResolver: ClaudeVersionExecutableResolving = ClaudeVersionExecutableResolver(),
        timeoutSeconds: Double = 5
    ) {
        self.executableResolver = executableResolver
        self.timeoutSeconds = timeoutSeconds
    }

    func runClaudeVersion() throws -> ClaudeVersionCommandResult {
        guard let executableURL = executableResolver.executableURL() else {
            throw ClaudeVersionProviderError.commandFailed
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["--version"]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            finished.signal()
        }

        do {
            try process.run()
        } catch {
            throw ClaudeVersionProviderError.commandFailed
        }

        let timeout = DispatchTime.now() + timeoutSeconds
        guard finished.wait(timeout: timeout) == .success else {
            process.terminate()
            throw ClaudeVersionProviderError.commandFailed
        }

        return ClaudeVersionCommandResult(
            terminationStatus: process.terminationStatus,
            standardOutput: output.fileHandleForReading.readDataToEndOfFile()
        )
    }
}
