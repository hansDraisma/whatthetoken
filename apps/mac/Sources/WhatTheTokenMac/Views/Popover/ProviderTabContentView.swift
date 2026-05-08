import SwiftUI

struct ProviderTabContentView: View {
    let model: ProviderTabModel
    let onOpenSettings: () -> Void
    let onRetry: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        switch model.body {
        case let .connected(snapshots, _, _):
            StatusSectionView(snapshots: snapshots)
        case .empty:
            empty
        case .loading:
            checking
        case let .disconnected(reason):
            disconnected(reason: reason)
        case let .error(kind, lastSnapshots, _):
            errorBody(kind: kind, lastSnapshots: lastSnapshots)
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
            Text(headline(for: reason))
                .font(.headline)
            Text(detail(for: reason))
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Open Settings", action: onOpenSettings)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func errorBody(kind: ProviderTabModel.ErrorKind, lastSnapshots: [UsageSnapshot]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(errorHeadline(kind: kind))
                .font(.headline)
            if !lastSnapshots.isEmpty {
                StatusSectionView(snapshots: lastSnapshots)
                    .opacity(0.6)
            }
            Button("Retry", action: onRetry)
                .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func headline(for reason: ProviderTabModel.DisconnectedReason) -> String {
        switch (model.tab, reason) {
        case let (.claude, .claude(claudeReason)):
            switch claudeReason {
            case .notConnected:
                return "Claude Code is not connected"
            case .missingCredentials:
                return "Claude Code credentials were not found"
            case .missingCLI:
                return "Claude Code CLI was not found"
            case .tokenInvalid:
                return "Claude Code credentials are invalid"
            case .rateLimited:
                return "Claude usage is rate limited"
            }
        case let (.codex, .codex(codexReason)):
            switch codexReason {
            case .notConnected:
                return "Codex is not connected"
            case .missingCredentials:
                return "Sign in to Codex locally"
            case .permissionDenied:
                return "Codex app-server could not be started"
            }
        case (.claude, .codex), (.codex, .claude):
            assertionFailure("ProviderTabModel invariant violated: tab=\(model.tab) but reason=\(reason); see ProviderTabModel.from mapping in ProviderTabModel.swift")
            return "\(model.tab.title) is unavailable"
        }
    }

    private func detail(for reason: ProviderTabModel.DisconnectedReason) -> String {
        switch model.tab {
        case .claude:
            return "Connect Claude Code in Settings to see remaining usage."
        case .codex:
            return "Connect Codex in Settings to see remaining usage and rate-limit status."
        }
    }

    private func errorHeadline(kind: ProviderTabModel.ErrorKind) -> String {
        switch (model.tab, kind) {
        case (.claude, .network):
            return "Claude Code usage could not be refreshed"
        case (.claude, .schemaChanged):
            return "Claude usage response changed"
        case (.codex, .network):
            return "Codex usage could not be refreshed"
        case (.codex, .schemaChanged):
            return "Codex usage response changed"
        }
    }
}
