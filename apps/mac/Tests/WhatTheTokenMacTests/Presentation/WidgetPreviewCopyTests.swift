import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct WidgetPreviewCopyTests {
    @Test func connectedRowFormatsPercentage() {
        let copy = WidgetPreviewCopy.row(for: WidgetRow(provider: .claude, state: .connected(percentage: 47)))

        #expect(copy.providerLabel == "Claude")
        #expect(copy.valueLabel == "47%")
        #expect(copy.isConnected == true)
    }

    @Test func notConnectedRowSaysSo() {
        let copy = WidgetPreviewCopy.row(for: WidgetRow(provider: .codex, state: .notConnected))

        #expect(copy.providerLabel == "Codex")
        #expect(copy.valueLabel == "Not connected")
        #expect(copy.isConnected == false)
    }

    @Test func bothDisconnectedShowsEmptyStateCopy() {
        let entry = WidgetEntry(
            rows: [
                WidgetRow(provider: .claude, state: .notConnected),
                WidgetRow(provider: .codex, state: .notConnected)
            ],
            isStale: false,
            asOf: .now
        )

        let copy = WidgetPreviewCopy.emptyState(for: entry)

        #expect(copy?.title == "No providers connected")
        #expect(copy?.hint == "Open the app to connect Claude or Codex.")
    }

    @Test func providerPillAppearanceUsesPaletteFillAndOutline() {
        let connected = WidgetPreviewCopy.pillAppearance(isConnected: true)
        let disconnected = WidgetPreviewCopy.pillAppearance(isConnected: false)

        #expect(connected.fillColorName == "systemGreen")
        #expect(disconnected.fillColorName == "controlBackgroundColor")
        #expect(connected.outlineColorName == "labelColor")
        #expect(disconnected.outlineColorName == "labelColor")
    }

    @Test func staleEntryReportsStaleness() {
        let entry = WidgetEntry(
            rows: [WidgetRow(provider: .claude, state: .connected(percentage: 10))],
            isStale: true,
            asOf: .now
        )
        let copy = WidgetPreviewCopy.staleBadge(for: entry)

        #expect(copy == "Stale")
    }

    @Test func emptyStateSuppressesStaleness() {
        let entry = WidgetEntry(
            rows: [
                WidgetRow(provider: .claude, state: .notConnected),
                WidgetRow(provider: .codex, state: .notConnected)
            ],
            isStale: true,
            asOf: .distantPast
        )

        #expect(WidgetPreviewCopy.emptyState(for: entry) != nil)
        #expect(WidgetPreviewCopy.staleBadge(for: entry) == nil)
    }

    @Test func widgetPreviewRowExposesCombinedAccessibilityLabel() {
        let label = WidgetPreviewCopy.rowAccessibilityLabel(provider: "Claude", percent: 47, connected: true)

        #expect(label == "Claude, 47 percent remaining")
    }

    @Test func widgetPreviewRowExposesDisconnectedLabel() {
        let label = WidgetPreviewCopy.rowAccessibilityLabel(provider: "Codex", percent: 0, connected: false)

        #expect(label == "Codex, not connected")
    }

    @Test func emptyStateTextClampsDynamicTypeLikeRows() throws {
        let source = try launchSourceContents("WidgetPreviewView.swift")

        #expect(source.contains("Text(emptyState.title)\n                    .font(.caption.weight(.semibold))\n                    .dynamicTypeSize(...DynamicTypeSize.xxLarge)"))
        #expect(source.contains("Text(emptyState.hint)\n                    .font(.caption2)\n                    .dynamicTypeSize(...DynamicTypeSize.xxLarge)"))
    }

    private func launchSourceContents(_ name: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/WhatTheTokenMac/Views/Launch/\(name)")
        return try String(contentsOf: url, encoding: .utf8)
    }
}
