import Foundation
@testable import WhatTheTokenMac

final class RecordingTestLogger: AppLogger, @unchecked Sendable {
    private let lock = NSLock()
    private var storedMessages: [String] = []

    var messages: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedMessages
    }

    func error(_ message: String) {
        lock.lock()
        storedMessages.append(message)
        lock.unlock()
    }
}
