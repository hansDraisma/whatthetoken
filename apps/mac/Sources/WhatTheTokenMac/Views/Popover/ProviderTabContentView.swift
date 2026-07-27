import SwiftUI

struct ProviderTabContentView: View {
    let model: ProviderTabModel
    let onOpenConnectors: () -> Void
    let onConnect: () -> Void
    let onRetry: () -> Void
    let onRefresh: () -> Void
    let canCheckForUpdates: Bool
    let onCheckForUpdates: () -> Void

    var body: some View {
        switch model.body {
        case let .connected(snapshots, _, isRefreshing):
            VStack(spacing: 0) {
                refreshProgressLine(isVisible: isRefreshing)
                StatusSectionView(snapshots: snapshots)
            }
        case .empty:
            empty
        case .loading:
            checking
        case let .disconnected(reason):
            disconnected(reason: reason)
        case let .error(kind, lastSnapshots, isRefreshing):
            VStack(spacing: 0) {
                refreshProgressLine(isVisible: isRefreshing)
                errorBody(kind: kind, lastSnapshots: lastSnapshots)
            }
        }
    }

    @ViewBuilder
    private func refreshProgressLine(isVisible: Bool) -> some View {
        if isVisible {
            ProgressView()
                .progressViewStyle(.linear)
                .controlSize(.small)
                .frame(height: 2)
                .padding(.horizontal, 12)
                .accessibilityLabel("Updating values")
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Text("Connected - no usage data yet")
                .font(.callout)
            Button("Refresh now", action: onRefresh)
                .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    private var checking: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text("Refreshing...")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    private func disconnected(reason: ProviderTabModel.DisconnectedReason) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.copy.headline)
                .font(.headline)
            Text(model.copy.advice)
                .font(.caption)
                .foregroundStyle(.secondary)
            recoveryActions
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func errorBody(kind: ProviderTabModel.ErrorKind, lastSnapshots: [UsageSnapshot]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(errorHeadline(kind: kind))
                .font(.headline)
            if !model.copy.advice.isEmpty {
                Text(model.copy.advice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !lastSnapshots.isEmpty {
                StatusSectionView(snapshots: lastSnapshots)
                    .opacity(0.6)
            }
            recoveryActions
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var recoveryActions: some View {
        if let action = model.copy.recovery.primaryAction(for: model.tab) {
            Button(action.title) {
                perform(action)
            }
            .buttonStyle(.borderedProminent)
            .disabled(action == .checkForUpdates && !canCheckForUpdates)

            Button("Open Connectors", action: onOpenConnectors)
                .buttonStyle(.link)
        }
    }

    private func perform(_ action: ConnectorPrimaryAction) {
        switch action {
        case .connect:
            onConnect()
        case .retry:
            onRetry()
        case .checkForUpdates:
            onCheckForUpdates()
        }
    }

    private func errorHeadline(kind: ProviderTabModel.ErrorKind) -> String {
        _ = kind
        return model.copy.headline
    }
}
