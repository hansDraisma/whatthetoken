import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct GlobalHotkeyServiceTests {
    @MainActor
    @Test func registerRejectsCombinationWithoutModifiers() {
        let service = GlobalHotkeyService(registrar: SpyRegistrar())
        let invalid = HotkeyCombination(modifiers: [], keyCode: 17)

        let result = service.register(combination: invalid, onTrigger: { })

        #expect(result == .invalidCombination)
    }

    @MainActor
    @Test func invalidReplacementUnregistersExistingHotkey() {
        let registrar = SpyRegistrar()
        let service = GlobalHotkeyService(registrar: registrar)

        _ = service.register(combination: .default, onTrigger: { })
        let result = service.register(
            combination: HotkeyCombination(modifiers: [], keyCode: 17),
            onTrigger: { }
        )

        #expect(result == .invalidCombination)
        #expect(registrar.unregisterCount == 1)
    }

    @MainActor
    @Test func registerCallsRegistrarWithCarbonModifierMask() {
        let registrar = SpyRegistrar()
        let service = GlobalHotkeyService(registrar: registrar)
        let combo = HotkeyCombination(modifiers: [.control, .option], keyCode: 17)

        let result = service.register(combination: combo, onTrigger: { })

        #expect(result == .registered)
        #expect(registrar.lastKeyCode == 17)
        #expect(registrar.lastModifierMask == 0x1800) // control 0x1000 | option 0x0800
    }

    @MainActor
    @Test func registerReportsFailureWhenRegistrarFails() {
        let registrar = SpyRegistrar()
        registrar.shouldFail = true
        let service = GlobalHotkeyService(registrar: registrar)

        let result = service.register(combination: .default, onTrigger: { })

        #expect(result == .failed)
    }

    @MainActor
    @Test func unregisterCallsRegistrarUnregister() {
        let registrar = SpyRegistrar()
        let service = GlobalHotkeyService(registrar: registrar)

        _ = service.register(combination: .default, onTrigger: { })
        service.unregister()

        #expect(registrar.unregisterCount == 1)
    }

    @Test func carbonRegistrarDocumentsDeinitThreadSafetyAssumption() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/WhatTheTokenMac/Hotkey/GlobalHotkeyService.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("Carbon event hot key cleanup APIs are safe to call from deinit"))
    }
}

@MainActor
final class SpyRegistrar: HotkeyRegistering {
    var lastKeyCode: UInt32?
    var lastModifierMask: UInt32?
    var shouldFail = false
    var unregisterCount = 0

    func register(keyCode: UInt32, modifierMask: UInt32, onTrigger: @escaping () -> Void) -> Bool {
        lastKeyCode = keyCode
        lastModifierMask = modifierMask
        return !shouldFail
    }

    func unregister() { unregisterCount += 1 }
}
