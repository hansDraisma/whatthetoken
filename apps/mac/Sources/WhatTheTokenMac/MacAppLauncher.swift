import Foundation

#if canImport(AppKit)
import AppKit
#endif

enum MacAppActivationPolicy: Equatable, Sendable {
    case regular
}

@MainActor
protocol MacApplicationActivating: AnyObject {
    func setActivationPolicy(_ policy: MacAppActivationPolicy)
    func activateIgnoringOtherApps()
}

enum MacAppLauncher {
    @MainActor
    static func configureForInteractiveLaunch(
        arguments: [String] = CommandLine.arguments,
        application: MacApplicationActivating = SystemMacApplication.shared
    ) {
        guard !ClaudeConnectorSmokeCommand.shouldRun(arguments: arguments) else {
            return
        }

        application.setActivationPolicy(.regular)
        application.activateIgnoringOtherApps()
    }
}

@MainActor
private final class SystemMacApplication: MacApplicationActivating {
    static let shared = SystemMacApplication()

    private init() {}

    func setActivationPolicy(_ policy: MacAppActivationPolicy) {
        #if canImport(AppKit)
        switch policy {
        case .regular:
            NSApplication.shared.setActivationPolicy(.regular)
        }
        #endif
    }

    func activateIgnoringOtherApps() {
        #if canImport(AppKit)
        NSApplication.shared.activate(ignoringOtherApps: true)
        #endif
    }
}
