# Contextual Provider Availability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace raw worst-row provider health with contextual availability so optional fallback credits do not make Claude or Codex look critically low while included usage is still available.

**Architecture:** Add a pure presentation-layer `ProviderAvailability` model that classifies selected-provider snapshots into included quota and fallback credit lanes. `BannerState` and any stateful menu-bar icon logic read availability instead of raw `worstUsageState()`, while `StatusRowCopy` uses neutral copy for zero fallback credits.

**Tech Stack:** Swift 6, SwiftUI, `@MainActor` presentation projections, swift-testing.

---

## File Structure

- Create: `apps/mac/Sources/WhatTheTokenMac/ViewModels/ProviderAvailability.swift`
  - Owns lane classification, worst-of aggregation, fallback credit interpretation, and provider-level availability.
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/BannerState.swift`
  - Uses `ProviderAvailability` for selected-provider banner decisions.
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusRowCopy.swift`
  - Changes fallback credit zero copy from `Out of credits` to `No extra credits available`.
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusRowDisplayModel.swift`
  - Adds a lightweight context argument so fallback credit rows can use neutral or red styling based on provider availability.
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusSectionDisplayModel.swift`
  - Passes provider availability into row display models.
- Test: `apps/mac/Tests/WhatTheTokenMacTests/Presentation/ProviderAvailabilityTests.swift`
  - New availability matrix tests for Claude and Codex.
- Test: `apps/mac/Tests/WhatTheTokenMacTests/Presentation/BannerStateTests.swift`
  - Adds screenshot regression and fallback-only banner tests.
- Test: `apps/mac/Tests/WhatTheTokenMacTests/StatusRowCopyTests.swift`
  - Verifies zero fallback credits no longer produce `Out of credits`.
- Test: `apps/mac/Tests/WhatTheTokenMacTests/StatusRowDisplayModelTests.swift`
  - Verifies fallback credit zero row styling is neutral when included usage is usable and red only when no usable path remains.

---

## Task 1: Add ProviderAvailability Tests

**Files:**
- Create: `apps/mac/Tests/WhatTheTokenMacTests/Presentation/ProviderAvailabilityTests.swift`
- Read: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelFakes.swift`

- [ ] **Step 1: Write matrix tests before implementation**

Create `apps/mac/Tests/WhatTheTokenMacTests/Presentation/ProviderAvailabilityTests.swift`:

```swift
import Testing
@testable import WhatTheTokenMac

