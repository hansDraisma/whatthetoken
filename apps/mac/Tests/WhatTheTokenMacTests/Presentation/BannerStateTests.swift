import Testing
@testable import WhatTheTokenMac

@Suite struct BannerStateTests {
    @Test func criticalCarriesText() {
        let state = BannerState.critical(text: "Claude Code is out of usable quota")
        if case let .critical(text) = state {
            #expect(text == "Claude Code is out of usable quota")
        } else {
            Issue.record("Expected .critical case")
        }
    }

    @Test func bannerCopyForCriticalProvider_codex() {
        #expect(BannerCopy.critical(provider: .codex) == "Codex is out of usable quota")
    }

    @Test func bannerCopyForLowProvider_claude() {
        #expect(BannerCopy.low(provider: .claude) == "Claude Code included usage is running low")
    }

    @Test func bannerCopyForCriticalLowFallbackProvider_codex() {
        #expect(BannerCopy.criticalLowFallback(provider: .codex) == "Codex included usage is critically low. Extra credits available.")
    }

    @Test func bannerCopyForFallbackOnlyProvider_claude() {
        #expect(BannerCopy.fallbackOnly(provider: .claude) == "Claude Code included usage is exhausted. Extra credits available.")
    }

    @Test func bannerCopyForStale_isProviderAgnostic() {
        #expect(BannerCopy.stale == "Usage may be outdated. Refresh to check current limits.")
    }

    @Test func bannerCopyForDisconnectedSelected_codex() {
        #expect(BannerCopy.disconnected(selected: .codex) == "Codex is not connected. Open Settings to connect.")
    }

    @Test func bannerCopyForDisconnectedBoth_isBroad() {
        #expect(BannerCopy.disconnectedBoth == "Connect Claude or Codex in Settings.")
    }

    @Test func bannerCopyHintForOtherHealthy_codex() {
        #expect(BannerCopy.hint(otherHealthy: .codex) == "Codex has more room — consider switching new work.")
    }

    @MainActor
    @Test func banner_disconnectedSelected_codex_yieldsDisconnected() {
        let vm = StatusViewModel(snapshots: [], connectorState: .connected, codexConnectorState: .notConnected)
        let banner = BannerState.from(viewModel: vm, selected: .codex)
        #expect(banner == .disconnected(text: "Codex is not connected. Open Settings to connect."))
    }

    @MainActor
    @Test func banner_bothDisconnected_broadensCopy() {
        let vm = StatusViewModel(snapshots: [], connectorState: .notConnected, codexConnectorState: .notConnected)
        let banner = BannerState.from(viewModel: vm, selected: .codex)
        #expect(banner == .disconnected(text: "Connect Claude or Codex in Settings."))
    }

    @MainActor
    @Test func banner_networkError_yieldsStale() {
        let vm = StatusViewModel(snapshots: [], connectorState: .connected, codexConnectorState: .networkError)
        let banner = BannerState.from(viewModel: vm, selected: .codex)
        #expect(banner == .stale(text: BannerCopy.stale))
    }

    @MainActor
    @Test func banner_claudeSessionExpired_isHiddenBecauseBodyCarriesRecovery() {
        let vm = StatusViewModel(
            snapshots: [UsageSnapshotFixture.claudeSample()],
            connectorState: .sessionExpired
        )

        #expect(BannerState.from(viewModel: vm, selected: .claude) == .hidden)
    }

    @MainActor
    @Test func banner_claudeRateLimited_isHiddenBecauseBodyCarriesRecovery() {
        let vm = StatusViewModel(
            snapshots: [UsageSnapshotFixture.claudeSample()],
            connectorState: .rateLimited
        )

        #expect(BannerState.from(viewModel: vm, selected: .claude) == .hidden)
    }

    @MainActor
    @Test func banner_connectedHealthy_yieldsHidden() {
        let snap = UsageSnapshotFixture.claudeIncludedSample(remaining: 62, utilization: 0.38)
        let vm = StatusViewModel(snapshots: [snap], connectorState: .connected)
        let banner = BannerState.from(viewModel: vm, selected: .claude)
        #expect(banner == .hidden)
    }

    @MainActor
    @Test func banner_emptyBody_isHidden() {
        let vm = StatusViewModel(snapshots: [], connectorState: .connected)
        let banner = BannerState.from(viewModel: vm, selected: .claude)
        #expect(banner == .hidden)
    }

