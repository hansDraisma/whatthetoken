import SwiftUI

@main
struct WhatTheTokenApp: App {
    init() {
        if ClaudeConnectorSmokeCommand.shouldRun(arguments: CommandLine.arguments) {
            ClaudeConnectorSmokeCommand.startCommandLineSmoke()
        } else {
            MacAppLauncher.configureForInteractiveLaunch()
        }
        if CodexConnectorSmokeCommand.shouldRun(arguments: CommandLine.arguments) {
            CodexConnectorSmokeCommand.startCommandLineSmoke()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: .live())
        }
    }
}
