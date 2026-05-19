import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct MacChromeActionTests {
    @MainActor
    @Test func openSettingsDismissesPopoverBeforeActivatingAndOpeningScene() {
        let recorder = ChromeActionRecorder()

        MacChromeActions.openSettings(
            dismissPopover: { recorder.record("dismissPopover") },
            activate: { recorder.record("activate") },
            openSettings: { recorder.record("openSettings") }
        )

        #expect(recorder.calls == ["dismissPopover", "activate", "openSettings"])
    }

    @MainActor
    @Test func showAboutActivatesBeforeShowingPanel() {
        let recorder = ChromeActionRecorder()

        MacChromeActions.showAbout(
            activate: { recorder.record("activate") },
            showAbout: { recorder.record("showAbout") }
        )

        #expect(recorder.calls == ["activate", "showAbout"])
    }

    @MainActor
    @Test func openDeveloperWindowActivatesBeforeOpeningWindow() {
        let recorder = ChromeActionRecorder()

        MacChromeActions.openDeveloperWindow(
            activate: { recorder.record("activate") },
            openWindow: { recorder.record("openWindow") }
        )

        #expect(recorder.calls == ["activate", "openWindow"])
    }

    @MainActor
    @Test func openLaunchWindowDismissesPopoverActivatesAndOpens() {
        let recorder = ChromeActionRecorder()

        MacChromeActions.openLaunchWindow(
            dismissPopover: { recorder.record("dismissPopover") },
            activate: { recorder.record("activate") },
            openWindow: { recorder.record("openWindow") }
        )

        #expect(recorder.calls == ["dismissPopover", "activate", "openWindow"])
    }

    @Test func appScenesDoesNotContainSettingsScene() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/WhatTheTokenMac/WhatTheTokenApp.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(!source.contains("Settings("))
        #expect(!source.contains("Settings {"))
        #expect(source.contains("CommandGroup(replacing: .appSettings)"))
        #expect(source.contains("MacChromeActions.openLaunchWindow("))
        #expect(source.contains("dismissPopover:"))
        #expect(source.contains("openWindow:"))
        #expect(source.contains("app?.launchWindowController.open()"))
    }

    @Test func defaultDismissPopoverUsesExplicitMenuBarPopoverIdentifier() throws {
        let chromeActions = try sourceContents("MacChromeActions.swift")
        let menuBarController = try sourceContents("MenuBar/MenuBarController.swift")

        #expect(chromeActions.contains("key.identifier == .whatTheTokenMenuBarPopover"))
        #expect(!chromeActions.contains("key.title.isEmpty"))
        #expect(menuBarController.contains("window?.identifier = .whatTheTokenMenuBarPopover"))
    }

    private func sourceContents(_ relativePath: String) throws -> String {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/WhatTheTokenMac/\(relativePath)")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}

@MainActor
private final class ChromeActionRecorder {
    private(set) var calls: [String] = []

    func record(_ call: String) {
        calls.append(call)
    }
}
