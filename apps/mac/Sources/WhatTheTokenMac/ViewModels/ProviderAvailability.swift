import Foundation

enum ProviderAvailability: Equatable, Sendable {
    case available
    case low
    case criticalWithFallback
    case fallbackOnly
    case critical
    case stale

    static func from(snapshots: [UsageSnapshot], tab: ProviderTab) -> ProviderAvailability {
        let providerSnapshots = snapshots.filter { ProviderTab.from(snapshot: $0) == tab }

        if providerSnapshots.contains(where: { $0.staleReason != nil }) {
            return .stale
        }

        let includedWorst = includedWorstState(from: providerSnapshots, tab: tab)
        let fallback = fallbackLane(from: providerSnapshots, tab: tab)

        switch (includedWorst, fallback) {
        case (.healthy, _):
            return .available
        case (.low, _):
            return .low
        case (.critical, .positive):
            return .criticalWithFallback
        case (.critical, .zero), (.critical, .missing):
            return .critical
        case (.empty, .positive):
            return .fallbackOnly
        case (.empty, .zero), (.empty, .missing):
            return .critical
        }
    }

    private static func includedWorstState(from snapshots: [UsageSnapshot], tab: ProviderTab) -> StatusUsageState {
        snapshots
            .filter { isIncludedLane($0, tab: tab) }
            .map(StatusUsageState.init(snapshot:))
            .reduce(.healthy, worse)
    }

    private static func fallbackLane(from snapshots: [UsageSnapshot], tab: ProviderTab) -> FallbackLane {
        let fallbackSnapshots = snapshots.filter { isFallbackLane($0, tab: tab) }
        guard !fallbackSnapshots.isEmpty else { return .missing }

        if fallbackSnapshots.contains(where: { StatusUsageState(snapshot: $0) != .empty }) {
            return .positive
        }

        return .zero
    }

    private static func isIncludedLane(_ snapshot: UsageSnapshot, tab: ProviderTab) -> Bool {
        switch tab {
        case .claude:
            return snapshot.poolKey == "anthropic_claude_subscription"
        case .codex:
            return snapshot.unit == "utilization" && snapshot.poolKey != "openai_codex_credits"
        }
    }

    private static func isFallbackLane(_ snapshot: UsageSnapshot, tab: ProviderTab) -> Bool {
        switch tab {
        case .claude:
            return snapshot.poolKey == "anthropic_claude_extra_usage"
        case .codex:
            return snapshot.poolKey == "openai_codex_credits"
        }
    }

    private static func worse(_ lhs: StatusUsageState, _ rhs: StatusUsageState) -> StatusUsageState {
        severity(lhs) >= severity(rhs) ? lhs : rhs
    }

    private static func severity(_ state: StatusUsageState) -> Int {
        switch state {
        case .healthy:
            return 0
        case .low:
            return 1
        case .critical:
            return 2
        case .empty:
            return 3
        }
    }
}

extension ProviderTab {
    static func from(snapshot: UsageSnapshot) -> ProviderTab? {
        switch (snapshot.provider, snapshot.product) {
        case ("anthropic", "claude_code"):
            return .claude
        case ("openai", "codex"):
            return .codex
        default:
            return nil
        }
    }
}

private enum FallbackLane {
    case missing
    case zero
    case positive
}
