import Foundation

struct ClaudeStoredCredential: Equatable, Sendable {
    let accessToken: String
    let expiresAt: Date?
}

protocol ClaudeCredentialStore: Sendable {
    func readCredential() throws -> ClaudeStoredCredential?
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

    func readCredential() throws -> ClaudeStoredCredential? {
        let result: ClaudeCredentialCommandResult
        do {
            result = try commandRunner.readGenericPassword(serviceName: serviceName)
        } catch {
            throw ClaudeCredentialStoreError.commandFailed
        }

        if result.terminationStatus == 44 {
            return nil
        }
        guard result.terminationStatus == 0 else {
            throw ClaudeCredentialStoreError.commandFailed
        }

        return try decodeCredential(from: result.standardOutput)
    }

    private func decodeCredential(from data: Data) throws -> ClaudeStoredCredential? {
        guard let text = String(data: data, encoding: .utf8) else {
            throw ClaudeCredentialStoreError.invalidUtf8
        }

        guard let jsonData = text.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8) else {
            throw ClaudeCredentialStoreError.invalidUtf8
        }

        do {
            let credentials = try JSONDecoder().decode(ClaudeCredentials.self, from: jsonData)
            guard let token = credentials.accessToken, !token.isEmpty else {
                return nil
            }
            return ClaudeStoredCredential(accessToken: token, expiresAt: credentials.expiresAt)
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
