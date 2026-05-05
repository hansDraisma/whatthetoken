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

            VStack(alignment: .leading, spacing: 8) {
                Text(CodexConnectorSetupCopy.title(for: viewModel.codexConnectorState))
                    .font(.headline)

                Text(CodexConnectorSetupCopy.trustMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    Task {
                        await viewModel.connectCodex()
                    }
                } label: {
                    Label("Connect Codex", systemImage: "link")
                }
                .disabled(viewModel.codexConnectorState == .checking)
            }

            Divider()

            if viewModel.snapshots.isEmpty {
                Text("No usage signal")
                    .font(.headline)
                    .padding()
            } else {
                ForEach(viewModel.snapshotSections) { section in
                    StatusSectionView(snapshots: section.snapshots)
                }
            }
        }
        .padding()
    }
}
