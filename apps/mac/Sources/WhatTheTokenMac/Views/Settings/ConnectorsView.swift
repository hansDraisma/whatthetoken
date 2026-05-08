import SwiftUI

struct ConnectorsView: View {
    let viewModel: StatusViewModel
    @State private var pendingDisconnect: CachedProviderID?

    var body: some View {
        Form {
            Section("Connectors") {
                ConnectorRowView(
                    title: "Claude Code",
                    stateTitle: ClaudeConnectorSetupCopy.title(for: viewModel.connectorState),
                    detail: viewModel.connectorStatusMessage,
                    trustMessage: ConnectorConsentCopy.claude,
                    connectionActionTitle: connectorConnectionActionTitle(
                        for: .claude,
                        isEnabled: viewModel.settings.connectors.claudeCode.isEnabled,
                        isPaused: viewModel.settings.connectors.claudeCode.isPaused
                    ),
                    connectionActionRole: nil,
                    isConnectionActionDisabled: viewModel.connectorState == .checking,
                    refreshActionTitle: viewModel.settings.connectors.claudeCode.isEnabled
                        ? claudeActionTitle(for: viewModel.connectorState)
                        : nil,
                    isRefreshActionDisabled: viewModel.connectorState == .checking || viewModel.settings.connectors.claudeCode.isPaused,
                    disconnectActionTitle: viewModel.settings.connectors.claudeCode.isEnabled
                        ? connectorDisconnectActionTitle(for: .claude)
                        : nil,
                    connectionAction: {
                        if !viewModel.settings.connectors.claudeCode.isEnabled {
                            let viewModel = self.viewModel
                            Task { await viewModel.connectClaudeCode() }
                        } else if viewModel.settings.connectors.claudeCode.isPaused {
                            let viewModel = self.viewModel
                            Task { await viewModel.setConnector(.claude, paused: false) }
                        } else {
                            let viewModel = self.viewModel
                            Task { await viewModel.setConnector(.claude, paused: true) }
                        }
                    },
                    refreshAction: {
                        let viewModel = self.viewModel
                        Task { await viewModel.connectClaudeCode() }
                    },
                    disconnectAction: {
                        pendingDisconnect = .claude
                    }
                )

                ConnectorRowView(
                    title: "Codex",
                    stateTitle: CodexConnectorSetupCopy.title(for: viewModel.codexConnectorState),
                    detail: viewModel.codexConnectorStatusMessage,
                    trustMessage: ConnectorConsentCopy.codex,
                    connectionActionTitle: connectorConnectionActionTitle(
                        for: .codex,
                        isEnabled: viewModel.settings.connectors.codex.isEnabled,
                        isPaused: viewModel.settings.connectors.codex.isPaused
                    ),
                    connectionActionRole: nil,
                    isConnectionActionDisabled: viewModel.codexConnectorState == .checking,
                    refreshActionTitle: viewModel.settings.connectors.codex.isEnabled
                        ? codexActionTitle(for: viewModel.codexConnectorState)
                        : nil,
                    isRefreshActionDisabled: viewModel.codexConnectorState == .checking || viewModel.settings.connectors.codex.isPaused,
                    disconnectActionTitle: viewModel.settings.connectors.codex.isEnabled
                        ? connectorDisconnectActionTitle(for: .codex)
                        : nil,
                    connectionAction: {
                        if !viewModel.settings.connectors.codex.isEnabled {
                            let viewModel = self.viewModel
                            Task { await viewModel.connectCodex() }
                        } else if viewModel.settings.connectors.codex.isPaused {
                            let viewModel = self.viewModel
                            Task { await viewModel.setConnector(.codex, paused: false) }
                        } else {
                            let viewModel = self.viewModel
                            Task { await viewModel.setConnector(.codex, paused: true) }
                        }
                    },
                    refreshAction: {
                        let viewModel = self.viewModel
                        Task { await viewModel.connectCodex() }
                    },
                    disconnectAction: {
                        pendingDisconnect = .codex
                    }
                )
            }

            Section("Refresh") {
                Toggle("Auto-refresh while popover is open", isOn: Binding(
                    get: { viewModel.settings.refresh.autoRefreshEnabled },
                    set: { enabled in
                        var settings = viewModel.settings
                        settings.refresh.autoRefreshEnabled = enabled
                        Task { await viewModel.saveSettings(settings) }
                    }
                ))

                Stepper(
                    "Interval: \(viewModel.settings.refresh.intervalSeconds / 60) min",
                    value: Binding(
                        get: { viewModel.settings.refresh.intervalSeconds },
                        set: { seconds in
                            var settings = viewModel.settings
                            settings.refresh.intervalSeconds = max(300, seconds)
                            Task { await viewModel.saveSettings(settings) }
                        }
                    ),
                    in: 300...3600,
                    step: 300
                )
                .disabled(!viewModel.settings.refresh.autoRefreshEnabled)
            }

            Section("Alerts") {
                Toggle("Notify me before quota runs low", isOn: Binding(
                    get: { viewModel.settings.notifications.isEnabled },
                    set: { enabled in
                        let viewModel = self.viewModel
                        Task { _ = await viewModel.setNotificationsEnabled(enabled) }
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
                                settings.notifications.criticalThreshold = max(value - 0.01, 0.01)
                            }
                            Task { await viewModel.saveSettings(settings) }
                        }
                    ),
                    in: 0.10...0.50,
                    step: 0.05
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
                                settings.notifications.warningThreshold = min(value + 0.01, 0.50)
                            }
                            Task { await viewModel.saveSettings(settings) }
                        }
                    ),
                    in: 0.01...0.25,
                    step: 0.01
                )
                .disabled(!viewModel.settings.notifications.isEnabled)
            }
        }
        .formStyle(.grouped)
        .alert(disconnectAlertTitle, isPresented: disconnectConfirmationPresented) {
            Button("Cancel", role: .cancel) {
                pendingDisconnect = nil
            }
            Button("Disconnect", role: .destructive) {
                confirmDisconnect()
            }
        } message: {
            Text(disconnectAlertMessage)
        }
    }

    private var disconnectConfirmationPresented: Binding<Bool> {
        Binding(
            get: { pendingDisconnect != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDisconnect = nil
                }
            }
        )
    }

    private var disconnectAlertTitle: String {
        guard let pendingDisconnect else { return "Disconnect Connector?" }
        return "Disconnect \(pendingDisconnect.displayName)?"
    }

    private var disconnectAlertMessage: String {
        guard let pendingDisconnect else { return "" }
        return "Disconnecting stops WhatTheToken from reading \(pendingDisconnect.dataDescription) and removes cached \(pendingDisconnect.dataDescription) from this app."
    }

    private func confirmDisconnect() {
        guard let provider = pendingDisconnect else { return }
        pendingDisconnect = nil
        let viewModel = self.viewModel
        Task { await viewModel.disconnect(provider) }
    }
}

private extension CachedProviderID {
    var dataDescription: String {
        switch self {
        case .claude:
            return "Claude Code usage"
        case .codex:
            return "Codex rate-limit status"
        }
    }
}
