# Contextual Provider Availability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace raw worst-row provider health with contextual availability so optional fallback credits do not make Claude or Codex look critically low while included usage is still available.

**Architecture:** Add a pure presentation-layer `ProviderAvailability` model that classifies selected-provider snapshots into included quota and fallback credit lanes, and exposes distinct availability cases for "critical with fallback" vs "fallback only" vs plain "low" so banner copy maps unambiguously. `BannerState` reads availability instead of raw `worstUsageState()`. `StatusRowCopy` uses neutral copy for zero fallback credits, and `StatusRowDisplayModel` tints the empty fallback row red only when no usable path remains.

**Tech Stack:** Swift 6, SwiftUI, `@MainActor` presentation projections, swift-testing.

---

## File Structure

- Create: `apps/mac/Sources/WhatTheTokenMac/ViewModels/ProviderAvailability.swift`
  - Owns lane classification, included worst-of, fallback tri-state, and availability cases.
  - Adds a `ProviderTab.from(snapshot:)` helper used here and by `StatusSectionDisplayModel`.
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/BannerState.swift`
  - `BannerState.from(...)` delegates the `.connected` branch to `ProviderAvailability`.
  - `BannerCopy` gets `criticalLowFallback`, `fallbackOnly`, and an updated `low` string per spec §14.
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusRowCopy.swift`
  - Empty fallback credit rows render `No extra credits available` instead of `Out of credits`.
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusRowDisplayModel.swift`
  - Initializer takes a `providerAvailability: ProviderAvailability` argument.
  - Empty fallback rows suppress red hero/status/bar styling unless provider availability is `.critical`.
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusSectionDisplayModel.swift`
  - Computes `ProviderAvailability` once per section and passes it into row construction.
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelFakes.swift`
  - Adds shared fixture helpers used by every test in this plan.
- Test: `apps/mac/Tests/WhatTheTokenMacTests/Presentation/ProviderAvailabilityTests.swift`
  - Lane-classification matrix tests for Claude and Codex, including stale precedence.
- Test: `apps/mac/Tests/WhatTheTokenMacTests/Presentation/BannerStateTests.swift`
  - Screenshot regression, fallback-only banner, critical-with-fallback banner, hint-suppression.
- Test: `apps/mac/Tests/WhatTheTokenMacTests/StatusRowCopyTests.swift`
  - Zero fallback credits render `No extra credits available`.
- Test: `apps/mac/Tests/WhatTheTokenMacTests/StatusRowDisplayModelTests.swift`
  - Empty fallback row shows no red hero/status/bar styling unless provider availability is `.critical`.

---

## Task 1: Add Shared Snapshot Fixture Helpers

Sequenced first so every later test consumes the same fixtures. Avoids the duplicate-helper drift that would otherwise appear in the availability tests.

**Files:**
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelFakes.swift`
- Read: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelFakes.swift` to confirm `testConnectorSource()` and existing fixtures (`claudeSample`, `codexSample`, …) before adding new ones.

- [ ] **Step 1: Append fixture helpers to `enum UsageSnapshotFixture`**

```swift
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
```

The `bucketKey` parameter on `codexIncludedSample` matches the dynamic `openai_codex_<bucketKey>` form produced by `CodexUsageMapper.swift`; it is parameterized so the tightened Codex lane filter (`poolKey != "openai_codex_credits"`) can be exercised against realistic keys.

- [ ] **Step 2: Build and run existing tests**

```bash
cd apps/mac && swift test
```

Expected: PASS unchanged. Adding helpers does not affect any existing test.

- [ ] **Step 3: Commit**

```bash
git add apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelFakes.swift
git commit -m "test(mac): add shared fallback-credit and included-quota snapshot fixtures"
```

---

## Task 2: Add ProviderAvailability Matrix Tests (Failing)

**Files:**
- Create: `apps/mac/Tests/WhatTheTokenMacTests/Presentation/ProviderAvailabilityTests.swift`

- [ ] **Step 1: Write matrix tests using `UsageSnapshotFixture`**

```swift
import Testing
@testable import WhatTheTokenMac

@Suite struct ProviderAvailabilityTests {
    // MARK: - Claude lane matrix

