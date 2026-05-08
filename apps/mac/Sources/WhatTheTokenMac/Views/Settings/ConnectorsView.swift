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
                    trustMessage: ClaudeConnectorSetupCopy.trustMessage,
                    actionTitle: claudeActionTitle(for: viewModel.connectorState),
                    isWorking: viewModel.connectorState == .checking,
                    action: {
                        let viewModel = self.viewModel
                        Task { await viewModel.connectClaudeCode() }
                    }
                )

                ConnectorRowView(
                    title: "Codex",
                    stateTitle: CodexConnectorSetupCopy.title(for: viewModel.codexConnectorState),
                    detail: viewModel.codexConnectorStatusMessage,
                    trustMessage: CodexConnectorSetupCopy.trustMessage,
                    actionTitle: codexActionTitle(for: viewModel.codexConnectorState),
                    isWorking: viewModel.codexConnectorState == .checking,
                    action: {
                        let viewModel = self.viewModel
                        Task { await viewModel.connectCodex() }
                    }
                )
            }
        }
        .formStyle(.grouped)
    }
}
