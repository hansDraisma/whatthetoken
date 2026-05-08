import Foundation

struct PopoverFooterState: Equatable, Sendable {
    let lastUpdatedAt: Date?
    let isRefreshing: Bool
    let canRefresh: Bool
}

extension PopoverFooterState {
    func labelText(now: Date = Date()) -> String {
        guard !isRefreshing else { return "Updating values..." }
        guard let lastUpdatedAt else { return "-" }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Last updated " + formatter.localizedString(for: lastUpdatedAt, relativeTo: now)
    }

    @MainActor
    static func from(viewModel: StatusViewModel, selected: ProviderTab) -> PopoverFooterState {
        let isSelectedRefreshing = viewModel.isRefreshing(selected)
        return PopoverFooterState(
            lastUpdatedAt: viewModel.lastRefreshAt(for: selected),
            isRefreshing: isSelectedRefreshing,
            canRefresh: !viewModel.isAnyRefreshing
        )
    }
}
