import Foundation

#if canImport(Sentry)
import Sentry
#endif

protocol ClaudeURLLoading: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: ClaudeURLLoading {}

enum ClaudeUsageClientError: Error, Equatable {
    case tokenInvalid
    case rateLimited
    case networkError
    case schemaChanged
}

struct ClaudeUsageSchemaIncident: Equatable, Sendable {
    enum Reason: String, Equatable, Sendable {
        case responseDecodingFailed = "response_decoding_failed"
        case noUsageSignals = "no_usage_signals"
        case malformedUsageFields = "malformed_usage_fields"
    }

    let reason: Reason
    let topLevelKeys: [String]
    let affectedKeys: [String]
}

protocol ClaudeUsageSchemaReporting: Sendable {
    func report(_ incident: ClaudeUsageSchemaIncident)
}

struct SentryClaudeUsageSchemaReporter: ClaudeUsageSchemaReporting {
    func report(_ incident: ClaudeUsageSchemaIncident) {
        #if canImport(Sentry)
        guard SentrySDK.isEnabled else { return }

        let error = NSError(
            domain: "com.whatthetoken.claude-usage-schema",
            code: errorCode(for: incident.reason),
            userInfo: [
                NSLocalizedDescriptionKey: "Claude usage response schema changed",
                "reason": incident.reason.rawValue,
                "top_level_keys": incident.topLevelKeys.joined(separator: ","),
                "affected_keys": incident.affectedKeys.joined(separator: ",")
            ]
        )
        SentrySDK.capture(error: error)
        #endif
    }

    private func errorCode(for reason: ClaudeUsageSchemaIncident.Reason) -> Int {
        switch reason {
        case .responseDecodingFailed:
            return 1
        case .noUsageSignals:
            return 2
        case .malformedUsageFields:
            return 3
        }
    }
}

enum ClaudeUsageRequestFactory {
    static func makeRequest(accessToken: String, claudeVersion: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-code/\(claudeVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        return request
    }
}

struct ClaudeUsageClient: ClaudeUsageFetching, Sendable {
    private let loader: ClaudeURLLoading
    private let schemaReporter: ClaudeUsageSchemaReporting

    init(
        loader: ClaudeURLLoading = URLSession.shared,
        schemaReporter: ClaudeUsageSchemaReporting = SentryClaudeUsageSchemaReporter()
    ) {
        self.loader = loader
        self.schemaReporter = schemaReporter
    }

    func fetchUsage(accessToken: String, claudeVersion: String) async throws -> ClaudeUsageResponse {
        let request = ClaudeUsageRequestFactory.makeRequest(
            accessToken: accessToken,
            claudeVersion: claudeVersion
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await loader.data(for: request)
        } catch {
            throw ClaudeUsageClientError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeUsageClientError.networkError
        }

        switch httpResponse.statusCode {
        case 200..<300:
            let topLevelKeys = Self.topLevelKeys(in: data)
            do {
                let usageResponse = try JSONDecoder().decode(ClaudeUsageResponse.self, from: data)
                if !usageResponse.malformedUsageKeys.isEmpty {
                    schemaReporter.report(ClaudeUsageSchemaIncident(
                        reason: .malformedUsageFields,
                        topLevelKeys: topLevelKeys,
                        affectedKeys: usageResponse.malformedUsageKeys
                            .map(Self.sanitizedSchemaKey)
                            .sorted()
                    ))
                }
                guard usageResponse.hasAnyUsageSignal else {
                    if usageResponse.malformedUsageKeys.isEmpty {
                        schemaReporter.report(ClaudeUsageSchemaIncident(
                            reason: .noUsageSignals,
                            topLevelKeys: topLevelKeys,
                            affectedKeys: []
                        ))
                    }
                    throw ClaudeUsageClientError.schemaChanged
                }
                return usageResponse
            } catch let error as ClaudeUsageClientError {
                throw error
            } catch {
                schemaReporter.report(ClaudeUsageSchemaIncident(
                    reason: .responseDecodingFailed,
                    topLevelKeys: topLevelKeys,
                    affectedKeys: []
                ))
                throw ClaudeUsageClientError.schemaChanged
            }
        case 401, 403:
            throw ClaudeUsageClientError.tokenInvalid
        case 429:
            throw ClaudeUsageClientError.rateLimited
        default:
            throw ClaudeUsageClientError.networkError
        }
    }

    private static func topLevelKeys(in data: Data) -> [String] {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            return []
        }
        return Set(dictionary.keys.map(sanitizedSchemaKey)).sorted()
    }

    private static func sanitizedSchemaKey(_ key: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        guard !key.isEmpty,
              key.utf8.count <= 64,
              key.unicodeScalars.allSatisfy(allowed.contains) else {
            return "<redacted>"
        }
        return key
    }
}

private extension ClaudeUsageResponse {
    var hasAnyUsageSignal: Bool {
        !windows.isEmpty || extraUsage != nil
    }
}