@Suite struct ProviderAvailabilityTests {
    @Test func claude_includedHealthy_fallbackMissing_isAvailable() {
        let snapshots = [
            claude(windowKey: "five_hour", remaining: 62, utilization: 0.38)
        ]

        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .available)
    }

    @Test func claude_includedHealthy_fallbackZero_isAvailable() {
        let snapshots = [
            claude(windowKey: "five_hour", remaining: 62, utilization: 0.38),
            claudeCredits(remaining: 0, limit: 100)
        ]

        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .available)
    }

    @Test func claude_includedHealthy_fallbackPositive_isAvailable() {
        let snapshots = [
            claude(windowKey: "seven_day", remaining: 88, utilization: 0.12),
            claudeCredits(remaining: 20, limit: 100)
        ]

        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .available)
    }

    @Test func claude_includedLow_fallbackZero_isLow() {
        let snapshots = [
            claude(windowKey: "seven_day", remaining: 20, utilization: 0.80),
            claudeCredits(remaining: 0, limit: 100)
        ]

        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .low)
    }

    @Test func claude_includedCritical_fallbackPositive_isLow() {
        let snapshots = [
            claude(windowKey: "five_hour", remaining: 5, utilization: 0.95),
            claudeCredits(remaining: 20, limit: 100)
        ]

        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .low)
    }

    @Test func claude_includedCritical_fallbackZero_isCritical() {
        let snapshots = [
            claude(windowKey: "five_hour", remaining: 5, utilization: 0.95),
            claudeCredits(remaining: 0, limit: 100)
        ]

        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .critical)
    }

    @Test func claude_includedEmpty_fallbackPositive_isFallbackOnly() {
        let snapshots = [
            claude(windowKey: "five_hour", remaining: 0, utilization: 1.0),
            claudeCredits(remaining: 20, limit: 100)
        ]

        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .fallbackOnly)
    }

    @Test func claude_includedEmpty_fallbackMissing_isCritical() {
        let snapshots = [
            claude(windowKey: "five_hour", remaining: 0, utilization: 1.0)
        ]

        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .critical)
    }

    @Test func claude_includedEmpty_fallbackZero_isCritical() {
        let snapshots = [
            claude(windowKey: "five_hour", remaining: 0, utilization: 1.0),
            claudeCredits(remaining: 0, limit: 100)
        ]

        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .claude) == .critical)
    }

    @Test func codex_includedHealthy_creditsZero_isAvailable() {
        let snapshots = [
            codex(windowKey: "primary_rolling_300m", remaining: 75, utilization: 0.25),
            codexCredits(remaining: 0)
        ]

        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .codex) == .available)
    }

    @Test func codex_includedEmpty_creditsPositive_isFallbackOnly() {
        let snapshots = [
            codex(windowKey: "primary_rolling_300m", remaining: 0, utilization: 1.0),
            codexCredits(remaining: 25)
        ]

        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .codex) == .fallbackOnly)
    }

    @Test func codex_includedEmpty_creditsZero_isCritical() {
        let snapshots = [
            codex(windowKey: "primary_rolling_300m", remaining: 0, utilization: 1.0),
            codexCredits(remaining: 0)
        ]

        #expect(ProviderAvailability.from(snapshots: snapshots, tab: .codex) == .critical)
    }

    @Test func staleOverridesAvailabilityStates() {
        #expect(ProviderAvailability.from(snapshots: [
            claude(windowKey: "five_hour", remaining: 62, utilization: 0.38, staleReason: "old")
        ], tab: .claude) == .stale)

        #expect(ProviderAvailability.from(snapshots: [
            claude(windowKey: "five_hour", remaining: 20, utilization: 0.80, staleReason: "old")
        ], tab: .claude) == .stale)

        #expect(ProviderAvailability.from(snapshots: [
            claude(windowKey: "five_hour", remaining: 0, utilization: 1.0, staleReason: "old"),
            claudeCredits(remaining: 20, limit: 100)
        ], tab: .claude) == .stale)

        #expect(ProviderAvailability.from(snapshots: [
            codex(windowKey: "primary_rolling_300m", remaining: 0, utilization: 1.0, staleReason: "old"),
            codexCredits(remaining: 0)
        ], tab: .codex) == .stale)
    }
}

private func claude(
    windowKey: String,
    remaining: Double,
    utilization: Double,
    staleReason: String? = nil
) -> UsageSnapshot {
    snapshot(
        provider: "anthropic",
        product: "claude_code",
        poolKey: "anthropic_claude_subscription",
        windowKey: windowKey,
        unit: "utilization",
        used: utilization * 100,
        limit: 100,
        remaining: remaining,
        utilization: utilization,
        staleReason: staleReason
    )
}

private func claudeCredits(remaining: Double, limit: Double) -> UsageSnapshot {
    snapshot(
        provider: "anthropic",
        product: "claude_code",
        poolKey: "anthropic_claude_extra_usage",
        windowKey: "monthly_extra_usage",
        unit: "credits",
        used: max(limit - remaining, 0),
        limit: limit,
        remaining: remaining,
        utilization: max(limit - remaining, 0) / limit,
        staleReason: nil
    )
}

private func codex(
    windowKey: String,
    remaining: Double,
    utilization: Double,
    staleReason: String? = nil
) -> UsageSnapshot {
    snapshot(
        provider: "openai",
        product: "codex",
        poolKey: "openai_codex_codex_d4cde064",
        windowKey: windowKey,
        unit: "utilization",
        used: utilization * 100,
        limit: 100,
        remaining: remaining,
        utilization: utilization,
        staleReason: staleReason
    )
}

private func codexCredits(remaining: Double) -> UsageSnapshot {
    snapshot(
        provider: "openai",
        product: "codex",
        poolKey: "openai_codex_credits",
        windowKey: "credits_remaining",
        unit: "credits",
        used: nil,
        limit: nil,
        remaining: remaining,
        utilization: nil,
        staleReason: nil,
        display: UsageSnapshotDisplay(poolLabel: "Codex", windowLabel: "Credits remaining")
    )
}

