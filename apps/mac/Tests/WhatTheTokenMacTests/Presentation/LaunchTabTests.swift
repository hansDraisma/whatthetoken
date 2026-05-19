import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct LaunchTabTests {
    @Test func tabsAreInSidebarOrder() {
        #expect(LaunchTab.allCases == [.status, .connectors, .notifications, .tools, .about])
    }

    @Test func tabsHaveExpectedTitlesAndSymbols() {
        #expect(LaunchTab.status.title == "Status")
        #expect(LaunchTab.status.systemImage == "gauge.with.dots.needle.bottom.50percent")
        #expect(LaunchTab.connectors.title == "Connectors")
        #expect(LaunchTab.connectors.systemImage == "powerplug")
        #expect(LaunchTab.notifications.title == "Notifications")
        #expect(LaunchTab.notifications.systemImage == "bell")
        #expect(LaunchTab.tools.title == "Tools")
        #expect(LaunchTab.tools.systemImage == "wrench.and.screwdriver")
        #expect(LaunchTab.about.title == "About")
        #expect(LaunchTab.about.systemImage == "info.circle")
    }

    @Test func statusTabDisconnectedProviderActionNavigatesToConnectors() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let launchRoot = try String(
            contentsOf: root.appendingPathComponent("Sources/WhatTheTokenMac/Views/Launch/LaunchWindowRootView.swift"),
            encoding: .utf8
        )
        let statusTab = try String(
            contentsOf: root.appendingPathComponent("Sources/WhatTheTokenMac/Views/Launch/StatusTabView.swift"),
            encoding: .utf8
        )

        #expect(launchRoot.contains("StatusTabView(viewModel: viewModel, onOpenConnectors: { selection = .connectors })"))
        #expect(statusTab.contains("let onOpenConnectors: () -> Void"))
        #expect(statusTab.contains("onOpenSettings: onOpenConnectors"))
    }
}
