import Foundation

protocol CodexAppServerTransport: Sendable {
    func transact(_ requests: [Data], expecting responseId: Int) async throws -> Data
}

protocol CodexRateLimitsFetching: Sendable {
    func readRateLimits() async throws -> CodexRateLimitsResponse
}

protocol CodexAppServerExecutableResolving: Sendable {
    func executableURL() -> URL?
}

enum CodexAppServerClientError: Error, Equatable {
    case authRequired
    case permissionDenied
    case networkError
    case schemaChanged
}

struct CodexAppServerClient: Sendable {
    let transport: CodexAppServerTransport

    func readRateLimits() async throws -> CodexRateLimitsResponse {
        let responseId = 1
        let requests = [
            #"{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"clientInfo":{"name":"whatthetoken","version":"0.0.0"},"capabilities":{"experimentalApi":true}}}"#.data(using: .utf8)!,
            #"{"jsonrpc":"2.0","method":"initialized","params":null}"#.data(using: .utf8)!,
            #"{"jsonrpc":"2.0","method":"account/rateLimits/read","id":1}"#.data(using: .utf8)!
        ]

        let data: Data
        do {
            data = try await transport.transact(requests, expecting: responseId)
        } catch let error as CodexAppServerClientError {
            throw error
        } catch {
            throw CodexAppServerClientError.networkError
        }

        return try CodexJSONRPCDecoder.decodeRateLimitsResponse(from: data)
    }
}

extension CodexAppServerClient: CodexRateLimitsFetching {}

struct CodexAppServerExecutableResolver: CodexAppServerExecutableResolving {
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
        let pathCandidates = environment["PATH", default: ""]
            .split(separator: ":")
            .map { "\($0)/codex" }

        return Array(NSOrderedSet(array: pathCandidates + [
            homeDirectory.appendingPathComponent(".local/bin/codex").path,
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ])) as? [String] ?? []
    }
}

enum CodexJSONRPCDecoder {
    static func decodeRateLimitsResponse(from data: Data) throws -> CodexRateLimitsResponse {
        let envelope: CodexJSONRPCEnvelope
        do {
            envelope = try JSONDecoder().decode(CodexJSONRPCEnvelope.self, from: data)
        } catch {
            throw CodexAppServerClientError.schemaChanged
        }

        if let error = envelope.error {
            if error.isAuthError {
                throw CodexAppServerClientError.authRequired
            }

            throw CodexAppServerClientError.networkError
        }

        guard let result = envelope.result else {
            throw CodexAppServerClientError.schemaChanged
        }

        return result
    }
}

enum CodexJSONRPCResponseSelector {
    static func response(withId responseId: Int, from lines: [Data]) throws -> Data {
        guard let response = matchingResponse(withId: responseId, from: lines) else {
            throw CodexAppServerClientError.networkError
        }

        return response
    }

    static func matchingResponse(withId responseId: Int, from lines: [Data]) -> Data? {
        for line in lines {
            guard !line.isEmpty,
                  let header = try? JSONDecoder().decode(CodexJSONRPCMessageHeader.self, from: line),
                  header.id?.intValue == responseId else {
                continue
            }

            return line
        }

        return nil
    }
}

struct LiveCodexAppServerTransport: CodexAppServerTransport {
    let timeoutSeconds: TimeInterval
    private let executableResolver: CodexAppServerExecutableResolving

    init(
        timeoutSeconds: TimeInterval = 10,
        executableResolver: CodexAppServerExecutableResolving = CodexAppServerExecutableResolver()
    ) {
        self.timeoutSeconds = timeoutSeconds
        self.executableResolver = executableResolver
    }

    func transact(_ requests: [Data], expecting responseId: Int) async throws -> Data {
        guard let executableURL = executableResolver.executableURL() else {
            throw CodexAppServerClientError.permissionDenied
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try runCodexAppServer(
                        executableURL: executableURL,
                        requests: requests,
                        expecting: responseId,
                        timeoutSeconds: timeoutSeconds
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private func runCodexAppServer(
    executableURL: URL,
    requests: [Data],
    expecting responseId: Int,
    timeoutSeconds: TimeInterval
) throws -> Data {
    let process = Process()
    process.executableURL = executableURL
    process.arguments = ["app-server", "--listen", "stdio://"]

    let input = Pipe()
    let output = Pipe()
    let errorOutput = Pipe()
    process.standardInput = input
    process.standardOutput = output
    process.standardError = errorOutput

    let responseCapture = CodexProcessLineCapture()
    let responseReady = DispatchSemaphore(value: 0)

    output.fileHandleForReading.readabilityHandler = { handle in
        let chunk = handle.availableData
        guard !chunk.isEmpty else {
            return
        }

        if responseCapture.append(chunk) {
            responseReady.signal()
        }
    }

    do {
        try process.run()
    } catch {
        output.fileHandleForReading.readabilityHandler = nil
        throw CodexAppServerClientError.permissionDenied
    }

    for request in requests {
        var requestWithNewline = request
        requestWithNewline.append(0x0A)
        input.fileHandleForWriting.write(requestWithNewline)
    }

    let deadline = Date().addingTimeInterval(timeoutSeconds)
    while Date() < deadline {
        if let response = CodexJSONRPCResponseSelector.matchingResponse(
            withId: responseId,
            from: responseCapture.popLines()
        ) {
            input.fileHandleForWriting.closeFile()
            output.fileHandleForReading.readabilityHandler = nil
            process.terminate()
            return response
        }

        let remaining = max(0, deadline.timeIntervalSinceNow)
        let timeout = DispatchTime.now() + min(remaining, 0.25)
        _ = responseReady.wait(timeout: timeout)
    }

    if let response = CodexJSONRPCResponseSelector.matchingResponse(
        withId: responseId,
        from: responseCapture.popLines()
    ) {
        input.fileHandleForWriting.closeFile()
        output.fileHandleForReading.readabilityHandler = nil
        process.terminate()
        return response
    }

    input.fileHandleForWriting.closeFile()
    output.fileHandleForReading.readabilityHandler = nil
    process.terminate()
    throw CodexAppServerClientError.networkError
}

private struct CodexJSONRPCEnvelope: Decodable {
    let result: CodexRateLimitsResponse?
    let error: CodexJSONRPCError?
}

private struct CodexJSONRPCMessageHeader: Decodable {
    let id: CodexJSONRPCID?
}

private enum CodexJSONRPCID: Decodable {
    case int(Int)
    case string(String)

    var intValue: Int? {
        switch self {
        case .int(let value):
            return value
        case .string(let value):
            return Int(value)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(Int.self) {
            self = .int(value)
            return
        }

        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }

        throw DecodingError.typeMismatch(
            CodexJSONRPCID.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON-RPC id type")
        )
    }
}

private final class CodexProcessLineCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private var lines: [Data] = []

    func append(_ data: Data) -> Bool {
        lock.withLock {
            let startingCount = lines.count
            buffer.append(data)

            while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                let line = buffer[..<newlineIndex]
                lines.append(Data(line))
                buffer.removeSubrange(...newlineIndex)
            }

            return lines.count > startingCount
        }
    }

    func popLines() -> [Data] {
        lock.withLock {
            let pending = lines
            lines.removeAll(keepingCapacity: true)
            return pending
        }
    }
}

private struct CodexJSONRPCError: Decodable {
    let code: Int?
    let message: String?

    var isAuthError: Bool {
        if code == 401 || code == 403 {
            return true
        }

        guard let message = message?.lowercased() else {
            return false
        }

        return message.contains("auth")
            || message.contains("login")
            || message.contains("sign in")
            || message.contains("unauthorized")
    }
}
