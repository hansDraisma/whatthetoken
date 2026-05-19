import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct AppSettingsTests {
    @Test func defaultsKeepConnectorsAndAutoRefreshDisabled() {
        let settings = AppSettings.defaults

        #expect(settings.schemaVersion == 2)
        #expect(settings.connectors.claudeCode.isEnabled == false)
        #expect(settings.connectors.claudeCode.isPaused == false)
        #expect(settings.connectors.codex.isEnabled == false)
        #expect(settings.connectors.codex.isPaused == false)
        #expect(settings.refresh.autoRefreshEnabled == false)
        #expect(settings.refresh.intervalSeconds == 300)
        #expect(settings.notifications.isEnabled == false)
        #expect(settings.notifications.warningThreshold == 0.20)
        #expect(settings.notifications.criticalThreshold == 0.10)
        #expect(settings.notifications.providerAlerts.claudeCode.isEnabled == true)
        #expect(settings.notifications.providerAlerts.codex.isEnabled == true)
        #expect(settings.launchAtLogin.isEnabled == false)
        #expect(settings.menuBar.displayMode == .statusIcon)
    }

    @Test func decodesV1SettingsAndMigratesDefaultLowThresholdToWarningTwentyPercent() throws {
        let json = """
        {
          "schemaVersion" : 1,
          "connectors" : {
            "claudeCode" : { "isEnabled" : true },
            "codex" : { "isEnabled" : false }
          },
          "refresh" : {
            "autoRefreshEnabled" : true,
            "intervalSeconds" : 600
          },
          "notifications" : {
            "isEnabled" : true,
            "lowThreshold" : 0.3,
            "criticalThreshold" : 0.1
          },
          "menuBar" : {
            "displayMode" : "statusIcon"
          }
        }
        """.data(using: .utf8)!

        let decoded = try AppSettings.decodeValidated(from: json)

        #expect(decoded.schemaVersion == 2)
        #expect(decoded.connectors.claudeCode.isEnabled == true)
        #expect(decoded.connectors.claudeCode.isPaused == false)
        #expect(decoded.connectors.codex.isEnabled == false)
        #expect(decoded.refresh.autoRefreshEnabled == false)
        #expect(decoded.refresh.intervalSeconds == 600)
        #expect(decoded.notifications.isEnabled == true)
        #expect(decoded.notifications.warningThreshold == 0.20)
        #expect(decoded.notifications.criticalThreshold == 0.10)
        #expect(decoded.notifications.providerAlerts.claudeCode.isEnabled == true)
        #expect(decoded.notifications.providerAlerts.codex.isEnabled == true)
        #expect(decoded.launchAtLogin.isEnabled == false)
    }

    @Test func decodesV1SettingsAndPreservesCustomLowThresholdAsWarningThreshold() throws {
        let json = """
        {
          "schemaVersion" : 1,
          "connectors" : {
            "claudeCode" : { "isEnabled" : true },
            "codex" : { "isEnabled" : true }
          },
          "refresh" : {
            "autoRefreshEnabled" : false,
            "intervalSeconds" : 300
          },
          "notifications" : {
            "isEnabled" : true,
            "lowThreshold" : 0.25,
            "criticalThreshold" : 0.08
          },
          "menuBar" : {
            "displayMode" : "statusIcon"
          }
        }
        """.data(using: .utf8)!

        let decoded = try AppSettings.decodeValidated(from: json)

        #expect(decoded.notifications.warningThreshold == 0.25)
        #expect(decoded.notifications.criticalThreshold == 0.08)
        #expect(decoded.notifications.providerAlerts.claudeCode.isEnabled == true)
        #expect(decoded.notifications.providerAlerts.codex.isEnabled == true)
    }

    @Test func unknownFutureSchemaVersionThrowsUnsupportedSchemaVersion() {
        let data = #"{"schemaVersion":999}"#.data(using: .utf8)!

        do {
            _ = try AppSettings.decodeValidated(from: data)
            Issue.record("Expected unsupported schema version")
        } catch AppSettingsDecodeError.unsupportedSchemaVersion(let version) {
            #expect(version == 999)
        } catch {
            Issue.record("Expected unsupported schema version, got \(error)")
        }
    }

    @Test func roundTripPreservesSettings() throws {
        var settings = AppSettings.defaults
        settings.connectors.claudeCode.isEnabled = true
        settings.refresh.autoRefreshEnabled = true
        settings.refresh.intervalSeconds = 600
        settings.launchAtLogin.isEnabled = true

        let data = try JSONEncoder().encode(settings)
        let decoded = try AppSettings.decodeValidated(from: data)

        #expect(decoded == settings)
    }

    @Test func unknownSchemaVersionFallsBackThroughStoreLoad() async {
        let data = #"{"schemaVersion":999}"#.data(using: .utf8)!
        let store = InMemoryAppSettingsStore(data: data)

        let loaded = await store.load()

        #expect(loaded == .defaults)
    }

    @Test func invalidJSONFallsBackThroughStoreLoad() async {
        let store = InMemoryAppSettingsStore(data: Data("not json".utf8))

        let loaded = await store.load()

        #expect(loaded == .defaults)
    }

    @Test func decodeIgnoresMalformedHotkeySubstruct() throws {
        let json = """
        {
          "schemaVersion": 2,
          "connectors": {
            "claudeCode": { "isEnabled": false, "isPaused": false },
            "codex": { "isEnabled": false, "isPaused": false }
          },
          "refresh": { "autoRefreshEnabled": false, "intervalSeconds": 300 },
          "notifications": {
            "isEnabled": false,
            "warningThreshold": 0.2,
            "criticalThreshold": 0.1,
            "providerAlerts": {
              "claudeCode": { "isEnabled": true },
              "codex": { "isEnabled": true }
            }
          },
          "launchAtLogin": { "isEnabled": false },
          "menuBar": { "displayMode": "statusIcon" },
          "hotkey": { "keyCode": "not-a-number" }
        }
        """.data(using: .utf8)!

        let decoded = try AppSettings.decodeValidated(from: json)

        #expect(decoded.hotkey == .default)
    }

    @Test func decodeLogsMalformedHotkeySubstructFallback() throws {
        let logger = RecordingTestLogger()
        let json = """
        {
          "schemaVersion": 2,
          "connectors": {
            "claudeCode": { "isEnabled": false, "isPaused": false },
            "codex": { "isEnabled": false, "isPaused": false }
          },
          "refresh": { "autoRefreshEnabled": false, "intervalSeconds": 300 },
          "notifications": {
            "isEnabled": false,
            "warningThreshold": 0.2,
            "criticalThreshold": 0.1,
            "providerAlerts": {
              "claudeCode": { "isEnabled": true },
              "codex": { "isEnabled": true }
            }
          },
          "launchAtLogin": { "isEnabled": false },
          "menuBar": { "displayMode": "statusIcon" },
          "hotkey": { "keyCode": "not-a-number" }
        }
        """.data(using: .utf8)!

        _ = try AppSettings.decodeValidated(from: json, logger: logger)

        #expect(logger.messages.contains { $0.contains("settings.hotkey") })
        #expect(logger.messages.contains { $0.contains("using default") })
    }

    @Test func storeLogsMalformedSettingsSubstructFallback() async throws {
        let logger = RecordingTestLogger()
        let json = """
        {
          "schemaVersion": 2,
          "connectors": {
            "claudeCode": { "isEnabled": false, "isPaused": false },
            "codex": { "isEnabled": false, "isPaused": false }
          },
          "refresh": { "autoRefreshEnabled": false, "intervalSeconds": 300 },
          "notifications": {
            "isEnabled": false,
            "warningThreshold": 0.2,
            "criticalThreshold": 0.1,
            "providerAlerts": {
              "claudeCode": { "isEnabled": true },
              "codex": { "isEnabled": true }
            }
          },
          "launchAtLogin": { "isEnabled": false },
          "menuBar": { "displayMode": "statusIcon" },
          "appearance": { "showInDock": "not-a-bool" }
        }
        """.data(using: .utf8)!
        let store = InMemoryAppSettingsStore(data: json, logger: logger)

        _ = await store.load()

        #expect(logger.messages.contains { $0.contains("settings.appearance") })
    }

    @Test func decodeIgnoresMalformedAppearanceSubstruct() throws {
        let json = """
        {
          "schemaVersion": 2,
          "connectors": {
            "claudeCode": { "isEnabled": false, "isPaused": false },
            "codex": { "isEnabled": false, "isPaused": false }
          },
          "refresh": { "autoRefreshEnabled": false, "intervalSeconds": 300 },
          "notifications": {
            "isEnabled": false,
            "warningThreshold": 0.2,
            "criticalThreshold": 0.1,
            "providerAlerts": {
              "claudeCode": { "isEnabled": true },
              "codex": { "isEnabled": true }
            }
          },
          "launchAtLogin": { "isEnabled": false },
          "menuBar": { "displayMode": "statusIcon" },
          "appearance": ["not", "an", "object"]
        }
        """.data(using: .utf8)!

        let decoded = try AppSettings.decodeValidated(from: json)

        #expect(decoded.appearance == .default)
    }

    @Test func encodedSettingsDoNotContainSensitiveKeys() throws {
        var settings = AppSettings.defaults
        settings.connectors.codex.isEnabled = true

        let data = try JSONEncoder().encode(settings)
        let json = String(decoding: data, as: UTF8.self)

        #expect(!json.contains("token"))
        #expect(!json.contains("cookie"))
        #expect(!json.contains("authHeader"))
        #expect(!json.contains("session"))
        #expect(!json.contains("prompt"))
        #expect(!json.contains("response"))
    }

    @Test func decodingOldSchemaDefaultsLaunchAtLogin() throws {
        let json = """
        {
          "schemaVersion": 1,
          "connectors": {
            "claudeCode": { "isEnabled": true },
            "codex": { "isEnabled": false }
          },
          "refresh": { "autoRefreshEnabled": true, "intervalSeconds": 600 },
          "notifications": { "isEnabled": false, "lowThreshold": 0.3, "criticalThreshold": 0.1 },
          "menuBar": { "displayMode": "statusIcon" }
        }
        """.data(using: .utf8)!

        let decoded = try AppSettings.decodeValidated(from: json)

        #expect(decoded.connectors.claudeCode.isEnabled)
        #expect(decoded.refresh.autoRefreshEnabled == false)
        #expect(decoded.launchAtLogin.isEnabled == false)
    }

    @Test func memoryStorePersistsLatestValue() async {
        let store = InMemoryAppSettingsStore()
        var settings = AppSettings.defaults
        settings.connectors.claudeCode.isEnabled = true

        await store.save(settings)
        let loaded = await store.load()

        #expect(loaded.connectors.claudeCode.isEnabled == true)
    }

    @Test func defaultsAddNewSubstructuresWithFreshUserState() {
        let s = AppSettings.defaults

        #expect(s.appearance.showInDock == true)
        #expect(s.hotkey.combination == HotkeyCombination.default)
        #expect(s.onboarding.firstLaunchCompleted == false)
        #expect(s.onboarding.steps.connectProviders == .pending)
    }

    @Test func decodesV2PayloadWithoutNewKeysAsExistingUser() throws {
        let json = """
        {
          "schemaVersion" : 2,
          "connectors" : {
            "claudeCode" : { "isEnabled" : true,  "isPaused" : false },
            "codex"      : { "isEnabled" : false, "isPaused" : false }
          },
          "refresh" : { "autoRefreshEnabled" : false, "intervalSeconds" : 300 },
          "notifications" : {
            "isEnabled" : true,
            "warningThreshold" : 0.20,
            "criticalThreshold" : 0.10,
            "providerAlerts" : {
              "claudeCode" : { "isEnabled" : true },
              "codex"      : { "isEnabled" : true }
            }
          },
          "launchAtLogin" : { "isEnabled" : false },
          "menuBar" : { "displayMode" : "statusIcon" }
        }
        """.data(using: .utf8)!

        let decoded = try AppSettings.decodeValidated(from: json)

        #expect(decoded.appearance == AppearanceSettings.default)
        #expect(decoded.hotkey == HotkeySettings.default)
        #expect(decoded.onboarding.firstLaunchCompleted == true)
        #expect(decoded.onboarding.steps.connectProviders == .skipped)
    }

    @Test func decodesV2PayloadWithAllNewKeysPreservesValues() throws {
        let json = """
        {
          "schemaVersion" : 2,
          "connectors" : {
            "claudeCode" : { "isEnabled" : true,  "isPaused" : false },
            "codex"      : { "isEnabled" : false, "isPaused" : false }
          },
          "refresh" : { "autoRefreshEnabled" : false, "intervalSeconds" : 300 },
          "notifications" : {
            "isEnabled" : false,
            "warningThreshold" : 0.20,
            "criticalThreshold" : 0.10,
            "providerAlerts" : {
              "claudeCode" : { "isEnabled" : true },
              "codex"      : { "isEnabled" : true }
            }
          },
          "launchAtLogin" : { "isEnabled" : true },
          "menuBar" : { "displayMode" : "statusIcon" },
          "appearance" : { "showInDock" : false },
          "hotkey" : {
            "combination" : { "modifiers" : { "rawValue" : 1 }, "keyCode" : 17 }
          },
          "onboarding" : {
            "firstLaunchCompleted" : true,
            "steps" : {
              "connectProviders" : "done",
              "findMenuBar" : "skipped",
              "addWidget" : "done",
              "allowNotifications" : "pending",
              "setHotkey" : "done",
              "launchAtLogin" : "skipped"
            }
          }
        }
        """.data(using: .utf8)!

        let decoded = try AppSettings.decodeValidated(from: json)

        #expect(decoded.appearance.showInDock == false)
        #expect(decoded.hotkey.combination.modifiers == [.command])
        #expect(decoded.onboarding.firstLaunchCompleted == true)
        #expect(decoded.onboarding.steps.addWidget == .done)
        #expect(decoded.onboarding.steps.findMenuBar == .skipped)
    }

    @Test func v1MigrationDefaultsNewSubstructuresAsExistingUser() throws {
        let json = """
        {
          "schemaVersion" : 1,
          "connectors" : {
            "claudeCode" : { "isEnabled" : true },
            "codex"      : { "isEnabled" : false }
          },
          "refresh" : { "autoRefreshEnabled" : true, "intervalSeconds" : 600 },
          "notifications" : {
            "isEnabled" : true,
            "lowThreshold" : 0.30,
            "criticalThreshold" : 0.10
          },
          "menuBar" : { "displayMode" : "statusIcon" }
        }
        """.data(using: .utf8)!

        let decoded = try AppSettings.decodeValidated(from: json)

        #expect(decoded.schemaVersion == 2)
        #expect(decoded.appearance == AppearanceSettings.default)
        #expect(decoded.hotkey == HotkeySettings.default)
        #expect(decoded.onboarding.firstLaunchCompleted == true)
    }
}
