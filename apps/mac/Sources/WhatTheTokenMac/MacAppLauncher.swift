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
        application: MacApplicationActivating = SystemMacApplication.shared,
        showInDock: () -> Bool = { Self.persistedShowInDock() }
    ) {
        if ClaudeConnectorSmokeCommand.shouldRun(arguments: arguments) { return }
        if CodexConnectorSmokeCommand.shouldRun(arguments: arguments) { return }

        if arguments.contains("--developer-window") {
            application.setActivationPolicy(.regular)
            application.activateIgnoringOtherApps()
        } else {
            application.setActivationPolicy(showInDock() ? .regular : .accessory)
        }
    }

    @MainActor
    static func configureForInteractiveLaunch(
        arguments: [String] = CommandLine.arguments,
        application: MacApplicationActivating = SystemMacApplication.shared,
        showInDock: () -> Bool = { Self.persistedShowInDock() }
    ) {
        configureLaunch(arguments: arguments, application: application, showInDock: showInDock)
    }

    @MainActor
    private static func persistedShowInDock() -> Bool {
        let url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WhatTheToken", isDirectory: true)
            .appendingPathComponent("settings.json")
        return persistedShowInDock(settingsURL: url, logger: OSLogAppLogger(category: "MacAppLauncher"))
    }

    static func persistedShowInDock(settingsURL: URL, logger: AppLogger) -> Bool {
        do {
            let data = try Data(contentsOf: settingsURL)
            let settings = try AppSettings.decodeValidated(from: data)
            return settings.appearance.showInDock
        } catch CocoaError.fileReadNoSuchFile {
            return AppearanceSettings.default.showInDock
        } catch {
            logger.error("Failed to decode settings.json: \(error.localizedDescription) - falling back to dock-visible default")
            return AppearanceSettings.default.showInDock
        }
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
