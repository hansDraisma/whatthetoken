import Foundation
import AppKit
import Testing
@testable import WhatTheTokenMac

@Suite struct AppearanceSettingsTests {
    @Test func defaultEnablesShowInDock() {
        #expect(AppearanceSettings.default.showInDock == true)
    }

    @Test func codingRoundtrip() throws {
        let s = AppearanceSettings(showInDock: false)
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(AppearanceSettings.self, from: data)
        #expect(decoded == s)
    }
}
