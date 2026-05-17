import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct StatusTabBannerVisibilityTests {
    @Test func bannerVisibleWhenAnyStepPending() {
        let state = OnboardingState(stepStates: .allPending)
        #expect(StatusTabBannerVisibility.shouldShow(state: state) == true)
    }

    @Test func bannerHiddenWhenAllStepsAreFinal() {
        var states = OnboardingStepStates.allPending
        states.connectProviders = .done
        states.findMenuBar = .skipped
        states.addWidget = .done
        states.allowNotifications = .skipped
        states.setHotkey = .skipped
        states.launchAtLogin = .done
        let state = OnboardingState(stepStates: states)

        #expect(StatusTabBannerVisibility.shouldShow(state: state) == false)
    }
}