    @Test func claude_includedHealthy_fallbackMissing_isAvailable() {
        let snapshots = [UsageSnapshotFixture.claudeIncludedSample(remaining: 62, utilization: 0.38)]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .available)
    }

    @Test func claude_includedHealthy_fallbackZero_isAvailable() {
        let snapshots = [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 62, utilization: 0.38),
            UsageSnapshotFixture.claudeCreditsSample(remaining: 0)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .available)
    }

    @Test func claude_includedHealthy_fallbackPositive_isAvailable() {
        let snapshots = [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 88, utilization: 0.12, windowKey: "seven_day"),
            UsageSnapshotFixture.claudeCreditsSample(remaining: 20)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .available)
    }

    @Test func claude_includedLow_fallbackZero_isLow() {
        let snapshots = [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 20, utilization: 0.80, windowKey: "seven_day"),
            UsageSnapshotFixture.claudeCreditsSample(remaining: 0)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .low)
    }

    @Test func claude_includedCritical_fallbackPositive_isCriticalWithFallback() {
        let snapshots = [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 5, utilization: 0.95),
            UsageSnapshotFixture.claudeCreditsSample(remaining: 20)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .criticalWithFallback)
    }

    @Test func claude_includedCritical_fallbackZero_isCritical() {
        let snapshots = [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 5, utilization: 0.95),
            UsageSnapshotFixture.claudeCreditsSample(remaining: 0)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .critical)
    }

    @Test func claude_includedEmpty_fallbackPositive_isFallbackOnly() {
        let snapshots = [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 0, utilization: 1.0),
            UsageSnapshotFixture.claudeCreditsSample(remaining: 20)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .fallbackOnly)
    }

    @Test func claude_includedEmpty_fallbackMissing_isCritical() {
        let snapshots = [UsageSnapshotFixture.claudeIncludedSample(remaining: 0, utilization: 1.0)]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .critical)
    }

    @Test func claude_includedEmpty_fallbackZero_isCritical() {
        let snapshots = [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 0, utilization: 1.0),
            UsageSnapshotFixture.claudeCreditsSample(remaining: 0)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .critical)
    }

    // MARK: - Codex lane matrix

    @Test func codex_includedHealthy_creditsMissing_isAvailable() {
        let snapshots = [
            UsageSnapshotFixture.codexIncludedSample(remaining: 75, utilization: 0.25)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .codex) == .available)
    }

    @Test func codex_includedHealthy_creditsZero_isAvailable() {
        let snapshots = [
            UsageSnapshotFixture.codexIncludedSample(remaining: 75, utilization: 0.25),
            UsageSnapshotFixture.codexCreditsSample(remaining: 0)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .codex) == .available)
    }

    @Test func codex_includedHealthy_creditsPositive_isAvailable() {
        let snapshots = [
            UsageSnapshotFixture.codexIncludedSample(remaining: 75, utilization: 0.25),
            UsageSnapshotFixture.codexCreditsSample(remaining: 25)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .codex) == .available)
    }

    @Test func codex_includedLow_creditsZero_isLow() {
        let snapshots = [
            UsageSnapshotFixture.codexIncludedSample(remaining: 20, utilization: 0.80),
            UsageSnapshotFixture.codexCreditsSample(remaining: 0)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .codex) == .low)
    }

    @Test func codex_includedCritical_creditsPositive_isCriticalWithFallback() {
        let snapshots = [
            UsageSnapshotFixture.codexIncludedSample(remaining: 5, utilization: 0.95),
            UsageSnapshotFixture.codexCreditsSample(remaining: 25)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .codex) == .criticalWithFallback)
    }

    @Test func codex_includedCritical_creditsZero_isCritical() {
        let snapshots = [
            UsageSnapshotFixture.codexIncludedSample(remaining: 5, utilization: 0.95),
            UsageSnapshotFixture.codexCreditsSample(remaining: 0)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .codex) == .critical)
    }

    @Test func codex_includedEmpty_creditsPositive_isFallbackOnly() {
        let snapshots = [
            UsageSnapshotFixture.codexIncludedSample(remaining: 0, utilization: 1.0),
            UsageSnapshotFixture.codexCreditsSample(remaining: 25)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .codex) == .fallbackOnly)
    }

    @Test func codex_includedEmpty_creditsMissing_isCritical() {
        let snapshots = [
            UsageSnapshotFixture.codexIncludedSample(remaining: 0, utilization: 1.0)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .codex) == .critical)
    }

    @Test func codex_includedEmpty_creditsZero_isCritical() {
        let snapshots = [
            UsageSnapshotFixture.codexIncludedSample(remaining: 0, utilization: 1.0),
            UsageSnapshotFixture.codexCreditsSample(remaining: 0)
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .codex) == .critical)
    }

    @Test func codex_creditsRowDoesNotLeakIntoIncludedLane() {
        // Regression: ensures the Codex included filter excludes openai_codex_credits even
        // though that row would otherwise pass a naive `unit == "utilization"` check on a
        // future schema where credits use utilization framing.
        let snapshots = [
            UsageSnapshotFixture.codexIncludedSample(remaining: 75, utilization: 0.25),
            UsageSnapshotFixture.codexCreditsSample(
                remaining: 0,
                unit: "utilization",
                used: 100,
                limit: 100,
                utilization: 1.0
            )
        ]
        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .codex) == .available)
    }

    // MARK: - Stale precedence

    @Test func staleOverridesAvailableLowCriticalWithFallbackFallbackOnlyAndCritical() {
        #expect(ProviderAvailability.from(snapshots: [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 62, utilization: 0.38, staleReason: "old")
        ], tab: .claude) == .stale)

        #expect(ProviderAvailability.from(snapshots: [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 20, utilization: 0.80, windowKey: "seven_day", staleReason: "old")
        ], tab: .claude) == .stale)

        #expect(ProviderAvailability.from(snapshots: [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 5, utilization: 0.95, staleReason: "old"),
            UsageSnapshotFixture.claudeCreditsSample(remaining: 20)
        ], tab: .claude) == .stale)

        #expect(ProviderAvailability.from(snapshots: [
            UsageSnapshotFixture.claudeIncludedSample(remaining: 0, utilization: 1.0, staleReason: "old"),
            UsageSnapshotFixture.claudeCreditsSample(remaining: 20)
        ], tab: .claude) == .stale)

        #expect(ProviderAvailability.from(snapshots: [
            UsageSnapshotFixture.codexIncludedSample(remaining: 0, utilization: 1.0, staleReason: "old"),
            UsageSnapshotFixture.codexCreditsSample(remaining: 0)
        ], tab: .codex) == .stale)
    }
}
```

- [ ] **Step 2: Run the new tests and verify they fail**

```bash
cd apps/mac && swift test --filter ProviderAvailabilityTests
```

Expected: FAIL because `ProviderAvailability` does not exist yet.

- [ ] **Step 3: Commit the failing tests**

```bash
git add apps/mac/Tests/WhatTheTokenMacTests/Presentation/ProviderAvailabilityTests.swift
git commit -m "test(mac): define contextual provider availability matrix"
```

---

## Task 3: Implement ProviderAvailability

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/ViewModels/ProviderAvailability.swift`

