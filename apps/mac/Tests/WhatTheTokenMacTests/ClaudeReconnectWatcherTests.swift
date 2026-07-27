import Foundation
import Testing
@testable import WhatTheTokenMac

@MainActor
private final class WatcherStubProbe: ClaudeCredentialProbing {
    private var results: [ClaudeCredentialProbeResult]
    private(set) var callCount = 0

    init(_ results: [ClaudeCredentialProbeResult]) {
        self.results = results
    }

    func probe() async -> ClaudeCredentialProbeResult {
        callCount += 1
        guard results.count > 1 else {
            return results.first ?? .absent
        }
        return results.removeFirst()
    }
}

@MainActor
private final class WatcherHolder {
    var watcher: ClaudeReconnectWatcher?
}

private func watcherCredential(
    _ digest: String,
    expiresAt: Date?
) -> ClaudeCredentialProbeResult {
    .found(ClaudeCredentialFingerprint(tokenDigest: digest, expiresAt: expiresAt))
}

@Test
func watcherRecoverableStatesAreCredentialFailuresOnly() {
    #expect(ClaudeReconnectWatcher.isRecoverable(.sessionExpired))
    #expect(ClaudeReconnectWatcher.isRecoverable(.tokenInvalid))
    #expect(ClaudeReconnectWatcher.isRecoverable(.missingCredentials))
    #expect(!ClaudeReconnectWatcher.isRecoverable(.connected))
    #expect(!ClaudeReconnectWatcher.isRecoverable(.checking))
    #expect(!ClaudeReconnectWatcher.isRecoverable(.missingClaudeCli))
    #expect(!ClaudeReconnectWatcher.isRecoverable(.rateLimited))
}

@MainActor
@Test
func watcherDoesNotProbeBeforeActivation() async {
    let probe = WatcherStubProbe([.absent])
    let watcher = ClaudeReconnectWatcher(
        probe: probe,
        sleeper: { _ in },
        onRotationDetected: { true }
    )

    watcher.connectorStateDidChange(to: .sessionExpired)
    for _ in 0..<10 {
        await Task.yield()
    }

    #expect(probe.callCount == 0)
}

@MainActor
@Test
func expiredInitialCredentialBecomesBaselineWithoutRefresh() async {
    let now = Date(timeIntervalSince1970: 2_000)
    let probe = WatcherStubProbe([
        watcherCredential("old", expiresAt: Date(timeIntervalSince1970: 1_000))
    ])
    var refreshCount = 0
    let sleeper = FakeSleeper()
    let watcher = ClaudeReconnectWatcher(
        probe: probe,
        sleeper: { duration in await sleeper.sleep(duration) },
        now: { now },
        onRotationDetected: {
            refreshCount += 1
            return true
        }
    )

    watcher.activate(currentState: .sessionExpired)
    for _ in 0..<20 {
        if probe.callCount == 1 {
            break
        }
        await Task.yield()
    }

    #expect(probe.callCount == 1)
    #expect(refreshCount == 0)
    watcher.stop()
}

@MainActor
@Test
func usableCredentialContradictsSessionExpiredAndRefreshesImmediately() async {
    let now = Date(timeIntervalSince1970: 2_000)
    let probe = WatcherStubProbe([
        watcherCredential("new", expiresAt: Date(timeIntervalSince1970: 3_000))
    ])
    var refreshCount = 0
    let watcher = ClaudeReconnectWatcher(
        probe: probe,
        sleeper: { _ in },
        now: { now },
        onRotationDetected: {
            refreshCount += 1
            return true
        }
    )

    watcher.activate(currentState: .sessionExpired)
    for _ in 0..<20 {
        if refreshCount == 1 {
            break
        }
        await Task.yield()
    }

    #expect(refreshCount == 1)
}

@MainActor
@Test
func credentialAppearingContradictsMissingCredentialsAndRefreshesImmediately() async {
    let probe = WatcherStubProbe([
        watcherCredential("new", expiresAt: nil)
    ])
    var refreshCount = 0
    let watcher = ClaudeReconnectWatcher(
        probe: probe,
        sleeper: { _ in },
        onRotationDetected: {
            refreshCount += 1
            return true
        }
    )

    watcher.activate(currentState: .missingCredentials)
    for _ in 0..<20 {
        if refreshCount == 1 {
            break
        }
        await Task.yield()
    }

    #expect(refreshCount == 1)
}

@MainActor
@Test
func unavailableThenReadableTokenInvalidCredentialEstablishesBaseline() async {
    let probe = WatcherStubProbe([
        .unavailable,
        watcherCredential("same", expiresAt: nil)
    ])
    let sleeper = FakeSleeper()
    var refreshCount = 0
    let watcher = ClaudeReconnectWatcher(
        probe: probe,
        sleeper: { duration in await sleeper.sleep(duration) },
        onRotationDetected: {
            refreshCount += 1
            return true
        }
    )

    watcher.activate(currentState: .tokenInvalid)
    for _ in 0..<20 {
        if sleeper.pendingTicks == 1 {
            break
        }
        await Task.yield()
    }
    #expect(sleeper.lastDuration == .seconds(60))

    sleeper.fireOneTick()
    for _ in 0..<20 {
        if probe.callCount == 2 {
            break
        }
        await Task.yield()
    }

    #expect(refreshCount == 0)
    watcher.stop()
}

