import Foundation

enum ProviderTab: String, CaseIterable, Identifiable, Sendable {
    case codex
    case claude

    var id: String { rawValue }

    var title: String {
        switch self {
        case .codex:
            return "Codex"
        case .claude:
            return "Claude Code"
        }
    }
}

enum BannerState: Equatable, Sendable {
    case hidden
    case critical(text: String)
    case low(text: String)
    case stale(text: String)
    case disconnected(text: String)
}

enum BannerCopy {
    static let stale = "Usage may be outdated. Refresh to check current limits."
    static let disconnectedBoth = "Connect Claude or Codex in Settings."

    static func critical(provider: ProviderTab) -> String {
        "\(provider.title) is out of usable quota"
    }

    static func low(provider: ProviderTab) -> String {
        "\(provider.title) included usage is running low"
    }

    static func criticalLowFallback(provider: ProviderTab) -> String {
        "\(provider.title) included usage is critically low. Extra credits available."
    }

    static func fallbackOnly(provider: ProviderTab) -> String {
        "\(provider.title) included usage is exhausted. Extra credits available."
    }

    static func disconnected(selected: ProviderTab) -> String {
        "\(selected.title) is not connected. Open Settings to connect."
    }

    static func hint(otherHealthy other: ProviderTab) -> String {
        "\(other.title) has more room — consider switching new work."
    }
}

extension BannerState {
    @MainActor
    static func from(viewModel: StatusViewModel, selected: ProviderTab) -> BannerState {
        let selectedModel = ProviderTabModel.from(viewModel: viewModel, tab: selected)
        let otherTab: ProviderTab = selected == .claude ? .codex : .claude
        let otherModel = ProviderTabModel.from(viewModel: viewModel, tab: otherTab)

        let bothDisconnected: Bool = {
            if case .disconnected = selectedModel.body, case .disconnected = otherModel.body {
                return true
            }
            return false
        }()

        switch selectedModel.body {
        case .disconnected:
            let text = bothDisconnected ? BannerCopy.disconnectedBoth : BannerCopy.disconnected(selected: selected)
            return .disconnected(text: text)
        case .error(.network, _), .error(.schemaChanged, _):
            return .stale(text: BannerCopy.stale)
        case let .connected(snapshots, _):
            let availability = ProviderAvailability.from(snapshots: snapshots, tab: selected)

            switch availability {
            case .available:
                return .hidden
            case .stale:
                return .stale(text: BannerCopy.stale)
            case .low:
                let text = BannerCopy.low(provider: selected)
                return .low(text: appendHintIfApplicable(text, otherTab: otherTab, otherBody: otherModel.body))
            case .criticalWithFallback:
                return .low(text: BannerCopy.criticalLowFallback(provider: selected))
            case .fallbackOnly:
                return .low(text: BannerCopy.fallbackOnly(provider: selected))
            case .critical:
                let text = BannerCopy.critical(provider: selected)
                return .critical(text: appendHintIfApplicable(text, otherTab: otherTab, otherBody: otherModel.body))
            }
        case .empty, .checking:
            return .hidden
        }
    }

    private static func appendHintIfApplicable(
        _ base: String,
        otherTab: ProviderTab,
        otherBody: ProviderTabModel.Body
    ) -> String {
        if case let .connected(snapshots, _) = otherBody,
           ProviderAvailability.from(snapshots: snapshots, tab: otherTab) == .available {
            return base + ". " + BannerCopy.hint(otherHealthy: otherTab)
        }
        return base
    }
}
