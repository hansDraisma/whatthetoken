import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct PopoverRefreshControllerTests {
    @MainActor
    @Test func userTappedRefresh_routesThroughRefreshAll() async {
        var settings = AppSettings.defaults
        settings.connectors.claudeCode.isEnabled = true
        let vm = StatusViewModel(
            snapshots: [],
            settings: settings,
            claudeRefresher: NoopClaudeRefresher(),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
            codexRefresher: NoopCodexRefresher()
        )
        let controller = PopoverRefreshController(viewModel: vm, sleeper: { _ in })

        controller.userTappedRefresh()
        for _ in 0..<5 { await Task.yield() }

        #expect(vm.lastClaudeRefreshAt != nil || vm.lastCodexRefreshAt != nil)
    }

    @MainActor
    @Test func userTappedRetry_routesThroughRefreshAll() async {
        var settings = AppSettings.defaults
        settings.connectors.claudeCode.isEnabled = true
        let vm = StatusViewModel(
            snapshots: [],
            settings: settings,
            claudeRefresher: NoopClaudeRefresher(),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
            codexRefresher: NoopCodexRefresher()
        )
        let controller = PopoverRefreshController(viewModel: vm, sleeper: { _ in })

        controller.userTappedRetry()
        for _ in 0..<5 { await Task.yield() }

        #expect(vm.lastClaudeRefreshAt != nil || vm.lastCodexRefreshAt != nil)
    }

    @MainActor
    @Test func popoverDidOpen_runsImmediateRefresh_withoutStartingTimerWhenAutoRefreshDisabled() async {
        var settings = AppSettings.defaults
        settings.connectors.claudeCode.isEnabled = true
        let vm = StatusViewModel(
            settings: settings,
            claudeRefresher: NoopClaudeRefresher(),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
            settingsStore: InMemoryAppSettingsStore(data: try! JSONEncoder.prettyStable.encode(settings))
        )
        let fake = FakeSleeper()
        let controller = PopoverRefreshController(viewModel: vm, sleeper: { duration in await fake.sleep(duration) })

        controller.popoverDidOpen()
        for _ in 0..<100 {
            if vm.lastClaudeRefreshAt != nil { break }
            await Task.yield()
        }

        #expect(vm.lastClaudeRefreshAt != nil)
        #expect(fake.pendingTicks == 0)
    }

    @MainActor
    @Test func popoverOpenDoesNotStartPopoverTimerWhenBackgroundAutoRefreshIsEnabled() async {
        var settings = AppSettings.defaults
        settings.connectors.claudeCode.isEnabled = true
        settings.refresh.autoRefreshEnabled = true
        settings.refresh.intervalSeconds = 300
        let vm = StatusViewModel(
            settings: settings,
            claudeRefresher: NoopClaudeRefresher(),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
            settingsStore: InMemoryAppSettingsStore(data: try! JSONEncoder.prettyStable.encode(settings))
        )
        let fake = FakeSleeper()
        let controller = PopoverRefreshController(viewModel: vm, sleeper: { duration in await fake.sleep(duration) })

        controller.popoverDidOpen()
        for _ in 0..<20 {
            if fake.pendingTicks > 0 { break }
            await Task.yield()
        }

        #expect(fake.pendingTicks == 0)
        controller.popoverDidClose()
    }

    @MainActor
    @Test func popoverOpenSkipsRefreshAfterRecentBackgroundRefresh() async {
        var settings = AppSettings.defaults
        settings.connectors.claudeCode.isEnabled = true
        var current = Date(timeIntervalSince1970: 1_000)
        let counter = Counter()
        let vm = StatusViewModel(
            settings: settings,
            claudeRefresher: SlowClaudeRefresher(counter: counter),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
            settingsStore: InMemoryAppSettingsStore(data: try! JSONEncoder.prettyStable.encode(settings)),
            now: { current }
        )
        await vm.refreshAll(reason: .timerTick)
        current = Date(timeIntervalSince1970: 1_030)
        let controller = PopoverRefreshController(viewModel: vm, sleeper: { _ in })

        controller.popoverDidOpen()
        for _ in 0..<20 { await Task.yield() }

        #expect(counter.value == 1)
    }

    @MainActor
    @Test func popoverDidOpen_loadsPersistedStateBeforeImmediateRefresh() async {
        var settings = AppSettings.defaults
        settings.connectors.claudeCode.isEnabled = true
        let settingsStore = InMemoryAppSettingsStore(data: try! JSONEncoder.prettyStable.encode(settings))
        let counter = Counter()
        let vm = StatusViewModel(
            claudeRefresher: SlowClaudeRefresher(counter: counter),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
            settingsStore: settingsStore
        )
        let controller = PopoverRefreshController(viewModel: vm, sleeper: { _ in })

        controller.popoverDidOpen()
        for _ in 0..<30 {
            if counter.value > 0 { break }
            await Task.yield()
        }

        #expect(vm.hasLoadedPersistedState == true)
        #expect(counter.value == 1)
    }

    @MainActor
    @Test func popoverDidClose_cancelsBeforeNextTick() async {
        var settings = AppSettings.defaults
        settings.connectors.claudeCode.isEnabled = true
        settings.refresh.autoRefreshEnabled = true
        let vm = StatusViewModel(
            snapshots: [],
            settings: settings,
            claudeRefresher: NoopClaudeRefresher(),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
            codexRefresher: NoopCodexRefresher(),
            settingsStore: InMemoryAppSettingsStore(data: try! JSONEncoder.prettyStable.encode(settings))
        )
        let fake = FakeSleeper()
        let controller = PopoverRefreshController(viewModel: vm, sleeper: { duration in await fake.sleep(duration) })

        controller.popoverDidOpen()
        for _ in 0..<10 { await Task.yield() }
        controller.popoverDidClose()

        let stampAfterClose = vm.lastClaudeRefreshAt
        fake.fireOneTick()
        for _ in 0..<20 { await Task.yield() }

        #expect(vm.lastClaudeRefreshAt == stampAfterClose)
    }

    @MainActor
    @Test func userTappedRefreshDuringInFlight_isDropped() async {
        var settings = AppSettings.defaults
        settings.connectors.claudeCode.isEnabled = true
        let counter = Counter()
        let vm = StatusViewModel(
            snapshots: [],
            settings: settings,
            claudeRefresher: SlowClaudeRefresher(counter: counter),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
            codexRefresher: NoopCodexRefresher(),
            settingsStore: InMemoryAppSettingsStore(data: try! JSONEncoder.prettyStable.encode(settings))
        )
        let controller = PopoverRefreshController(viewModel: vm, sleeper: { _ in })

        controller.userTappedRefresh()
        controller.userTappedRefresh()
        for _ in 0..<20 { await Task.yield() }

        #expect(counter.value == 1)
    }

    @MainActor
    @Test func popoverDidClose_cancelsImmediateRefreshBeforeItClaimsFreshness() async {
        var settings = AppSettings.defaults
        settings.connectors.claudeCode.isEnabled = true
        let counter = Counter()
        let vm = StatusViewModel(
            snapshots: [],
            settings: settings,
            claudeRefresher: SlowClaudeRefresher(counter: counter),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
            codexRefresher: NoopCodexRefresher(),
            settingsStore: InMemoryAppSettingsStore(data: try! JSONEncoder.prettyStable.encode(settings))
        )
        let controller = PopoverRefreshController(viewModel: vm, sleeper: { _ in })

        controller.popoverDidOpen()
        for _ in 0..<20 {
            if counter.value > 0 { break }
            await Task.yield()
        }
        controller.popoverDidClose()
        try? await Task.sleep(nanoseconds: 80_000_000)

        #expect(vm.lastClaudeRefreshAt == nil, "Closing the popover should cancel the open refresh before it updates freshness.")
    }
}

final class FakeSleeper: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var storedLastDuration: Duration?

    func sleep(_ duration: Duration) async {
        await withCheckedContinuation { continuation in
            lock.withLock {
                storedLastDuration = duration
                continuations.append(continuation)
            }
        }
    }

    func fireOneTick() {
        let continuation: CheckedContinuation<Void, Never>? = lock.withLock {
            continuations.isEmpty ? nil : continuations.removeFirst()
        }
        continuation?.resume()
    }

    var pendingTicks: Int {
        lock.withLock { continuations.count }
    }

    var lastDuration: Duration? {
        lock.withLock { storedLastDuration }
    }
}
