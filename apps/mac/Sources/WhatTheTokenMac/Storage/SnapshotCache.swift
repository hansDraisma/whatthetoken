import Foundation

enum CachedProviderID: String, Codable, Equatable, Sendable {
    case claude = "anthropic_claude_code"
    case codex = "openai_codex"

    var snapshotPredicate: @Sendable (UsageSnapshot) -> Bool {
        switch self {
        case .claude:
            return { $0.provider == "anthropic" && $0.product == "claude_code" }
        case .codex:
            return { $0.provider == "openai" && $0.product == "codex" }
        }
    }

    static func from(tab: ProviderTab) -> CachedProviderID {
        switch tab {
        case .claude:
            return .claude
        case .codex:
            return .codex
        }
    }
}

struct SnapshotCache: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var snapshots: [UsageSnapshot]
    var updatedAtByProvider: [String: Date]
    var lastSuccessfulRefreshAtByProvider: [String: Date]
    var lastErrorByProvider: [String: CachedProviderError]

    static let empty = SnapshotCache(
        schemaVersion: currentSchemaVersion,
        snapshots: [],
        updatedAtByProvider: [:],
        lastSuccessfulRefreshAtByProvider: [:],
        lastErrorByProvider: [:]
    )

    static func decodeValidated(from data: Data) throws -> SnapshotCache {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SnapshotCache.self, from: data)
        guard decoded.schemaVersion == currentSchemaVersion else {
            throw SnapshotCacheDecodeError.unsupportedSchemaVersion(decoded.schemaVersion)
        }
        return decoded
    }

    mutating func replaceSnapshots(_ replacement: [UsageSnapshot], for provider: CachedProviderID, at date: Date) {
        snapshots = snapshots.filter { !provider.snapshotPredicate($0) } + replacement
        updatedAtByProvider[provider.rawValue] = date
        lastSuccessfulRefreshAtByProvider[provider.rawValue] = date
        lastErrorByProvider[provider.rawValue] = nil
    }

    mutating func removeProvider(_ provider: CachedProviderID) {
        snapshots = snapshots.filter { !provider.snapshotPredicate($0) }
        updatedAtByProvider[provider.rawValue] = nil
        lastSuccessfulRefreshAtByProvider[provider.rawValue] = nil
        lastErrorByProvider[provider.rawValue] = nil
    }

    mutating func recordFailure(for provider: CachedProviderID, code: CachedProviderError.Code, message: String, now: Date) {
        let previousCount = lastErrorByProvider[provider.rawValue]?.consecutiveFailureCount ?? 0
        let nextCount = previousCount + 1
        let delay: TimeInterval
        switch nextCount {
        case 1:
            delay = 5 * 60
        case 2:
            delay = 15 * 60
        default:
            delay = 60 * 60
        }
        lastErrorByProvider[provider.rawValue] = CachedProviderError(
            code: code,
            message: message,
            consecutiveFailureCount: nextCount,
            nextAutomaticRefreshAt: now.addingTimeInterval(delay)
        )
    }

    func allowsAutomaticRefresh(for provider: CachedProviderID, now: Date) -> Bool {
        guard let next = lastErrorByProvider[provider.rawValue]?.nextAutomaticRefreshAt else { return true }
        return now >= next
    }

    func snapshotsEvaluatingStaleness(
        now: Date,
        policy: SnapshotStalePolicy = SnapshotStalePolicy(staleAfterMinutes: 60)
    ) -> [UsageSnapshot] {
        snapshots.map { $0.evaluatingStaleness(now: now, staleAfterMinutes: policy.staleAfterMinutes) }
    }
}

struct SnapshotStalePolicy: Equatable, Sendable {
    let staleAfterMinutes: Int

    static func from(settings: AppSettings) -> SnapshotStalePolicy {
        guard settings.refresh.autoRefreshEnabled else {
            return SnapshotStalePolicy(staleAfterMinutes: 60)
        }
        let intervalMinutes = max(settings.refresh.intervalSeconds / 60, 1)
        return SnapshotStalePolicy(staleAfterMinutes: max(intervalMinutes * 2, 15))
    }
}

struct CachedProviderError: Codable, Equatable, Sendable {
    enum Code: String, Codable, Equatable, Sendable {
        case network
        case schemaChanged
        case unavailable
    }

    var code: Code
    var message: String
    var consecutiveFailureCount: Int
    var nextAutomaticRefreshAt: Date
}

enum SnapshotCacheDecodeError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
}

extension UsageSnapshot {
    func evaluatingStaleness(now: Date, staleAfterMinutes: Int) -> UsageSnapshot {
        guard staleReason == nil else { return self }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]

        guard let updatedAt = fractional.date(from: lastUpdatedAt) ?? plain.date(from: lastUpdatedAt) else {
            return copy(confidence: "stale", staleReason: "Last update timestamp is invalid.")
        }

        let ageSeconds = now.timeIntervalSince(updatedAt)
        if ageSeconds < 0 {
            return copy(confidence: "stale", staleReason: "Last update timestamp is in the future.")
        }

        let ageMinutes = Int(ageSeconds / 60)
        if ageMinutes > staleAfterMinutes {
            return copy(confidence: "stale", staleReason: "Last update was \(ageMinutes) minutes ago.")
        }

        return self
    }

    func copy(confidence: String, staleReason: String?) -> UsageSnapshot {
        UsageSnapshot(
            id: id,
            userAccountId: userAccountId,
            provider: provider,
            product: product,
            surface: surface,
            poolKey: poolKey,
            windowKey: windowKey,
            unit: unit,
            used: used,
            limit: limit,
            remaining: remaining,
            utilization: utilization,
            resetAt: resetAt,
            lastUpdatedAt: lastUpdatedAt,
            confidence: confidence,
            undercountRisk: undercountRisk,
            staleReason: staleReason,
            display: display,
            source: source
        )
    }
}
