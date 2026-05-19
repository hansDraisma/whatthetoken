import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct HotkeySettingsTests {
    @Test func defaultMatchesHotkeyCombinationDefault() {
        #expect(HotkeySettings.default.combination == HotkeyCombination.default)
    }

    @Test func codingRoundtrip() throws {
        let s = HotkeySettings(combination: HotkeyCombination(modifiers: [.command], keyCode: 17))
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(HotkeySettings.self, from: data)
        #expect(decoded == s)
    }
}
