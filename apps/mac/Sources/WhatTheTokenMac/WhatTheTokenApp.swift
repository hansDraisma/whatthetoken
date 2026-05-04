import SwiftUI

@main
struct WhatTheTokenApp: App {
    init() {
        if ClaudeConnectorSmokeCommand.shouldRun(arguments: CommandLine.arguments) {
            ClaudeConnectorSmokeCommand.startCommandLineSmoke()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: .live())
        }
    }
}
