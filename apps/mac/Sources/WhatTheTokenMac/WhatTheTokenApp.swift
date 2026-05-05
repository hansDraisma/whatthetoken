import SwiftUI

@main
struct WhatTheTokenApp: App {
    init() {
        if ClaudeConnectorSmokeCommand.shouldRun(arguments: CommandLine.arguments) {
            ClaudeConnectorSmokeCommand.startCommandLineSmoke()
        } else {
            MacAppLauncher.configureForInteractiveLaunch()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: .live())
        }
    }
}
