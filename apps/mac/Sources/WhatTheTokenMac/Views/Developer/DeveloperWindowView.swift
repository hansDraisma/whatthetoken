#if DEBUG
import SwiftUI

struct DeveloperWindowView: View {
    let viewModel: StatusViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Build: DEBUG | Bundle: \(Bundle.main.bundleIdentifier ?? "?") | macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                providerSection(
                    title: "Claude Code",
                    state: "\(viewModel.connectorState)",
                    message: viewModel.connectorStatusMessage,
                    timestamp: viewModel.lastClaudeRefreshAt,
                    action: {
                        let viewModel = self.viewModel
                        Task { await viewModel.connectClaudeCode() }
                    }
                )

                providerSection(
                    title: "Codex",
                    state: "\(viewModel.codexConnectorState)",
                    message: viewModel.codexConnectorStatusMessage,
                    timestamp: viewModel.lastCodexRefreshAt,
                    action: {
                        let viewModel = self.viewModel
                        Task { await viewModel.connectCodex() }
                    }
                )

                globalSection
                snapshotsSection
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 600, minHeight: 480)
    }

    private func providerSection(
        title: String,
        state: String,
        message: String,
        timestamp: Date?,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            keyValueRow("setupState", state)
            keyValueRow("connectorStatusMessage", message)
            keyValueRow("lastRefreshAt", timestamp.map { "\($0)" } ?? "nil")
            Button("Refresh now", action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(12)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var globalSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Global")
                .font(.headline)
            keyValueRow("isRefreshAllInFlight", "\(viewModel.isRefreshAllInFlight)")
            keyValueRow("isAnyRefreshing", "\(viewModel.isAnyRefreshing)")
            keyValueRow("lastUpdatedAt (min)", viewModel.lastUpdatedAt.map { "\($0)" } ?? "nil")
            Button("Refresh all") {
                let viewModel = self.viewModel
                Task { await viewModel.refreshAll(reason: .manual) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var snapshotsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Snapshots (\(viewModel.snapshots.count))")
                .font(.headline)
            ForEach(viewModel.snapshots, id: \.id) { snapshot in
                Text(jsonString(for: snapshot))
                    .font(.system(.caption2, design: .monospaced))
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func keyValueRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
        }
    }

    private func jsonString(for snapshot: UsageSnapshot) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(snapshot), let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "<encoding failed>"
    }
}
#endif
