import Foundation

struct StatusSectionDisplayModel: Sendable {
    let brandTitle: String?
    let trustLine: String?
    let compareLink: StatusSectionCompareLink?
    let rows: [StatusRowDisplayModel]

    init(snapshots: [UsageSnapshot], now: Date) {
        guard let first = snapshots.first else {
            brandTitle = nil
            trustLine = nil
            compareLink = nil
            rows = []
            return
        }

        brandTitle = Self.brandTitle(provider: first.provider, product: first.product)
        compareLink = Self.compareLink(provider: first.provider, product: first.product)

        let confidences = Set(snapshots.map(\.confidence))
        let labels = Set(snapshots.map(\.source.label))
        let trustUniform = confidences.count == 1 && labels.count == 1

        if trustUniform {
            trustLine = "\(first.confidence.capitalized) by \(first.source.label)"
        } else {
            trustLine = nil
        }

        let sectionDefault = StatusSectionDefault(
            confidence: Self.mode(snapshots.map(\.confidence)),
            undercountRisk: Self.mode(snapshots.map(\.undercountRisk))
        )
        let providerAvailability = Self.firstProviderTab(in: snapshots)
            .map { ProviderAvailability.from(snapshots: snapshots, tab: $0) }
            ?? .available

        rows = snapshots.map {
            StatusRowDisplayModel(
                snapshot: $0,
                sectionDefault: sectionDefault,
                now: now,
                providerAvailability: providerAvailability
            )
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

    private static func compareLink(provider: String, product: String) -> StatusSectionCompareLink? {
        if provider == "anthropic" && product == "claude_code" {
            return StatusSectionCompareLink(
                title: "Compare in Claude →",
                url: URL(string: "https://claude.ai/settings/usage")!
            )
        }

        if provider == "openai" && product == "codex" {
            return StatusSectionCompareLink(
                title: "Open Codex usage →",
                url: URL(string: "https://chatgpt.com/codex/settings/usage")!
            )
        }

        return nil
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

    private static func firstProviderTab(in snapshots: [UsageSnapshot]) -> ProviderTab? {
        snapshots.lazy.compactMap(ProviderTab.from(snapshot:)).first
    }
}

struct StatusSectionCompareLink: Equatable, Sendable {
    let title: String
    let url: URL
}