private func snapshot(
    provider: String,
    product: String,
    poolKey: String,
    windowKey: String,
    unit: String,
    used: Double?,
    limit: Double?,
    remaining: Double?,
    utilization: Double?,
    staleReason: String?,
    display: UsageSnapshotDisplay? = nil
) -> UsageSnapshot {
    UsageSnapshot(
        id: "snap_\(provider)_\(product)_\(poolKey)_\(windowKey)",
        userAccountId: "local_user",
        provider: provider,
        product: product,
        surface: "cli",
        poolKey: poolKey,
        windowKey: windowKey,
        unit: unit,
        used: used,
        limit: limit,
        remaining: remaining,
        utilization: utilization,
        resetAt: nil,
        lastUpdatedAt: "2026-05-08T08:00:00.000Z",
        confidence: "verified",
        undercountRisk: "possible",
        staleReason: staleReason,
        display: display,
        source: ConnectorSource(
            connector: "test",
            state: .connected,
            label: "Test",
            parserVersion: "test-v1",
            deviceId: "local_mac"
        )
    )
}
```

- [ ] **Step 2: Run the new tests and verify they fail**

Run:

```bash
cd apps/mac && swift test --filter ProviderAvailabilityTests
```

Expected: FAIL because `ProviderAvailability` does not exist.

- [ ] **Step 3: Commit the failing tests**

```bash
git add apps/mac/Tests/WhatTheTokenMacTests/Presentation/ProviderAvailabilityTests.swift
git commit -m "test(mac): define contextual provider availability matrix"
```

---

## Task 2: Implement ProviderAvailability

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/ViewModels/ProviderAvailability.swift`

- [ ] **Step 1: Add the availability model**

Create `apps/mac/Sources/WhatTheTokenMac/ViewModels/ProviderAvailability.swift`:

```swift
import Foundation

enum ProviderAvailability: Equatable, Sendable {
    case available
    case low
    case fallbackOnly
    case critical
    case stale
    case disconnected

    static func from(snapshots: [UsageSnapshot], tab: ProviderTab) -> ProviderAvailability {
        let providerSnapshots = snapshots.filter { snapshot in
            switch tab {
            case .claude:
                return snapshot.provider == "anthropic" && snapshot.product == "claude_code"
            case .codex:
                return snapshot.provider == "openai" && snapshot.product == "codex"
            }
        }

        if providerSnapshots.contains(where: { $0.staleReason != nil }) {
            return .stale
        }

        let included = providerSnapshots.filter { snapshot in
            switch tab {
            case .claude:
                return snapshot.poolKey == "anthropic_claude_subscription"
            case .codex:
                return snapshot.unit == "utilization"
            }
        }

        let fallback = providerSnapshots.filter { snapshot in
            switch tab {
            case .claude:
                return snapshot.poolKey == "anthropic_claude_extra_usage"
            case .codex:
                return snapshot.poolKey == "openai_codex_credits"
            }
        }

        let includedWorst = included.map(StatusUsageState.init(snapshot:)).worstCase(default: .healthy)
        let hasFallbackCapacity = fallback.contains { snapshot in
            StatusUsageState(snapshot: snapshot) != .empty
        }

        switch includedWorst {
        case .healthy:
            return .available
        case .low:
            return .low
        case .critical:
            return hasFallbackCapacity ? .low : .critical
        case .empty:
            return hasFallbackCapacity ? .fallbackOnly : .critical
        }
    }
}

extension ProviderAvailability {
    var isUsable: Bool {
        switch self {
        case .available, .low, .fallbackOnly:
            return true
        case .critical, .stale, .disconnected:
            return false
        }
    }
}

private extension Array where Element == StatusUsageState {
    func worstCase(default defaultValue: StatusUsageState) -> StatusUsageState {
        if contains(.empty) { return .empty }
        if contains(.critical) { return .critical }
        if contains(.low) { return .low }
        if contains(.healthy) { return .healthy }
        return defaultValue
    }
}
```

- [ ] **Step 2: Run availability tests**

Run:

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

## Task 3: Switch BannerState To ProviderAvailability

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/BannerState.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/Presentation/BannerStateTests.swift`

- [ ] **Step 1: Add banner regression tests**

Append to `BannerStateTests`:

```swift
@MainActor
@Test func banner_claudeIncludedHealthyAndExtraCreditsZero_isHidden() {
    let included = UsageSnapshotFixture.claudeIncludedSample(remaining: 62, utilization: 0.38)
    let credits = UsageSnapshotFixture.claudeCreditsSample(remaining: 0)
    let vm = StatusViewModel(snapshots: [included, credits], connectorState: .connected)

    let banner = BannerState.from(viewModel: vm, selected: .claude)

    #expect(banner == .hidden)
}