- [ ] **Step 1: Add the availability model and `ProviderTab.from(snapshot:)` helper**

```swift
import Foundation

extension ProviderTab {
    /// Single source of truth for `(provider, product) → ProviderTab` classification.
    /// Reused by `ProviderAvailability.from(snapshots:tab:)` and
    /// `StatusSectionDisplayModel` so a future provider/product addition only changes one place.
    static func from(snapshot: UsageSnapshot) -> ProviderTab? {
        switch (snapshot.provider, snapshot.product) {
        case ("anthropic", "claude_code"): return .claude
        case ("openai", "codex"): return .codex
        default: return nil
        }
    }
}

enum ProviderAvailability: Equatable, Sendable {
    case available
    case low
    case criticalWithFallback
    case fallbackOnly
    case critical
    case stale

    static func from(snapshots: [UsageSnapshot], tab: ProviderTab) -> ProviderAvailability {
        let providerSnapshots = snapshots.filter { ProviderTab.from(snapshot: $0) == tab }

        if providerSnapshots.contains(where: { $0.staleReason != nil }) {
            return .stale
        }

        let included = providerSnapshots.filter { isIncluded($0, tab: tab) }
        let fallback = providerSnapshots.filter { isFallback($0, tab: tab) }

        let includedWorst = worstIncludedState(included)
        let fallbackLane = FallbackLane(snapshots: fallback)

        switch (includedWorst, fallbackLane) {
        case (.healthy, _):
            return .available
        case (.low, _):
            return .low
        case (.critical, .positive):
            return .criticalWithFallback
        case (.critical, .zero), (.critical, .missing):
            return .critical
        case (.empty, .positive):
            return .fallbackOnly
        case (.empty, .zero), (.empty, .missing):
            return .critical
        }
    }

    // MARK: - Lane filters (spec §14)

    private static func isIncluded(_ snapshot: UsageSnapshot, tab: ProviderTab) -> Bool {
        switch tab {
        case .claude:
            return snapshot.poolKey == "anthropic_claude_subscription"
        case .codex:
            // Tightened: explicitly exclude the credits poolKey so a future schema change
            // that frames credits as utilization cannot leak into the included lane.
            return snapshot.unit == "utilization"
                && snapshot.poolKey != "openai_codex_credits"
        }
    }

    private static func isFallback(_ snapshot: UsageSnapshot, tab: ProviderTab) -> Bool {
        switch tab {
        case .claude: return snapshot.poolKey == "anthropic_claude_extra_usage"
        case .codex:  return snapshot.poolKey == "openai_codex_credits"
        }
    }

    // MARK: - Lane aggregation

    /// Lane-scoped worst-of, distinct from `ProviderTabModel.Body.connected(_, worst:)`
    /// which aggregates across every snapshot for the provider.
    private static func worstIncludedState(_ included: [UsageSnapshot]) -> StatusUsageState {
        let states = included.map(StatusUsageState.init(snapshot:))
        if states.contains(.empty)    { return .empty }
        if states.contains(.critical) { return .critical }
        if states.contains(.low)      { return .low }
        return .healthy
    }

    private enum FallbackLane: Equatable {
        case missing, zero, positive

        init(snapshots: [UsageSnapshot]) {
            if snapshots.isEmpty { self = .missing; return }
            self = snapshots.contains(where: { StatusUsageState(snapshot: $0) != .empty }) ? .positive : .zero
        }
    }
}

extension ProviderAvailability {
    /// True when the provider has a usable path to continue work (banner is informational, not blocking).
    var isUsable: Bool {
        switch self {
        case .available, .low, .criticalWithFallback, .fallbackOnly: return true
        case .critical, .stale:                                      return false
        }
    }
}
```

