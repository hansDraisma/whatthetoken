import SwiftUI

enum NotificationAlertsCopy {
    static func statusMessage(
        authorizationStatus: NotificationAuthorizationStatus?,
        notificationsEnabled: Bool
    ) -> String? {
        guard notificationsEnabled, authorizationStatus == .denied else { return nil }
        return "Notifications are enabled in WhatTheToken, but macOS notification permission is denied. Enable notifications in System Settings to receive quota alerts."
    }
}

struct NotificationAlertsView: View {
    let viewModel: StatusViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var authorizationStatus: NotificationAuthorizationStatus?

    var body: some View {
        Section {
            Toggle("Notify me before quota runs low", isOn: Binding(
                get: { viewModel.settings.notifications.isEnabled },
                set: { enabled in
                    let viewModel = self.viewModel
                    Task {
                        _ = await viewModel.setNotificationsEnabled(enabled)
                        await refreshAuthorizationStatus()
                    }
                }
            ))

            Toggle("Claude Code alerts", isOn: Binding(
                get: { viewModel.settings.notifications.providerAlerts.claudeCode.isEnabled },
                set: { enabled in
                    var settings = viewModel.settings
                    settings.notifications.providerAlerts.claudeCode.isEnabled = enabled
                    Task { await viewModel.saveSettings(settings) }
                }
            ))
            .disabled(!viewModel.settings.notifications.isEnabled)

            Toggle("Codex alerts", isOn: Binding(
                get: { viewModel.settings.notifications.providerAlerts.codex.isEnabled },
                set: { enabled in
                    var settings = viewModel.settings
                    settings.notifications.providerAlerts.codex.isEnabled = enabled
                    Task { await viewModel.saveSettings(settings) }
                }
            ))
            .disabled(!viewModel.settings.notifications.isEnabled)

            Stepper(
                "Warning: \(Int(viewModel.settings.notifications.warningThreshold * 100))%",
                value: Binding(
                    get: { viewModel.settings.notifications.warningThreshold },
                    set: { value in
                        var settings = viewModel.settings
                        settings.notifications.warningThreshold = value
                        if settings.notifications.criticalThreshold >= value {
                            settings.notifications.criticalThreshold = max(value - NotificationThresholdSteps.critical, 0.01)
                        }
                        Task { await viewModel.saveSettings(settings) }
                    }
                ),
                in: 0.10...0.50,
                step: NotificationThresholdSteps.warning
            )
            .disabled(!viewModel.settings.notifications.isEnabled)

            Stepper(
                "Critical: \(Int(viewModel.settings.notifications.criticalThreshold * 100))%",
                value: Binding(
                    get: { viewModel.settings.notifications.criticalThreshold },
                    set: { value in
                        var settings = viewModel.settings
                        settings.notifications.criticalThreshold = value
                        if settings.notifications.warningThreshold <= value {
                            settings.notifications.warningThreshold = NotificationThresholdSteps.warningStepAbove(value)
                        }
                        Task { await viewModel.saveSettings(settings) }
                    }
                ),
                in: 0.01...0.25,
                step: NotificationThresholdSteps.critical
            )
            .disabled(!viewModel.settings.notifications.isEnabled)
        } header: {
            Text("Alerts")
        } footer: {
            if let message = NotificationAlertsCopy.statusMessage(
                authorizationStatus: authorizationStatus,
                notificationsEnabled: viewModel.settings.notifications.isEnabled
            ) {
                Text(message)
                    .foregroundStyle(.orange)
            }
        }
        .task {
            await refreshAuthorizationStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await refreshAuthorizationStatus() }
            }
        }
    }

    private func refreshAuthorizationStatus() async {
        authorizationStatus = await viewModel.notificationAuthorizationStatus()
    }
}

private enum NotificationThresholdSteps {
    static let warning = 0.05
    static let critical = 0.01

    static func warningStepAbove(_ value: Double) -> Double {
        let candidate = ((value / warning).rounded(.down) + 1) * warning
        return min(candidate, 0.50)
    }
}
