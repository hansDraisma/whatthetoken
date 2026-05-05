import Foundation

struct StatusSectionDefault: Equatable, Sendable {
    let confidence: String
    let undercountRisk: String
}

enum StatusRowBadge: Equatable, Sendable {
    case undercountPossible
    case undercountLikely
    case inferred

    var label: String {
        switch self {
        case .undercountPossible:
            return "Undercount possible"
        case .undercountLikely:
            return "Undercount likely"
        case .inferred:
            return "Inferred"
        }
    }

    var tooltip: String {
        switch self {
        case .undercountPossible:
            return "Some recent activity may not be reflected in this number."
        case .undercountLikely:
            return "Recent activity may not be reflected in this number."
        case .inferred:
            return "This row is inferred rather than verified by the connector."
        }
    }
}

struct StatusRowDisplayModel: Equatable, Sendable {
    let id: String
    let name: String
    let resetHint: String?
    let heroText: String
    let echoText: String?
    let progressValue: Double
    let state: StatusUsageState
    let statusWord: String
    let heroTintsRed: Bool
    let showsBar: Bool
    let badges: [StatusRowBadge]
    let staleReason: String?

    init(
        snapshot: UsageSnapshot,
        sectionDefault: StatusSectionDefault?,
        now: Date
    ) {
        let state = StatusUsageState(snapshot: snapshot)
        id = snapshot.id
        name = Self.windowName(for: snapshot)
        resetHint = StatusRowCopy.resetHint(resetAt: snapshot.resetAt, now: now)
        heroText = StatusRowCopy.heroText(snapshot: snapshot, state: state)
        echoText = StatusRowCopy.echoText(snapshot: snapshot)
        progressValue = Self.progressValue(snapshot: snapshot)
        self.state = state
        statusWord = StatusRowCopy.statusWord(state: state)
        heroTintsRed = state == .critical || state == .empty
        showsBar = Self.showsBar(snapshot: snapshot)
        badges = Self.badges(snapshot: snapshot, sectionDefault: sectionDefault)
        staleReason = snapshot.staleReason
    }

    private static func windowName(for snapshot: UsageSnapshot) -> String {
        if snapshot.provider == "anthropic",
           snapshot.product == "claude_code" {
            switch snapshot.windowKey {
            case "five_hour":
                return "Current session"
            case "seven_day":
                return "Weekly · all models"
            case "seven_day_opus":
                return "Weekly · Opus"
            case "seven_day_sonnet":
                return "Weekly · Sonnet"
            case "monthly_extra_usage":
                return "Extra usage credits"
            default:
                break
            }
        }

        return snapshot.windowKey
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private static func progressValue(snapshot: UsageSnapshot) -> Double {
        if let utilization = snapshot.utilization {
            return min(max(utilization, 0), 1)
        }
        if let remaining = snapshot.remaining,
           let limit = snapshot.limit,
           limit > 0 {
            return min(max(1 - (remaining / limit), 0), 1)
        }
        return 0
    }

    private static func showsBar(snapshot: UsageSnapshot) -> Bool {
        if snapshot.unit == "utilization" {
            return true
        }
        guard let limit = snapshot.limit else {
            return false
        }
        return limit > 0
    }

    private static func badges(
        snapshot: UsageSnapshot,
        sectionDefault: StatusSectionDefault?
    ) -> [StatusRowBadge] {
        guard let sectionDefault else { return [] }

        var result: [StatusRowBadge] = []
        if snapshot.confidence != "verified" {
            result.append(.inferred)
        }
        if snapshot.undercountRisk != sectionDefault.undercountRisk {
            switch snapshot.undercountRisk {
            case "possible":
                result.append(.undercountPossible)
            case "likely":
                result.append(.undercountLikely)
            default:
                break
            }
        }
        return result
    }
}
