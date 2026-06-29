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

    enum CodingKeys: String, CodingKey {
        case accessToken
        case expiresAt
    }

    init(accessToken: String?, expiresAt: Double?) {
        self.accessToken = accessToken
        self.expiresAt = expiresAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken)
        // expiresAt is non-essential. Tolerate absence or an unexpected upstream
        // type (e.g. a format change) rather than failing the whole decode,
        // which would also drop the essential access token.
        expiresAt = try? container.decodeIfPresent(Double.self, forKey: .expiresAt)
    }
}
