import Foundation

enum ProviderTabIndicator: Equatable, Sendable {
    case none
    case warning
    case critical
    case stale
    case disconnected

    func accessibilityLabel(for tab: ProviderTab) -> String {
        switch self {
        case .none:
            return tab.title
        case .warning:
            return "\(tab.title), running low"
        case .critical:
            return "\(tab.title), critical"
        case .stale:
            return "\(tab.title), usage may be outdated"
        case .disconnected:
            return "\(tab.title), disconnected"
        }
    }

    var helpText: String? {
        switch self {
        case .none:
            return nil
        case .warning:
            return "Running low"
        case .critical:
            return "Critical"
        case .stale:
            return "Usage may be outdated"
        case .disconnected:
            return "Disconnected"
        }
    }

    var hasInlineMarker: Bool {
        self != .none
    }
}

struct PopoverChromeState: Equatable, Sendable {
    let topBanner: BannerState
    let selectedBanner: BannerState
    let indicators: [ProviderTab: ProviderTabIndicator]
}

extension PopoverChromeState {
    @MainActor
    static func from(viewModel: StatusViewModel, selected: ProviderTab) -> PopoverChromeState {
        let selectedBanner = BannerState.from(viewModel: viewModel, selected: selected)
        let codexModel = ProviderTabModel.from(viewModel: viewModel, tab: .codex)
        let claudeModel = ProviderTabModel.from(viewModel: viewModel, tab: .claude)
        let bothDisconnected = Self.isDisconnected(codexModel.body) && Self.isDisconnected(claudeModel.body)

        return PopoverChromeState(
            topBanner: bothDisconnected ? selectedBanner : .hidden,
            selectedBanner: bothDisconnected ? .hidden : selectedBanner,
            indicators: [
                .codex: indicator(for: codexModel),
                .claude: indicator(for: claudeModel)
            ]
        )
    }

    private static func isDisconnected(_ body: ProviderTabModel.Body) -> Bool {
        if case .disconnected = body {
            return true
        }
        return false
    }

    private static func indicator(for model: ProviderTabModel) -> ProviderTabIndicator {
        switch model.body {
        case let .connected(snapshots, _, _):
            switch ProviderAvailability.from(snapshots: snapshots, tab: model.tab) {
            case .available:
                return .none
            case .low, .criticalWithFallback, .fallbackOnly:
                return .warning
            case .critical:
                return .critical
            case .stale:
                return .stale
            }
        case .error:
            return .stale
        case .disconnected:
            return .disconnected
        case .empty, .loading:
            return .none
        }
    }

    @MainActor
    static func menuBarTitle(isCritical: Bool) -> String {
        isCritical ? "WhatTheToken - Critical" : "WhatTheToken"
    }

    @MainActor
    static func menuBarSystemImage(isCritical: Bool) -> String {
        isCritical ? "gauge.with.dots.needle.67percent" : "gauge"
    }

    @MainActor
    static func menuBarTitle(viewModel: StatusViewModel) -> String {
        menuBarTitle(isCritical: hasCriticalProvider(viewModel: viewModel))
    }

    @MainActor
    static func menuBarSystemImage(viewModel: StatusViewModel) -> String {
        menuBarSystemImage(isCritical: hasCriticalProvider(viewModel: viewModel))
    }

    @MainActor
    static func hasCriticalProvider(viewModel: StatusViewModel) -> Bool {
        isProviderCritical(
            viewModel: viewModel,
            tab: .claude,
            isPaused: viewModel.settings.connectors.claudeCode.isPaused
        )
        || isProviderCritical(
            viewModel: viewModel,
            tab: .codex,
            isPaused: viewModel.settings.connectors.codex.isPaused
        )
    }

    @MainActor
    private static func isProviderCritical(
        viewModel: StatusViewModel,
        tab: ProviderTab,
        isPaused: Bool
    ) -> Bool {
        guard !isPaused else { return false }
        let providerID = CachedProviderID.from(tab: tab)
        let availability = ProviderAvailability.from(
            snapshots: viewModel.snapshots.filter(providerID.snapshotPredicate),
            tab: tab
        )
        switch availability {
        case .critical, .criticalWithFallback, .fallbackOnly:
            return true
        case .available, .low, .stale:
            return false
        }
    }
}