- [ ] **Step 2: Run availability tests**

```bash
cd apps/mac && swift test --filter ProviderAvailabilityTests
```

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/ProviderAvailability.swift
git commit -m "feat(mac): add contextual provider availability model"
```

---

## Task 4: Switch BannerState To ProviderAvailability

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/BannerState.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/Presentation/BannerStateTests.swift`

- [ ] **Step 1: Add failing banner tests**

Append to `BannerStateTests`:

```swift
@MainActor
@Test func banner_claudeIncludedHealthyAndExtraCreditsZero_isHidden() {
    let included = UsageSnapshotFixture.claudeIncludedSample(remaining: 62, utilization: 0.38)
    let credits = UsageSnapshotFixture.claudeCreditsSample(remaining: 0)
    let vm = StatusViewModel(snapshots: [included, credits], connectorState: .connected)

    #expect(BannerState.from(viewModel: vm, selected: .claude) == .hidden)
}

@MainActor
@Test func banner_codexIncludedHealthyAndCreditsZero_isHidden() {
    let included = UsageSnapshotFixture.codexIncludedSample(remaining: 75, utilization: 0.25)
    let credits = UsageSnapshotFixture.codexCreditsSample(remaining: 0)
    let vm = StatusViewModel(
        snapshots: [included, credits],
        connectorState: .notConnected,
        codexConnectorState: .connected
    )

    #expect(BannerState.from(viewModel: vm, selected: .codex) == .hidden)
}

@MainActor
@Test func banner_includedEmptyAndCreditsPositive_isFallbackOnlyCopy() {
    let included = UsageSnapshotFixture.claudeIncludedSample(remaining: 0, utilization: 1.0)
    let credits = UsageSnapshotFixture.claudeCreditsSample(remaining: 25)
    let vm = StatusViewModel(snapshots: [included, credits], connectorState: .connected)

    #expect(BannerState.from(viewModel: vm, selected: .claude)
            == .low(text: "Claude Code included usage is exhausted. Extra credits available."))
}

@MainActor
@Test func banner_includedCriticalAndCreditsPositive_isCriticalWithFallbackCopy() {
    let included = UsageSnapshotFixture.claudeIncludedSample(remaining: 5, utilization: 0.95)
    let credits = UsageSnapshotFixture.claudeCreditsSample(remaining: 25)
    let vm = StatusViewModel(snapshots: [included, credits], connectorState: .connected)

    #expect(BannerState.from(viewModel: vm, selected: .claude)
            == .low(text: "Claude Code included usage is critically low. Extra credits available."))
}

@MainActor
@Test func banner_includedEmptyAndCreditsZero_isCritical() {
    let included = UsageSnapshotFixture.claudeIncludedSample(remaining: 0, utilization: 1.0)
    let credits = UsageSnapshotFixture.claudeCreditsSample(remaining: 0)
    let vm = StatusViewModel(snapshots: [included, credits], connectorState: .connected)

    #expect(BannerState.from(viewModel: vm, selected: .claude)
            == .critical(text: "Claude Code is out of usable quota"))
}

@MainActor
@Test func banner_fallbackOnly_doesNotAppendCrossProviderHint_evenWhenOtherIsHealthy() {
    let claudeIncluded = UsageSnapshotFixture.claudeIncludedSample(remaining: 0, utilization: 1.0)
    let claudeCredits = UsageSnapshotFixture.claudeCreditsSample(remaining: 25)
    let codexHealthy = UsageSnapshotFixture.codexIncludedSample(remaining: 75, utilization: 0.25)
    let vm = StatusViewModel(
        snapshots: [claudeIncluded, claudeCredits, codexHealthy],
        connectorState: .connected,
        codexConnectorState: .connected
    )

    let banner = BannerState.from(viewModel: vm, selected: .claude)

    #expect(banner == .low(text: "Claude Code included usage is exhausted. Extra credits available."))
}

@MainActor
@Test func banner_criticalWithFallback_doesNotAppendHint_evenWhenOtherIsHealthy() {
    let claudeIncluded = UsageSnapshotFixture.claudeIncludedSample(remaining: 5, utilization: 0.95)
    let claudeCredits = UsageSnapshotFixture.claudeCreditsSample(remaining: 25)
    let codexHealthy = UsageSnapshotFixture.codexIncludedSample(remaining: 75, utilization: 0.25)
    let vm = StatusViewModel(
        snapshots: [claudeIncluded, claudeCredits, codexHealthy],
        connectorState: .connected,
        codexConnectorState: .connected
    )

    #expect(BannerState.from(viewModel: vm, selected: .claude)
            == .low(text: "Claude Code included usage is critically low. Extra credits available."))
}

@MainActor
@Test func banner_low_appendsHint_whenOtherIsHealthy() {
    let claudeIncluded = UsageSnapshotFixture.claudeIncludedSample(remaining: 20, utilization: 0.80, windowKey: "seven_day")
    let codexHealthy = UsageSnapshotFixture.codexIncludedSample(remaining: 75, utilization: 0.25)
    let vm = StatusViewModel(
        snapshots: [claudeIncluded, codexHealthy],
        connectorState: .connected,
        codexConnectorState: .connected
    )

    let banner = BannerState.from(viewModel: vm, selected: .claude)

    if case let .low(text) = banner {
        #expect(text.contains("Claude Code included usage is running low"))
        #expect(text.contains("Codex has more room"))
    } else {
        Issue.record("Expected .low banner, got \(banner)")
    }
}
```

