import Testing
@testable import WhatTheTokenMac

@Suite struct ProviderTabModelTests {
    @Test func bodyEquatable_connected() {
        let snap: [UsageSnapshot] = []
        let a = ProviderTabModel.Body.connected(snapshots: snap, worst: .healthy, isRefreshing: true)
        let b = ProviderTabModel.Body.connected(snapshots: snap, worst: .healthy, isRefreshing: true)
        #expect(a == b)
    }

    @Test func disconnectedReasonsAreDistinct() {
        let a = ProviderTabModel.Body.disconnected(reason: .claude(.notConnected))
        let b = ProviderTabModel.Body.disconnected(reason: .claude(.missingCredentials))
        let c = ProviderTabModel.Body.disconnected(reason: .codex(.notConnected))
        #expect(a != b)
        #expect(a != c)
    }

    @Test func errorKindsAreDistinct() {
        let a = ProviderTabModel.Body.error(kind: .network, lastSnapshots: [], isRefreshing: false)
        let b = ProviderTabModel.Body.error(kind: .schemaChanged, lastSnapshots: [], isRefreshing: false)
        #expect(a != b)
    }

    @MainActor
    @Test func claude_notConnected_mapsToDisconnectedNotConnected() {
        let vm = StatusViewModel(snapshots: [], connectorState: .notConnected)
        let model = ProviderTabModel.from(viewModel: vm, tab: .claude)
        #expect(model.body == .disconnected(reason: .claude(.notConnected)))
    }

    @MainActor
    @Test func claude_checkingWithNoSnapshots_mapsToLoading() {
        let vm = StatusViewModel(snapshots: [], connectorState: .checking)
        let model = ProviderTabModel.from(viewModel: vm, tab: .claude)
        #expect(model.body == .loading)
    }

    @MainActor
    @Test func claude_checkingWithSnapshots_keepsRowsVisibleAndMarksRefreshing() {
        let snapshots = [UsageSnapshotFixture.claudeSample()]
        let vm = StatusViewModel(snapshots: snapshots, connectorState: .checking)
        let model = ProviderTabModel.from(viewModel: vm, tab: .claude)
        #expect(model.body == .connected(snapshots: snapshots, worst: .healthy, isRefreshing: true))
    }

    @MainActor
    @Test func claude_connectedWithSnapshots_mapsToConnectedWithWorst() {
        let vm = StatusViewModel(snapshots: [UsageSnapshotFixture.claudeSample()], connectorState: .connected)
        let model = ProviderTabModel.from(viewModel: vm, tab: .claude)
        if case let .connected(snapshots, worst, isRefreshing) = model.body {
            #expect(snapshots.count == 1)
            #expect(worst == .healthy)
            #expect(isRefreshing == false)
        } else {
            Issue.record("Expected .connected body")
        }
    }

    @MainActor
    @Test func claude_connectedWithoutSnapshots_mapsToEmpty() {
        let vm = StatusViewModel(snapshots: [], connectorState: .connected)
        let model = ProviderTabModel.from(viewModel: vm, tab: .claude)
        #expect(model.body == .empty)
    }

    @MainActor
    @Test func claude_missingClaudeCli_mapsToDisconnectedMissingCLI() {
        let vm = StatusViewModel(snapshots: [], connectorState: .missingClaudeCli)
        let model = ProviderTabModel.from(viewModel: vm, tab: .claude)
        #expect(model.body == .disconnected(reason: .claude(.missingCLI)))
    }

    @MainActor
    @Test func claude_missingCredentials_mapsToDisconnected() {
        let vm = StatusViewModel(snapshots: [], connectorState: .missingCredentials)
        let model = ProviderTabModel.from(viewModel: vm, tab: .claude)
        #expect(model.body == .disconnected(reason: .claude(.missingCredentials)))
    }

    @MainActor
    @Test func claude_tokenInvalid_mapsToDisconnected() {
        let vm = StatusViewModel(snapshots: [], connectorState: .tokenInvalid)
        let model = ProviderTabModel.from(viewModel: vm, tab: .claude)
        #expect(model.body == .disconnected(reason: .claude(.tokenInvalid)))
    }

    @MainActor
    @Test func claude_rateLimited_mapsToDisconnectedRateLimited() {
        let vm = StatusViewModel(snapshots: [], connectorState: .rateLimited)
        let model = ProviderTabModel.from(viewModel: vm, tab: .claude)
        #expect(model.body == .disconnected(reason: .claude(.rateLimited)))
    }

