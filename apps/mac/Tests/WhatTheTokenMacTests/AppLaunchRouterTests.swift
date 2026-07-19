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

    @MainActor
    @Test func startupRoutineLogsLoadFailure() async {
        let logger = RecordingTestLogger()
        var loadStarted = false

        await AppStartupRoutine.run(
            loadPersistedState: {
                loadStarted = true
                throw NSError(domain: "test", code: 1)
            },
            logger: logger,
            registerHotkey: { Issue.record("registerHotkey should not run after load failure") },
            startRefresh: { Issue.record("startRefresh should not run after load failure") }
        )

        #expect(loadStarted)
        #expect(logger.messages.contains { $0.contains("Failed to load persisted state") })
    }

    @MainActor
    @Test func startupRoutineAwaitsHotkeyRegistrationBeforeRefreshStarts() async {
        let logger = RecordingTestLogger()
        var events: [String] = []

        await AppStartupRoutine.run(
            loadPersistedState: { events.append("load") },
            logger: logger,
            registerHotkey: {
                events.append("register:start")
                await Task.yield()
                events.append("register:end")
            },
            startRefresh: { events.append("refresh") }
        )

        #expect(events == ["load", "register:start", "register:end", "refresh"])
    }

    @MainActor
    @Test func startupRoutineTreatsMissingSettingsFileAsFreshInstall() async {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-settings-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let settingsStore = JSONFileAppSettingsStore(
            url: root.appendingPathComponent("settings.json"),
            logger: nil
        )
        let logger = RecordingTestLogger()
        var events: [String] = []

        await AppStartupRoutine.run(
            loadPersistedState: {
                let settings = try await settingsStore.loadValidated()
                #expect(settings == .defaults)
                events.append("load")
            },
            logger: logger,
            registerHotkey: { events.append("register") },
            startRefresh: { events.append("refresh") }
        )

        #expect(events == ["load", "register", "refresh"])
        #expect(logger.messages.isEmpty)
    }

    @Test func liveStartupUsesThrowingPersistedStateLoadForLoggingPath() throws {
        let appModel = try sourceContents("AppModel.swift")
        let statusViewModel = try sourceContents("ViewModels/StatusViewModel.swift")

        #expect(appModel.contains("try await viewModel.loadPersistedStateThrowing()"))
        #expect(!appModel.contains("autoOpenLaunchWindow"))
        #expect(statusViewModel.contains("func loadPersistedStateThrowing() async throws"))
    }

    private func sourceContents(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/WhatTheTokenMac/\(relativePath)")
        return try String(contentsOf: url, encoding: .utf8)
    }
}
