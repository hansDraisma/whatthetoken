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
        keyCodeDisplayTable[keyCode] ?? "?"
    }

    private static let keyCodeDisplayTable: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 25: "9", 26: "7", 28: "8", 29: "0", 31: "O", 32: "U",
        34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
        50: "`", 53: "Esc", 65: ".", 67: "*", 69: "+", 71: "Clear",
        75: "/", 76: "Return", 78: "-", 81: "=", 82: "0", 83: "1",
        84: "2", 85: "3", 86: "4", 87: "5", 88: "6", 89: "7",
        91: "8", 92: "9", 96: "F5", 97: "F6", 98: "F7", 99: "F3",
        100: "F8", 101: "F9", 103: "F11", 109: "F10", 111: "F12",
        118: "F4", 120: "F2", 122: "F1", 123: "←", 124: "→",
        125: "↓", 126: "↑"
    ]
}

struct HotkeyRecorderEventPolicy: @unchecked Sendable {
    weak var recordingWindow: NSWindow?
    var onCancel: () -> Void

    func handle(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) {
        if keyCode == 53 {
            onCancel()
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        guard let recordingWindow else {
            onCancel()
            return
        }
        guard notification.object as? NSWindow === recordingWindow else { return }
        onCancel()
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
    @State private var windowObserver: NSObjectProtocol?

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
        let recordingWindow = NSApp.keyWindow
        let policy = HotkeyRecorderEventPolicy(recordingWindow: recordingWindow, onCancel: { stopRecording() })
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            policy.handle(keyCode: event.keyCode, modifierFlags: event.modifierFlags)
            if event.keyCode == 53 {
                return nil
            }
            if let combo = HotkeyEventDecoder.combination(
                modifierFlags: event.modifierFlags,
                keyCode: UInt32(event.keyCode)
            ) {
                onRecord(combo)
                stopRecording()
            }
            return nil
        }
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: recordingWindow,
            queue: .main
        ) { notification in
            policy.windowDidResignKey(notification)
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        if let windowObserver {
            NotificationCenter.default.removeObserver(windowObserver)
        }
        monitor = nil
        windowObserver = nil
        isRecording = false
    }
}
