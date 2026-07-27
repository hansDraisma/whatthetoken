import SwiftUI

struct ConnectorsView: View {
    let viewModel: StatusViewModel
    let canCheckForUpdates: Bool
    let onCheckForUpdates: () -> Void
    @State private var pendingDisconnect: CachedProviderID?

    init(
        viewModel: StatusViewModel,
        canCheckForUpdates: Bool = false,
        onCheckForUpdates: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.canCheckForUpdates = canCheckForUpdates
        self.onCheckForUpdates = onCheckForUpdates
    }

    var body: some View {
        let claudeCopy = ConnectorRecoveryCopy.claude(viewModel.connectorState)
        let claudePrimary = connectorRowAction(
            for: .claude(viewModel.connectorState),
            isEnabled: viewModel.settings.connectors.claudeCode.isEnabled,
            isPaused: viewModel.settings.connectors.claudeCode.isPaused
        )
        let codexCopy = ConnectorRecoveryCopy.codex(viewModel.codexConnectorState)
        let codexPrimary = connectorRowAction(
            for: .codex(viewModel.codexConnectorState),
            isEnabled: viewModel.settings.connectors.codex.isEnabled,
            isPaused: viewModel.settings.connectors.codex.isPaused
        )

        Form {
            Section("Connectors") {
                ConnectorRowView(
                    title: "Claude Code",
                    stateTitle: claudeCopy.headline,
                    detail: claudeCopy.advice.isEmpty
                        ? viewModel.connectorStatusMessage
                        : claudeCopy.advice,
                    trustMessage: ConnectorConsentCopy.claude,
                    connectionActionTitle: claudePrimary.title,
                    connectionActionRole: nil,
                    isConnectionActionDisabled: claudePrimary.isDisabledByState
                        || (claudePrimary == .checkForUpdates && !canCheckForUpdates),
                    secondaryActionTitle: connectorPauseActionTitle(
                        for: .claude,
                        isEnabled: viewModel.settings.connectors.claudeCode.isEnabled,
                        isPaused: viewModel.settings.connectors.claudeCode.isPaused
                    ),
                    disconnectActionTitle: viewModel.settings.connectors.claudeCode.isEnabled
                        ? connectorDisconnectActionTitle(for: .claude)
                        : nil,
                    connectionAction: {
                        performClaude(claudePrimary)
                    },
                    secondaryAction: {
                        let viewModel = self.viewModel
                        Task { await viewModel.setConnector(.claude, paused: true) }
                    },
                    disconnectAction: {
                        pendingDisconnect = .claude
                    }
                )

                ConnectorRowView(
                    title: "Codex",
                    stateTitle: codexCopy.headline,
                    detail: codexCopy.advice.isEmpty
                        ? viewModel.codexConnectorStatusMessage
                        : codexCopy.advice,
                    trustMessage: ConnectorConsentCopy.codex,
                    connectionActionTitle: codexPrimary.title,
                    connectionActionRole: nil,
                    isConnectionActionDisabled: codexPrimary.isDisabledByState
                        || (codexPrimary == .checkForUpdates && !canCheckForUpdates),
                    secondaryActionTitle: connectorPauseActionTitle(
                        for: .codex,
                        isEnabled: viewModel.settings.connectors.codex.isEnabled,
                        isPaused: viewModel.settings.connectors.codex.isPaused
                    ),
                    disconnectActionTitle: viewModel.settings.connectors.codex.isEnabled
                        ? connectorDisconnectActionTitle(for: .codex)
                        : nil,
                    connectionAction: {
                        performCodex(codexPrimary)
                    },
                    secondaryAction: {
                        let viewModel = self.viewModel
                        Task { await viewModel.setConnector(.codex, paused: true) }
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

    private func performClaude(_ action: ConnectorRowAction) {
        let viewModel = self.viewModel
        switch action {
        case .connect, .refresh, .retry:
            Task { await viewModel.connectClaudeCode() }
        case .resume:
            Task { await viewModel.setConnector(.claude, paused: false) }
        case .checkForUpdates:
            onCheckForUpdates()
        case .checking:
            break
        }
    }

    private func performCodex(_ action: ConnectorRowAction) {
        let viewModel = self.viewModel
        switch action {
        case .connect, .refresh, .retry:
            Task { await viewModel.connectCodex() }
        case .resume:
            Task { await viewModel.setConnector(.codex, paused: false) }
        case .checkForUpdates:
            onCheckForUpdates()
        case .checking:
            break
        }
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