@MainActor
@Test func banner_codexIncludedHealthyAndCreditsZero_isHidden() {
    let included = UsageSnapshotFixture.codexIncludedSample(remaining: 75, utilization: 0.25)
    let credits = UsageSnapshotFixture.codexCreditsSample(remaining: 0)
    let vm = StatusViewModel(snapshots: [included, credits], codexConnectorState: .connected)

    let banner = BannerState.from(viewModel: vm, selected: .codex)

    #expect(banner == .hidden)
}

@MainActor
@Test func banner_includedEmptyAndCreditsPositive_isFallbackOnly() {
    let included = UsageSnapshotFixture.claudeIncludedSample(remaining: 0, utilization: 1.0)
    let credits = UsageSnapshotFixture.claudeCreditsSample(remaining: 25)
    let vm = StatusViewModel(snapshots: [included, credits], connectorState: .connected)

    let banner = BannerState.from(viewModel: vm, selected: .claude)

    #expect(banner == .low(text: "Claude Code included usage is exhausted. Extra credits available."))
}

@MainActor
@Test func banner_includedEmptyAndCreditsZero_isCritical() {
    let included = UsageSnapshotFixture.claudeIncludedSample(remaining: 0, utilization: 1.0)
    let credits = UsageSnapshotFixture.claudeCreditsSample(remaining: 0)
    let vm = StatusViewModel(snapshots: [included, credits], connectorState: .connected)

    let banner = BannerState.from(viewModel: vm, selected: .claude)

    #expect(banner == .critical(text: "Claude Code is out of usable quota"))
}
```

Also add the fixture helpers shown in Task 4 before running the tests.

- [ ] **Step 2: Run banner tests and verify failures**

Run:

```bash
cd apps/mac && swift test --filter BannerStateTests
```

Expected: FAIL because `BannerState` still uses raw worst-row state and fixture helpers are not added yet.

- [ ] **Step 3: Update banner copy**

Modify `BannerCopy` in `BannerState.swift`:

```swift
enum BannerCopy {
    static let stale = "Usage may be outdated. Refresh to check current limits."
    static let disconnectedBoth = "Connect Claude or Codex in Settings."

    static func critical(provider: ProviderTab) -> String {
        "\(provider.title) is out of usable quota"
    }

    static func low(provider: ProviderTab) -> String {
        "\(provider.title) included usage is running low"
    }

    static func fallbackOnly(provider: ProviderTab) -> String {
        "\(provider.title) included usage is exhausted. Extra credits available."
    }

    static func disconnected(selected: ProviderTab) -> String {
        "\(selected.title) is not connected. Open Settings to connect."
    }

    static func hint(otherHealthy other: ProviderTab) -> String {
        "\(other.title) has more room - consider switching new work."
    }
}
```

- [ ] **Step 4: Update `BannerState.from`**

Replace the `.connected` branch in `BannerState.from(viewModel:selected:)` with availability logic:

```swift
case let .connected(snapshots, _):
    let availability = ProviderAvailability.from(snapshots: snapshots, tab: selected)
    switch availability {
    case .available:
        return .hidden
    case .low:
        let text = BannerCopy.low(provider: selected)
        return .low(text: appendHintIfApplicable(text, otherTab: otherTab, otherBody: otherModel.body))
    case .fallbackOnly:
        return .low(text: BannerCopy.fallbackOnly(provider: selected))
    case .critical:
        let text = BannerCopy.critical(provider: selected)
        return .critical(text: appendHintIfApplicable(text, otherTab: otherTab, otherBody: otherModel.body))
    case .stale:
        return .stale(text: BannerCopy.stale)
    case .disconnected:
        return .disconnected(text: BannerCopy.disconnected(selected: selected))
    }
