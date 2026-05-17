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
}
