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
