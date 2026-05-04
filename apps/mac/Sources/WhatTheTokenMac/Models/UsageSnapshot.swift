import Foundation

struct UsageSnapshot: Codable, Equatable, Sendable {
    let id: String
    let userAccountId: String
    let provider: String
    let product: String
    let surface: String
    let poolKey: String
    let windowKey: String
    let unit: String
    let used: Double?
    let limit: Double?
    let remaining: Double?
    let utilization: Double?
    let resetAt: String?
    let lastUpdatedAt: String
    let confidence: String
    let undercountRisk: String
    let staleReason: String?
    let source: ConnectorSource
}
