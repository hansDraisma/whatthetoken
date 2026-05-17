import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct AppLaunchRouterTests {
    @Test func claudeSmokeLaunchStartsClaudeSmokeAndSkipsInteractiveApp() {
        var startedClaude = false
        var startedCodex = false
        var configuredInteractive = false
        var madeLiveApp = false

        let app: String? = AppLaunchRouter.route(
            arguments: ["WhatTheToken", "--claude-smoke"],
            shouldRunClaudeSmoke: { _ in true },
            shouldRunCodexSmoke: { _ in false },
            startClaudeSmoke: { startedClaude = true },
            startCodexSmoke: { startedCodex = true },
            configureInteractiveLaunch: { configuredInteractive = true },
            makeLiveApp: {
                madeLiveApp = true
                return "live"
            }
        )

        #expect(app == nil)
        #expect(startedClaude == true)
        #expect(startedCodex == false)
        #expect(configuredInteractive == false)
        #expect(madeLiveApp == false)
    }

    @Test func codexSmokeLaunchStartsCodexSmokeWhenClaudeSmokeIsNotRequested() {
        var startedCodex = false

        let app: String? = AppLaunchRouter.route(
            arguments: ["WhatTheToken", "--codex-smoke"],
            shouldRunClaudeSmoke: { _ in false },
            shouldRunCodexSmoke: { _ in true },
            startClaudeSmoke: {},
            startCodexSmoke: { startedCodex = true },
            configureInteractiveLaunch: { Issue.record("interactive launch should not be configured") },
            makeLiveApp: {
                Issue.record("live app should not be made")
                return "live"
            }
        )

        #expect(app == nil)
        #expect(startedCodex == true)
    }

    @Test func normalLaunchConfiguresInteractiveLaunchBeforeCreatingApp() {
        var events: [String] = []

        let app: String? = AppLaunchRouter.route(
            arguments: ["WhatTheToken"],
            shouldRunClaudeSmoke: { _ in false },
            shouldRunCodexSmoke: { _ in false },
            startClaudeSmoke: { events.append("claude") },
            startCodexSmoke: { events.append("codex") },
            configureInteractiveLaunch: { events.append("configure") },
            makeLiveApp: {
                events.append("make")
                return "live"
            }
        )

        #expect(app == "live")
        #expect(events == ["configure", "make"])
    }
}
