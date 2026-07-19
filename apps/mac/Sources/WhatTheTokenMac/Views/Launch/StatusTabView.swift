import SwiftUI
import AppKit

enum StatusTabBannerVisibility {
    static func shouldShow(state: OnboardingState) -> Bool {
        !state.bannerDismissable
    }
}

enum StatusTabStepBodyPolicy {
    static func canContinueConnectingProviders(anyProviderConnected: Bool) -> Bool {
        anyProviderConnected
    }

    static func shouldMarkNotificationsDone(result: NotificationSettingsUpdateResult) -> Bool {
        result == .enabled
    }

    static func notificationActionMessage(
        result: NotificationSettingsUpdateResult
    ) -> String? {
        switch result {
        case .permissionDenied:
            return StatusTabCopy.notificationPermissionDenied
        case .saveFailed:
            return StatusTabCopy.notificationSaveFailed
        case .enabled, .disabled:
            return nil
        }
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
    let onOpenConnectors: () -> Void
    @State private var selectedTab: ProviderTab = .codex
    @State private var isUpdatingNotifications = false
    @State private var notificationActionMessage: String?

    init(viewModel: StatusViewModel, onOpenConnectors: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onOpenConnectors = onOpenConnectors
    }

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
                        Button(StatusTabCopy.hotkeyWarningDismissTitle) {
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

                Text(StatusTabCopy.quotaTitle)
                    .font(.headline)
                quotaCards
            }
            .padding(20)
        }
        .task {
            await viewModel.reconcileOnboardingFromSystemState()
        }
    }

    @ViewBuilder
    private var quotaCards: some View {
        if !viewModel.settings.connectors.claudeCode.isEnabled
            && !viewModel.settings.connectors.codex.isEnabled {
            Text(StatusTabCopy.noProvidersConnected)
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
                    onOpenSettings: onOpenConnectors,
                    onRetry: { Task { await viewModel.refreshAll(reason: .retry) } },
                    onRefresh: { Task { await viewModel.refreshAll(reason: .manual) } }
                )
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private func stepBody(for step: OnboardingStep) -> some View {
        switch step {
        case .connectProviders:
            connectProvidersBody
        case .findMenuBar:
            findMenuBarBody
        case .addWidget:
            addWidgetBody
        case .allowNotifications:
            allowNotificationsBody
        case .setHotkey:
            setHotkeyBody
        case .launchAtLogin:
            launchAtLoginBody
        }
    }

    private var connectProvidersBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(StatusTabCopy.connectProvidersInstruction)
                .font(.caption)
            BannerProviderCard(
                title: StatusTabCopy.claudeProviderTitle,
                subtitle: StatusTabCopy.claudeProviderSubtitle,
                isConnected: viewModel.settings.connectors.claudeCode.isEnabled,
                connectActionTitle: StatusTabCopy.connectActionTitle,
                onConnect: { Task { await viewModel.connectClaudeCode() } }
            )
            BannerProviderCard(
                title: StatusTabCopy.codexProviderTitle,
                subtitle: StatusTabCopy.codexProviderSubtitle,
                isConnected: viewModel.settings.connectors.codex.isEnabled,
                connectActionTitle: StatusTabCopy.connectActionTitle,
                onConnect: { Task { await viewModel.connectCodex() } }
            )
            HStack {
                Spacer()
                Button(StatusTabCopy.skipStepTitle) {
                    Task { await viewModel.markOnboardingStep(.connectProviders, as: .skipped) }
                }
                .buttonStyle(.link)
                Button(StatusTabCopy.continueTitle) {
                    Task { await viewModel.markOnboardingStep(.connectProviders, as: .done) }
                }
                .disabled(!StatusTabStepBodyPolicy.canContinueConnectingProviders(
                    anyProviderConnected: anyProviderConnected
                ))
            }
        }
    }

    private var anyProviderConnected: Bool {
        viewModel.settings.connectors.claudeCode.isEnabled
            || viewModel.settings.connectors.codex.isEnabled
    }

    private var findMenuBarBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(StatusTabCopy.findMenuBarInstruction)
                .font(.caption)
            HStack {
                Button(StatusTabCopy.pulseIconTitle) {
                    Task {
                        await viewModel.pulseMenuBarIcon()
                        await viewModel.markOnboardingStep(.findMenuBar, as: .done)
                    }
                }
                Button(StatusTabCopy.skipStepTitle) {
                    Task { await viewModel.markOnboardingStep(.findMenuBar, as: .skipped) }
                }
                .buttonStyle(.link)
            }
            Text(StatusTabCopy.findMenuBarTip)
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
            Text(StatusTabCopy.allowNotificationsInstruction)
                .font(.caption)
            HStack {
                Button(StatusTabCopy.enableNotificationsTitle) {
                    Task {
                        isUpdatingNotifications = true
                        let result = await viewModel.setNotificationsEnabled(true)
                        notificationActionMessage = StatusTabStepBodyPolicy.notificationActionMessage(
                            result: result
                        )
                        if StatusTabStepBodyPolicy.shouldMarkNotificationsDone(result: result) {
                            await viewModel.markOnboardingStep(.allowNotifications, as: .done)
                        }
                        isUpdatingNotifications = false
                    }
                }
                .disabled(isUpdatingNotifications)
                Button(StatusTabCopy.skipStepTitle) {
                    Task { await viewModel.markOnboardingStep(.allowNotifications, as: .skipped) }
                }
                .buttonStyle(.link)
            }
            if isUpdatingNotifications {
                ProgressView("Updating notification settings...")
                    .controlSize(.small)
            } else if let notificationActionMessage {
                Text(notificationActionMessage)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var setHotkeyBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(StatusTabCopy.setHotkeyInstruction)
                .font(.caption)
            HotkeyRecorderField(
                combination: Binding(
                    get: { viewModel.settings.hotkey.combination },
                    set: { value in
                        Task {
                            let warning = await viewModel.setHotkey(value)
                            if StatusTabStepBodyPolicy.shouldMarkHotkeyDone(warning: warning) {
                                await viewModel.markOnboardingStep(.setHotkey, as: .done)
                            }
                        }
                    }
                ),
                onRecord: { value in
                    Task {
                        let warning = await viewModel.setHotkey(value)
                        if StatusTabStepBodyPolicy.shouldMarkHotkeyDone(warning: warning) {
                            await viewModel.markOnboardingStep(.setHotkey, as: .done)
                        }
                    }
                },
                warningText: viewModel.hotkeyRegistrationWarning
            )
            Button(StatusTabCopy.skipStepTitle) {
                Task { await viewModel.markOnboardingStep(.setHotkey, as: .skipped) }
            }
            .buttonStyle(.link)
        }
    }

    private var launchAtLoginBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(StatusTabCopy.launchAtLoginInstruction)
                .font(.caption)
            HStack {
                Button(StatusTabCopy.launchAtLoginTitle) {
                    Task {
                        let success = await viewModel.setLaunchAtLoginEnabled(true)
                        if StatusTabStepBodyPolicy.shouldMarkLaunchAtLoginDone(success: success) {
                            await viewModel.markOnboardingStep(.launchAtLogin, as: .done)
                        }
                    }
                }
                Button(StatusTabCopy.skipStepTitle) {
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
