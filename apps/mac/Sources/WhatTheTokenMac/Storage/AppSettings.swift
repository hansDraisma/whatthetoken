import Foundation

struct AppSettings: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var connectors: ConnectorSettings
    var refresh: RefreshSettings
    var notifications: NotificationSettings
    var menuBar: MenuBarSettings

    static let defaults = AppSettings(
        schemaVersion: currentSchemaVersion,
        connectors: ConnectorSettings(
            claudeCode: ConnectorConsentSettings(isEnabled: false),
            codex: ConnectorConsentSettings(isEnabled: false)
        ),
        refresh: RefreshSettings(autoRefreshEnabled: false, intervalSeconds: 300),
        notifications: NotificationSettings(isEnabled: false, lowThreshold: 0.30, criticalThreshold: 0.10),
        menuBar: MenuBarSettings(displayMode: .statusIcon)
    )

    static func decodeValidated(from data: Data) throws -> AppSettings {
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        guard decoded.schemaVersion == currentSchemaVersion else {
            throw AppSettingsDecodeError.unsupportedSchemaVersion(decoded.schemaVersion)
        }
        return decoded
    }
}

struct ConnectorSettings: Codable, Equatable, Sendable {
    var claudeCode: ConnectorConsentSettings
    var codex: ConnectorConsentSettings
}

struct ConnectorConsentSettings: Codable, Equatable, Sendable {
    var isEnabled: Bool
}

struct RefreshSettings: Codable, Equatable, Sendable {
    var autoRefreshEnabled: Bool
    var intervalSeconds: Int

    var intervalDuration: Duration {
        .seconds(intervalSeconds)
    }
}

struct NotificationSettings: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var lowThreshold: Double
    var criticalThreshold: Double
}

struct MenuBarSettings: Codable, Equatable, Sendable {
    enum DisplayMode: String, Codable, Equatable, Sendable {
        case statusIcon
    }

    var displayMode: DisplayMode
}

enum AppSettingsDecodeError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
}
