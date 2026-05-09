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

    @Test func memoryStorePersistsLatestValue() async {
        let store = InMemoryAppSettingsStore()
        var settings = AppSettings.defaults
        settings.connectors.claudeCode.isEnabled = true

        await store.save(settings)
        let loaded = await store.load()

        #expect(loaded.connectors.claudeCode.isEnabled == true)
    }
}
