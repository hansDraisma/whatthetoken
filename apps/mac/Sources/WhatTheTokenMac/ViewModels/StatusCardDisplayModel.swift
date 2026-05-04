import Foundation

struct StatusCardDisplayModel: Equatable, Sendable {
    let title: String
    let primaryMetric: String
    let confidenceLabel: String
    let updatedLabel: String
    let progressValue: Double

    init(snapshot: UsageSnapshot) {
        title = "\(snapshot.provider.capitalized) / \(snapshot.product.replacingOccurrences(of: "_", with: " "))"
        confidenceLabel = snapshot.confidence.capitalized
        updatedLabel = "Updated \(snapshot.lastUpdatedAt)"
        progressValue = snapshot.utilization ?? 0
        primaryMetric = Self.primaryMetric(for: snapshot)
    }

    private static func primaryMetric(for snapshot: UsageSnapshot) -> String {
        guard let remaining = snapshot.remaining else {
            return "Usage observed"
        }

        switch snapshot.unit {
        case "utilization":
            return "\(Int(remaining))% remaining"
        case "credits":
            return "\(remaining.formatted()) credits remaining"
        case "tokens":
            return "\(Int(remaining)) tokens remaining"
        case "requests":
            return "\(Int(remaining)) requests remaining"
        case "messages":
            return "\(Int(remaining)) messages remaining"
        default:
            return "\(remaining.formatted()) remaining"
        }
    }
}
