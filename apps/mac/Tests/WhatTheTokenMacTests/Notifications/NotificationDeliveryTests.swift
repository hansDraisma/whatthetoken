import Testing
@testable import WhatTheTokenMac

@Suite struct NotificationDeliveryTests {
    @Test func recordingDeliveryRequestsPermissionOnlyWhenAsked() async {
        let delivery = RecordingNotificationDelivery(permissionResult: .granted)

        #expect(await delivery.authorizationStatus() == .notDetermined)
        #expect(await delivery.requestAuthorization() == .granted)
        #expect(await delivery.authorizationStatus() == .granted)
    }

    @Test func recordingDeliveryRecordsDeliveredIntents() async {
        let delivery = RecordingNotificationDelivery(permissionResult: .granted)
        let intent = NotificationIntent(
            id: "test",
            provider: .claude,
            level: .warning,
            title: "Claude Code is below 20% remaining",
            body: "Claude Code is below 20% remaining. Verified from local Claude Code usage status."
        )

        await delivery.deliver([intent])

        #expect(await delivery.deliveredIntents == [intent])
    }

    @Test func userNotificationDeliveryFailsClosedWhenNotificationCenterIsUnavailable() async {
        let delivery = UserNotificationDelivery(isNotificationCenterAvailable: { false })
        let intent = NotificationIntent(
            id: "test",
            provider: .claude,
            level: .warning,
            title: "Claude Code is below 20% remaining",
            body: "Claude Code is below 20% remaining. Verified from local Claude Code usage status."
        )

        #expect(await delivery.authorizationStatus() == .denied)
        #expect(await delivery.requestAuthorization() == .denied)
        await delivery.deliver([intent])
    }
}
