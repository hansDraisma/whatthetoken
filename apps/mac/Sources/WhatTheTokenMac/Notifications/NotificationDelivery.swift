import Foundation
import UserNotifications

enum NotificationAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case denied
    case granted
}

enum NotificationSettingsUpdateResult: Equatable, Sendable {
    case enabled
    case disabled
    case permissionDenied
    case saveFailed
}

protocol NotificationDelivery: Sendable {
    func authorizationStatus() async -> NotificationAuthorizationStatus
    func requestAuthorization() async -> NotificationAuthorizationStatus
    func deliver(_ intents: [NotificationIntent]) async
}

actor RecordingNotificationDelivery: NotificationDelivery {
    private let permissionResult: NotificationAuthorizationStatus
    private var status: NotificationAuthorizationStatus = .notDetermined
    private var storedAuthorizationRequestCount = 0
    private var storedDeliveredIntents: [NotificationIntent] = []

    init(permissionResult: NotificationAuthorizationStatus) {
        self.permissionResult = permissionResult
    }

    var deliveredIntents: [NotificationIntent] {
        storedDeliveredIntents
    }

    var authorizationRequestCount: Int {
        storedAuthorizationRequestCount
    }

    func authorizationStatus() async -> NotificationAuthorizationStatus {
        status
    }

    func requestAuthorization() async -> NotificationAuthorizationStatus {
        storedAuthorizationRequestCount += 1
        status = permissionResult
        return status
    }

    func deliver(_ intents: [NotificationIntent]) async {
        storedDeliveredIntents.append(contentsOf: intents)
    }
}

struct UserNotificationDelivery: NotificationDelivery {
    private let isNotificationCenterAvailable: @Sendable () -> Bool

    init(isNotificationCenterAvailable: @escaping @Sendable () -> Bool = UserNotificationDelivery.defaultIsNotificationCenterAvailable) {
        self.isNotificationCenterAvailable = isNotificationCenterAvailable
    }

    @Sendable
    static func defaultIsNotificationCenterAvailable() -> Bool {
        guard Bundle.main.bundleIdentifier != nil else { return false }
        return Bundle.main.bundleURL.pathExtension == "app"
    }

    func authorizationStatus() async -> NotificationAuthorizationStatus {
        guard isNotificationCenterAvailable() else { return .denied }
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
        guard isNotificationCenterAvailable() else { return .denied }
        let currentStatus = await authorizationStatus()
        guard currentStatus == .notDetermined else { return currentStatus }
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            return granted ? .granted : .denied
        } catch {
            notificationsLogger.warning("notification authorization request failed: \(String(describing: error), privacy: .private)")
            return .denied
        }
    }

    func deliver(_ intents: [NotificationIntent]) async {
        guard isNotificationCenterAvailable() else { return }
        for intent in intents {
            let content = UNMutableNotificationContent()
            content.title = intent.title
            content.body = intent.body
            content.sound = .default
            let request = UNNotificationRequest(identifier: intent.id, content: content, trigger: nil)
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                notificationsLogger.error("notification delivery failed for \(intent.id, privacy: .public): \(String(describing: error), privacy: .private)")
            }
        }
    }
}
