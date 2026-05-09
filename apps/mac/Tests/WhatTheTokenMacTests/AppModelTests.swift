import Testing
@testable import WhatTheTokenMac

@Suite struct AppModelTests {
    @MainActor
    @Test func live_initializesWiredDependencies() {
        let app = AppModel.live()
        #expect(app.viewModel.isRefreshAllInFlight == false)
        app.refreshController.userTappedRefresh()
    }

    @MainActor
    @Test func smokeStartupSkipsLiveAppConstruction() {
        var madeLiveApp = false
        var startedClaudeSmoke = false
        var configuredInteractiveLaunch = false

        let app = WhatTheTokenApp.makeAppForLaunch(
            arguments: ["WhatTheToken", "--claude-connector-smoke"],
            makeLiveApp: {
                madeLiveApp = true
                return AppModel.live()
            },
            startClaudeSmoke: {
                startedClaudeSmoke = true
            },
            startCodexSmoke: {},
            configureInteractiveLaunch: {
                configuredInteractiveLaunch = true
            }
        )

        #expect(app == nil)
        #expect(madeLiveApp == false)
        #expect(startedClaudeSmoke == true)
        #expect(configuredInteractiveLaunch == false)
    }
}
