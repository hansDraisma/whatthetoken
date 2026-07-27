import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct AppModelTests {
    @Test func liveWiresReconnectWithoutConstructingLiveProviderDependencies() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/WhatTheTokenMac/AppModel.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("ClaudeCredentialProbe"))
        #expect(source.contains("refreshClaudeAfterCredentialRotation"))
        #expect(source.contains("activateReconnectWatcher"))
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
