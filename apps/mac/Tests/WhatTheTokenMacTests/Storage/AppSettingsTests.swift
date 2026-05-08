import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct AppSettingsTests {
    @Test func defaultsKeepConnectorsAndAutoRefreshDisabled() {
        let settings = AppSettings.defaults

        #expect(settings.schemaVersion == 1)
        #expect(settings.connectors.claudeCode.isEnabled == false)
        #expect(settings.connectors.codex.isEnabled == false)
        #expect(settings.refresh.autoRefreshEnabled == false)
        #expect(settings.refresh.intervalSeconds == 300)
        #expect(settings.notifications.isEnabled == false)
        #expect(settings.menuBar.displayMode == .statusIcon)
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