    @MainActor
    @Test func banner_checkingBody_isHidden() {
        let vm = StatusViewModel(snapshots: [], connectorState: .checking)
        let banner = BannerState.from(viewModel: vm, selected: .claude)
        #expect(banner == .hidden)
    }

    @MainActor
    @Test func banner_critical_yieldsCritical() {
        let snap = UsageSnapshotFixture.claudeIncludedSample(remaining: 5, utilization: 0.95)
        let vm = StatusViewModel(snapshots: [snap], connectorState: .connected)
        let banner = BannerState.from(viewModel: vm, selected: .claude)
        if case .critical = banner { } else { Issue.record("Expected .critical") }
    }

    @MainActor
    @Test func banner_low_yieldsLow() {
        let snap = UsageSnapshotFixture.claudeIncludedSample(remaining: 20, utilization: 0.80)
        let vm = StatusViewModel(snapshots: [snap], connectorState: .connected)
        let banner = BannerState.from(viewModel: vm, selected: .claude)
        if case .low = banner { } else { Issue.record("Expected .low") }
    }

    @MainActor
    @Test func banner_empty_yieldsCriticalNotHidden() {
        let snap = UsageSnapshotFixture.claudeIncludedSample(remaining: 0, utilization: 1.0)
        let vm = StatusViewModel(snapshots: [snap], connectorState: .connected)
        let banner = BannerState.from(viewModel: vm, selected: .claude)
        if case .critical = banner { } else { Issue.record("Expected .critical for 0% remaining") }
    }

    @MainActor
    @Test func banner_connectedWithStaleReason_yieldsStale_overridingWorst() {
        let snap = UsageSnapshotFixture.claudeStaleSample()
        let vm = StatusViewModel(snapshots: [snap], connectorState: .connected)
        let banner = BannerState.from(viewModel: vm, selected: .claude)
        if case let .stale(text) = banner {
            #expect(text == BannerCopy.stale)
        } else {
            Issue.record("Expected .stale when snapshot has staleReason")
        }
    }

    @MainActor
    @Test func banner_critical_appendsHint_whenOtherIsHealthy() {
        let claudeCrit = UsageSnapshotFixture.claudeIncludedSample(remaining: 5, utilization: 0.95)
        let codexHealthy = UsageSnapshotFixture.codexIncludedSample(remaining: 75, utilization: 0.25)
        let vm = StatusViewModel(
            snapshots: [claudeCrit, codexHealthy],
            connectorState: .connected,
            codexConnectorState: .connected
        )
        let banner = BannerState.from(viewModel: vm, selected: .claude)
        if case let .critical(text) = banner {
            #expect(text.contains("Codex has more room"))
        } else {
            Issue.record("Expected .critical with hint")
        }
    }

    @MainActor
    @Test func banner_critical_doesNotAppendHint_whenOtherIsAlsoCritical() {
        let claudeCrit = UsageSnapshotFixture.claudeIncludedSample(remaining: 5, utilization: 0.95)
        let codexCrit = UsageSnapshotFixture.codexIncludedSample(remaining: 5, utilization: 0.95)
        let vm = StatusViewModel(
            snapshots: [claudeCrit, codexCrit],
            connectorState: .connected,
            codexConnectorState: .connected
        )
        let banner = BannerState.from(viewModel: vm, selected: .claude)
        if case let .critical(text) = banner {
            #expect(!text.contains("more room"))
        } else {
            Issue.record("Expected .critical")
        }
    }

    @MainActor
    @Test func banner_critical_doesNotAppendHint_whenOtherIsDisconnected() {
        let claudeCrit = UsageSnapshotFixture.claudeIncludedSample(remaining: 5, utilization: 0.95)
        let vm = StatusViewModel(
            snapshots: [claudeCrit],
            connectorState: .connected,
            codexConnectorState: .notConnected
        )
        let banner = BannerState.from(viewModel: vm, selected: .claude)
        if case let .critical(text) = banner {
            #expect(!text.contains("more room"))
        } else {
            Issue.record("Expected .critical")
        }
    }