@MainActor
@Test
func rotationTriggersExactlyOneIndependentRefresh() async {
    let now = Date(timeIntervalSince1970: 2_000)
    let probe = WatcherStubProbe([
        watcherCredential("old", expiresAt: Date(timeIntervalSince1970: 1_000)),
        watcherCredential("new", expiresAt: Date(timeIntervalSince1970: 3_000))
    ])
    let sleeper = FakeSleeper()
    var refreshStarted = 0
    var refreshCompleted = 0
    let holder = WatcherHolder()
    let watcher = ClaudeReconnectWatcher(
        probe: probe,
        sleeper: { duration in await sleeper.sleep(duration) },
        now: { now },
        onRotationDetected: {
            refreshStarted += 1
            holder.watcher?.connectorStateDidChange(to: .checking)
            await Task.yield()
            refreshCompleted += 1
            return true
        }
    )
    holder.watcher = watcher

    watcher.activate(currentState: .sessionExpired)
    for _ in 0..<20 {
        if sleeper.pendingTicks == 1 {
            break
        }
        await Task.yield()
    }
    sleeper.fireOneTick()
    for _ in 0..<30 {
        if refreshCompleted == 1 {
            break
        }
        await Task.yield()
    }

    #expect(refreshStarted == 1)
    #expect(refreshCompleted == 1)
}

@MainActor
@Test
func rejectedRefreshHandoffRearmsTheWatcherBehindAFullInterval() async {
    let now = Date(timeIntervalSince1970: 2_000)
    let usable = watcherCredential(
        "new",
        expiresAt: Date(timeIntervalSince1970: 3_000)
    )
    let probe = WatcherStubProbe([usable, usable])
    let sleeper = FakeSleeper()
    var attempts = 0
    let watcher = ClaudeReconnectWatcher(
        probe: probe,
        sleeper: { duration in await sleeper.sleep(duration) },
        now: { now },
        onRotationDetected: {
            attempts += 1
            return attempts > 1
        }
    )

    watcher.activate(currentState: .sessionExpired)
    for _ in 0..<40 {
        if sleeper.pendingTicks == 1 {
            break
        }
        await Task.yield()
    }

    // The refusal must not be retried until a full interval has elapsed.
    #expect(attempts == 1)
    #expect(probe.callCount == 1)
    #expect(sleeper.lastDuration == ClaudeReconnectWatcher.baseInterval)

    sleeper.fireOneTick()
    for _ in 0..<40 {
        if attempts == 2 {
            break
        }
        await Task.yield()
    }

    #expect(attempts == 2)
    #expect(probe.callCount == 2)
}

@MainActor
@Test
func repeatedlyRejectedRefreshHandoffDoesNotSpinTheProbe() async {
    let now = Date(timeIntervalSince1970: 2_000)
    let probe = WatcherStubProbe([
        watcherCredential("new", expiresAt: Date(timeIntervalSince1970: 3_000))
    ])
    let sleeper = FakeSleeper()
    var attempts = 0
    let watcher = ClaudeReconnectWatcher(
        probe: probe,
        sleeper: { duration in await sleeper.sleep(duration) },
        now: { now },
        // Models refreshAll already being in flight for the whole window, which
        // makes refreshClaudeAfterCredentialRotation() return false every time.
        onRotationDetected: {
            attempts += 1
            return false
        }
    )

    watcher.activate(currentState: .sessionExpired)
    for _ in 0..<200 {
        await Task.yield()
    }

    #expect(attempts == 1)
    #expect(probe.callCount == 1)
    #expect(sleeper.pendingTicks == 1)
    watcher.stop()
}

@MainActor
@Test
func firstReadableProbeUsesTheCurrentStateNotTheStateThatStartedTheWatch() async {
    let now = Date(timeIntervalSince1970: 2_000)
    let probe = WatcherStubProbe([
        .unavailable,
        watcherCredential("new", expiresAt: Date(timeIntervalSince1970: 3_000))
    ])
    let sleeper = FakeSleeper()
    var refreshCount = 0
    let watcher = ClaudeReconnectWatcher(
        probe: probe,
        sleeper: { duration in await sleeper.sleep(duration) },
        now: { now },
        onRotationDetected: {
            refreshCount += 1
            return true
        }
    )

    // An unreadable first probe leaves no baseline, so the next readable probe
    // is still judged by the immediate rule.
    watcher.activate(currentState: .tokenInvalid)
    for _ in 0..<40 {
        if sleeper.pendingTicks == 1 {
            break
        }
        await Task.yield()
    }
    #expect(refreshCount == 0)

    // The live watch cannot restart, so it must read the new state rather than
    // the tokenInvalid it was started with — which would never refresh.
    watcher.connectorStateDidChange(to: .sessionExpired)
    sleeper.fireOneTick()
    for _ in 0..<40 {
        if refreshCount == 1 {
            break
        }
        await Task.yield()
    }

    #expect(refreshCount == 1)
    watcher.stop()
}
