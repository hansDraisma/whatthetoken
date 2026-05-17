import Foundation
#if canImport(Carbon)
import Carbon.HIToolbox
#endif

enum HotkeyRegistrationResult: Equatable {
    case registered
    case invalidCombination
    case failed
}

@MainActor
protocol HotkeyRegistering: AnyObject {
    func register(keyCode: UInt32, modifierMask: UInt32, onTrigger: @escaping () -> Void) -> Bool
    func unregister()
}

@MainActor
final class GlobalHotkeyService {
    private let registrar: HotkeyRegistering

    init(registrar: HotkeyRegistering) { self.registrar = registrar }

    func register(combination: HotkeyCombination, onTrigger: @escaping () -> Void) -> HotkeyRegistrationResult {
        guard combination.isValidForGlobalRegistration else { return .invalidCombination }
        let mask = Self.carbonModifierMask(for: combination.modifiers)
        return registrar.register(keyCode: combination.keyCode, modifierMask: mask, onTrigger: onTrigger)
            ? .registered : .failed
    }

    func unregister() { registrar.unregister() }

    static func carbonModifierMask(for modifiers: HotkeyCombination.ModifierSet) -> UInt32 {
        var mask: UInt32 = 0
        #if canImport(Carbon)
        if modifiers.contains(.command) { mask |= UInt32(cmdKey) }
        if modifiers.contains(.option)  { mask |= UInt32(optionKey) }
        if modifiers.contains(.control) { mask |= UInt32(controlKey) }
        if modifiers.contains(.shift)   { mask |= UInt32(shiftKey) }
        #else
        if modifiers.contains(.command) { mask |= 0x100 }
        if modifiers.contains(.option)  { mask |= 0x800 }
        if modifiers.contains(.control) { mask |= 0x1000 }
        if modifiers.contains(.shift)   { mask |= 0x200 }
        #endif
        return mask
    }
}

#if canImport(Carbon) && canImport(AppKit)
import AppKit

@MainActor
final class CarbonHotkeyRegistrar: HotkeyRegistering {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var trigger: (() -> Void)?

    func register(keyCode: UInt32, modifierMask: UInt32, onTrigger: @escaping () -> Void) -> Bool {
        unregister()

        let hotKeyID = EventHotKeyID(signature: OSType(0x57544B59), id: 1) // 'WTKY'
        var ref: EventHotKeyRef?
        let registerStatus = RegisterEventHotKey(
            keyCode, modifierMask, hotKeyID, GetApplicationEventTarget(), 0, &ref
        )
        guard registerStatus == noErr, let registeredRef = ref else { return false }
        hotKeyRef = registeredRef
        trigger = onTrigger

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        var handler: EventHandlerRef?
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let userData else { return noErr }
                let registrar = Unmanaged<CarbonHotkeyRegistrar>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in registrar.trigger?() }
                return noErr
            },
            1, &spec, selfPtr, &handler
        )
        if installStatus != noErr {
            UnregisterEventHotKey(registeredRef)
            hotKeyRef = nil
            trigger = nil
            return false
        }
        eventHandler = handler
        return true
    }

    func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let handler = eventHandler { RemoveEventHandler(handler) }
        hotKeyRef = nil
        eventHandler = nil
        trigger = nil
    }
}
#endif
