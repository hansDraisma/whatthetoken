import SwiftUI
import Observation

enum LaunchTab: Hashable, CaseIterable {
    case status
    case connectors
    case notifications
    case tools
    case about

    var title: String {
        switch self {
        case .status:
            return "Status"
        case .connectors:
            return "Connectors"
        case .notifications:
            return "Notifications"
        case .tools:
            return "Tools"
        case .about:
            return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .status:
            return "gauge.with.dots.needle.bottom.50percent"
        case .connectors:
            return "powerplug"
        case .notifications:
            return "bell"
        case .tools:
            return "wrench.and.screwdriver"
        case .about:
            return "info.circle"
        }
    }
}

@MainActor
@Observable
final class LaunchWindowNavigation {
    var selection: LaunchTab

    init(selection: LaunchTab = .status) {
        self.selection = selection
    }
}

struct LaunchWindowRootView: View {
    let viewModel: StatusViewModel
    let canCheckForUpdates: @MainActor () -> Bool
    let onCheckForUpdates: @MainActor () -> Void
    @Bindable var navigation: LaunchWindowNavigation

    var body: some View {
        NavigationSplitView {
            List(LaunchTab.allCases, id: \.self, selection: $navigation.selection) { tab in
                Label(tab.title, systemImage: tab.systemImage)
                    .tag(tab)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            switch navigation.selection {
            case .status:
                StatusTabView(
                    viewModel: viewModel,
                    onOpenConnectors: { navigation.selection = .connectors },
                    canCheckForUpdates: canCheckForUpdates(),
                    onCheckForUpdates: onCheckForUpdates
                )
            case .connectors:
                ConnectorsView(
                    viewModel: viewModel,
                    canCheckForUpdates: canCheckForUpdates(),
                    onCheckForUpdates: onCheckForUpdates
                )
            case .notifications:
                NotificationsTabView(viewModel: viewModel)
            case .tools:
                ToolsTabView(viewModel: viewModel)
            case .about:
                AboutTabView()
            }
        }
        .frame(minWidth: 720, minHeight: 480)
    }
}
