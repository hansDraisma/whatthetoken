import Foundation

struct CodexRateLimitsResponse: Decodable, Equatable, Sendable {
    let rateLimits: CodexRateLimitSnapshot
    let rateLimitsByLimitId: [String: CodexRateLimitSnapshot]?

    var buckets: [CodexRateLimitSnapshot] {
        if let rateLimitsByLimitId, !rateLimitsByLimitId.isEmpty {
            return rateLimitsByLimitId.values.sorted { ($0.limitId ?? "") < ($1.limitId ?? "") }
        }

        return [rateLimits]
    }
}

struct CodexRateLimitSnapshot: Decodable, Equatable, Sendable {
    let credits: CodexCreditsSnapshot?
    let limitId: String?
    let limitName: String?
    let planType: String?
    let primary: CodexRateLimitWindow?
    let rateLimitReachedType: String?
    let secondary: CodexRateLimitWindow?
}

struct CodexRateLimitWindow: Decodable, Equatable, Sendable {
    let resetsAt: Int?
    let usedPercent: Int
    let windowDurationMins: Int?
}

struct CodexCreditsSnapshot: Decodable, Equatable, Sendable {
    let balance: String?
    let hasCredits: Bool
    let unlimited: Bool
}
