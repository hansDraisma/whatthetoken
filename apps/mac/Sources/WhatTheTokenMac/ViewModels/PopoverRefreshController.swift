import Foundation

typealias SleepClosure = @Sendable (Duration) async -> Void

@MainActor
final class PopoverRefreshController {
    private let viewModel: StatusViewModel
    private let interval: Duration
    private let sleeper: SleepClosure
    private var timerTask: Task<Void, Never>?
    private var openRefreshTask: Task<Void, Never>?
    private var generation = 0

    init(
        viewModel: StatusViewModel,
        interval: Duration = .seconds(30),
        sleeper: @escaping SleepClosure = { try? await Task.sleep(for: $0) }
    ) {
        self.viewModel = viewModel
        self.interval = interval
        self.sleeper = sleeper
    }

    func userTappedRefresh() {
        let viewModel = self.viewModel
        Task { await viewModel.refreshAll(reason: .manual) }
    }

    func userTappedRetry() {
        let viewModel = self.viewModel
        Task { await viewModel.refreshAll(reason: .retry) }
    }

    func popoverDidOpen() {
        generation &+= 1
        stopTimer()
        stopOpenRefresh()
        let expected = generation
        let viewModel = self.viewModel
        startTimer(expectedGeneration: expected)
        openRefreshTask = Task { [weak self] in
            await viewModel.refreshAll(reason: .popoverOpened)
            guard let self, self.isCurrentGeneration(expected) else { return }
            self.clearOpenRefreshTask()
        }
    }

    func popoverDidClose() {
        generation &+= 1
        stopOpenRefresh()
        stopTimer()
    }

    private func startTimer(expectedGeneration expected: Int) {
        stopTimer()
        let sleeper = self.sleeper
        let interval = self.interval
        let viewModel = self.viewModel
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                await sleeper(interval)
                if Task.isCancelled { break }
                guard let self, self.isCurrentGeneration(expected) else { break }
                await viewModel.refreshAll(reason: .timerTick)
            }
        }
    }

    @MainActor
    private func isCurrentGeneration(_ expected: Int) -> Bool {
        generation == expected
    }

    @MainActor
    private func clearOpenRefreshTask() {
        openRefreshTask = nil
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func stopOpenRefresh() {
        openRefreshTask?.cancel()
        openRefreshTask = nil
    }
}
