import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct OnboardingStateTests {
    @Test func freshStateHighlightsConnectProviders() {
        let state = OnboardingState(stepStates: .allPending)
        #expect(state.nextStep == .connectProviders)
        #expect(state.bannerDismissable == false)
    }

    @Test func nextSkipsCompletedAndSkippedSteps() {
        var states = OnboardingStepStates.allPending
        states.connectProviders = .done
        states.findMenuBar = .skipped

        let state = OnboardingState(stepStates: states)
        #expect(state.nextStep == .addWidget)
    }

    @Test func bannerDismissableWhenEveryStepIsFinal() {
        var states = OnboardingStepStates.allPending
        states.connectProviders = .done
        states.findMenuBar = .skipped
        states.addWidget = .done
        states.allowNotifications = .skipped
        states.setHotkey = .done
        states.launchAtLogin = .done

        let state = OnboardingState(stepStates: states)
        #expect(state.nextStep == nil)
        #expect(state.bannerDismissable == true)
    }

    @Test func progressCountReflectsDoneAndSkipped() {
        var states = OnboardingStepStates.allPending
        states.connectProviders = .done
        states.addWidget = .skipped
        states.setHotkey = .done

        let state = OnboardingState(stepStates: states)
        #expect(state.completedCount == 3)
        #expect(state.totalCount == 6)
    }

    @Test func skipAllMarksRemainingPendingAsSkipped() {
        var states = OnboardingStepStates.allPending
        states.connectProviders = .done

        let updated = OnboardingState.applySkipAll(to: states)
        #expect(updated.connectProviders == .done)
        #expect(updated.findMenuBar == .skipped)
        #expect(updated.addWidget == .skipped)
        #expect(updated.allowNotifications == .skipped)
        #expect(updated.setHotkey == .skipped)
        #expect(updated.launchAtLogin == .skipped)
    }

    @Test func replayResetsAllStepsToPending() {
        var states = OnboardingStepStates.allPending
        states.connectProviders = .done
        states.addWidget = .skipped

        let reset = OnboardingState.applyReplay(to: states)
        #expect(reset == .allPending)
    }
}
