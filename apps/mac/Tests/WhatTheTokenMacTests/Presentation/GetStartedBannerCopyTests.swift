import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct GetStartedBannerCopyTests {
    @Test func progressLabelShowsDoneOverTotal() {
        let copy = GetStartedBannerCopy(completedCount: 2, totalCount: 6)

        #expect(copy.progressLabel == "2 of 6 done")
    }

    @Test func stepTitlesCoverAllSixSteps() {
        #expect(GetStartedBannerCopy.title(for: .connectProviders) == "Connect your providers")
        #expect(GetStartedBannerCopy.title(for: .findMenuBar) == "Find the menu bar icon")
        #expect(GetStartedBannerCopy.title(for: .addWidget) == "Add the desktop widget")
        #expect(GetStartedBannerCopy.title(for: .allowNotifications) == "Allow notifications")
        #expect(GetStartedBannerCopy.title(for: .setHotkey) == "Set a global hotkey")
        #expect(GetStartedBannerCopy.title(for: .launchAtLogin) == "Launch at login")
    }

    @Test func stepAccessibilityStatusDistinguishesSkippedFromDone() {
        #expect(GetStartedBannerCopy.accessibilityStatus(for: .pending) == "pending")
        #expect(GetStartedBannerCopy.accessibilityStatus(for: .done) == "completed")
        #expect(GetStartedBannerCopy.accessibilityStatus(for: .skipped) == "skipped")
    }

    @Test func getStartedBannerDoesNotUseAnyView() throws {
        let source = try launchSourceContents("GetStartedBanner.swift")

        #expect(!source.contains("AnyView"))
    }

    @Test func statusTabViewDoesNotWrapStepBodiesInAnyView() throws {
        let source = try launchSourceContents("StatusTabView.swift")

        #expect(!source.contains("AnyView("))
    }

    @Test func statusAndToolsTabDoNotShadowHotkeyWarningState() throws {
        let status = try launchSourceContents("StatusTabView.swift")
        let tools = try launchSourceContents("ToolsTabView.swift")

        #expect(!status.contains("@State private var hotkeyWarning"))
        #expect(!tools.contains("@State private var hotkeyWarning"))
    }

    @Test func statusTabStringsAreCentralizedAndBannerRowsAreAccessible() throws {
        let status = try launchSourceContents("StatusTabView.swift")
        let copy = try launchSourceContents("StatusTabCopy.swift")
        let banner = try launchSourceContents("GetStartedBanner.swift")
        let notifications = try launchSourceContents("NotificationsTabView.swift")

        #expect(status.contains("StatusTabCopy."))
        #expect(status.contains(".task"))
        #expect(status.contains("reconcileOnboardingFromSystemState()"))
        #expect(copy.contains("enum StatusTabCopy"))
        #expect(banner.contains("@AccessibilityFocusState"))
        #expect(banner.contains(".accessibilityElement(children: .combine)"))
        #expect(banner.contains(".accessibilityHidden(true)"))
        #expect(!notifications.contains("isEnabled == false"))
    }

    @Test func bannerCombinesOnlyStepHeaderAccessibility() throws {
        let banner = try launchSourceContents("GetStartedBanner.swift")

        #expect(banner.contains("StepHeader("))
        #expect(banner.contains("private struct StepHeader"))
        #expect(banner.contains("expandedBody()"))
        #expect(!banner.contains("expandedBody()\n                    .padding(.leading, 26)\n            }\n        }\n        .padding(.vertical, 6)\n        .accessibilityElement(children: .combine)"))
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
