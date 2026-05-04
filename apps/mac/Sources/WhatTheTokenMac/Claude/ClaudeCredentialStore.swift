import Foundation

protocol ClaudeCredentialStore: Sendable {
    func readAccessToken() throws -> String?
}

enum ClaudeCredentialStoreError: Error, Equatable {
    case commandFailed
    case invalidUtf8
    case invalidCredentialJson
}

struct MacOSClaudeCredentialStore: ClaudeCredentialStore {
    private let serviceName = "Claude Code-credentials"

    func readAccessToken() throws -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", serviceName, "-w"]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            throw ClaudeCredentialStoreError.commandFailed
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
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
