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
                    disconnectAction: {
                        pendingDisconnect = .codex
                    }
                )
            }

            Section("Refresh") {
                Toggle("Auto-refresh while app is running", isOn: Binding(
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

            NotificationAlertsView(viewModel: viewModel)
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
