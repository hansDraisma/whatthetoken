import Foundation

#if canImport(AppKit)
import AppKit
#endif

enum MacAppActivationPolicy: Equatable, Sendable {
    case regular
    case accessory
}

@MainActor
protocol MacApplicationActivating: AnyObject {
    func setActivationPolicy(_ policy: MacAppActivationPolicy)
    func activateIgnoringOtherApps()
}

enum MacAppLauncher {
    @MainActor
    static func configureLaunch(
        arguments: [String] = CommandLine.arguments,
        application: MacApplicationActivating = SystemMacApplication.shared
    ) {
        if ClaudeConnectorSmokeCommand.shouldRun(arguments: arguments) { return }
        if CodexConnectorSmokeCommand.shouldRun(arguments: arguments) { return }

        if arguments.contains("--developer-window") {
            application.setActivationPolicy(.regular)
            application.activateIgnoringOtherApps()
        } else {
            application.setActivationPolicy(.accessory)
        }
    }

    @MainActor
    static func configureForInteractiveLaunch(
        arguments: [String] = CommandLine.arguments,
        application: MacApplicationActivating = SystemMacApplication.shared
    ) {
        configureLaunch(arguments: arguments, application: application)
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
        case .accessory:
            NSApplication.shared.setActivationPolicy(.accessory)
        }
        #endif
    }

    func activateIgnoringOtherApps() {
        #if canImport(AppKit)
        NSApplication.shared.activate(ignoringOtherApps: true)
        #endif
    }
}