    @MainActor
    @Test func banner_claudeIncludedHealthyAndExtraCreditsZero_isHidden() {
        let snapshots = [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 62, utilization: 0.38),
            UsageSnapshotFixture.claudeCreditsSample(remaining: 0)
        ]
        let vm = StatusViewModel(snapshots: snapshots, connectorState: .connected)
        let banner = BannerState.from(viewModel: vm, selected: .claude)
        #expect(banner == .hidden)
    }

    @MainActor
    @Test func banner_codexIncludedHealthyAndCreditsZero_isHidden() {
        let snapshots = [
            UsageSnapshotFixture.codexIncludedSample(remaining: 75, utilization: 0.25),
            UsageSnapshotFixture.codexCreditsSample(remaining: 0)
        ]
        let vm = StatusViewModel(snapshots: snapshots, codexConnectorState: .connected)
        let banner = BannerState.from(viewModel: vm, selected: .codex)
        #expect(banner == .hidden)
    }

    @MainActor
    @Test func banner_includedEmptyAndCreditsPositive_isFallbackOnlyCopy() {
        let snapshots = [
            UsageSnapshotFixture.codexIncludedSample(remaining: 0, utilization: 1.0),
            UsageSnapshotFixture.codexCreditsSample(remaining: 25)
        ]
        let vm = StatusViewModel(snapshots: snapshots, codexConnectorState: .connected)
        let banner = BannerState.from(viewModel: vm, selected: .codex)
        #expect(banner == .low(text: "Codex included usage is exhausted. Extra credits available."))
    }

    @MainActor
    @Test func banner_includedCriticalAndCreditsPositive_isCriticalWithFallbackCopy() {
        let snapshots = [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 5, utilization: 0.95),
            UsageSnapshotFixture.claudeCreditsSample(remaining: 20)
        ]
        let vm = StatusViewModel(snapshots: snapshots, connectorState: .connected)
        let banner = BannerState.from(viewModel: vm, selected: .claude)
        #expect(banner == .low(text: "Claude Code included usage is critically low. Extra credits available."))
    }

    @MainActor
    @Test func banner_includedEmptyAndCreditsZero_isCritical() {
        let snapshots = [
            UsageSnapshotFixture.codexIncludedSample(remaining: 0, utilization: 1.0),
            UsageSnapshotFixture.codexCreditsSample(remaining: 0)
        ]
        let vm = StatusViewModel(snapshots: snapshots, codexConnectorState: .connected)
        let banner = BannerState.from(viewModel: vm, selected: .codex)
        #expect(banner == .critical(text: "Codex is out of usable quota"))
    }

    @MainActor
    @Test func banner_fallbackOnly_doesNotAppendCrossProviderHint_evenWhenOtherIsHealthy() {
        let claudeFallbackOnly = [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 0, utilization: 1.0),
            UsageSnapshotFixture.claudeCreditsSample(remaining: 20)
        ]
        let codexHealthy = UsageSnapshotFixture.codexIncludedSample(remaining: 75, utilization: 0.25)
        let vm = StatusViewModel(
            snapshots: claudeFallbackOnly + [codexHealthy],
            connectorState: .connected,
            codexConnectorState: .connected
        )
        let banner = BannerState.from(viewModel: vm, selected: .claude)
        if case let .low(text) = banner {
            #expect(!text.contains("more room"))
        } else {
            Issue.record("Expected .low")
        }
    }

    @MainActor
    @Test func banner_criticalWithFallback_doesNotAppendHint_evenWhenOtherIsHealthy() {
        let claudeCriticalWithFallback = [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 5, utilization: 0.95),
            UsageSnapshotFixture.claudeCreditsSample(remaining: 20)
        ]
        let codexHealthy = UsageSnapshotFixture.codexIncludedSample(remaining: 75, utilization: 0.25)
        let vm = StatusViewModel(
            snapshots: claudeCriticalWithFallback + [codexHealthy],
            connectorState: .connected,
            codexConnectorState: .connected
        )
        let banner = BannerState.from(viewModel: vm, selected: .claude)
        if case let .low(text) = banner {
            #expect(!text.contains("more room"))
        } else {
            Issue.record("Expected .low")
        }
    }

    @MainActor
    @Test func banner_low_appendsHint_whenOtherIsHealthy() {
        let claudeLow = UsageSnapshotFixture.claudeIncludedSample(remaining: 20, utilization: 0.80)
        let codexHealthy = UsageSnapshotFixture.codexIncludedSample(remaining: 75, utilization: 0.25)
        let vm = StatusViewModel(
            snapshots: [claudeLow, codexHealthy],
            connectorState: .connected,
            codexConnectorState: .connected
        )
        let banner = BannerState.from(viewModel: vm, selected: .claude)
        if case let .low(text) = banner {
            #expect(text.contains("Codex has more room"))
        } else {
            Issue.record("Expected .low with hint")
        }
    }
}
