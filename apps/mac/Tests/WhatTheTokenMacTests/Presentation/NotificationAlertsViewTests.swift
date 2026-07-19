import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct NotificationAlertsViewTests {
    @Test func deniedSystemPermissionShowsActionableFooter() {
        let message = NotificationAlertsCopy.statusMessage(
            authorizationStatus: .denied,
            notificationsEnabled: false
        )

        #expect(message?.contains("macOS notification permission is denied") == true)
        #expect(message?.contains("System Settings") == true)
    }

    @Test func grantedPermissionConfirmsNotificationsAreEnabled() {
        let message = NotificationAlertsCopy.statusMessage(
            authorizationStatus: .granted,
            notificationsEnabled: true
        )

        #expect(message == "Notifications are enabled.")
        #expect(NotificationAlertsCopy.statusIsSuccess(
            authorizationStatus: .granted,
            notificationsEnabled: true
        ))
    }

    @Test func successfulEnableActionConfirmsImmediately() {
        let message = NotificationAlertsCopy.statusMessage(
            authorizationStatus: nil,
            notificationsEnabled: true,
            updateResult: .enabled
        )

        #expect(message == "Notifications are enabled.")
        #expect(NotificationAlertsCopy.statusIsSuccess(
            authorizationStatus: nil,
            notificationsEnabled: true,
            updateResult: .enabled
        ))
    }

    @Test func settingsSaveFailureIsVisible() {
        let message = NotificationAlertsCopy.statusMessage(
            authorizationStatus: .granted,
            notificationsEnabled: false,
            updateResult: .saveFailed
        )

        #expect(message?.contains("could not save") == true)
        #expect(!NotificationAlertsCopy.statusIsSuccess(
            authorizationStatus: .granted,
            notificationsEnabled: false,
            updateResult: .saveFailed
        ))
    }

    @Test func notificationAlertsViewRefreshesPermissionStatusAfterToggle() throws {
        let source = try settingsSourceContents("NotificationAlertsView.swift")

        #expect(source.contains("refreshAuthorizationStatus()"))
        #expect(source.contains("await viewModel.setNotificationsEnabled(enabled)"))
        #expect(source.contains("await refreshAuthorizationStatus()"))
        #expect(source.contains("isUpdatingNotifications"))
        #expect(source.contains("ProgressView(\"Updating notification settings...\")"))
    }

    @Test func notificationAlertsViewRefreshesPermissionStatusWhenAppBecomesActive() throws {
        let source = try settingsSourceContents("NotificationAlertsView.swift")

        #expect(source.contains("@Environment(\\.scenePhase)"))
        #expect(source.contains(".onChange(of: scenePhase)"))
        #expect(source.contains("if newPhase == .active"))
        #expect(source.contains("await refreshAuthorizationStatus()"))
    }

    private func settingsSourceContents(_ name: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/WhatTheTokenMac/Views/Settings/\(name)")
        return try String(contentsOf: url, encoding: .utf8)
    }
}