```

Keep the existing disconnected and error branches above this branch so disconnected and explicit network/schema errors retain precedence.

- [ ] **Step 5: Run banner tests**

Run:

```bash
cd apps/mac && swift test --filter BannerStateTests
```

Expected: PASS after fixture helpers are added in Task 4.

- [ ] **Step 6: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/BannerState.swift apps/mac/Tests/WhatTheTokenMacTests/Presentation/BannerStateTests.swift apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelFakes.swift
git commit -m "feat(mac): make provider banner availability contextual"
```

---

## Task 4: Add Snapshot Fixture Helpers

**Files:**
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelFakes.swift`

- [ ] **Step 1: Add fixture helpers**

Add these methods to `enum UsageSnapshotFixture`:

```swift
static func claudeCreditsSample(remaining: Double) -> UsageSnapshot {
    let limit = 100.0
    let used = max(limit - remaining, 0)
    return UsageSnapshot(
        id: "snap_anthropic_claude_code_extra_usage_test",
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
        utilization: used / limit,
        resetAt: nil,
        lastUpdatedAt: "2026-05-08T08:00:00.000Z",
        confidence: "verified",
        undercountRisk: "possible",
        staleReason: nil,
        display: nil,
        source: testConnectorSource()
    )
}

static func codexCreditsSample(remaining: Double) -> UsageSnapshot {
    UsageSnapshot(
        id: "snap_openai_codex_credits_test",
        userAccountId: "local_user",
        provider: "openai",
        product: "codex",
        surface: "aggregate",
        poolKey: "openai_codex_credits",
        windowKey: "credits_remaining",
        unit: "credits",
        used: nil,
        limit: nil,
        remaining: remaining,
        utilization: nil,
        resetAt: nil,
        lastUpdatedAt: "2026-05-08T08:00:00.000Z",
        confidence: "observed",
        undercountRisk: "possible",
        staleReason: nil,
        display: UsageSnapshotDisplay(poolLabel: "Codex", windowLabel: "Credits remaining"),
        source: testConnectorSource()
    )
}

static func claudeIncludedSample(remaining: Double, utilization: Double) -> UsageSnapshot {
    let used = utilization * 100
    return UsageSnapshot(
        id: "snap_anthropic_claude_code_included_test",
        userAccountId: "local_user",
        provider: "anthropic",
        product: "claude_code",
        surface: "cli",
        poolKey: "anthropic_claude_subscription",
        windowKey: "five_hour",
        unit: "utilization",
        used: used,
        limit: 100,
        remaining: remaining,
        utilization: utilization,
        resetAt: nil,
        lastUpdatedAt: "2026-05-08T08:00:00.000Z",
        confidence: "verified",
        undercountRisk: "possible",
        staleReason: nil,
        display: nil,
        source: testConnectorSource()
    )
}

static func codexIncludedSample(remaining: Double, utilization: Double) -> UsageSnapshot {
    let used = utilization * 100
    return UsageSnapshot(
        id: "snap_openai_codex_included_test",
        userAccountId: "local_user",
        provider: "openai",
        product: "codex",
        surface: "aggregate",
        poolKey: "openai_codex_codex_d4cde064",
        windowKey: "primary_rolling_300m",
        unit: "utilization",
        used: used,
        limit: 100,
        remaining: remaining,
        utilization: utilization,
        resetAt: nil,
        lastUpdatedAt: "2026-05-08T08:00:00.000Z",
        confidence: "observed",
        undercountRisk: "possible",
        staleReason: nil,
        display: UsageSnapshotDisplay(poolLabel: "Codex", windowLabel: "5 hour usage limit"),
        source: testConnectorSource()
    )
}
```

`testConnectorSource()` already exists in `StatusViewModelFakes.swift`; keep using that local helper rather than widening access.

- [ ] **Step 2: Run focused tests**

Run:

```bash
cd apps/mac && swift test --filter "ProviderAvailabilityTests|BannerStateTests"
```

Expected: PASS after Tasks 2 and 3 are implemented.

- [ ] **Step 3: Commit**

This task is committed with Task 3 because the banner tests depend on these helpers.

---

## Task 5: Neutralize Fallback Credit Row Copy

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusRowCopy.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/StatusRowCopyTests.swift`

- [ ] **Step 1: Add failing row-copy tests**

Append to `StatusRowCopyTests`:

