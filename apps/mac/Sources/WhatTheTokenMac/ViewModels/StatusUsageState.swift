import Foundation

enum StatusUsageState: Equatable, Sendable {
    case healthy
    case low
    case critical
    case empty

    init(snapshot: UsageSnapshot) {
        guard let fraction = Self.remainingFraction(snapshot: snapshot) else {
            self = .healthy
            return
        }

        if fraction <= 0 {
            self = .empty
        } else if fraction < 0.10 {
            self = .critical
        } else if fraction < 0.30 {
            self = .low
        } else {
            self = .healthy
        }
    }

    private static func remainingFraction(snapshot: UsageSnapshot) -> Double? {
        switch snapshot.unit {
        case "utilization":
            if let utilization = snapshot.utilization {
                let usedPercent = Int(round(utilization * 100))
                return Double(min(max(100 - usedPercent, 0), 100)) / 100
            }
            if let remaining = snapshot.remaining {
                return max(0, remaining / 100)
            }
            return nil
        default:
            guard let remaining = snapshot.remaining else { return nil }
            if remaining <= 0 { return 0 }
            guard let limit = snapshot.limit, limit > 0 else { return 1 }
            return max(0, remaining / limit)
        }
    }
}
