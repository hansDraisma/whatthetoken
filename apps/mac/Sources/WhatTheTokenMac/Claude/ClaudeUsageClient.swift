import Foundation

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

    init(loader: ClaudeURLLoading = URLSession.shared) {
        self.loader = loader
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
            do {
                let usageResponse = try JSONDecoder().decode(ClaudeUsageResponse.self, from: data)
                guard usageResponse.hasAnyUsageWindow else {
                    throw ClaudeUsageClientError.schemaChanged
                }
                return usageResponse
            } catch let error as ClaudeUsageClientError {
                throw error
            } catch {
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
}

private extension ClaudeUsageResponse {
    var hasAnyUsageWindow: Bool {
        fiveHour != nil || sevenDay != nil || sevenDayOpus != nil || sevenDaySonnet != nil
    }
}
