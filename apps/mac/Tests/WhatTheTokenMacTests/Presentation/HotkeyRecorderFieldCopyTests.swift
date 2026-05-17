import Foundation
import AppKit
import Testing
@testable import WhatTheTokenMac

@Suite struct HotkeyRecorderFieldCopyTests {
    @Test func defaultComboRendersAsCtrlOptionT() {
        #expect(HotkeyRecorderCopy.display(for: .default) == "⌃⌥T")
    }

    @Test func cmdShiftKRendersWithGlyphs() {
        let combo = HotkeyCombination(modifiers: [.command, .shift], keyCode: 40)

        #expect(HotkeyRecorderCopy.display(for: combo) == "⇧⌘K")
    }

    @Test func decoderRejectsKeyOnlyEventsWithoutModifiers() {
        let result = HotkeyEventDecoder.combination(
            modifierFlags: [],
            keyCode: 17
        )

        #expect(result == nil)
    }

    @Test func decoderAcceptsModifierPlusKey() {
        let result = HotkeyEventDecoder.combination(
            modifierFlags: [.control, .option],
            keyCode: 17
        )

        #expect(result == HotkeyCombination(modifiers: [.control, .option], keyCode: 17))
    }
}
