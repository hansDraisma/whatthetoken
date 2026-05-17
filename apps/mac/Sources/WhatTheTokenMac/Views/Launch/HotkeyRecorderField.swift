import SwiftUI
import AppKit

enum HotkeyRecorderCopy {
    static func display(for combination: HotkeyCombination) -> String {
        var s = ""
        if combination.modifiers.contains(.control) { s += "⌃" }
        if combination.modifiers.contains(.option) { s += "⌥" }
        if combination.modifiers.contains(.shift) { s += "⇧" }
        if combination.modifiers.contains(.command) { s += "⌘" }
        s += keyCodeDisplay(combination.keyCode)
        return s
    }

    static func keyCodeDisplay(_ keyCode: UInt32) -> String {
        switch keyCode {
        case 0: return "A"
        case 8: return "C"
        case 9: return "V"
        case 17: return "T"
        case 37: return "L"
        case 40: return "K"
        default: return "?"
        }
    }
}

enum HotkeyEventDecoder {
    static func combination(
        modifierFlags: NSEvent.ModifierFlags,
        keyCode: UInt32
    ) -> HotkeyCombination? {
        var modifiers: HotkeyCombination.ModifierSet = []
        if modifierFlags.contains(.command) { modifiers.insert(.command) }
        if modifierFlags.contains(.option) { modifiers.insert(.option) }
        if modifierFlags.contains(.control) { modifiers.insert(.control) }
        if modifierFlags.contains(.shift) { modifiers.insert(.shift) }
        let combo = HotkeyCombination(modifiers: modifiers, keyCode: keyCode)
        return combo.isValidForGlobalRegistration ? combo : nil
    }
}

struct HotkeyRecorderField: View {
    @Binding var combination: HotkeyCombination
    let onRecord: (HotkeyCombination) -> Void
    let warningText: String?

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(HotkeyRecorderCopy.display(for: combination))
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .textBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.secondary.opacity(0.3)))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Button(isRecording ? "Press a key…" : "Record") {
                    startRecording()
                }
                .disabled(isRecording)
            }
            if let warningText {
                Text(warningText)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        guard monitor == nil else { return }
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if let combo = HotkeyEventDecoder.combination(
                modifierFlags: event.modifierFlags,
                keyCode: UInt32(event.keyCode)
            ) {
                onRecord(combo)
                stopRecording()
            }
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        isRecording = false
    }
}
