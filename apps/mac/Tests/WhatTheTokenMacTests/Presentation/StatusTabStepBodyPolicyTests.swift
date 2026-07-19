import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct StatusTabStepBodyPolicyTests {
    @Test func providerStepCanContinueOnlyAfterAtLeastOneProviderConnects() {
        #expect(StatusTabStepBodyPolicy.canContinueConnectingProviders(anyProviderConnected: true))
        #expect(!StatusTabStepBodyPolicy.canContinueConnectingProviders(anyProviderConnected: false))
    }

    @Test func providerConnectionDoesNotAutomaticallyAdvanceOnboarding() throws {
        let source = try launchSourceContents("StatusTabView.swift")

        #expect(source.contains("Button(StatusTabCopy.continueTitle)"))
        #expect(!source.contains(".onChange(of: anyProviderConnected)"))
    }

    @Test func notificationStepCompletesOnlyWhenNotificationsWereEnabled() {
        #expect(StatusTabStepBodyPolicy.shouldMarkNotificationsDone(result: .enabled) == true)
        #expect(StatusTabStepBodyPolicy.shouldMarkNotificationsDone(result: .permissionDenied) == false)
        #expect(StatusTabStepBodyPolicy.shouldMarkNotificationsDone(result: .saveFailed) == false)
        #expect(StatusTabStepBodyPolicy.shouldMarkNotificationsDone(result: .disabled) == false)
    }

    @Test func notificationStepExplainsDeniedPermissionAndSaveFailures() {
        #expect(StatusTabStepBodyPolicy.notificationActionMessage(result: .permissionDenied)?.contains("System Settings") == true)
        #expect(StatusTabStepBodyPolicy.notificationActionMessage(result: .saveFailed)?.contains("could not save") == true)
        #expect(StatusTabStepBodyPolicy.notificationActionMessage(result: .enabled) == nil)
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
