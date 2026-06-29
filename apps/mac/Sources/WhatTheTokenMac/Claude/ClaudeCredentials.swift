import Foundation

struct ClaudeCredentials: Codable, Equatable, Sendable, CustomStringConvertible {
    let claudeAiOauth: ClaudeOAuthCredential?

    var accessToken: String? {
        claudeAiOauth?.accessToken
    }

    var expiresAt: Date? {
        claudeAiOauth?.expiresAtDate
    }

    var description: String {
        "ClaudeCredentials(accessToken: \(accessToken == nil ? "missing" : "redacted"))"
    }
}

struct ClaudeOAuthCredential: Codable, Equatable, Sendable {
    let accessToken: String?
    let expiresAt: Double?

    var expiresAtDate: Date? {
        guard let expiresAt else { return nil }
        return Date(timeIntervalSince1970: expiresAt / 1000)
    }
}
