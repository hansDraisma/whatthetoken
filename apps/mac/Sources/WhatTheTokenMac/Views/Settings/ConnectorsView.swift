import SwiftUI

struct ConnectorsView: View {
    let viewModel: StatusViewModel

    var body: some View {
        Form {
            Section("Connectors") {
                ConnectorRowView(
                    title: "Claude Code",
                    stateTitle: ClaudeConnectorSetupCopy.title(for: viewModel.connectorState),
                    detail: viewModel.connectorStatusMessage,
                    trustMessage: ConnectorConsentCopy.claude,
                    actionTitle: claudeActionTitle(for: viewModel.connectorState),
                    isWorking: viewModel.connectorState == .checking,
                    isEnabled: viewModel.settings.connectors.claudeCode.isEnabled,
                    canDisconnect: viewModel.settings.connectors.claudeCode.isEnabled
                        || viewModel.snapshots.contains(where: CachedProviderID.claude.snapshotPredicate),
                    onEnabledChange: { enabled in
                        let viewModel = self.viewModel
                        Task { await viewModel.setConnector(.claude, enabled: enabled) }
                    },
                    onDisconnect: {
                        let viewModel = self.viewModel
                        Task { await viewModel.disconnect(.claude) }
                    },
                    action: {
                        let viewModel = self.viewModel
                        Task { await viewModel.connectClaudeCode() }
                    }
                )

                ConnectorRowView(
                    title: "Codex",
                    stateTitle: CodexConnectorSetupCopy.title(for: viewModel.codexConnectorState),
                    detail: viewModel.codexConnectorStatusMessage,
                    trustMessage: ConnectorConsentCopy.codex,
                    actionTitle: codexActionTitle(for: viewModel.codexConnectorState),
                    isWorking: viewModel.codexConnectorState == .checking,
                    isEnabled: viewModel.settings.connectors.codex.isEnabled,
                    canDisconnect: viewModel.settings.connectors.codex.isEnabled
                        || viewModel.snapshots.contains(where: CachedProviderID.codex.snapshotPredicate),
                    onEnabledChange: { enabled in
                        let viewModel = self.viewModel
                        Task { await viewModel.setConnector(.codex, enabled: enabled) }
                    },
                    onDisconnect: {
                        let viewModel = self.viewModel
                        Task { await viewModel.disconnect(.codex) }
                    },
                    action: {
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
    }
}
