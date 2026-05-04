import SwiftUI

@main
struct WhatTheTokenApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: .fixture())
        }
    }
}
