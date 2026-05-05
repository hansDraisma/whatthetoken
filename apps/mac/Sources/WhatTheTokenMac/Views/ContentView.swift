import SwiftUI

struct ContentView: View {
    let viewModel: StatusViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(ClaudeConnectorSetupCopy.title(for: viewModel.connectorState))
                    .font(.headline)

                Text(ClaudeConnectorSetupCopy.trustMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    Task {
                        await viewModel.connectClaudeCode()
                    }
                } label: {
                    Label("Connect Claude Code", systemImage: "link")
                }
                .disabled(viewModel.connectorState == .checking)
            }

            Divider()

            if viewModel.snapshots.isEmpty {
                Text("No usage signal")
                    .font(.headline)
                    .padding()
            } else {
                StatusSectionView(snapshots: viewModel.snapshots)
            }
        }
        .padding()
    }
}
