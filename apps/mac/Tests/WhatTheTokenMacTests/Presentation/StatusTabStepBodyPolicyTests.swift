import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct StatusTabStepBodyPolicyTests {
    @Test func providerStepCompletesOnlyWhenProviderBecomesConnectedWhilePending() {
        #expect(StatusTabStepBodyPolicy.shouldMarkConnectProvidersDone(anyProviderConnected: true, currentState: .pending) == true)
        #expect(StatusTabStepBodyPolicy.shouldMarkConnectProvidersDone(anyProviderConnected: false, currentState: .pending) == false)
        #expect(StatusTabStepBodyPolicy.shouldMarkConnectProvidersDone(anyProviderConnected: true, currentState: .skipped) == false)
    }

    @Test func notificationStepCompletesOnlyWhenAuthorizationGranted() {
        #expect(StatusTabStepBodyPolicy.shouldMarkNotificationsDone(status: .granted) == true)
        #expect(StatusTabStepBodyPolicy.shouldMarkNotificationsDone(status: .denied) == false)
        #expect(StatusTabStepBodyPolicy.shouldMarkNotificationsDone(status: .notDetermined) == false)
    }

    @Test func hotkeyStepCompletesOnlyWhenThereIsNoWarning() {
        #expect(StatusTabStepBodyPolicy.shouldMarkHotkeyDone(warning: nil) == true)
        #expect(StatusTabStepBodyPolicy.shouldMarkHotkeyDone(warning: "Could not register this hotkey") == false)
    }

    @Test func hotkeyWarningBannerShowsOnlyWhenWarningExists() {
        #expect(StatusTabHotkeyWarningBanner.message(from: nil) == nil)
        #expect(StatusTabHotkeyWarningBanner.message(from: "Could not register this hotkey") == "Could not register this hotkey")
    }

    @Test func launchAtLoginStepCompletesOnlyOnSuccess() {
        #expect(StatusTabStepBodyPolicy.shouldMarkLaunchAtLoginDone(success: true) == true)
        #expect(StatusTabStepBodyPolicy.shouldMarkLaunchAtLoginDone(success: false) == false)
    }
}
