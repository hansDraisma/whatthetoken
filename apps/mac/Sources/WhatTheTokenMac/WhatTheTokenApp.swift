import SwiftUI
import AppKit

enum AppLaunchRouter {
    static func route<LaunchApp>(
        arguments: [String],
        shouldRunClaudeSmoke: ([String]) -> Bool,
        shouldRunCodexSmoke: ([String]) -> Bool,
        startClaudeSmoke: () -> Void,
        startCodexSmoke: () -> Void,
        configureInteractiveLaunch: () -> Void,
        makeLiveApp: () -> LaunchApp
    ) -> LaunchApp? {
        if shouldRunClaudeSmoke(arguments) {
            startClaudeSmoke()
            return nil
        }
        if shouldRunCodexSmoke(arguments) {
            startCodexSmoke()
            return nil
        }

        configureInteractiveLaunch()
        return makeLiveApp()
    }
}

@main
struct WhatTheTokenApp: App {
    private let app: AppModel?
    @Environment(\.openWindow) private var openWindow
    @NSApplicationDelegateAdaptor(MacAppDelegateAdaptor.self) private var delegateAdaptor

    init() {
        let app = Self.makeAppForLaunch(
            arguments: CommandLine.arguments,
            makeLiveApp: { AppModel.live() },
            startClaudeSmoke: { _ = ClaudeConnectorSmokeCommand.startCommandLineSmoke() },
            startCodexSmoke: { _ = CodexConnectorSmokeCommand.startCommandLineSmoke() },
            configureInteractiveLaunch: { MacAppLauncher.configureLaunch() }
        )
        self.app = app
        delegateAdaptor.bind(app: app)
    }

    @MainActor
    static func makeAppForLaunch(
        arguments: [String],
        makeLiveApp: () -> AppModel,
        startClaudeSmoke: () -> Void,
        startCodexSmoke: () -> Void,
        configureInteractiveLaunch: () -> Void
    ) -> AppModel? {
        AppLaunchRouter.route(
            arguments: arguments,
            shouldRunClaudeSmoke: { ClaudeConnectorSmokeCommand.shouldRun(arguments: $0) },
            shouldRunCodexSmoke: { CodexConnectorSmokeCommand.shouldRun(arguments: $0) },
            startClaudeSmoke: startClaudeSmoke,
            startCodexSmoke: startCodexSmoke,
            configureInteractiveLaunch: configureInteractiveLaunch,
            makeLiveApp: makeLiveApp
        )
    }

    @SceneBuilder
    var body: some Scene {
        Settings {
            if let app {
                LaunchWindowRootView(viewModel: app.viewModel)
            } else {
                EmptyView()
            }
        }

        #if DEBUG
        Window("WhatTheToken - Developer", id: "developer") {
            if let app {
                DeveloperWindowView(viewModel: app.viewModel)
            } else {
                EmptyView()
            }
        }
        .commands {
            CommandMenu("Debug") {
                Button("Developer Window") {
                    openWindow(id: "developer")
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }
        #endif
    }
}

@MainActor
final class MacAppDelegateAdaptor: NSObject, NSApplicationDelegate {
    private weak var app: AppModel?
    private var delegate: MacAppDelegate?

    func bind(app: AppModel?) {
        self.app = app
        if let app {
            delegate = MacAppDelegate(actions: AppModelDelegateActions(app: app))
        } else {
            delegate = nil
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        delegate?.applicationShouldHandleReopen(hasVisibleWindows: flag) ?? true
    }
}

@MainActor
private final class AppModelDelegateActions: MacAppDelegateActions {
    let app: AppModel

    init(app: AppModel) {
        self.app = app
    }

    func openPopover() {
        Task { await app.viewModel.openPopoverProgrammatically() }
    }

    func pulseMenuBarIcon() {
        Task { await app.viewModel.pulseMenuBarIcon() }
    }
}
