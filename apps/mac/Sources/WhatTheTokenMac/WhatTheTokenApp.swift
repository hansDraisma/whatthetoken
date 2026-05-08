import SwiftUI

@main
struct WhatTheTokenApp: App {
    private let app: AppModel = .live()
    @Environment(\.openWindow)   private var openWindow
    @Environment(\.openSettings) private var openSettingsScene

    init() {
        if ClaudeConnectorSmokeCommand.shouldRun(arguments: CommandLine.arguments) {
            ClaudeConnectorSmokeCommand.startCommandLineSmoke()
            return
        }
        if CodexConnectorSmokeCommand.shouldRun(arguments: CommandLine.arguments) {
            CodexConnectorSmokeCommand.startCommandLineSmoke()
            return
        }
        MacAppLauncher.configureLaunch()
    }

    var body: some Scene {
        MenuBarExtra("WhatTheToken", systemImage: "gauge") {
            PopoverRootView(
                viewModel: app.viewModel,
                controller: app.refreshController,
                onOpenSettings: openSettingsAction,
                onOpenDeveloperWindow: developerWindowOpener
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsRootView(viewModel: app.viewModel)
        }

        #if DEBUG
        Window("WhatTheToken - Developer", id: "developer") {
            DeveloperWindowView(viewModel: app.viewModel)
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