```swift
@Test func fallbackCreditsZeroUsesNeutralCopy() {
    let snapshot = rowCopySnapshot(
        unit: "credits",
        remaining: 0,
        limit: 100,
        poolKey: "anthropic_claude_extra_usage",
        windowKey: "monthly_extra_usage"
    )

    #expect(StatusRowCopy.heroText(snapshot: snapshot, state: .empty) == "No extra credits available")
}

@Test func codexCreditsZeroUsesNeutralCopy() {
    let snapshot = rowCopySnapshot(
        unit: "credits",
        remaining: 0,
        limit: nil,
        poolKey: "openai_codex_credits",
        windowKey: "credits_remaining"
    )

    #expect(StatusRowCopy.heroText(snapshot: snapshot, state: .empty) == "No extra credits available")
}
```

If `rowCopySnapshot` does not currently accept `poolKey` and `windowKey`, extend that helper with defaulted arguments:

```swift
private func rowCopySnapshot(
    unit: String,
    remaining: Double?,
    utilization: Double? = nil,
    used: Double? = nil,
    limit: Double? = nil,
    poolKey: String = "p",
    windowKey: String = "five_hour"
) -> UsageSnapshot
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
cd apps/mac && swift test --filter "fallbackCreditsZeroUsesNeutralCopy|codexCreditsZeroUsesNeutralCopy"
```

Expected: FAIL because zero credits currently render `Out of credits` or `0`.

- [ ] **Step 3: Implement fallback credit detection**

Modify `StatusRowCopy.heroText(snapshot:state:)` before the generic balance-only branch:

```swift
if isFallbackCredits(snapshot), state == .empty {
    return "No extra credits available"
}
```

Add helper methods in `StatusRowCopy`:

```swift
private static func isFallbackCredits(_ snapshot: UsageSnapshot) -> Bool {
    snapshot.poolKey == "anthropic_claude_extra_usage"
        || snapshot.poolKey == "openai_codex_credits"
}
```

- [ ] **Step 4: Run row-copy tests**

Run:

```bash
cd apps/mac && swift test --filter StatusRowCopyTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusRowCopy.swift apps/mac/Tests/WhatTheTokenMacTests/StatusRowCopyTests.swift
git commit -m "feat(mac): use neutral copy for empty fallback credits"
```

---

## Task 6: Make Credit Row Styling Contextual

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusRowDisplayModel.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusSectionDisplayModel.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/StatusRowDisplayModelTests.swift`

- [ ] **Step 1: Add row styling tests**

Append to `StatusRowDisplayModelTests`:

```swift
@Test func emptyFallbackCreditsDoNotTintRedWhenProviderIsAvailable() {
    let row = StatusRowDisplayModel(
        snapshot: UsageSnapshotFixture.claudeCreditsSample(remaining: 0),
        sectionDefault: nil,
        now: Date(timeIntervalSince1970: 0),
        providerAvailability: .available
    )

    #expect(row.heroText == "No extra credits available")
    #expect(row.heroTintsRed == false)
    #expect(row.showsStatus == false)
}

