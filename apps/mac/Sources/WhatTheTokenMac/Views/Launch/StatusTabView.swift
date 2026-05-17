import SwiftUI
import AppKit

enum StatusTabBannerVisibility {
    static func shouldShow(state: OnboardingState) -> Bool {
        !state.bannerDismissable
    }
}

struct StatusTabView: View {
    let viewModel: StatusViewModel
    @State private var selectedTab: ProviderTab = .codex

    var body: some View {
        let onboarding = OnboardingState(stepStates: viewModel.settings.onboarding.steps)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if StatusTabBannerVisibility.shouldShow(state: onboarding) {
                    GetStartedBanner(
                        state: onboarding,
                        stepBody: { step in stepBody(for: step) },
                        onSkipAll: { Task { await viewModel.skipAllOnboarding() } }
                    )
                }

                Text("Quota")
                    .font(.headline)
                quotaCards
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private var quotaCards: some View {
        if !viewModel.settings.connectors.claudeCode.isEnabled
            && !viewModel.settings.connectors.codex.isEnabled {
            Text("No providers connected yet - start with the banner above.")
                .foregroundStyle(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            let chromeState = PopoverChromeState.from(viewModel: viewModel, selected: selectedTab)
            VStack(spacing: 0) {
                ProviderTabBarView(selected: $selectedTab, indicators: chromeState.indicators)
                ProviderTabContentView(
                    model: ProviderTabModel.from(viewModel: viewModel, tab: selectedTab),
                    onOpenSettings: { },
                    onRetry: { Task { await viewModel.refreshAll(reason: .retry) } },
                    onRefresh: { Task { await viewModel.refreshAll(reason: .manual) } }
                )
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func stepBody(for step: OnboardingStep) -> AnyView {
        switch step {
        case .connectProviders:
            return AnyView(Text("Connecting...").font(.caption))
        case .findMenuBar:
            return AnyView(Text("Pulsing...").font(.caption))
        case .addWidget:
            return AnyView(Text("Adding widget...").font(.caption))
        case .allowNotifications:
            return AnyView(Text("Allowing...").font(.caption))
        case .setHotkey:
            return AnyView(Text("Recording...").font(.caption))
        case .launchAtLogin:
            return AnyView(Text("Launching...").font(.caption))
        }
    }
}
