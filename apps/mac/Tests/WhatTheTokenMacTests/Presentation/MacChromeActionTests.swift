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
}

@MainActor
private final class ChromeActionRecorder {
    private(set) var calls: [String] = []

    func record(_ call: String) {
        calls.append(call)
    }
}
