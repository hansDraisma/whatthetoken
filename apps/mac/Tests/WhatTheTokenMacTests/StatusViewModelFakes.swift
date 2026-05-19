import Foundation
@testable import WhatTheTokenMac

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0

    var value: Int { lock.withLock { _value } }

    func increment() {
        lock.withLock { _value += 1 }
    }
}

private func testConnectorSource() -> ConnectorSource {
    ConnectorSource(
        connector: "test",
        state: .connected,
        label: "Test",
        parserVersion: "v1",
        deviceId: "test_device"
    )
}

private func stubConnectorStatus(product: String) -> ConnectorStatus {
    ConnectorStatus(
        product: product,
        source: testConnectorSource(),
        message: "ok"
    )
}

private func stubClaudeResult() -> ClaudeConnectorResult {
    ClaudeConnectorResult(snapshots: [], status: stubConnectorStatus(product: "claude_code"))
}

private func stubCodexResult() -> CodexConnectorResult {
    CodexConnectorResult(snapshots: [], status: stubConnectorStatus(product: "codex"))
}

final class RecordingClaudeRefresher: ClaudeConnectorRefreshing, @unchecked Sendable {
    let onRefresh: @Sendable () -> Void

    init(onRefresh: @escaping @Sendable () -> Void = {}) {
        self.onRefresh = onRefresh
    }

    func refresh() async throws -> ClaudeConnectorResult {
        onRefresh()
        return stubClaudeResult()
    }
}

final class SlowClaudeRefresher: ClaudeConnectorRefreshing, @unchecked Sendable {
    let counter: Counter
    let sleepNanoseconds: UInt64

    init(counter: Counter, sleepNanoseconds: UInt64 = 50_000_000) {
        self.counter = counter
        self.sleepNanoseconds = sleepNanoseconds
    }

    func refresh() async throws -> ClaudeConnectorResult {
        counter.increment()
        try? await Task.sleep(nanoseconds: sleepNanoseconds)
        return stubClaudeResult()
    }
}

final class NoopClaudeRefresher: ClaudeConnectorRefreshing, @unchecked Sendable {
    func refresh() async throws -> ClaudeConnectorResult {
        stubClaudeResult()
    }
}

final class NoopCodexRefresher: CodexConnectorRefreshing, @unchecked Sendable {
    func refresh() async throws -> CodexConnectorResult {
        stubCodexResult()
    }
}

final class SlowCodexRefresher: CodexConnectorRefreshing, @unchecked Sendable {
    let counter: Counter

    init(counter: Counter) {
        self.counter = counter
    }

    func refresh() async throws -> CodexConnectorResult {
        counter.increment()
        try? await Task.sleep(nanoseconds: 50_000_000)
        return stubCodexResult()
    }
}

final class RecordingCodexRefresher: CodexConnectorRefreshing, @unchecked Sendable {
    let onRefresh: @Sendable () -> Void

    init(onRefresh: @escaping @Sendable () -> Void = {}) {
        self.onRefresh = onRefresh
    }

    func refresh() async throws -> CodexConnectorResult {
        onRefresh()
        return stubCodexResult()
    }
}

final class SnapshotClaudeRefresher: ClaudeConnectorRefreshing, @unchecked Sendable {
    let snapshots: [UsageSnapshot]

    init(snapshots: [UsageSnapshot]) {
        self.snapshots = snapshots
    }

    func refresh() async throws -> ClaudeConnectorResult {
        ClaudeConnectorResult(
            snapshots: snapshots,
            status: ConnectorStatus(
                product: "claude_code",
                source: testConnectorSource(),
                message: "Claude Code connected"
            )
        )
    }
}

final class ThrowingClaudeRefresher: ClaudeConnectorRefreshing, @unchecked Sendable {
    func refresh() async throws -> ClaudeConnectorResult {
        throw SyntheticStatusViewModelError()
    }
}

struct SyntheticStatusViewModelError: Error {}

enum UsageSnapshotFixture {
    static func claudeSample() -> UsageSnapshot {
        UsageSnapshot(
            id: "test_claude_1",
            userAccountId: "u",
            provider: "anthropic",
            product: "claude_code",
            surface: "cli",
            poolKey: "user",
            windowKey: "weekly",
            unit: "messages",
            used: 0,
            limit: 100,
            remaining: 100,
            utilization: 0.0,
            resetAt: nil,
            lastUpdatedAt: "2026-05-07T00:00:00Z",
            confidence: "verified",
            undercountRisk: "none",
            staleReason: nil,
            display: nil,
            source: testConnectorSource()
        )
    }

    static func codexSample() -> UsageSnapshot {
        UsageSnapshot(
            id: "test_codex_1",
            userAccountId: "u",
            provider: "openai",
            product: "codex",
            surface: "app_server",
            poolKey: "user",
            windowKey: "weekly",
            unit: "messages",
            used: 0,
            limit: 100,
            remaining: 100,
            utilization: 0.0,
            resetAt: nil,
            lastUpdatedAt: "2026-05-07T00:00:00Z",
            confidence: "verified",
            undercountRisk: "none",
            staleReason: nil,
            display: nil,
            source: testConnectorSource()
        )
    }

    static func claudeCriticalSample() -> UsageSnapshot {
        let snapshot = claudeSample()
        return usageSample(from: snapshot, used: 95, remaining: 5, utilization: 0.95)
    }

    static func claudeLowSample() -> UsageSnapshot {
        let snapshot = claudeSample()
        return usageSample(from: snapshot, used: 80, remaining: 20, utilization: 0.80)
    }

