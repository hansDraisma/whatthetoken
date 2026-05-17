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
}
