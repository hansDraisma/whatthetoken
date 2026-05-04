import Foundation

struct ClaudeCredentials: Codable, Equatable, Sendable, CustomStringConvertible {
    let claudeAiOauth: ClaudeOAuthCredential?

    var accessToken: String? {
        claudeAiOauth?.accessToken
    }

    var description: String {
        "ClaudeCredentials(accessToken: \(accessToken == nil ? "missing" : "redacted"))"
    }
}

struct ClaudeOAuthCredential: Codable, Equatable, Sendable {
    let accessToken: String?
}