    static func claudeEmptySample() -> UsageSnapshot {
        let snapshot = claudeSample()
        return usageSample(from: snapshot, used: 100, remaining: 0, utilization: 1.0)
    }

    static func codexCriticalSample() -> UsageSnapshot {
        let snapshot = codexSample()
        return usageSample(from: snapshot, used: 95, remaining: 5, utilization: 0.95)
    }

    static func claudeStaleSample() -> UsageSnapshot {
        let snapshot = claudeSample()
        return UsageSnapshot(
            id: snapshot.id,
            userAccountId: snapshot.userAccountId,
            provider: snapshot.provider,
            product: snapshot.product,
            surface: snapshot.surface,
            poolKey: snapshot.poolKey,
            windowKey: snapshot.windowKey,
            unit: snapshot.unit,
            used: snapshot.used,
            limit: snapshot.limit,
            remaining: snapshot.remaining,
            utilization: snapshot.utilization,
            resetAt: snapshot.resetAt,
            lastUpdatedAt: snapshot.lastUpdatedAt,
            confidence: snapshot.confidence,
            undercountRisk: snapshot.undercountRisk,
            staleReason: "test_stale",
            display: snapshot.display,
            source: snapshot.source
        )
    }

    static func claudeIncludedSample(
        remaining: Double,
        utilization: Double,
        windowKey: String = "five_hour",
        staleReason: String? = nil
    ) -> UsageSnapshot {
        let used = utilization * 100
        return UsageSnapshot(
            id: "snap_anthropic_claude_code_included_\(windowKey)",
            userAccountId: "local_user",
            provider: "anthropic",
            product: "claude_code",
            surface: "cli",
            poolKey: "anthropic_claude_subscription",
            windowKey: windowKey,
            unit: "utilization",
            used: used,
            limit: 100,
            remaining: remaining,
            utilization: utilization,
            resetAt: nil,
            lastUpdatedAt: "2026-05-08T08:00:00.000Z",
            confidence: "verified",
            undercountRisk: "possible",
            staleReason: staleReason,
            display: nil,
            source: testConnectorSource()
        )
    }

    static func claudeCreditsSample(remaining: Double, limit: Double = 100) -> UsageSnapshot {
        let used = max(limit - remaining, 0)
        return UsageSnapshot(
            id: "snap_anthropic_claude_code_extra_usage",
            userAccountId: "local_user",
            provider: "anthropic",
            product: "claude_code",
            surface: "cli",
            poolKey: "anthropic_claude_extra_usage",
            windowKey: "monthly_extra_usage",
            unit: "credits",
            used: used,
            limit: limit,
            remaining: remaining,
            utilization: limit > 0 ? used / limit : 0,
            resetAt: nil,
            lastUpdatedAt: "2026-05-08T08:00:00.000Z",
            confidence: "verified",
            undercountRisk: "possible",
            staleReason: nil,
            display: nil,
            source: testConnectorSource()
        )
    }

    static func codexIncludedSample(
        remaining: Double,
        utilization: Double,
        windowKey: String = "primary_rolling_300m",
        bucketKey: String = "codex_d4cde064",
        staleReason: String? = nil
    ) -> UsageSnapshot {
        let used = utilization * 100
        return UsageSnapshot(
            id: "snap_openai_codex_included_\(bucketKey)",
            userAccountId: "local_user",
            provider: "openai",
            product: "codex",
            surface: "aggregate",
            poolKey: "openai_codex_\(bucketKey)",
            windowKey: windowKey,
            unit: "utilization",
            used: used,
            limit: 100,
            remaining: remaining,
            utilization: utilization,
            resetAt: nil,
            lastUpdatedAt: "2026-05-08T08:00:00.000Z",
            confidence: "observed",
            undercountRisk: "possible",
            staleReason: staleReason,
            display: UsageSnapshotDisplay(poolLabel: "Codex", windowLabel: "5 hour usage limit"),
            source: testConnectorSource()
        )
    }

    static func codexCreditsSample(
        remaining: Double,
        unit: String = "credits",
        used: Double? = nil,
        limit: Double? = nil,
        utilization: Double? = nil
    ) -> UsageSnapshot {
        UsageSnapshot(
            id: "snap_openai_codex_credits",
            userAccountId: "local_user",
            provider: "openai",
            product: "codex",
            surface: "aggregate",
            poolKey: "openai_codex_credits",
            windowKey: "credits_remaining",
            unit: unit,
            used: used,
            limit: limit,
            remaining: remaining,
            utilization: utilization,
            resetAt: nil,
            lastUpdatedAt: "2026-05-08T08:00:00.000Z",
            confidence: "observed",
            undercountRisk: "possible",
            staleReason: nil,
            display: UsageSnapshotDisplay(poolLabel: "Codex", windowLabel: "Credits remaining"),
            source: testConnectorSource()
        )
    }

    private static func usageSample(
        from snapshot: UsageSnapshot,
        used: Double,
        remaining: Double,
        utilization: Double
    ) -> UsageSnapshot {
        UsageSnapshot(
            id: snapshot.id,
            userAccountId: snapshot.userAccountId,
            provider: snapshot.provider,
            product: snapshot.product,
            surface: snapshot.surface,
            poolKey: snapshot.poolKey,
            windowKey: snapshot.windowKey,
            unit: "utilization",
            used: used,
            limit: 100,
            remaining: remaining,
            utilization: utilization,
            resetAt: snapshot.resetAt,
            lastUpdatedAt: snapshot.lastUpdatedAt,
            confidence: snapshot.confidence,
            undercountRisk: snapshot.undercountRisk,
            staleReason: snapshot.staleReason,
            display: snapshot.display,
            source: snapshot.source
        )
    }
}
