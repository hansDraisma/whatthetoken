import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct HotkeyCombinationTests {
    @Test func defaultCombinationIsControlOptionT() {
        let combo = HotkeyCombination.default

        #expect(combo.modifiers == [.control, .option])
        #expect(combo.keyCode == 17) // kVK_ANSI_T
    }

    @Test func codingRoundtrip() throws {
        let combo = HotkeyCombination(modifiers: [.command, .shift], keyCode: 17)
        let data = try JSONEncoder().encode(combo)
        let decoded = try JSONDecoder().decode(HotkeyCombination.self, from: data)

        #expect(decoded == combo)
    }

    @Test func rejectsNoModifiers() {
        let combo = HotkeyCombination(modifiers: [], keyCode: 17)

        #expect(combo.isValidForGlobalRegistration == false)
    }

    @Test func acceptsAtLeastOneModifierPlusKey() {
        let combo = HotkeyCombination(modifiers: [.option], keyCode: 17)

        #expect(combo.isValidForGlobalRegistration == true)
    }

    @Test func cmdQIsRejectedAsReserved() {
        let combo = HotkeyCombination(modifiers: [.command], keyCode: 12)

        #expect(combo.isValidForGlobalRegistration == false)
    }

    @Test func shiftOnlyComboIsRejected() {
        let combo = HotkeyCombination(modifiers: [.shift], keyCode: 17)

        #expect(combo.isValidForGlobalRegistration == false)
    }

    @Test func cmdShiftTIsAccepted() {
        let combo = HotkeyCombination(modifiers: [.command, .shift], keyCode: 17)

        #expect(combo.isValidForGlobalRegistration == true)
    }
}
