import Foundation

struct PopoverFooterState: Equatable, Sendable {
    let lastUpdatedAt: Date?
    let isRefreshing: Bool
    let canRefresh: Bool
}

extension PopoverFooterState {
    @MainActor
    static func from(viewModel: StatusViewModel, selected: ProviderTab) -> PopoverFooterState {
        PopoverFooterState(
            lastUpdatedAt: viewModel.lastRefreshAt(for: selected),
            isRefreshing: viewModel.isAnyRefreshing,
            canRefresh: !viewModel.isAnyRefreshing
        )
    }
}
