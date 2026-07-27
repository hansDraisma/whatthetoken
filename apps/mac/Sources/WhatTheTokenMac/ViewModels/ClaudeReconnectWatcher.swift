import Foundation

/// Watches the local Claude Code credential only while the connector is in a
/// recoverable credential state. It never calls a provider itself and never
/// persists credential material.
@MainActor
final class ClaudeReconnectWatcher {
    static let baseInterval: Duration = .seconds(30)
    static let maxInterval: Duration = .seconds(300)

    private let probe: ClaudeCredentialProbing
    private let sleeper: SleepClosure
    private let now: @Sendable () -> Date
    private let onRotationDetected: @MainActor () async -> Bool

    private var task: Task<Void, Never>?
    private var generation = 0
    private var isActivated = false
    private var currentState: ClaudeConnectorSetupState = .notConnected

    init(
        probe: ClaudeCredentialProbing,
        sleeper: @escaping SleepClosure = { try? await Task.sleep(for: $0) },
        now: @escaping @Sendable () -> Date = { Date() },
        onRotationDetected: @escaping @MainActor () async -> Bool
    ) {
        self.probe = probe
        self.sleeper = sleeper
        self.now = now
        self.onRotationDetected = onRotationDetected
    }

    nonisolated static func isRecoverable(
        _ state: ClaudeConnectorSetupState
    ) -> Bool {
        switch state {
        case .sessionExpired, .tokenInvalid, .missingCredentials:
            return true
        case .connected, .checking, .notConnected, .missingClaudeCli,
             .rateLimited, .networkError, .schemaChanged:
            return false
        }
    }

    /// Activates observation after startup verification has completed.
    func activate(currentState state: ClaudeConnectorSetupState) {
        isActivated = true
        connectorStateDidChange(to: state)
    }

    func connectorStateDidChange(to state: ClaudeConnectorSetupState) {
        currentState = state
        guard isActivated else {
            return
        }

        if Self.isRecoverable(state) {
            start(state: state)
        } else {
            cancelWatch()
        }
    }

    func stop() {
        isActivated = false
        cancelWatch()
    }

    private func start(state: ClaudeConnectorSetupState) {
        guard task == nil else {
            return
        }

        generation &+= 1
        let expectedGeneration = generation
        task = Task { [weak self] in
            await self?.run(
                expectedGeneration: expectedGeneration,
                state: state
            )
            guard let self, self.generation == expectedGeneration else {
                return
            }
            self.task = nil
        }
    }

    private func run(
        expectedGeneration: Int,
        state: ClaudeConnectorSetupState
    ) async {
        let initial = await probe.probe()
        guard isCurrent(expectedGeneration) else {
            return
        }

        if shouldRefreshImmediately(initial, for: state) {
            handOffRefresh()
            return
        }

        var previousSuccessful: ClaudeCredentialProbeResult?
        var interval = Self.baseInterval
        if initial == .unavailable {
            interval = min(interval * 2, Self.maxInterval)
        } else {
            previousSuccessful = initial
        }

        while isCurrent(expectedGeneration) {
            await sleeper(interval)
            guard isCurrent(expectedGeneration) else {
                return
            }

            let current = await probe.probe()
            guard isCurrent(expectedGeneration) else {
                return
            }

            if current == .unavailable {
                interval = min(interval * 2, Self.maxInterval)
                continue
            }
            interval = Self.baseInterval

            guard let previous = previousSuccessful else {
                if shouldRefreshImmediately(current, for: state) {
                    handOffRefresh()
                    return
                }
                previousSuccessful = current
                continue
            }

            if ClaudeRotationDecision.shouldRefresh(
                previous: previous,
                current: current,
                now: now()
            ) {
                handOffRefresh()
                return
            }
            previousSuccessful = current
        }
    }

    private func shouldRefreshImmediately(
        _ result: ClaudeCredentialProbeResult,
        for state: ClaudeConnectorSetupState
    ) -> Bool {
        guard case let .found(fingerprint) = result else {
            return false
        }

        switch state {
        case .sessionExpired:
            return !fingerprint.isExpired(at: now())
        case .missingCredentials:
            return true
        case .tokenInvalid:
            return false
        case .connected, .checking, .notConnected, .missingClaudeCli,
             .rateLimited, .networkError, .schemaChanged:
            return false
        }
    }

    private func handOffRefresh() {
        // Invalidate this watch without cancelling the independent task below.
        generation &+= 1
        task = nil
        let onRotationDetected = self.onRotationDetected

        Task { @MainActor [weak self] in
            let accepted = await onRotationDetected()
            guard !accepted, let self, self.isActivated,
                  Self.isRecoverable(self.currentState)
            else {
                return
            }
            self.start(state: self.currentState)
        }
    }

    private func cancelWatch() {
        generation &+= 1
        task?.cancel()
        task = nil
    }

    private func isCurrent(_ expectedGeneration: Int) -> Bool {
        !Task.isCancelled && generation == expectedGeneration
    }
}
