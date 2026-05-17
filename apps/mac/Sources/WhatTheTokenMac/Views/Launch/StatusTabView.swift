import SwiftUI
import AppKit

enum StatusTabBannerVisibility {
    static func shouldShow(state: OnboardingState) -> Bool {
        !state.bannerDismissable
    }
}

enum StatusTabStepBodyPolicy {
    static func shouldMarkConnectProvidersDone(
        anyProviderConnected: Bool,
        currentState: OnboardingStepState
    ) -> Bool {
        anyProviderConnected && currentState == .pending
    }

    static func shouldMarkNotificationsDone(status: NotificationAuthorizationStatus) -> Bool {
        status == .granted
    }

    static func shouldMarkHotkeyDone(warning: String?) -> Bool {
        warning == nil
    }

    static func shouldMarkLaunchAtLoginDone(success: Bool) -> Bool {
        success
    }
}

enum StatusTabHotkeyWarningBanner {
    static func message(from warning: String?) -> String? {
        warning
    }
}

struct StatusTabView: View {
    let viewModel: StatusViewModel
    @State private var selectedTab: ProviderTab = .codex
    @State private var hotkeyWarning: String?

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

                if let warning = StatusTabHotkeyWarningBanner.message(from: viewModel.hotkeyRegistrationWarning) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(warning)
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Dismiss") {
                            viewModel.dismissHotkeyRegistrationWarning()
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
            return AnyView(connectProvidersBody)
        case .findMenuBar:
            return AnyView(findMenuBarBody)
        case .addWidget:
            return AnyView(addWidgetBody)
        case .allowNotifications:
            return AnyView(allowNotificationsBody)
        case .setHotkey:
            return AnyView(setHotkeyBody)
        case .launchAtLogin:
            return AnyView(launchAtLoginBody)
        }
    }

    private var connectProvidersBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            BannerProviderCard(
                title: "Claude Code",
                subtitle: "Anthropic - usage from your local Claude Code OAuth session.",
                isConnected: viewModel.settings.connectors.claudeCode.isEnabled,
                connectActionTitle: "Connect",
                onConnect: { Task { await viewModel.connectClaudeCode() } }
            )
            BannerProviderCard(
                title: "Codex",
                subtitle: "OpenAI - usage from the local Codex app-server.",
                isConnected: viewModel.settings.connectors.codex.isEnabled,
                connectActionTitle: "Connect",
                onConnect: { Task { await viewModel.connectCodex() } }
            )
            HStack {
                Spacer()
                Button("Skip step") {
                    Task { await viewModel.markOnboardingStep(.connectProviders, as: .skipped) }
                }
                .buttonStyle(.link)
            }
        }
        .onChange(of: anyProviderConnected) { _, newValue in
            if StatusTabStepBodyPolicy.shouldMarkConnectProvidersDone(
                anyProviderConnected: newValue,
                currentState: viewModel.settings.onboarding.steps.connectProviders
            ) {
                Task { await viewModel.markOnboardingStep(.connectProviders, as: .done) }
            }
        }
    }

    private var anyProviderConnected: Bool {
        viewModel.settings.connectors.claudeCode.isEnabled
            || viewModel.settings.connectors.codex.isEnabled
    }

    private var findMenuBarBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Click the button below to pulse the menu bar icon so you can spot it. If you ever lose it, the Dock icon is your backup - disable it any time in Tools.")
                .font(.caption)
            HStack {
                Button("Pulse the icon") {
                    Task {
                        await viewModel.pulseMenuBarIcon()
                        await viewModel.markOnboardingStep(.findMenuBar, as: .done)
                    }
                }
                Button("Skip step") {
                    Task { await viewModel.markOnboardingStep(.findMenuBar, as: .skipped) }
                }
                .buttonStyle(.link)
            }
            Text("Tip: hold Command and drag the icon to reveal it from the overflow area.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var addWidgetBody: some View {
        WidgetInstructionsView(
            onAddedConfirm: { Task { await viewModel.markOnboardingStep(.addWidget, as: .done) } },
            onSkip: { Task { await viewModel.markOnboardingStep(.addWidget, as: .skipped) } }
        )
    }

    private var allowNotificationsBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Get a banner before quota runs out - even when the menu bar icon is hidden.")
                .font(.caption)
            HStack {
                Button("Enable notifications") {
                    Task {
                        let status = await viewModel.setNotificationsEnabled(true)
                        if StatusTabStepBodyPolicy.shouldMarkNotificationsDone(status: status) {
                            await viewModel.markOnboardingStep(.allowNotifications, as: .done)
                        }
                    }
                }
                Button("Skip step") {
                    Task { await viewModel.markOnboardingStep(.allowNotifications, as: .skipped) }
                }
                .buttonStyle(.link)
            }
        }
    }

    private var setHotkeyBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Press the hotkey from anywhere to open WhatTheToken. Default is Control-Option-T - change it any time.")
                .font(.caption)
            HotkeyRecorderField(
                combination: Binding(
                    get: { viewModel.settings.hotkey.combination },
                    set: { value in
                        Task {
                            let warning = await viewModel.setHotkey(value)
                            if StatusTabStepBodyPolicy.shouldMarkHotkeyDone(warning: warning) {
                                await viewModel.markOnboardingStep(.setHotkey, as: .done)
                                hotkeyWarning = nil
                            } else {
                                hotkeyWarning = warning
                            }
                        }
                    }
                ),
                onRecord: { value in
                    Task {
                        let warning = await viewModel.setHotkey(value)
                        if StatusTabStepBodyPolicy.shouldMarkHotkeyDone(warning: warning) {
                            await viewModel.markOnboardingStep(.setHotkey, as: .done)
                            hotkeyWarning = nil
                        } else {
                            hotkeyWarning = warning
                        }
                    }
                },
                warningText: hotkeyWarning
            )
            Button("Skip step") {
                Task { await viewModel.markOnboardingStep(.setHotkey, as: .skipped) }
            }
            .buttonStyle(.link)
        }
    }

    private var launchAtLoginBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Want WhatTheToken to start automatically when you log in?")
                .font(.caption)
            HStack {
                Button("Launch at login") {
                    Task {
                        let success = await viewModel.setLaunchAtLoginEnabled(true)
                        if StatusTabStepBodyPolicy.shouldMarkLaunchAtLoginDone(success: success) {
                            await viewModel.markOnboardingStep(.launchAtLogin, as: .done)
                        }
                    }
                }
                Button("Skip step") {
                    Task { await viewModel.markOnboardingStep(.launchAtLogin, as: .skipped) }
                }
                .buttonStyle(.link)
            }
            if let message = viewModel.launchAtLoginStatusMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }
}
