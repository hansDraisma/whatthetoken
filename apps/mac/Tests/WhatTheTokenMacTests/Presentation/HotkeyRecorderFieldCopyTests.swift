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

    @Test func recorderCancelsOnEscapeKeycode() {
        var cancelled = false
        let policy = HotkeyRecorderEventPolicy(onCancel: { cancelled = true })

        policy.handle(keyCode: 53, modifierFlags: [])

        #expect(cancelled)
    }

    @MainActor
    @Test func recorderCancelsOnItsWindowFocusLoss() {
        var cancelled = false
        let recorderWindow = NSWindow()
        let otherWindow = NSWindow()
        let policy = HotkeyRecorderEventPolicy(recordingWindow: recorderWindow, onCancel: { cancelled = true })

        policy.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification, object: otherWindow))
        #expect(!cancelled)

        policy.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification, object: recorderWindow))

        #expect(cancelled)
    }

    @Test func keyCodeDisplayCoversLettersArrowsAndFunctionKeys() {
        #expect(HotkeyRecorderCopy.keyCodeDisplay(0) == "A")
        #expect(HotkeyRecorderCopy.keyCodeDisplay(17) == "T")
        #expect(HotkeyRecorderCopy.keyCodeDisplay(123) == "←")
        #expect(HotkeyRecorderCopy.keyCodeDisplay(124) == "→")
        #expect(HotkeyRecorderCopy.keyCodeDisplay(122) == "F1")
    }
}
