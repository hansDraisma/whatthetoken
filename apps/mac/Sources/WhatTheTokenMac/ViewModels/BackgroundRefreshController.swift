import Foundation
#if canImport(AppKit)
import AppKit
#endif

@MainActor
final class BackgroundRefreshController {
    private let viewModel: StatusViewModel
    private let sleeper: SleepClosure
    private var timerTask: Task<Void, Never>?
    private var generation = 0
    private var lastAutomaticAttemptAt: Date?
#if canImport(AppKit)
    private var activeObserver: NSObjectProtocol?
#endif

    init(
        viewModel: StatusViewModel,
        sleeper: @escaping SleepClosure = { try? await Task.sleep(for: $0) }
    ) {
        self.viewModel = viewModel
        self.sleeper = sleeper
    }

    func start(afterStartupVerification: Bool = false) {
        generation &+= 1
        stop()
        guard viewModel.settings.refresh.autoRefreshEnabled else { return }

        if afterStartupVerification {
            lastAutomaticAttemptAt = viewModel.currentDate
        }
        startActivationObserver()
        let expected = generation
        let interval = viewModel.settings.refresh.intervalDuration
        let sleeper = self.sleeper
        let viewModel = self.viewModel

        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                await sleeper(interval)
                if Task.isCancelled { break }
                guard let self, self.generation == expected else { break }
                self.lastAutomaticAttemptAt = viewModel.currentDate
                await viewModel.refreshAll(reason: .timerTick)
            }
        }

        if !afterStartupVerification {
            Task { [weak self] in
                await self?.appBecameActive()
            }
        }
    }

    func settingsDidChange() {
        start()
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
        stopActivationObserver()
    }

    func appBecameActive() async {
        guard viewModel.settings.refresh.autoRefreshEnabled else { return }
        let now = viewModel.currentDate
        let interval = TimeInterval(viewModel.settings.refresh.intervalSeconds)
        if let lastAutomaticAttemptAt, now.timeIntervalSince(lastAutomaticAttemptAt) < interval {
            return
        }
        guard !viewModel.isAnyRefreshing else { return }
        lastAutomaticAttemptAt = now
        await viewModel.refreshAll(reason: .timerTick)
    }

    private func startActivationObserver() {
#if canImport(AppKit)
        stopActivationObserver()
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.appBecameActive()
            }
        }
#endif
    }

    private func stopActivationObserver() {
#if canImport(AppKit)
        if let activeObserver {
            NotificationCenter.default.removeObserver(activeObserver)
            self.activeObserver = nil
        }
#endif
    }
}
