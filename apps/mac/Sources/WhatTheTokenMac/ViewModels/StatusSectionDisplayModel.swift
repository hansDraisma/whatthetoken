import Foundation

struct StatusSectionDisplayModel: Sendable {
    let brandTitle: String?
    let trustLine: String?
    let compareURL: URL
    let rows: [StatusRowDisplayModel]

    init(snapshots: [UsageSnapshot], now: Date) {
        compareURL = URL(string: "https://claude.ai/settings/usage")!

        guard let first = snapshots.first else {
            brandTitle = nil
            trustLine = nil
            rows = []
            return
        }

        brandTitle = Self.brandTitle(provider: first.provider, product: first.product)

        let confidences = Set(snapshots.map(\.confidence))
        let labels = Set(snapshots.map(\.source.label))
        let trustUniform = confidences.count == 1 && labels.count == 1

        if trustUniform {
            trustLine = [
                "\(first.confidence.capitalized) by \(first.source.label)",
                Self.updatedLabel(snapshots: snapshots)
            ]
            .compactMap { $0 }
            .joined(separator: " · ")
        } else {
            trustLine = nil
        }

        let sectionDefault = StatusSectionDefault(
            confidence: Self.mode(snapshots.map(\.confidence)),
            undercountRisk: Self.mode(snapshots.map(\.undercountRisk))
        )

        rows = snapshots.map {
            StatusRowDisplayModel(snapshot: $0, sectionDefault: sectionDefault, now: now)
        }
    }

    private static func brandTitle(provider: String, product: String) -> String {
        let productWord = product
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
        return "\(provider.capitalized) · \(productWord)"
    }

    private static func updatedLabel(snapshots: [UsageSnapshot]) -> String? {
        let latest = snapshots
            .compactMap { parseISODate($0.lastUpdatedAt) }
            .max()
        guard let latest else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "Updated \(formatter.string(from: latest))"
    }

    private static func parseISODate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }

    private static func mode(_ values: [String]) -> String {
        var counts: [String: Int] = [:]
        for value in values {
            counts[value, default: 0] += 1
        }
        return values.max { lhs, rhs in
            counts[lhs, default: 0] < counts[rhs, default: 0]
        } ?? values.first ?? ""
    }
}
