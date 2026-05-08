import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct BackgroundRefreshControllerTests {
    @MainActor
    @Test func startDoesNotScheduleTimerWhenAutoRefreshDisabled() async {
        let vm = StatusViewModel(settings: .defaults)
        let fake = FakeSleeper()
        let controller = BackgroundRefreshController(viewModel: vm, sleeper: { duration in await fake.sleep(duration) })

        controller.start()
        for _ in 0..<10 { await Task.yield() }

        #expect(fake.pendingTicks == 0)
    }

    @MainActor
    @Test func startSchedulesConfiguredTimerWhenAutoRefreshEnabled() async {
        var settings = AppSettings.defaults
        settings.refresh.autoRefreshEnabled = true
        settings.refresh.intervalSeconds = 300
        let vm = StatusViewModel(settings: settings)
        let fake = FakeSleeper()
        let controller = BackgroundRefreshController(viewModel: vm, sleeper: { duration in await fake.sleep(duration) })

        controller.start()
        for _ in 0..<20 {
            if fake.pendingTicks > 0 { break }
            await Task.yield()
        }

        #expect(fake.pendingTicks == 1)
        #expect(fake.lastDuration == .seconds(300))
        controller.stop()
    }

    @MainActor
    @Test func startRunsImmediateRefreshWhenAutoRefreshEnabled() async {
        var settings = AppSettings.defaults
        settings.connectors.claudeCode.isEnabled = true
        settings.refresh.autoRefreshEnabled = true
        let vm = StatusViewModel(
            settings: settings,
            claudeRefresher: NoopClaudeRefresher(),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0")
        )
        let fake = FakeSleeper()
        let controller = BackgroundRefreshController(viewModel: vm, sleeper: { duration in await fake.sleep(duration) })

        controller.start()
        for _ in 0..<20 { await Task.yield() }

        #expect(vm.lastClaudeRefreshAt != nil)
        controller.stop()
    }

    @MainActor
    @Test func timerTickRefreshesWhilePopoverIsClosed() async {
        var settings = AppSettings.defaults
        settings.connectors.claudeCode.isEnabled = true
        settings.refresh.autoRefreshEnabled = true
        let vm = StatusViewModel(
            settings: settings,
            claudeRefresher: NoopClaudeRefresher(),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0")
        )
        let fake = FakeSleeper()
        let controller = BackgroundRefreshController(viewModel: vm, sleeper: { duration in await fake.sleep(duration) })

        controller.start()
        for _ in 0..<20 {
            if fake.pendingTicks > 0 { break }
            await Task.yield()
        }
        fake.fireOneTick()
        for _ in 0..<20 { await Task.yield() }

        #expect(vm.lastClaudeRefreshAt != nil)
        controller.stop()
    }

    @MainActor
    @Test func catchUpRefreshRunsWhenActivationFindsIntervalElapsed() async {
        var settings = AppSettings.defaults
        settings.connectors.claudeCode.isEnabled = true
        settings.refresh.autoRefreshEnabled = true
        settings.refresh.intervalSeconds = 300
        var current = Date(timeIntervalSince1970: 1_000)
        let vm = StatusViewModel(
            settings: settings,
            claudeRefresher: NoopClaudeRefresher(),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
            now: { current }
        )
        let controller = BackgroundRefreshController(viewModel: vm, sleeper: { _ in })

        await controller.appBecameActive()
        let first = vm.lastClaudeRefreshAt
        current = Date(timeIntervalSince1970: 1_301)
        await controller.appBecameActive()

        #expect(first != nil)
        #expect(vm.lastClaudeRefreshAt == current)
    }
}
