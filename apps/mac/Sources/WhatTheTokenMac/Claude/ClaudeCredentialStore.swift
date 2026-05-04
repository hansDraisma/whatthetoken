import Foundation

protocol ClaudeCredentialStore: Sendable {
    func readAccessToken() throws -> String?
}

protocol ClaudeCredentialCommandRunning: Sendable {
    func readGenericPassword(serviceName: String) throws -> ClaudeCredentialCommandResult
}

struct ClaudeCredentialCommandResult: Equatable, Sendable {
    let terminationStatus: Int32
    let standardOutput: Data
}

enum ClaudeCredentialStoreError: Error, Equatable {
    case commandFailed
    case invalidUtf8
    case invalidCredentialJson
}

struct MacOSClaudeCredentialStore: ClaudeCredentialStore {
    private let serviceName = "Claude Code-credentials"
    private let commandRunner: ClaudeCredentialCommandRunning

    init(commandRunner: ClaudeCredentialCommandRunning = SecurityClaudeCredentialCommandRunner()) {
        self.commandRunner = commandRunner
    }

    func readAccessToken() throws -> String? {
        let result: ClaudeCredentialCommandResult
        do {
            result = try commandRunner.readGenericPassword(serviceName: serviceName)
        } catch {
            throw ClaudeCredentialStoreError.commandFailed
        }

        guard result.terminationStatus == 0 else {
            return nil
        }

        return try decodeAccessToken(from: result.standardOutput)
    }

    private func decodeAccessToken(from data: Data) throws -> String? {
        guard let text = String(data: data, encoding: .utf8) else {
            throw ClaudeCredentialStoreError.invalidUtf8
        }

        guard let jsonData = text.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8) else {
            throw ClaudeCredentialStoreError.invalidUtf8
        }

        do {
            let credentials = try JSONDecoder().decode(ClaudeCredentials.self, from: jsonData)
            return credentials.accessToken?.isEmpty == false ? credentials.accessToken : nil
        } catch {
            throw ClaudeCredentialStoreError.invalidCredentialJson
        }
    }
}

struct SecurityClaudeCredentialCommandRunner: ClaudeCredentialCommandRunning {
    private let timeoutSeconds: Double

    init(timeoutSeconds: Double = 5) {
        self.timeoutSeconds = timeoutSeconds
    }

    func readGenericPassword(serviceName: String) throws -> ClaudeCredentialCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", serviceName, "-w"]

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
            throw ClaudeCredentialStoreError.commandFailed
        }

        let timeout = DispatchTime.now() + timeoutSeconds
        guard finished.wait(timeout: timeout) == .success else {
            process.terminate()
            throw ClaudeCredentialStoreError.commandFailed
        }

        return ClaudeCredentialCommandResult(
            terminationStatus: process.terminationStatus,
            standardOutput: output.fileHandleForReading.readDataToEndOfFile()
        )
    }
}
