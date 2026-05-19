import Foundation

enum StalenessThreshold {
    /// Minimum staleness window; matches the floor in
    /// `notifications-background-freshness-design.md`.
    static let minimum: Duration = .seconds(15 * 60)

    static func isStale(snapshotAge age: Duration) -> Bool {
        age >= minimum
    }
}
