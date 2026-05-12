import SwiftUI

@main
struct WhatTheTokenApp: App {
    private let app: AppModel?
    @Environment(\.openWindow)   private var openWindow
    @Environment(\.openSettings) private var openSettingsScene

    init() {
        app = Self.makeAppForLaunch(
            arguments: CommandLine.arguments,
            makeLiveApp: { AppModel.live() },
            startClaudeSmoke: { _ = ClaudeConnectorSmokeCommand.startCommandLineSmoke() },
            startCodexSmoke: { _ = CodexConnectorSmokeCommand.startCommandLineSmoke() },
            configureInteractiveLaunch: { MacAppLauncher.configureLaunch() }
        )
    }

    @MainActor
    static func makeAppForLaunch(
        arguments: [String],
        makeLiveApp: () -> AppModel,
        startClaudeSmoke: () -> Void,
        startCodexSmoke: () -> Void,
        configureInteractiveLaunch: () -> Void
    ) -> AppModel? {
        if ClaudeConnectorSmokeCommand.shouldRun(arguments: arguments) {
            startClaudeSmoke()
            return nil
        }
        if CodexConnectorSmokeCommand.shouldRun(arguments: arguments) {
            startCodexSmoke()
            return nil
        }

        configureInteractiveLaunch()
        return makeLiveApp()
    }

    @SceneBuilder
    var body: some Scene {
        MenuBarExtra {
            if let app {
                PopoverRootView(
                    viewModel: app.viewModel,
                    controller: app.refreshController,
                    canCheckForUpdates: { app.updateController.canCheckForUpdates },
                    onOpenSettings: openSettingsAction,
                    onCheckForUpdates: { app.updateController.checkForUpdates(nil) },
                    onOpenDeveloperWindow: developerWindowOpener
                )
            } else {
                EmptyView()
            }
        } label: {
            if let app {
                MenuBarStatusLabel(viewModel: app.viewModel)
            } else {
                EmptyView()
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            if let app {
                SettingsRootView(viewModel: app.viewModel)
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
        #endif
    }

    /// Activate first so the responder chain has a frontmost app, then ask
    /// SwiftUI to open the Settings scene. The previous `NSApp.sendAction`
    /// approach dispatched into nothing because `.accessory` apps are not
    /// frontmost when the menu-bar popover is shown.
    private func openSettingsAction() {
        MacChromeActions.openSettings {
            openSettingsScene()
        }
    }

    private var developerWindowOpener: (() -> Void)? {
        #if DEBUG
        let openWindow = self.openWindow
        return {
            MacChromeActions.openDeveloperWindow {
                openWindow(id: "developer")
            }
        }
        #else
        return nil
        #endif
    }
}