    @MainActor
    @Test func claude_networkError_mapsToErrorNetwork() {
        let cached = [UsageSnapshotFixture.claudeSample()]
        let vm = StatusViewModel(snapshots: cached, connectorState: .networkError)
        let model = ProviderTabModel.from(viewModel: vm, tab: .claude)
        #expect(model.body == .error(kind: .network, lastSnapshots: cached, isRefreshing: false))
    }

    @MainActor
    @Test func claude_schemaChanged_mapsToErrorSchemaChanged() {
        let vm = StatusViewModel(snapshots: [], connectorState: .schemaChanged)
        let model = ProviderTabModel.from(viewModel: vm, tab: .claude)
        #expect(model.body == .error(kind: .schemaChanged, lastSnapshots: [], isRefreshing: false))
    }

    @MainActor
    @Test func codex_notConnected_mapsToDisconnected() {
        let vm = StatusViewModel(snapshots: [], codexConnectorState: .notConnected)
        let model = ProviderTabModel.from(viewModel: vm, tab: .codex)
        #expect(model.body == .disconnected(reason: .codex(.notConnected)))
    }

    @MainActor
    @Test func codex_checkingWithNoSnapshots_mapsToLoading() {
        let vm = StatusViewModel(snapshots: [], codexConnectorState: .checking)
        let model = ProviderTabModel.from(viewModel: vm, tab: .codex)
        #expect(model.body == .loading)
    }

    @MainActor
    @Test func codex_checkingWithSnapshots_keepsRowsVisibleAndMarksRefreshing() {
        let snapshots = [UsageSnapshotFixture.codexSample()]
        let vm = StatusViewModel(snapshots: snapshots, codexConnectorState: .checking)
        let model = ProviderTabModel.from(viewModel: vm, tab: .codex)
        #expect(model.body == .connected(snapshots: snapshots, worst: .healthy, isRefreshing: true))
    }

    @MainActor
    @Test func codex_connectedWithSnapshots_mapsToConnected() {
        let vm = StatusViewModel(snapshots: [UsageSnapshotFixture.codexSample()], codexConnectorState: .connected)
        let model = ProviderTabModel.from(viewModel: vm, tab: .codex)
        if case let .connected(snapshots, _, isRefreshing) = model.body {
            #expect(snapshots.count == 1)
            #expect(isRefreshing == false)
        } else {
            Issue.record("Expected .connected")
        }
    }

    @MainActor
    @Test func codex_connectedWithoutSnapshots_mapsToEmpty() {
        let vm = StatusViewModel(snapshots: [], codexConnectorState: .connected)
        let model = ProviderTabModel.from(viewModel: vm, tab: .codex)
        #expect(model.body == .empty)
    }

    @MainActor
    @Test func codex_missingCredentials_mapsToDisconnected() {
        let vm = StatusViewModel(snapshots: [], codexConnectorState: .missingCredentials)
        let model = ProviderTabModel.from(viewModel: vm, tab: .codex)
        #expect(model.body == .disconnected(reason: .codex(.missingCredentials)))
    }

    @MainActor
    @Test func codex_permissionDenied_mapsToDisconnectedPermissionDenied() {
        let vm = StatusViewModel(snapshots: [], codexConnectorState: .permissionDenied)
        let model = ProviderTabModel.from(viewModel: vm, tab: .codex)
        #expect(model.body == .disconnected(reason: .codex(.permissionDenied)))
    }

    @MainActor
    @Test func codex_networkError_mapsToErrorNetwork() {
        let vm = StatusViewModel(snapshots: [], codexConnectorState: .networkError)
        let model = ProviderTabModel.from(viewModel: vm, tab: .codex)
        #expect(model.body == .error(kind: .network, lastSnapshots: [], isRefreshing: false))
    }

    @MainActor
    @Test func codex_schemaChanged_mapsToErrorSchema() {
        let vm = StatusViewModel(snapshots: [], codexConnectorState: .schemaChanged)
        let model = ProviderTabModel.from(viewModel: vm, tab: .codex)
        #expect(model.body == .error(kind: .schemaChanged, lastSnapshots: [], isRefreshing: false))
    }
}