- [ ] **Step 2: Run banner tests and verify failures**

```bash
cd apps/mac && swift test --filter BannerStateTests
```

Expected: FAIL because `BannerState` still uses raw worst-row state and the new copy is not present.

- [ ] **Step 3: Update existing banner tests to lane-aware fixtures and canonical copy**

Before changing implementation, update existing `BannerStateTests` expectations that encode the old raw-worst-row behavior:

```swift
@Test func bannerCopyForCriticalProvider_codex() {
    #expect(BannerCopy.critical(provider: .codex) == "Codex is out of usable quota")
}

@Test func bannerCopyForLowProvider_claude() {
    #expect(BannerCopy.low(provider: .claude) == "Claude Code included usage is running low")
}

@Test func bannerCopyHintForOtherHealthy_codex() {
    #expect(BannerCopy.hint(otherHealthy: .codex) == "Codex has more room — consider switching new work.")
}
```

Replace old generic fixtures in banner tests with lane-aware fixtures:

```swift
// Healthy selected provider:
UsageSnapshotFixture.claudeIncludedSample(remaining: 62, utilization: 0.38)

// Low selected provider:
UsageSnapshotFixture.claudeIncludedSample(remaining: 20, utilization: 0.80)

// Critical selected provider:
UsageSnapshotFixture.claudeIncludedSample(remaining: 5, utilization: 0.95)

// Empty selected provider:
UsageSnapshotFixture.claudeIncludedSample(remaining: 0, utilization: 1.0)

// Healthy Codex provider for cross-provider hints:
UsageSnapshotFixture.codexIncludedSample(remaining: 75, utilization: 0.25)

// Critical Codex provider for "other is also critical":
UsageSnapshotFixture.codexIncludedSample(remaining: 5, utilization: 0.95)
```

Do not keep `UsageSnapshotFixture.claudeCriticalSample()`, `claudeLowSample()`, `claudeEmptySample()`, `codexSample()`, or `codexCriticalSample()` in banner tests that intend to exercise included-lane availability. Those older helpers use broad test `poolKey` values and are still valid for other tests, but they are not lane-classification fixtures.

- [ ] **Step 4: Update `BannerCopy` to spec §14 canonical strings**

In `BannerState.swift`, replace `BannerCopy` with:

```swift
enum BannerCopy {
    static let stale = "Usage may be outdated. Refresh to check current limits."
    static let disconnectedBoth = "Connect Claude or Codex in Settings."

    static func low(provider: ProviderTab) -> String {
        "\(provider.title) included usage is running low"
    }

    static func criticalLowFallback(provider: ProviderTab) -> String {
        "\(provider.title) included usage is critically low. Extra credits available."
    }

    static func fallbackOnly(provider: ProviderTab) -> String {
        "\(provider.title) included usage is exhausted. Extra credits available."
    }

    static func critical(provider: ProviderTab) -> String {
        "\(provider.title) is out of usable quota"
    }

    static func disconnected(selected: ProviderTab) -> String {
        "\(selected.title) is not connected. Open Settings to connect."
    }

    static func hint(otherHealthy other: ProviderTab) -> String {
        "\(other.title) has more room — consider switching new work."
    }
}
```

Note the em-dash in `hint(...)` matches spec §14.

- [ ] **Step 5: Replace the `.connected` branch in `BannerState.from`**

Keep the existing `.disconnected`, `.empty`, `.checking`, and `.error(.network/.schemaChanged)` branches above the `.connected` branch — they handle disconnection and explicit error bodies and must retain precedence over availability.

```swift
case let .connected(snapshots, _):
    let availability = ProviderAvailability.from(snapshots: snapshots, tab: selected)
    switch availability {
    case .available:
        return .hidden
    case .stale:
        return .stale(text: BannerCopy.stale)
    case .low:
        let text = BannerCopy.low(provider: selected)
        return .low(text: appendHintIfApplicable(text, otherTab: otherTab, otherBody: otherModel.body))
    case .criticalWithFallback:
        // Hint intentionally suppressed: the copy already conveys a usable path.
        return .low(text: BannerCopy.criticalLowFallback(provider: selected))
    case .fallbackOnly:
        // Hint intentionally suppressed for the same reason.
        return .low(text: BannerCopy.fallbackOnly(provider: selected))
    case .critical:
        let text = BannerCopy.critical(provider: selected)
        return .critical(text: appendHintIfApplicable(text, otherTab: otherTab, otherBody: otherModel.body))
    }
```

`appendHintIfApplicable` already exists (`BannerState.swift`) and only fires when the other body is `.connected(_, worst: .healthy)` — keep it unchanged.

- [ ] **Step 6: Run banner tests**

```bash
cd apps/mac && swift test --filter BannerStateTests
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/BannerState.swift \
        apps/mac/Tests/WhatTheTokenMacTests/Presentation/BannerStateTests.swift
git commit -m "feat(mac): make provider banner availability contextual"
```

---

## Task 5: Neutralize Fallback Credit Row Copy

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusRowCopy.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/StatusRowCopyTests.swift`

- [ ] **Step 1: Add failing row-copy tests**

Append to `StatusRowCopyTests`:

```swift
@Test func claudeFallbackCreditsZero_usesNeutralCopy() {
    let snapshot = UsageSnapshotFixture.claudeCreditsSample(remaining: 0)
    #expect(StatusRowCopy.heroText(snapshot: snapshot, state: .empty) == "No extra credits available")
}

@Test func codexCreditsZero_usesNeutralCopy() {
    let snapshot = UsageSnapshotFixture.codexCreditsSample(remaining: 0)
    #expect(StatusRowCopy.heroText(snapshot: snapshot, state: .empty) == "No extra credits available")
}
```

- [ ] **Step 2: Run tests and verify failure**

```bash
cd apps/mac && swift test --filter StatusRowCopyTests
```

Expected: FAIL. Claude fallback credits currently produce `"Out of credits"`; Codex balance-only credits currently produce `"0"`.

- [ ] **Step 3: Implement fallback credit detection in `StatusRowCopy.heroText`**

Insert this as the first branch inside `heroText(snapshot:state:)`, before the existing balance-only branch. This ordering matters: Codex credit rows currently have `used == nil` and `limit == nil`, so the balance-only branch would otherwise return `"0"` before the empty-state copy runs.

```swift
if Self.isFallbackCredits(snapshot), state == .empty {
    return "No extra credits available"
}
```

Add helper:

```swift
private static func isFallbackCredits(_ snapshot: UsageSnapshot) -> Bool {
    snapshot.poolKey == "anthropic_claude_extra_usage"
        || snapshot.poolKey == "openai_codex_credits"
}
```

- [ ] **Step 4: Run row-copy tests**

```bash
cd apps/mac && swift test --filter StatusRowCopyTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusRowCopy.swift \
        apps/mac/Tests/WhatTheTokenMacTests/StatusRowCopyTests.swift
