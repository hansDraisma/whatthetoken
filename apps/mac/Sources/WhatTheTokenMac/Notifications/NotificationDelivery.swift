import Foundation
import UserNotifications

enum NotificationAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case denied
    case granted
}

protocol NotificationDelivery: Sendable {
    func authorizationStatus() async -> NotificationAuthorizationStatus
    func requestAuthorization() async -> NotificationAuthorizationStatus
    func deliver(_ intents: [NotificationIntent]) async
}

actor RecordingNotificationDelivery: NotificationDelivery {
    private let permissionResult: NotificationAuthorizationStatus
    private var status: NotificationAuthorizationStatus = .notDetermined
    private var storedDeliveredIntents: [NotificationIntent] = []

    init(permissionResult: NotificationAuthorizationStatus) {
        self.permissionResult = permissionResult
    }

    var deliveredIntents: [NotificationIntent] {
        storedDeliveredIntents
    }

    func authorizationStatus() async -> NotificationAuthorizationStatus {
        status
    }

    func requestAuthorization() async -> NotificationAuthorizationStatus {
        status = permissionResult
        return status
    }

    func deliver(_ intents: [NotificationIntent]) async {
        storedDeliveredIntents.append(contentsOf: intents)
    }
}

struct UserNotificationDelivery: NotificationDelivery {
    func authorizationStatus() async -> NotificationAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .granted
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    func requestAuthorization() async -> NotificationAuthorizationStatus {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            return granted ? .granted : .denied
        } catch {
            return .denied
        }
    }

    func deliver(_ intents: [NotificationIntent]) async {
        for intent in intents {
            let content = UNMutableNotificationContent()
            content.title = intent.title
            content.body = intent.body
            content.sound = .default
            let request = UNNotificationRequest(identifier: intent.id, content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}
