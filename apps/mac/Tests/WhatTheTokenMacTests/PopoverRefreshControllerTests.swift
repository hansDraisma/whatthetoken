import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct PopoverRefreshControllerTests {
    @MainActor
    @Test func userTappedRefresh_routesThroughRefreshAll() async {
        let vm = StatusViewModel(
            snapshots: [],
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
        let vm = StatusViewModel(
            snapshots: [],
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
    @Test func popoverDidOpen_runsImmediateRefresh_andStartsTimer() async {
        let vm = StatusViewModel(
            snapshots: [],
            claudeRefresher: NoopClaudeRefresher(),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
            codexRefresher: NoopCodexRefresher()
        )
        let fake = FakeSleeper()
        let controller = PopoverRefreshController(viewModel: vm, sleeper: { duration in await fake.sleep(duration) })

        controller.popoverDidOpen()
        for _ in 0..<10 { await Task.yield() }
        let firstStamp = vm.lastClaudeRefreshAt
        #expect(firstStamp != nil)

        for _ in 0..<20 {
            if fake.pendingTicks > 0 { break }
            await Task.yield()
        }
        #expect(fake.pendingTicks == 1)

        let stampedBefore = vm.lastClaudeRefreshAt
        fake.fireOneTick()
        for _ in 0..<20 { await Task.yield() }
        #expect(vm.lastClaudeRefreshAt != stampedBefore)
    }

    @MainActor
    @Test func popoverDidClose_cancelsBeforeNextTick() async {
        let vm = StatusViewModel(
            snapshots: [],
            claudeRefresher: NoopClaudeRefresher(),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
            codexRefresher: NoopCodexRefresher()
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
    @Test func timer_skipsRefresh_ifGenerationChangedDuringSleep() async {
        let counter = Counter()
        let vm = StatusViewModel(
            snapshots: [],
            claudeRefresher: SlowClaudeRefresher(counter: counter),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
            codexRefresher: NoopCodexRefresher()
        )
        let fake = FakeSleeper()
        let controller = PopoverRefreshController(viewModel: vm, sleeper: { duration in await fake.sleep(duration) })

        controller.popoverDidOpen()
        for _ in 0..<30 {
            if fake.pendingTicks > 0 { break }
            await Task.yield()
        }
        if fake.pendingTicks == 0 {
            try? await Task.sleep(nanoseconds: 60_000_000)
        }
        for _ in 0..<30 {
            if fake.pendingTicks > 0 { break }
            await Task.yield()
        }
        #expect(fake.pendingTicks > 0)
        let immediateCount = counter.value

        controller.popoverDidOpen()
        for _ in 0..<30 {
            if counter.value > immediateCount { break }
            await Task.yield()
        }
        let countAfterReopenImmediateRefresh = counter.value

        fake.fireOneTick()
        for _ in 0..<30 { await Task.yield() }

        #expect(
            counter.value == countAfterReopenImmediateRefresh,
            "Old timer must not refresh after generation invalidation."
        )
    }

    @MainActor
    @Test func userTappedRefreshDuringInFlight_isDropped() async {
        let counter = Counter()
        let vm = StatusViewModel(
            snapshots: [],
            claudeRefresher: SlowClaudeRefresher(counter: counter),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
            codexRefresher: NoopCodexRefresher()
        )
        let controller = PopoverRefreshController(viewModel: vm, sleeper: { _ in })

        controller.userTappedRefresh()
        controller.userTappedRefresh()
        for _ in 0..<20 { await Task.yield() }

        #expect(counter.value == 1)
    }

    @MainActor
    @Test func popoverDidOpen_startsTimerBeforeImmediateRefreshCompletes() async {
        let counter = Counter()
        let vm = StatusViewModel(
            snapshots: [],
            claudeRefresher: SlowClaudeRefresher(counter: counter),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
            codexRefresher: NoopCodexRefresher()
        )
        let fake = FakeSleeper()
        let controller = PopoverRefreshController(viewModel: vm, sleeper: { duration in await fake.sleep(duration) })

        controller.popoverDidOpen()
        for _ in 0..<20 {
            if counter.value > 0 && fake.pendingTicks > 0 { break }
            await Task.yield()
        }

        #expect(counter.value == 1)
        #expect(fake.pendingTicks == 1, "Timer should be registered while the immediate refresh is still in flight.")
    }

    @MainActor
    @Test func popoverDidClose_cancelsImmediateRefreshBeforeItClaimsFreshness() async {
        let counter = Counter()
        let vm = StatusViewModel(
            snapshots: [],
            claudeRefresher: SlowClaudeRefresher(counter: counter),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
            codexRefresher: NoopCodexRefresher()
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

    func sleep(_: Duration) async {
        await withCheckedContinuation { continuation in
            lock.withLock { continuations.append(continuation) }
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
}