git commit -m "feat(mac): use neutral copy for empty fallback credits"
```

---

## Task 6: Make Credit Row Styling Contextual

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusRowDisplayModel.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusSectionDisplayModel.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/StatusRowDisplayModelTests.swift`

- [ ] **Step 1: Add failing row-styling tests**

Append to `StatusRowDisplayModelTests`:

```swift
@Test func emptyFallbackCredits_doNotTintRed_whenProviderIsAvailable() {
    let row = StatusRowDisplayModel(
        snapshot: UsageSnapshotFixture.claudeCreditsSample(remaining: 0),
        sectionDefault: nil,
        now: Date(timeIntervalSince1970: 0),
        providerAvailability: .available
    )

    #expect(row.heroText == "No extra credits available")
    #expect(row.heroTintsRed == false)
    #expect(row.showsStatus == false)
    #expect(row.showsBar == false)
}

@Test func emptyFallbackCredits_doNotTintRed_whenProviderIsFallbackOnly() {
    let row = StatusRowDisplayModel(
        snapshot: UsageSnapshotFixture.claudeCreditsSample(remaining: 0),
        sectionDefault: nil,
        now: Date(timeIntervalSince1970: 0),
        providerAvailability: .fallbackOnly
    )

    #expect(row.heroTintsRed == false)
    #expect(row.showsStatus == false)
    #expect(row.showsBar == false)
}

@Test func emptyFallbackCredits_tintRed_whenProviderIsCritical() {
    let row = StatusRowDisplayModel(
        snapshot: UsageSnapshotFixture.claudeCreditsSample(remaining: 0),
        sectionDefault: nil,
        now: Date(timeIntervalSince1970: 0),
        providerAvailability: .critical
    )

    #expect(row.heroText == "No extra credits available")
    #expect(row.heroTintsRed == true)
    #expect(row.showsStatus == true)
    #expect(row.showsBar == true)
}
```

- [ ] **Step 2: Run tests and verify failure**

```bash
cd apps/mac && swift test --filter StatusRowDisplayModelTests
```

Expected: FAIL — `StatusRowDisplayModel.init` does not accept `providerAvailability`.

- [ ] **Step 3: Extend `StatusRowDisplayModel` initializer**

Change the initializer signature, then replace the existing `heroTintsRed`, `showsBar`, and `showsStatus` assignments with the availability-aware block below.

```swift
init(
    snapshot: UsageSnapshot,
    sectionDefault: StatusSectionDefault?,
    now: Date,
    providerAvailability: ProviderAvailability = .available
) {
    // … existing computation of `state`, `balanceOnly`, etc. …

    let neutralEmptyFallback = Self.isFallbackCredits(snapshot)
        && state == .empty
        && providerAvailability != .critical

    if Self.isFallbackCredits(snapshot) && state == .empty {
        heroTintsRed = providerAvailability == .critical
    } else {
        heroTintsRed = !balanceOnly && (state == .critical || state == .empty)
    }
    showsBar = neutralEmptyFallback ? false : Self.showsBar(snapshot: snapshot)
    showsStatus = neutralEmptyFallback ? false : !balanceOnly
}

private static func isFallbackCredits(_ snapshot: UsageSnapshot) -> Bool {
    snapshot.poolKey == "anthropic_claude_extra_usage"
        || snapshot.poolKey == "openai_codex_credits"
}
```

The default `providerAvailability: .available` keeps existing call sites compiling without behavioral change for non-fallback rows.

- [ ] **Step 4: Pass availability from `StatusSectionDisplayModel`**

In `StatusSectionDisplayModel.init(snapshots:now:)`, after `sectionDefault` is computed:

```swift
let providerTab = snapshots.first.flatMap(ProviderTab.from(snapshot:))
let providerAvailability = providerTab.map {
    ProviderAvailability.from(snapshots: snapshots, tab: $0)
} ?? .available

rows = snapshots.map {
    StatusRowDisplayModel(
        snapshot: $0,
        sectionDefault: sectionDefault,
        now: now,
        providerAvailability: providerAvailability
    )
}
```

`ProviderTab.from(snapshot:)` is the helper added in Task 3 — same source of truth as `ProviderAvailability.from`.

- [ ] **Step 5: Run row-display tests**

```bash
cd apps/mac && swift test --filter StatusRowDisplayModelTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusRowDisplayModel.swift \
        apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusSectionDisplayModel.swift \
        apps/mac/Tests/WhatTheTokenMacTests/StatusRowDisplayModelTests.swift
git commit -m "feat(mac): style fallback credit rows by provider availability"
```

---

## Task 7: Verification, Icon Alignment Check, And Rollback Note

**Files:** No code edits unless one of the verifications surfaces a regression.

