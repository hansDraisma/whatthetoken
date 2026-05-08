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
                        isEnabled: viewModel.settings.connectors.claudeCode.isEnabled
                    ),
                    connectionActionRole: viewModel.settings.connectors.claudeCode.isEnabled ? .destructive : nil,
                    isConnectionActionDisabled: viewModel.connectorState == .checking,
                    refreshActionTitle: viewModel.settings.connectors.claudeCode.isEnabled
                        ? claudeActionTitle(for: viewModel.connectorState)
                        : nil,
                    isRefreshActionDisabled: viewModel.connectorState == .checking,
                    connectionAction: {
                        if viewModel.settings.connectors.claudeCode.isEnabled {
                            pendingDisconnect = .claude
                        } else {
                            let viewModel = self.viewModel
                            Task { await viewModel.connectClaudeCode() }
                        }
                    },
                    refreshAction: {
                        let viewModel = self.viewModel
                        Task { await viewModel.connectClaudeCode() }
                    }
                )

                ConnectorRowView(
                    title: "Codex",
                    stateTitle: CodexConnectorSetupCopy.title(for: viewModel.codexConnectorState),
                    detail: viewModel.codexConnectorStatusMessage,
                    trustMessage: ConnectorConsentCopy.codex,
                    connectionActionTitle: connectorConnectionActionTitle(
                        for: .codex,
                        isEnabled: viewModel.settings.connectors.codex.isEnabled
                    ),
                    connectionActionRole: viewModel.settings.connectors.codex.isEnabled ? .destructive : nil,
                    isConnectionActionDisabled: viewModel.codexConnectorState == .checking,
                    refreshActionTitle: viewModel.settings.connectors.codex.isEnabled
                        ? codexActionTitle(for: viewModel.codexConnectorState)
                        : nil,
                    isRefreshActionDisabled: viewModel.codexConnectorState == .checking,
                    connectionAction: {
                        if viewModel.settings.connectors.codex.isEnabled {
                            pendingDisconnect = .codex
                        } else {
                            let viewModel = self.viewModel
                            Task { await viewModel.connectCodex() }
                        }
                    },
                    refreshAction: {
                        let viewModel = self.viewModel
                        Task { await viewModel.connectCodex() }
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
