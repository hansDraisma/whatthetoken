import Foundation

struct AppSettings: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int
    var connectors: ConnectorSettings
    var refresh: RefreshSettings
    var notifications: NotificationSettings
    var menuBar: MenuBarSettings

    static let defaults = AppSettings(
        schemaVersion: currentSchemaVersion,
        connectors: ConnectorSettings(
            claudeCode: ConnectorConsentSettings(isEnabled: false, isPaused: false),
            codex: ConnectorConsentSettings(isEnabled: false, isPaused: false)
        ),
        refresh: RefreshSettings(autoRefreshEnabled: false, intervalSeconds: 300),
        notifications: NotificationSettings(
            isEnabled: false,
            warningThreshold: 0.20,
            criticalThreshold: 0.10,
            providerAlerts: ProviderAlertSettings(
                claudeCode: ProviderAlertToggle(isEnabled: true),
                codex: ProviderAlertToggle(isEnabled: true)
            )
        ),
        menuBar: MenuBarSettings(displayMode: .statusIcon)
    )

    static func decodeValidated(from data: Data) throws -> AppSettings {
        let envelope = try JSONDecoder().decode(SettingsVersionEnvelope.self, from: data)
        switch envelope.schemaVersion {
        case currentSchemaVersion:
            return try JSONDecoder().decode(AppSettings.self, from: data)
        case 1:
            return try migrateV1(from: data)
        default:
            throw AppSettingsDecodeError.unsupportedSchemaVersion(envelope.schemaVersion)
        }
    }

    private static func migrateV1(from data: Data) throws -> AppSettings {
        let v1 = try JSONDecoder().decode(AppSettingsV1.self, from: data)
        let warningThreshold = abs(v1.notifications.lowThreshold - 0.30) < 0.000_001
            ? 0.20
            : v1.notifications.lowThreshold
        return AppSettings(
            schemaVersion: currentSchemaVersion,
            connectors: ConnectorSettings(
                claudeCode: ConnectorConsentSettings(isEnabled: v1.connectors.claudeCode.isEnabled, isPaused: false),
                codex: ConnectorConsentSettings(isEnabled: v1.connectors.codex.isEnabled, isPaused: false)
            ),
            refresh: RefreshSettings(autoRefreshEnabled: false, intervalSeconds: v1.refresh.intervalSeconds),
            notifications: NotificationSettings(
                isEnabled: v1.notifications.isEnabled,
                warningThreshold: warningThreshold,
                criticalThreshold: v1.notifications.criticalThreshold,
                providerAlerts: ProviderAlertSettings(
                    claudeCode: ProviderAlertToggle(isEnabled: true),
                    codex: ProviderAlertToggle(isEnabled: true)
                )
            ),
            menuBar: v1.menuBar
        )
    }
}

private struct SettingsVersionEnvelope: Decodable {
    let schemaVersion: Int
}

private struct AppSettingsV1: Decodable {
    let schemaVersion: Int
    let connectors: ConnectorSettingsV1
    let refresh: RefreshSettings
    let notifications: NotificationSettingsV1
    let menuBar: MenuBarSettings
}

private struct ConnectorSettingsV1: Decodable {
    let claudeCode: ConnectorConsentSettingsV1
    let codex: ConnectorConsentSettingsV1
}

private struct ConnectorConsentSettingsV1: Decodable {
    let isEnabled: Bool
}

private struct NotificationSettingsV1: Decodable {
    let isEnabled: Bool
    let lowThreshold: Double
    let criticalThreshold: Double
}

struct ConnectorSettings: Codable, Equatable, Sendable {
    var claudeCode: ConnectorConsentSettings
    var codex: ConnectorConsentSettings
}

struct ConnectorConsentSettings: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var isPaused: Bool
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
    var warningThreshold: Double
    var criticalThreshold: Double
    var providerAlerts: ProviderAlertSettings
}

struct ProviderAlertSettings: Codable, Equatable, Sendable {
    var claudeCode: ProviderAlertToggle
    var codex: ProviderAlertToggle

    func isEnabled(for provider: CachedProviderID) -> Bool {
        switch provider {
        case .claude: return claudeCode.isEnabled
        case .codex: return codex.isEnabled
        }
    }
}

struct ProviderAlertToggle: Codable, Equatable, Sendable {
    var isEnabled: Bool
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