- [ ] **Step 1: Run focused presentation tests**

```bash
cd apps/mac && swift test --filter "ProviderAvailabilityTests|BannerStateTests|StatusRowCopyTests|StatusRowDisplayModelTests"
```

Expected: PASS.

- [ ] **Step 2: Run full test suite**

```bash
cd apps/mac && swift test
```

Expected: PASS (218 baseline tests + the new presentation tests).

- [ ] **Step 3: Run release build**

```bash
cd apps/mac && swift build -c release
```

Expected: build completes successfully.

- [ ] **Step 4: Confirm menu-bar icon remains static**

```bash
grep -n "MenuBarExtra" apps/mac/Sources/WhatTheTokenMac/WhatTheTokenApp.swift
```

Expected: shows `MenuBarExtra("WhatTheToken", systemImage: "gauge")` with no dynamic tint, badge, or state-derived title. If the line has changed to a stateful form, the icon code MUST consume `ProviderAvailability` (per spec §14 future-icon clause) before merge.

- [ ] **Step 5: Guard against accidental raw worst-state icon logic**

```bash
grep -rn "worstUsageState\|StatusUsageState(snapshot" apps/mac/Sources/WhatTheTokenMac/WhatTheTokenApp.swift
```

Expected: no matches. Other source files (`ProviderTabModel.swift`, `ProviderAvailability.swift`, row display files) may legitimately use these symbols.

- [ ] **Step 6: Manual screenshot regression (best effort)**

This step requires real account state matching the screenshot, so it is condition-dependent. The unit tests in Tasks 2 and 4 are the primary regression guard; this step is a sanity check, not a gating verification.

If a real account with healthy session/weekly Claude usage and zero extra-usage credits is available:

1. Open the popover → Claude tab. The banner must NOT be `critical`. Either `.hidden` (if all included rows are healthy) or `.low` with the `criticalLowFallback` / `low` copy.
2. The `Extra usage credits` row hero text must be `No extra credits available`, not `Out of credits`.
3. The row must render in neutral styling, not red.
4. Repeat for Codex with healthy included usage and zero credits.

If the account state is not reproducible, record this on the PR and rely on the unit tests.

- [ ] **Step 7: Rollback note**

If a regression appears in production, the changes are independently revertable:

- `BannerState.swift` change (Task 4) can be reverted in isolation; `ProviderAvailability` is additive and safe to leave in place.
- `StatusRowDisplayModel` / `StatusSectionDisplayModel` changes (Task 6) revert independently of the banner change because the new `providerAvailability` parameter has a `.available` default.
- Row copy change (Task 5) reverts independently of banner and styling.

Document the chosen rollback path in the PR description.

- [ ] **Step 8: Commit any docs touched during implementation**

If implementation surfaced a spec/plan inaccuracy:

```bash
git add docs/superpowers/specs/2026-05-07-menu-bar-shell-design.md \
        docs/superpowers/plans/2026-05-08-contextual-provider-availability.md
git commit -m "docs(mac): correct contextual provider availability spec/plan"
```

If nothing changed, no commit.

---

## Self-Review Checklist

- **Spec coverage:** implements addendum §14 lanes (with Codex credits exclusion), aggregation (worst-of included, tri-state fallback), thresholds, six availability cases (`.available`, `.low`, `.criticalWithFallback`, `.fallbackOnly`, `.critical`, `.stale`), canonical banner strings, hint suppression for fallback states, row copy, and row styling.
- **Sequencing:** fixture helpers (Task 1) ship before any test that consumes them; availability tests (Task 2) precede implementation (Task 3); banner change (Task 4) lands after availability is in place.
- **Consolidation:** `ProviderTab.from(snapshot:)` is the single classifier consumed by `ProviderAvailability.from` and `StatusSectionDisplayModel`. No duplicate provider-discriminator logic.
- **Codex robustness:** included-lane filter excludes `openai_codex_credits` even though the credits row uses `unit == "credits"` today; defensive against future schema framing.
- **Banner copy parity:** `BannerCopy` strings match spec §14 verbatim, including the em-dash in `hint(otherHealthy:)`.
- **Hint suppression:** `.criticalWithFallback` and `.fallbackOnly` never append the cross-provider hint; covered by tests.
- **Type consistency:** `ProviderAvailability`, `ProviderTab`, `UsageSnapshot`, `StatusUsageState`, `BannerState`, and `UsageSnapshotFixture` names match the current codebase.
- **Scope control:** no persistence, account history, migrations, provider auth changes, or connector protocol changes are included.
- **Rollback path:** every code change is independently revertable; documented in Task 7.
