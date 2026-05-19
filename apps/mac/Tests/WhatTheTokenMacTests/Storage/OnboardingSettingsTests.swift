import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct OnboardingSettingsTests {
    @Test func freshDefaultHasAllStepsPending() {
        let s = OnboardingSettings.default

        #expect(s.firstLaunchCompleted == false)
        #expect(s.steps.connectProviders == .pending)
        #expect(s.steps.findMenuBar == .pending)
        #expect(s.steps.addWidget == .pending)
        #expect(s.steps.allowNotifications == .pending)
        #expect(s.steps.setHotkey == .pending)
        #expect(s.steps.launchAtLogin == .pending)
    }

    @Test func existingUserMarksFlagComplete() {
        #expect(OnboardingSettings.existingUser.firstLaunchCompleted == true)
    }

    @Test func existingUserHasFinalStepsSoBannerStaysHiddenUntilReplay() {
        let settings = OnboardingSettings.existingUser
        let state = OnboardingState(stepStates: settings.steps)

        #expect(state.bannerDismissable == true)
        #expect(state.nextStep == nil)
    }

    @Test func codingRoundtripPreservesEveryStepState() throws {
        var s = OnboardingSettings.default
        s.firstLaunchCompleted = true
        s.steps.connectProviders = .done
        s.steps.addWidget = .skipped
        s.steps.allowNotifications = .done
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(OnboardingSettings.self, from: data)
        #expect(decoded == s)
    }
}
