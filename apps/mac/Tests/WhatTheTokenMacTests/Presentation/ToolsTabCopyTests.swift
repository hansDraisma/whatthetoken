import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct ToolsTabCopyTests {
    @Test func sectionTitlesMatchExpectedTools() {
        #expect(ToolsTabCopy.appearanceSection == "Appearance")
        #expect(ToolsTabCopy.hotkeySection == "Global hotkey")
        #expect(ToolsTabCopy.launchAtLoginSection == "Launch at login")
        #expect(ToolsTabCopy.widgetSection == "Desktop widget")
        #expect(ToolsTabCopy.onboardingSection == "Onboarding")
    }

    @Test func actionTitlesMatchExpectedTools() {
        #expect(ToolsTabCopy.replayOnboardingTitle == "Replay onboarding")
        #expect(ToolsTabCopy.pulseMenuBarIconTitle == "Pulse the menu bar icon")
    }
}
