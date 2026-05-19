import Foundation
import os.log

protocol AppLogger: Sendable {
    func error(_ message: String)
}

struct OSLogAppLogger: AppLogger {
    let log: OSLog

    init(subsystem: String = "com.whatthetoken.mac", category: String) {
        log = OSLog(subsystem: subsystem, category: category)
    }

    func error(_ message: String) {
        os_log("%{public}@", log: log, type: .error, message)
    }
}
