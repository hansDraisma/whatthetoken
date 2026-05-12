import SwiftUI

struct PopoverRootView: View {
    let viewModel: StatusViewModel
    let controller: PopoverRefreshController
    let canCheckForUpdates: @MainActor () -> Bool
    let onOpenSettings: () -> Void
    let onCheckForUpdates: () -> Void
    let onOpenDeveloperWindow: (() -> Void)?

    @State private var selectedTab: ProviderTab = .codex

    var body: some View {
        let chromeState = PopoverChromeState.from(viewModel: viewModel, selected: selectedTab)
        let tabModel = ProviderTabModel.from(viewModel: viewModel, tab: selectedTab)
        let footerState = PopoverFooterState.from(viewModel: viewModel, selected: selectedTab)

        VStack(spacing: 0) {
            StatusBannerView(state: chromeState.topBanner)
            ProviderTabBarView(selected: $selectedTab, indicators: chromeState.indicators)
            StatusBannerView(state: chromeState.selectedBanner)
            Divider()
            ProviderTabContentView(
                model: tabModel,
                onOpenSettings: onOpenSettings,
                onRetry: { controller.userTappedRetry() },
                onRefresh: { controller.userTappedRefresh() }
            )
            Divider()
            PopoverFooterView(
                state: footerState,
                onRefresh: { controller.userTappedRefresh() },
                canCheckForUpdates: canCheckForUpdates(),
                onOpenSettings: onOpenSettings,
                onCheckForUpdates: onCheckForUpdates,
                onOpenDeveloperWindow: onOpenDeveloperWindow
            )
        }
        .frame(width: 320)
        .onAppear { controller.popoverDidOpen() }
        .onDisappear { controller.popoverDidClose() }
    }
}