@Test func emptyFallbackCreditsTintRedWhenProviderIsCritical() {
    let row = StatusRowDisplayModel(
        snapshot: UsageSnapshotFixture.claudeCreditsSample(remaining: 0),
        sectionDefault: nil,
        now: Date(timeIntervalSince1970: 0),
        providerAvailability: .critical
    )

    #expect(row.heroText == "No extra credits available")
    #expect(row.heroTintsRed == true)
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
cd apps/mac && swift test --filter "emptyFallbackCreditsDoNotTintRedWhenProviderIsAvailable|emptyFallbackCreditsTintRedWhenProviderIsCritical"
```

Expected: FAIL because `StatusRowDisplayModel` has no `providerAvailability` argument.

- [ ] **Step 3: Extend `StatusRowDisplayModel` initializer**

Change the initializer signature:

```swift
init(
    snapshot: UsageSnapshot,
    sectionDefault: StatusSectionDefault?,
    now: Date,
    providerAvailability: ProviderAvailability = .available
)
```

Replace `heroTintsRed` assignment:

```swift
let fallbackCredits = Self.isFallbackCredits(snapshot)
heroTintsRed = if fallbackCredits {
    providerAvailability == .critical
} else {
    !balanceOnly && (state == .critical || state == .empty)
}
```

Add helper:

```swift
private static func isFallbackCredits(_ snapshot: UsageSnapshot) -> Bool {
    snapshot.poolKey == "anthropic_claude_extra_usage"
        || snapshot.poolKey == "openai_codex_credits"
}
```

- [ ] **Step 4: Pass availability from `StatusSectionDisplayModel`**

In `StatusSectionDisplayModel.init(snapshots:now:)`, compute provider availability after `sectionDefault`:

```swift
let providerTab: ProviderTab? = {
    if first.provider == "anthropic", first.product == "claude_code" { return .claude }
    if first.provider == "openai", first.product == "codex" { return .codex }
    return nil
}()

let providerAvailability = providerTab.map {
    ProviderAvailability.from(snapshots: snapshots, tab: $0)
} ?? .available
```

Then pass it into row construction:

```swift
rows = snapshots.map {
    StatusRowDisplayModel(
        snapshot: $0,
        sectionDefault: sectionDefault,
        now: now,
        providerAvailability: providerAvailability
    )
}
```

- [ ] **Step 5: Run row display tests**

Run:

```bash
cd apps/mac && swift test --filter StatusRowDisplayModelTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusRowDisplayModel.swift apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusSectionDisplayModel.swift apps/mac/Tests/WhatTheTokenMacTests/StatusRowDisplayModelTests.swift
git commit -m "feat(mac): style fallback credit rows by provider availability"
```

---

## Task 7: Menu-Bar Icon Alignment Check

**Files:**
- Read: `apps/mac/Sources/WhatTheTokenMac/WhatTheTokenApp.swift`

- [ ] **Step 1: Confirm icon remains static**

Run:

```bash
cd apps/mac && grep -rn "MenuBarExtra" Sources/WhatTheTokenMac/WhatTheTokenApp.swift
```

Expected output includes:

```swift
MenuBarExtra("WhatTheToken", systemImage: "gauge") {
```

Because the icon is a static SF Symbol with no tint, badge, or dynamic title, no implementation change is needed in this task.

- [ ] **Step 2: Guard against accidental raw worst-state icon logic**

Run:

```bash
cd apps/mac && grep -rn "worstUsageState\\|StatusUsageState(snapshot" Sources/WhatTheTokenMac
```

Expected: matches may remain in `ProviderTabModel.swift`, `ProviderAvailability.swift`, and row display files. There must be no match in `WhatTheTokenApp.swift`.

- [ ] **Step 3: Commit only if code changed**

If this task finds no dynamic icon code, do not commit. Record the check result in the PR description.

---

## Task 8: Full Verification

**Files:**
- No code edits.

- [ ] **Step 1: Run focused presentation tests**

```bash
cd apps/mac && swift test --filter "ProviderAvailabilityTests|BannerStateTests|StatusRowCopyTests|StatusRowDisplayModelTests"
```

Expected: all selected tests pass.

- [ ] **Step 2: Run full test suite**

```bash
cd apps/mac && swift test
```

Expected: all tests pass.

- [ ] **Step 3: Run release build**

```bash
cd apps/mac && swift build -c release
```

Expected: build completes successfully.

- [ ] **Step 4: Manual screenshot regression**

Using the current menu-bar app, confirm:

1. Claude tab with session/weekly green and extra usage credits zero has no critical banner.
2. Codex tab with included usage available and credits zero has no critical banner.
3. A provider with included usage exhausted and positive credits shows fallback-only copy.
4. A provider with included usage exhausted and no/zero credits shows critical copy.
5. The menu-bar icon remains static or agrees with the same availability state if dynamic icon work was added separately.

- [ ] **Step 5: Commit verification note if docs changed**

If implementation required changing docs beyond this plan/spec addendum, commit them:

```bash
git add docs/superpowers/specs/2026-05-07-menu-bar-shell-design.md docs/superpowers/plans/2026-05-08-contextual-provider-availability.md
git commit -m "docs(mac): document contextual provider availability"
```

---

## Self-Review Checklist

- **Spec coverage:** implements addendum §14 lanes, thresholds, precedence, missing fallback handling, row copy, menu-bar alignment, and tests.
- **Type consistency:** `ProviderAvailability`, `ProviderTab`, `UsageSnapshot`, `StatusUsageState`, `BannerState`, and fixture helper names match the current codebase.
- **No placeholders:** every implementation step includes exact paths, test names, commands, and code snippets.
- **Scope control:** no persistence, account history, migrations, provider auth changes, or connector protocol changes are included.
