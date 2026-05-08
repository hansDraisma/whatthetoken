import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct PopoverChromeStateTests {
    @MainActor
    @Test func providerSpecificBannerRendersBelowTabs() {
        let claudeLow = UsageSnapshotFixture.claudeIncludedSample(remaining: 20, utilization: 0.80)
        let codexHealthy = UsageSnapshotFixture.codexIncludedSample(remaining: 75, utilization: 0.25)
        let vm = StatusViewModel(
            snapshots: [claudeLow, codexHealthy],
            connectorState: .connected,
            codexConnectorState: .connected
        )

        let chrome = PopoverChromeState.from(viewModel: vm, selected: .claude)

        #expect(chrome.topBanner == .hidden)
        if case let .low(text) = chrome.selectedBanner {
            #expect(text.contains("Claude Code included usage is running low"))
        } else {
            Issue.record("Expected selected provider banner below tabs")
        }
    }

    @MainActor
    @Test func bothDisconnectedBannerRendersAboveTabs() {
        let vm = StatusViewModel(
            snapshots: [],
            connectorState: .notConnected,
            codexConnectorState: .notConnected
        )

        let chrome = PopoverChromeState.from(viewModel: vm, selected: .codex)

        #expect(chrome.topBanner == .disconnected(text: BannerCopy.disconnectedBoth))
        #expect(chrome.selectedBanner == .hidden)
    }

    @MainActor
    @Test func nonSelectedLowProviderGetsTabIndicator() {
        let claudeLow = UsageSnapshotFixture.claudeIncludedSample(remaining: 20, utilization: 0.80)
        let codexHealthy = UsageSnapshotFixture.codexIncludedSample(remaining: 75, utilization: 0.25)
        let vm = StatusViewModel(
            snapshots: [claudeLow, codexHealthy],
            connectorState: .connected,
            codexConnectorState: .connected
        )

        let chrome = PopoverChromeState.from(viewModel: vm, selected: .codex)

        #expect(chrome.selectedBanner == .hidden)
        #expect(chrome.indicators[.claude] == .warning)
        #expect(chrome.indicators[.codex] == ProviderTabIndicator.none)
    }

    @MainActor
    @Test func criticalProviderGetsCriticalTabIndicator() {
        let claudeCritical = UsageSnapshotFixture.claudeIncludedSample(remaining: 0, utilization: 1.0)
        let vm = StatusViewModel(snapshots: [claudeCritical], connectorState: .connected)

        let chrome = PopoverChromeState.from(viewModel: vm, selected: .claude)

        #expect(chrome.indicators[.claude] == .critical)
    }

    @Test func tabAccessibilityLabelsIncludeIndicatorState() {
        #expect(ProviderTabIndicator.none.accessibilityLabel(for: .codex) == "Codex")
        #expect(ProviderTabIndicator.warning.accessibilityLabel(for: .claude) == "Claude Code, running low")
        #expect(ProviderTabIndicator.critical.accessibilityLabel(for: .codex) == "Codex, critical")
        #expect(ProviderTabIndicator.stale.accessibilityLabel(for: .claude) == "Claude Code, usage may be outdated")
        #expect(ProviderTabIndicator.disconnected.accessibilityLabel(for: .codex) == "Codex, disconnected")
    }

    @Test func tabIndicatorHelpTextNamesVisualMarker() {
        #expect(ProviderTabIndicator.none.helpText == nil)
        #expect(ProviderTabIndicator.warning.helpText == "Running low")
        #expect(ProviderTabIndicator.critical.helpText == "Critical")
        #expect(ProviderTabIndicator.stale.helpText == "Usage may be outdated")
        #expect(ProviderTabIndicator.disconnected.helpText == "Disconnected")
    }

    @Test func tabIndicatorsExposeInlineMarkerOnlyForAttentionStates() {
        #expect(ProviderTabIndicator.none.hasInlineMarker == false)
        #expect(ProviderTabIndicator.warning.hasInlineMarker)
        #expect(ProviderTabIndicator.critical.hasInlineMarker)
        #expect(ProviderTabIndicator.stale.hasInlineMarker)
        #expect(ProviderTabIndicator.disconnected.hasInlineMarker)
    }

    @Test func providerTabBarAvoidsNativePickerSoInlineMarkersRender() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let packageRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = packageRoot
            .appendingPathComponent("Sources/WhatTheTokenMac/Views/Popover/ProviderTabBarView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(!source.contains("Picker("))
    }
}
