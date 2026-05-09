# Status Card Color States and Layout Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** Implemented on 2026-05-05. Final implementation includes the post-review fixes listed in "Implementation Amendments" below; older task snippets are retained as execution history, not as the source of truth.

**Goal:** Rebuild the Mac app's Claude Code usage panel as a single section with row-based layout, conditional color states (green ≥30 % remaining, orange 10–29 %, red <10 %, empty at 0), an explicit "Y% used" echo for cross-reference with Claude's Settings → Usage screen, and a sentence hero ("Out of credits") only when the quota is actually empty.

**Architecture:** Presentation-layer change only. Introduce two display models (`StatusRowDisplayModel`, `StatusSectionDisplayModel`) and a state enum (`StatusUsageState`), backed by pure copy/threshold helpers (`StatusRowCopy`). Replace `StatusCardView` with `StatusSectionView`. No new model types, no service changes.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing (`@Test` / `#expect`), Swift Package Manager. Build with `swift build` and test with `swift test` from `apps/mac/`.

**Spec:** `docs/superpowers/specs/2026-05-05-status-card-color-states-design.md`

---

## Implementation Amendments

- `StatusSectionView` is wrapped in `TimelineView(.periodic(from: .now, by: 60))` so reset hints tick down without another connector refresh.
- Updated timestamps and absolute reset hints use the user's local timezone.
- Utilization rows derive both hero and echo percentages from rounded `utilization` when it is available, so `X% remaining` + `Y% used` sums to 100.
- `.critical` is the red non-empty state: it keeps the numeric hero and uses `Almost empty`; `.empty` swaps to the sentence hero.
- Confidence badges describe the row itself: every non-verified row receives an `Inferred` badge, and verified rows never do, even when most rows are inferred.
- Rows without a meaningful denominator hide the progress bar.
- Color rendering uses SwiftUI semantic colors (`.green`, `.orange`, `.red`, and adaptive yellow/orange badge styling) instead of fixed RGB values.
- `Compare in Claude →` points at `https://claude.ai/settings/usage`, which was verified to resolve to Claude's settings/usage page.

## File Structure

**Created:**

| Path | Responsibility |
|------|----------------|
| `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusUsageState.swift` | `StatusUsageState` enum (`.healthy`, `.low`, `.critical`, `.empty`) and threshold computation from a `UsageSnapshot`. |
| `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusRowCopy.swift` | Pure copy strings: hero, echo, empty-state hero per unit, reset-hint formatter. |
| `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusRowDisplayModel.swift` | View-ready row model derived from a single `UsageSnapshot` plus optional section-default context. |
| `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusSectionDisplayModel.swift` | View-ready section model: brand, uniform trust line, compare URL, rows with badges. |
| `apps/mac/Sources/WhatTheTokenMac/Views/StatusSectionView.swift` | SwiftUI section view (header + dividers + private row view). |
| `apps/mac/Tests/WhatTheTokenMacTests/StatusUsageStateTests.swift` | Threshold boundary tests. |
| `apps/mac/Tests/WhatTheTokenMacTests/StatusRowCopyTests.swift` | Hero/echo/critical/reset-hint formatting tests. |
| `apps/mac/Tests/WhatTheTokenMacTests/StatusRowDisplayModelTests.swift` | Row model assembly tests across all four sample windows. |
| `apps/mac/Tests/WhatTheTokenMacTests/StatusSectionDisplayModelTests.swift` | Section model: uniform vs divergent confidence/risk, badge derivation, compare URL. |

**Modified:**

| Path | Why |
|------|-----|
| `apps/mac/Sources/WhatTheTokenMac/Views/ContentView.swift` | Replace `ForEach(StatusCardView)` with a single `StatusSectionView(snapshots:)`. |
| `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift` | Drop `statusCardCopyIncludesConnectorAndConfidence`; keep fixture and sanitization tests. |

**Deleted:**

| Path | Why |
|------|-----|
| `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusCardDisplayModel.swift` | Replaced by `StatusRowDisplayModel`. |
| `apps/mac/Sources/WhatTheTokenMac/Views/StatusCardView.swift` | Replaced by `StatusSectionView` (which inlines the row view). The `StatusCardCopy` enum dies with it. |
| `apps/mac/Tests/WhatTheTokenMacTests/StatusCardDisplayModelTests.swift` | Replaced by row + section tests. |

---

## Open assumption (confirm before Task 5)

The "Compare in Claude →" link uses `https://claude.ai/settings/usage`. **Verify this URL is correct in your browser before Task 5.** If Claude has migrated the page, replace the constant in `StatusSectionDisplayModel.compareURL`.

---

## Task 1: `StatusUsageState` enum and threshold logic

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusUsageState.swift`
- Create: `apps/mac/Tests/WhatTheTokenMacTests/StatusUsageStateTests.swift`

The state has four cases with these thresholds:

| Remaining | State |
|-----------|-------|
| ≥ 30 %    | `.healthy` |
| ≥ 10 % and < 30 % | `.low` |
| > 0 % and < 10 % | `.critical` |
| 0 %       | `.empty` |

For non-percentage units (`credits`, `tokens`, `requests`, `messages`), use `remaining / limit` when both are present; if `limit` is missing, treat as `.healthy` unless `remaining <= 0` (then `.empty`). For utilization rows, prefer rounded `utilization` when present; fall back to `remaining / 100` only when utilization is missing.

- [ ] **Step 1.1: Write the failing tests**

Create `apps/mac/Tests/WhatTheTokenMacTests/StatusUsageStateTests.swift`:

```swift
import Testing
@testable import WhatTheTokenMac

private func snapshot(
    unit: String = "utilization",
    used: Double? = nil,
    limit: Double? = 100,
    remaining: Double?,
    utilization: Double? = nil
) -> UsageSnapshot {
    UsageSnapshot(
        id: "snap",
        userAccountId: "u",
        provider: "anthropic",
        product: "claude_code",
        surface: "cli",
        poolKey: "anthropic_claude_subscription",
        windowKey: "five_hour",
        unit: unit,
        used: used,
        limit: limit,
        remaining: remaining,
        utilization: utilization,
        resetAt: nil,
        lastUpdatedAt: "2026-05-05T09:44:00.000Z",
        confidence: "verified",
        undercountRisk: "none",
        staleReason: nil,
        source: ConnectorSource(
            connector: "mac_connector",
            state: .connected,
            label: "Mac connector",
            parserVersion: "v1",
            deviceId: "d"
        )
    )
}

@Test func healthyAtThirtyPercentRemaining() {
    let s = snapshot(remaining: 30, utilization: 0.70)
    #expect(StatusUsageState(snapshot: s) == .healthy)
}

@Test func lowJustUnderThirtyPercentRemaining() {
    let s = snapshot(remaining: 29, utilization: 0.71)
    #expect(StatusUsageState(snapshot: s) == .low)
}

@Test func lowAtTenPercentRemaining() {
    let s = snapshot(remaining: 10, utilization: 0.90)
    #expect(StatusUsageState(snapshot: s) == .low)
}

@Test func criticalJustUnderTenPercentRemaining() {
    let s = snapshot(remaining: 9, utilization: 0.91)
    #expect(StatusUsageState(snapshot: s) == .critical)
}

@Test func emptyAtZero() {
    let s = snapshot(remaining: 0, utilization: 1.0)
    #expect(StatusUsageState(snapshot: s) == .empty)
}

@Test func creditsHealthyWhenRemainingPositiveAndLimitMissing() {
    let s = snapshot(unit: "credits", limit: nil, remaining: 5)
    #expect(StatusUsageState(snapshot: s) == .healthy)
}

@Test func creditsEmptyWhenZero() {
    let s = snapshot(unit: "credits", limit: 100, remaining: 0)
    #expect(StatusUsageState(snapshot: s) == .empty)
}

@Test func creditsLowAtFifteenOfHundred() {
    let s = snapshot(unit: "credits", limit: 100, remaining: 15)
    #expect(StatusUsageState(snapshot: s) == .low)
}

@Test func unknownRemainingTreatedAsHealthy() {
    let s = snapshot(remaining: nil, utilization: nil)
    #expect(StatusUsageState(snapshot: s) == .healthy)
}
```

- [ ] **Step 1.2: Run tests to verify they fail**

Run from `apps/mac/`:

```bash
swift test --filter StatusUsageStateTests
```

Expected: build error or fail with "cannot find 'StatusUsageState' in scope".

- [ ] **Step 1.3: Implement `StatusUsageState`**

Create `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusUsageState.swift`:

```swift
import Foundation

enum StatusUsageState: Equatable, Sendable {
    case healthy
    case low
    case critical
    case empty

    init(snapshot: UsageSnapshot) {
        let remainingFraction = Self.remainingFraction(snapshot: snapshot)

        guard let fraction = remainingFraction else {
            self = .healthy
            return
        }

        if fraction <= 0 {
            self = .empty
        } else if fraction < 0.10 {
            self = .critical
        } else if fraction < 0.30 {
            self = .low
        } else {
            self = .healthy
        }
    }

    private static func remainingFraction(snapshot: UsageSnapshot) -> Double? {
        switch snapshot.unit {
        case "utilization":
            if let utilization = snapshot.utilization {
                let usedPercent = Int(round(utilization * 100))
                return Double(min(max(100 - usedPercent, 0), 100)) / 100
            }
            if let remaining = snapshot.remaining {
                return max(0, remaining / 100)
            }
            return nil
        default:
            guard let remaining = snapshot.remaining else { return nil }
            if remaining <= 0 { return 0 }
            guard let limit = snapshot.limit, limit > 0 else { return 1 }
            return max(0, remaining / limit)
        }
    }
}
```

- [ ] **Step 1.4: Run tests to verify they pass**

```bash
swift test --filter StatusUsageStateTests
```

Expected: all 9 tests pass.

- [ ] **Step 1.5: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusUsageState.swift apps/mac/Tests/WhatTheTokenMacTests/StatusUsageStateTests.swift
git commit -m "feat(mac): add StatusUsageState threshold for status card color states"
```

---

## Task 2: `StatusRowCopy` (hero, echo, empty hero, reset hint)

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusRowCopy.swift`
- Create: `apps/mac/Tests/WhatTheTokenMacTests/StatusRowCopyTests.swift`

The module exposes four pure functions:

- `heroText(snapshot:state:)` — "87% remaining" / "5% remaining" in the red warning zone / "Out of credits" only when the row is actually empty.
- `echoText(snapshot:)` — "13% used" formatted to match Claude's Settings → Usage page exactly. For non-percentage units returns nil.
- `statusWord(state:)` — "Plenty left" / "Running low" / "Almost empty" / "Empty".
- `resetHint(resetAt:now:)` — "Resets in 3h 16m" if reset is within 24 h; "Resets Wed 19:00" otherwise; nil if `resetAt` is nil.

- [ ] **Step 2.1: Write the failing tests**

Create `apps/mac/Tests/WhatTheTokenMacTests/StatusRowCopyTests.swift`:

```swift
import Foundation
import Testing
@testable import WhatTheTokenMac

private func snap(
    unit: String,
    remaining: Double?,
    utilization: Double? = nil,
    used: Double? = nil,
    limit: Double? = nil
) -> UsageSnapshot {
    UsageSnapshot(
        id: "s",
        userAccountId: "u",
        provider: "anthropic",
        product: "claude_code",
        surface: "cli",
        poolKey: "p",
        windowKey: "five_hour",
        unit: unit,
        used: used,
        limit: limit,
        remaining: remaining,
        utilization: utilization,
        resetAt: nil,
        lastUpdatedAt: "2026-05-05T09:44:00.000Z",
        confidence: "verified",
        undercountRisk: "none",
        staleReason: nil,
        source: ConnectorSource(
            connector: "mac_connector",
            state: .connected,
            label: "Mac connector",
            parserVersion: "v1",
            deviceId: "d"
        )
    )
}

// MARK: - heroText

@Test func heroPercentRemainingForUtilization() {
    let s = snap(unit: "utilization", remaining: 87, utilization: 0.13)
    #expect(StatusRowCopy.heroText(snapshot: s, state: .healthy) == "87% remaining")
}

@Test func heroPercentRemainingForLowState() {
    let s = snap(unit: "utilization", remaining: 27, utilization: 0.73)
    #expect(StatusRowCopy.heroText(snapshot: s, state: .low) == "27% remaining")
}

@Test func heroSentenceForUtilizationEmpty() {
    let s = snap(unit: "utilization", remaining: 0, utilization: 1.0)
    #expect(StatusRowCopy.heroText(snapshot: s, state: .empty) == "Out of capacity")
}

@Test func heroCountForUtilizationCriticalButNotEmpty() {
    let s = snap(unit: "utilization", remaining: 5, utilization: 0.95)
    #expect(StatusRowCopy.heroText(snapshot: s, state: .critical) == "5% remaining")
}

@Test func heroSentenceForCreditsEmpty() {
    let s = snap(unit: "credits", remaining: 0, limit: 100)
    #expect(StatusRowCopy.heroText(snapshot: s, state: .empty) == "Out of credits")
}

@Test func heroCountForCreditsHealthy() {
    let s = snap(unit: "credits", remaining: 42, limit: 100)
    #expect(StatusRowCopy.heroText(snapshot: s, state: .healthy) == "42 credits remaining")
}

@Test func heroCountForTokensLow() {
    let s = snap(unit: "tokens", remaining: 1500, limit: 10_000)
    #expect(StatusRowCopy.heroText(snapshot: s, state: .low) == "1500 tokens remaining")
}

@Test func heroFallbackWhenRemainingMissing() {
    let s = snap(unit: "utilization", remaining: nil, utilization: nil)
    #expect(StatusRowCopy.heroText(snapshot: s, state: .healthy) == "Usage observed")
}

// MARK: - echoText

@Test func echoRoundsUtilizationToInteger() {
    let s = snap(unit: "utilization", remaining: 87, utilization: 0.13)
    #expect(StatusRowCopy.echoText(snapshot: s) == "13% used")
}

@Test func echoRoundsHalfUp() {
    let s = snap(unit: "utilization", remaining: 27, utilization: 0.7349)
    #expect(StatusRowCopy.echoText(snapshot: s) == "73% used")
}

@Test func echoNilForNonPercentageUnit() {
    let s = snap(unit: "credits", remaining: 0, limit: 100)
    #expect(StatusRowCopy.echoText(snapshot: s) == nil)
}

// MARK: - statusWord

@Test func statusWordHealthy() {
    #expect(StatusRowCopy.statusWord(state: .healthy) == "Plenty left")
}

@Test func statusWordLow() {
    #expect(StatusRowCopy.statusWord(state: .low) == "Running low")
}

@Test func statusWordCritical() {
    #expect(StatusRowCopy.statusWord(state: .critical) == "Almost empty")
}

@Test func statusWordEmpty() {
    #expect(StatusRowCopy.statusWord(state: .empty) == "Empty")
}

// MARK: - resetHint

@Test func resetHintRelativeUnderTwentyFourHours() {
    let now = ISO8601DateFormatter().date(from: "2026-05-05T09:44:00Z")!
    let resetAt = "2026-05-05T13:00:00Z"
    #expect(StatusRowCopy.resetHint(resetAt: resetAt, now: now) == "Resets in 3h 16m")
}

@Test func resetHintAbsoluteOverTwentyFourHours() {
    let now = ISO8601DateFormatter().date(from: "2026-05-05T09:44:00Z")!
    let resetAt = "2026-05-06T19:00:00Z" // 33h ahead
    let result = StatusRowCopy.resetHint(resetAt: resetAt, now: now)
    #expect(result?.hasPrefix("Resets ") == true)
    #expect(result?.contains(":") == true) // contains time
}

@Test func resetHintNilWhenResetAtNil() {
    let now = ISO8601DateFormatter().date(from: "2026-05-05T09:44:00Z")!
    #expect(StatusRowCopy.resetHint(resetAt: nil, now: now) == nil)
}
```

- [ ] **Step 2.2: Run tests to verify they fail**

```bash
swift test --filter StatusRowCopyTests
```

Expected: build error.

- [ ] **Step 2.3: Implement `StatusRowCopy`**

Create `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusRowCopy.swift`:

```swift
import Foundation

enum StatusRowCopy {
    static func heroText(snapshot: UsageSnapshot, state: StatusUsageState) -> String {
        if state == .empty {
            return emptyHero(unit: snapshot.unit)
        }

        guard let remaining = snapshot.remaining else {
            return "Usage observed"
        }

        switch snapshot.unit {
        case "utilization":
            return "\(Int(remaining))% remaining"
        case "credits":
            return "\(formatted(remaining)) credits remaining"
        case "tokens":
            return "\(Int(remaining)) tokens remaining"
        case "requests":
            return "\(Int(remaining)) requests remaining"
        case "messages":
            return "\(Int(remaining)) messages remaining"
        default:
            return "\(formatted(remaining)) remaining"
        }
    }

    static func echoText(snapshot: UsageSnapshot) -> String? {
        guard snapshot.unit == "utilization" else { return nil }
        guard let utilization = snapshot.utilization else { return nil }
        let percent = Int(round(utilization * 100))
        return "\(percent)% used"
    }

    static func statusWord(state: StatusUsageState) -> String {
        switch state {
        case .healthy: return "Plenty left"
        case .low:     return "Running low"
        case .critical: return "Almost empty"
        case .empty:   return "Empty"
        }
    }

    static func resetHint(resetAt: String?, now: Date) -> String? {
        guard let resetAt, let resetDate = parseISODate(resetAt) else {
            return nil
        }

        let interval = resetDate.timeIntervalSince(now)
        guard interval > 0 else { return nil }

        if interval < 24 * 60 * 60 {
            let totalMinutes = Int(interval / 60)
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return "Resets in \(hours)h \(minutes)m"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEE HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "Resets \(formatter.string(from: resetDate))"
    }

    private static func parseISODate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }

    private static func emptyHero(unit: String) -> String {
        switch unit {
        case "utilization": return "Out of capacity"
        case "credits":     return "Out of credits"
        case "tokens":      return "Out of tokens"
        case "requests":    return "Out of requests"
        case "messages":    return "Out of messages"
        default:            return "Empty"
        }
    }

    private static func formatted(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return value.formatted()
    }
}
```

- [ ] **Step 2.4: Run tests to verify they pass**

```bash
swift test --filter StatusRowCopyTests
```

Expected: all tests pass.

- [ ] **Step 2.5: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusRowCopy.swift apps/mac/Tests/WhatTheTokenMacTests/StatusRowCopyTests.swift
git commit -m "feat(mac): add StatusRowCopy with hero/echo/reset-hint formatting"
```

---

## Task 3: `StatusRowDisplayModel`

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusRowDisplayModel.swift`
- Create: `apps/mac/Tests/WhatTheTokenMacTests/StatusRowDisplayModelTests.swift`

A row is everything the view needs for one quota window. The model takes a snapshot, a "now" date, and an optional section default (used by the section model to decide which badges to surface).

Field summary:

| Field | Type | Description |
|-------|------|-------------|
| `name` | `String` | Window label ("Current session", "Weekly · all models", …). |
| `resetHint` | `String?` | "Resets in 3h 16m" or absolute. |
| `heroText` | `String` | "87% remaining" or "Out of credits". |
| `echoText` | `String?` | "13% used" — nil when not a utilization unit. |
| `progressValue` | `Double` | 0…1 fill width. |
| `state` | `StatusUsageState` | `.healthy` / `.low` / `.critical` / `.empty`. |
| `statusWord` | `String` | "Plenty left" / "Running low" / "Almost empty" / "Empty". |
| `heroTintsRed` | `Bool` | true when state is `.critical` or `.empty`. |
| `showsBar` | `Bool` | false when there is no meaningful denominator (for example credits with missing/zero `limit`). |
| `badges` | `[StatusRowBadge]` | Per-row exception badges. |
| `staleReason` | `String?` | passed through. |

`StatusRowBadge` is an enum with associated string for tooltip.

- [ ] **Step 3.1: Write the failing tests**

Create `apps/mac/Tests/WhatTheTokenMacTests/StatusRowDisplayModelTests.swift`:

```swift
import Foundation
import Testing
@testable import WhatTheTokenMac

private let fixedNow = ISO8601DateFormatter().date(from: "2026-05-05T09:44:00Z")!

private func snap(
    windowKey: String = "five_hour",
    poolKey: String = "anthropic_claude_subscription",
    unit: String = "utilization",
    used: Double? = 13,
    limit: Double? = 100,
    remaining: Double? = 87,
    utilization: Double? = 0.13,
    resetAt: String? = "2026-05-05T13:00:00Z",
    confidence: String = "verified",
    undercountRisk: String = "none",
    staleReason: String? = nil
) -> UsageSnapshot {
    UsageSnapshot(
        id: "s_\(windowKey)",
        userAccountId: "u",
        provider: "anthropic",
        product: "claude_code",
        surface: "cli",
        poolKey: poolKey,
        windowKey: windowKey,
        unit: unit,
        used: used,
        limit: limit,
        remaining: remaining,
        utilization: utilization,
        resetAt: resetAt,
        lastUpdatedAt: "2026-05-05T09:44:00.000Z",
        confidence: confidence,
        undercountRisk: undercountRisk,
        staleReason: staleReason,
        source: ConnectorSource(
            connector: "mac_connector",
            state: .connected,
            label: "Mac connector",
            parserVersion: "v1",
            deviceId: "d"
        )
    )
}

@Test func currentSessionRowAtThirteenPercentUsed() {
    let row = StatusRowDisplayModel(
        snapshot: snap(),
        sectionDefault: nil,
        now: fixedNow
    )

    #expect(row.name == "Current session")
    #expect(row.resetHint == "Resets in 3h 16m")
    #expect(row.heroText == "87% remaining")
    #expect(row.echoText == "13% used")
    #expect(row.progressValue == 0.13)
    #expect(row.state == .healthy)
    #expect(row.statusWord == "Plenty left")
    #expect(row.heroTintsRed == false)
    #expect(row.showsBar == true)
    #expect(row.badges.isEmpty)
    #expect(row.staleReason == nil)
}

@Test func weeklyAllModelsAtSeventyThreePercentUsedIsLow() {
    let row = StatusRowDisplayModel(
        snapshot: snap(
            windowKey: "seven_day",
            remaining: 27,
            utilization: 0.73,
            resetAt: "2026-05-07T19:00:00Z"
        ),
        sectionDefault: nil,
        now: fixedNow
    )

    #expect(row.name == "Weekly · all models")
    #expect(row.heroText == "27% remaining")
    #expect(row.echoText == "73% used")
    #expect(row.state == .low)
    #expect(row.heroTintsRed == false)
}

@Test func criticalUtilizationKeepsNumberHeroButTintsRed() {
    let row = StatusRowDisplayModel(
        snapshot: snap(
            windowKey: "five_hour",
            remaining: 5,
            utilization: 0.95
        ),
        sectionDefault: nil,
        now: fixedNow
    )

    #expect(row.heroText == "5% remaining")
    #expect(row.state == .critical)
    #expect(row.statusWord == "Almost empty")
    #expect(row.heroTintsRed == true)
    #expect(row.showsBar == true)
}

@Test func extraUsageCreditsEmptyHidesBarAndShowsSentence() {
    let row = StatusRowDisplayModel(
        snapshot: snap(
            windowKey: "monthly_extra_usage",
            poolKey: "anthropic_claude_extra_usage",
            unit: "credits",
            used: 0,
            limit: 0,
            remaining: 0,
            utilization: nil,
            resetAt: nil
        ),
        sectionDefault: nil,
        now: fixedNow
    )

    #expect(row.name == "Extra usage credits")
    #expect(row.heroText == "Out of credits")
    #expect(row.echoText == nil)
    #expect(row.state == .empty)
    #expect(row.heroTintsRed == true)
    #expect(row.showsBar == false)
    #expect(row.statusWord == "Empty")
}

@Test func badgeAddedWhenUndercountDivergesFromSection() {
    let sectionDefault = StatusSectionDefault(confidence: "verified", undercountRisk: "none")
    let row = StatusRowDisplayModel(
        snapshot: snap(undercountRisk: "likely"),
        sectionDefault: sectionDefault,
        now: fixedNow
    )

    #expect(row.badges.contains(.undercountLikely))
}

@Test func possibleUndercountBadgeAddedWhenRiskDivergesFromSection() {
    let sectionDefault = StatusSectionDefault(confidence: "verified", undercountRisk: "none")
    let row = StatusRowDisplayModel(
        snapshot: snap(undercountRisk: "possible"),
        sectionDefault: sectionDefault,
        now: fixedNow
    )

    #expect(row.badges.contains(.undercountPossible))
}

@Test func badgeAddedWhenConfidenceDivergesFromSection() {
    let sectionDefault = StatusSectionDefault(confidence: "verified", undercountRisk: "none")
    let row = StatusRowDisplayModel(
        snapshot: snap(confidence: "inferred"),
        sectionDefault: sectionDefault,
        now: fixedNow
    )

    #expect(row.badges.contains(.inferred))
}

@Test func noBadgeWhenSectionDefaultIsNil() {
    let row = StatusRowDisplayModel(
        snapshot: snap(confidence: "inferred", undercountRisk: "likely"),
        sectionDefault: nil,
        now: fixedNow
    )

    #expect(row.badges.isEmpty)
}
```

- [ ] **Step 3.2: Run tests to verify they fail**

```bash
swift test --filter StatusRowDisplayModelTests
```

Expected: build error (`StatusSectionDefault`, `StatusRowBadge`, `StatusRowDisplayModel` missing).

- [ ] **Step 3.3: Implement `StatusRowDisplayModel`**

Create `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusRowDisplayModel.swift`:

```swift
import Foundation

struct StatusSectionDefault: Equatable, Sendable {
    let confidence: String
    let undercountRisk: String
}

enum StatusRowBadge: Equatable, Sendable {
    case undercountPossible
    case undercountLikely
    case inferred

    var label: String {
        switch self {
        case .undercountPossible: return "Undercount possible"
        case .undercountLikely: return "Undercount likely"
        case .inferred:         return "Inferred"
        }
    }

    var tooltip: String {
        switch self {
        case .undercountPossible:
            return "Some recent activity may not be reflected in this number."
        case .undercountLikely:
            return "Recent activity may not be reflected in this number."
        case .inferred:
            return "This row is inferred rather than verified by the connector."
        }
    }
}

struct StatusRowDisplayModel: Equatable, Sendable {
    let id: String
    let name: String
    let resetHint: String?
    let heroText: String
    let echoText: String?
    let progressValue: Double
    let state: StatusUsageState
    let statusWord: String
    let heroTintsRed: Bool
    let showsBar: Bool
    let badges: [StatusRowBadge]
    let staleReason: String?

    init(
        snapshot: UsageSnapshot,
        sectionDefault: StatusSectionDefault?,
        now: Date
    ) {
        let state = StatusUsageState(snapshot: snapshot)
        id = snapshot.id
        name = Self.windowName(for: snapshot)
        resetHint = StatusRowCopy.resetHint(resetAt: snapshot.resetAt, now: now)
        heroText = StatusRowCopy.heroText(snapshot: snapshot, state: state)
        echoText = StatusRowCopy.echoText(snapshot: snapshot)
        progressValue = Self.progressValue(snapshot: snapshot)
        self.state = state
        statusWord = StatusRowCopy.statusWord(state: state)
        heroTintsRed = state == .critical || state == .empty
        showsBar = Self.showsBar(snapshot: snapshot)
        badges = Self.badges(snapshot: snapshot, sectionDefault: sectionDefault)
        staleReason = snapshot.staleReason
    }

    private static func windowName(for snapshot: UsageSnapshot) -> String {
        if snapshot.provider == "anthropic", snapshot.product == "claude_code" {
            switch snapshot.windowKey {
            case "five_hour":           return "Current session"
            case "seven_day":           return "Weekly · all models"
            case "seven_day_opus":      return "Weekly · Opus"
            case "seven_day_sonnet":    return "Weekly · Sonnet"
            case "monthly_extra_usage": return "Extra usage credits"
            default: break
            }
        }
        return snapshot.windowKey
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private static func progressValue(snapshot: UsageSnapshot) -> Double {
        if let utilization = snapshot.utilization {
            return min(max(utilization, 0), 1)
        }
        if let remaining = snapshot.remaining, let limit = snapshot.limit, limit > 0 {
            return min(max(1 - (remaining / limit), 0), 1)
        }
        return 0
    }

    private static func showsBar(snapshot: UsageSnapshot) -> Bool {
        if snapshot.unit == "utilization" {
            return true
        }
        guard let limit = snapshot.limit else {
            return false
        }
        return limit > 0
    }

    private static func badges(
        snapshot: UsageSnapshot,
        sectionDefault: StatusSectionDefault?
    ) -> [StatusRowBadge] {
        guard let sectionDefault else { return [] }
        var result: [StatusRowBadge] = []
        if snapshot.confidence != sectionDefault.confidence {
            result.append(.inferred)
        }
        if snapshot.undercountRisk != sectionDefault.undercountRisk {
            switch snapshot.undercountRisk {
            case "possible":
                result.append(.undercountPossible)
            case "likely":
                result.append(.undercountLikely)
            default:
                break
            }
        }
        return result
    }
}
```

- [ ] **Step 3.4: Run tests to verify they pass**

```bash
swift test --filter StatusRowDisplayModelTests
```

Expected: all row display-model tests pass.

- [ ] **Step 3.5: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusRowDisplayModel.swift apps/mac/Tests/WhatTheTokenMacTests/StatusRowDisplayModelTests.swift
git commit -m "feat(mac): add StatusRowDisplayModel with state, hero, and exception badges"
```

---

## Task 4: `StatusSectionDisplayModel`

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusSectionDisplayModel.swift`
- Create: `apps/mac/Tests/WhatTheTokenMacTests/StatusSectionDisplayModelTests.swift`

The section model derives:

- `brandTitle` — "Anthropic · Claude Code" (capitalized provider + humanized product). Section assumes uniform `(provider, product)` for the input array; if mixed, render each variant via separate sections (out of scope here — assert uniform).
- `trustLine` — "Verified by Mac connector · Updated 09:44" when `confidence` and `source.label` are uniform; otherwise nil (and rows surface their own indicators via badges). The update time is the latest valid `lastUpdatedAt` in the section, formatted as `HH:mm`.
- `compareURL` — `URL(string: "https://claude.ai/settings/usage")!`. **Confirm before merging.**
- `rows` — built from snapshots with the most common `undercountRisk` injected as `sectionDefault`; confidence badges describe each row's actual confidence rather than the section default confidence.

- [ ] **Step 4.1: Write the failing tests**

Create `apps/mac/Tests/WhatTheTokenMacTests/StatusSectionDisplayModelTests.swift`:

```swift
import Foundation
import Testing
@testable import WhatTheTokenMac

private let fixedNow = ISO8601DateFormatter().date(from: "2026-05-05T09:44:00Z")!

private let macConnector = ConnectorSource(
    connector: "mac_connector",
    state: .connected,
    label: "Mac connector",
    parserVersion: "v1",
    deviceId: "d"
)

private func snap(
    windowKey: String,
    poolKey: String = "anthropic_claude_subscription",
    unit: String = "utilization",
    remaining: Double?,
    utilization: Double? = nil,
    confidence: String = "verified",
    undercountRisk: String = "none",
    source: ConnectorSource = macConnector
) -> UsageSnapshot {
    UsageSnapshot(
        id: "s_\(windowKey)",
        userAccountId: "u",
        provider: "anthropic",
        product: "claude_code",
        surface: "cli",
        poolKey: poolKey,
        windowKey: windowKey,
        unit: unit,
        used: nil,
        limit: 100,
        remaining: remaining,
        utilization: utilization,
        resetAt: nil,
        lastUpdatedAt: "2026-05-05T09:44:00.000Z",
        confidence: confidence,
        undercountRisk: undercountRisk,
        staleReason: nil,
        source: source
    )
}

@Test func sectionWithUniformTrustHoistsLine() {
    let snapshots = [
        snap(windowKey: "five_hour", remaining: 87, utilization: 0.13),
        snap(windowKey: "seven_day", remaining: 27, utilization: 0.73),
        snap(windowKey: "seven_day_sonnet", remaining: 95, utilization: 0.05)
    ]

    let section = StatusSectionDisplayModel(snapshots: snapshots, now: fixedNow)

    #expect(section.brandTitle == "Anthropic · Claude Code")
    #expect(section.trustLine == "Verified by Mac connector · Updated 09:44")
    #expect(section.rows.count == 3)
    #expect(section.compareURL.absoluteString == "https://claude.ai/settings/usage")
}

@Test func sectionWithDivergentConfidenceOmitsTrustLineAndAddsBadge() {
    let snapshots = [
        snap(windowKey: "five_hour", remaining: 87, utilization: 0.13, confidence: "verified"),
        snap(windowKey: "seven_day", remaining: 27, utilization: 0.73, confidence: "inferred")
    ]

    let section = StatusSectionDisplayModel(snapshots: snapshots, now: fixedNow)

    #expect(section.trustLine == nil)
    let weekly = section.rows.first { $0.name == "Weekly · all models" }
    #expect(weekly?.badges.contains(.inferred) == true)
}

@Test func sectionWithOneLikelyRowAddsUndercountBadgeOnlyOnThatRow() {
    let snapshots = [
        snap(windowKey: "five_hour", remaining: 87, utilization: 0.13, undercountRisk: "none"),
        snap(windowKey: "seven_day", remaining: 27, utilization: 0.73, undercountRisk: "likely"),
        snap(windowKey: "seven_day_sonnet", remaining: 95, utilization: 0.05, undercountRisk: "none")
    ]

    let section = StatusSectionDisplayModel(snapshots: snapshots, now: fixedNow)
    let weekly = section.rows.first { $0.name == "Weekly · all models" }
    let session = section.rows.first { $0.name == "Current session" }

    #expect(weekly?.badges.contains(.undercountLikely) == true)
    #expect(session?.badges.isEmpty == true)
}

@Test func emptySnapshotsProducesNilTrustAndNoRows() {
    let section = StatusSectionDisplayModel(snapshots: [], now: fixedNow)

    #expect(section.brandTitle == nil)
    #expect(section.trustLine == nil)
    #expect(section.rows.isEmpty)
}
```

- [ ] **Step 4.2: Run tests to verify they fail**

```bash
swift test --filter StatusSectionDisplayModelTests
```

Expected: build error.

- [ ] **Step 4.3: Implement `StatusSectionDisplayModel`**

Create `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusSectionDisplayModel.swift`:

```swift
import Foundation

struct StatusSectionDisplayModel: Sendable {
    let brandTitle: String?
    let trustLine: String?
    let compareURL: URL
    let rows: [StatusRowDisplayModel]

    init(snapshots: [UsageSnapshot], now: Date) {
        compareURL = URL(string: "https://claude.ai/settings/usage")!

        guard let first = snapshots.first else {
            brandTitle = nil
            trustLine = nil
            rows = []
            return
        }

        brandTitle = Self.brandTitle(provider: first.provider, product: first.product)

        let confidences = Set(snapshots.map { $0.confidence })
        let labels = Set(snapshots.map { $0.source.label })
        let trustUniform = confidences.count == 1 && labels.count == 1

        if trustUniform {
            trustLine = [
                "\(first.confidence.capitalized) by \(first.source.label)",
                Self.updatedLabel(snapshots: snapshots)
            ]
            .compactMap { $0 }
            .joined(separator: " · ")
        } else {
            trustLine = nil
        }

        let modeRisk = Self.mode(snapshots.map { $0.undercountRisk })
        let modeConfidence = Self.mode(snapshots.map { $0.confidence })
        let sectionDefault = StatusSectionDefault(
            confidence: modeConfidence,
            undercountRisk: modeRisk
        )

        rows = snapshots.map {
            StatusRowDisplayModel(snapshot: $0, sectionDefault: sectionDefault, now: now)
        }
    }

    private static func brandTitle(provider: String, product: String) -> String {
        let providerWord = provider.capitalized
        let productWord = product
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
        return "\(providerWord) · \(productWord)"
    }

    private static func updatedLabel(snapshots: [UsageSnapshot]) -> String? {
        let latest = snapshots
            .compactMap { parseISODate($0.lastUpdatedAt) }
            .max()
        guard let latest else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "Updated \(formatter.string(from: latest))"
    }

    private static func parseISODate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }

    private static func mode(_ values: [String]) -> String {
        var counts: [String: Int] = [:]
        for v in values { counts[v, default: 0] += 1 }
        return values.max { lhs, rhs in
            counts[lhs, default: 0] < counts[rhs, default: 0]
        } ?? values.first ?? ""
    }
}
```

- [ ] **Step 4.4: Run tests to verify they pass**

```bash
swift test --filter StatusSectionDisplayModelTests
```

Expected: all 4 tests pass.

- [ ] **Step 4.5: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusSectionDisplayModel.swift apps/mac/Tests/WhatTheTokenMacTests/StatusSectionDisplayModelTests.swift
git commit -m "feat(mac): add StatusSectionDisplayModel with uniform trust line and badge derivation"
```

---

## Task 5: `StatusSectionView`

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/Views/StatusSectionView.swift`

SwiftUI views aren't unit-tested directly here; verification is via the display-model tests plus a manual smoke check after Task 6.

**Before this task: confirm the compare URL** (`https://claude.ai/settings/usage`). If wrong, update the constant in `StatusSectionDisplayModel.swift` and adjust the test assertion in Task 4.

- [ ] **Step 5.1: Implement `StatusSectionView`**

Create `apps/mac/Sources/WhatTheTokenMac/Views/StatusSectionView.swift`:

```swift
import SwiftUI

struct StatusSectionView: View {
    let snapshots: [UsageSnapshot]

    private var section: StatusSectionDisplayModel {
        StatusSectionDisplayModel(snapshots: snapshots, now: Date())
    }

    var body: some View {
        let model = section
        VStack(alignment: .leading, spacing: 0) {
            header(model)
                .padding(.bottom, 12)
                .overlay(
                    Rectangle().frame(height: 1).foregroundStyle(.secondary.opacity(0.18)),
                    alignment: .bottom
                )

            ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                StatusRowView(row: row)
                    .padding(.vertical, 12)
                    .overlay(
                        Group {
                            if index < model.rows.count - 1 {
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundStyle(.secondary.opacity(0.18))
                            }
                        },
                        alignment: .bottom
                    )
            }
        }
        .padding(20)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.secondary.opacity(0.18), lineWidth: 1)
        )
        .frame(maxWidth: 420, alignment: .leading)
    }

    @ViewBuilder
    private func header(_ model: StatusSectionDisplayModel) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                if let brand = model.brandTitle {
                    Text(brand)
                        .font(.subheadline.weight(.semibold))
                }
                if let trust = model.trustLine {
                    Text(trust)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Link("Compare in Claude →", destination: model.compareURL)
                .font(.caption)
        }
    }
}

private struct StatusRowView: View {
    let row: StatusRowDisplayModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Text(row.name)
                        .font(.subheadline.weight(.semibold))
                    ForEach(row.badges, id: \.self) { badge in
                        BadgeView(badge: badge)
                    }
                }
                Spacer()
                if let resetHint = row.resetHint {
                    Text(resetHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .firstTextBaseline) {
                Text(row.heroText)
                    .font(.system(size: row.state == .empty ? 18 : 24, weight: .semibold))
                    .foregroundStyle(row.heroTintsRed ? Color(red: 0.75, green: 0.22, blue: 0.17) : .primary)
                Spacer()
                if let echo = row.echoText {
                    Text(echo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            if row.showsBar {
                ProgressView(value: row.progressValue)
                    .progressViewStyle(.linear)
                    .tint(color(for: row.state))
            }

            HStack(spacing: 4) {
                Circle()
                    .frame(width: 6, height: 6)
                    .foregroundStyle(color(for: row.state))
                Text(row.statusWord)
                    .font(.caption)
                    .foregroundStyle(color(for: row.state))
            }

            if let stale = row.staleReason {
                Text(stale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func color(for state: StatusUsageState) -> Color {
        switch state {
        case .healthy: return Color(red: 0.12, green: 0.54, blue: 0.25)
        case .low:     return Color(red: 0.82, green: 0.50, blue: 0.16)
        case .critical, .empty:
            return Color(red: 0.75, green: 0.22, blue: 0.17)
        }
    }
}

private struct BadgeView: View {
    let badge: StatusRowBadge

    var body: some View {
        Text(badge.label)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Color(red: 1.0, green: 0.97, blue: 0.88))
            .foregroundStyle(Color(red: 0.60, green: 0.42, blue: 0.0))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(red: 0.95, green: 0.85, blue: 0.54), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .help(badge.tooltip)
    }
}
```

- [ ] **Step 5.2: Build to verify the view compiles**

```bash
cd apps/mac && swift build
```

Expected: build succeeds.

- [ ] **Step 5.3: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/Views/StatusSectionView.swift
git commit -m "feat(mac): add StatusSectionView with row-based layout and color states"
```

---

## Task 6: Wire `StatusSectionView` into `ContentView`

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/ContentView.swift`

- [ ] **Step 6.1: Replace the `ForEach(StatusCardView)` block**

Open `apps/mac/Sources/WhatTheTokenMac/Views/ContentView.swift` and change the body so the snapshot block reads:

```swift
            if viewModel.snapshots.isEmpty {
                Text("No usage signal")
                    .font(.headline)
                    .padding()
            } else {
                StatusSectionView(snapshots: viewModel.snapshots)
            }
```

The full file should now read:

```swift
import SwiftUI

struct ContentView: View {
    let viewModel: StatusViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(ClaudeConnectorSetupCopy.title(for: viewModel.connectorState))
                    .font(.headline)

                Text(ClaudeConnectorSetupCopy.trustMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    Task {
                        await viewModel.connectClaudeCode()
                    }
                } label: {
                    Label("Connect Claude Code", systemImage: "link")
                }
                .disabled(viewModel.connectorState == .checking)
            }

            Divider()

            if viewModel.snapshots.isEmpty {
                Text("No usage signal")
                    .font(.headline)
                    .padding()
            } else {
                StatusSectionView(snapshots: viewModel.snapshots)
            }
        }
        .padding()
    }
}
```

- [ ] **Step 6.2: Build to verify nothing broke**

```bash
cd apps/mac && swift build
```

Expected: build succeeds.

- [ ] **Step 6.3: Manual smoke check**

`WhatTheTokenApp` starts with a live `AppModel` today, so the deterministic fixture state requires a temporary local-only launcher edit. Inject a fixture-backed `StatusViewModel` through `AppModel`, run the app, then discard that launcher edit before committing Task 6.

```bash
cd apps/mac && swift run WhatTheTokenMac
```

With the fixture loaded (38 % remaining, healthy state) the app should now show:
- Single section header `Anthropic · Claude Code` with `Verified by Fixture · Updated 10:00` underneath.
- One row labeled `Current session` with `38% remaining`, a `62% used` echo, a green-tinted bar, and `● Plenty left`.
- "Compare in Claude →" link in the header.

Close the app once verified and restore the live `AppModel` path.

- [ ] **Step 6.4: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/Views/ContentView.swift
git commit -m "feat(mac): render usage snapshots through StatusSectionView"
```

---

## Task 7: Remove the obsolete card model, view, and tests

**Files:**
- Delete: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusCardDisplayModel.swift`
- Delete: `apps/mac/Sources/WhatTheTokenMac/Views/StatusCardView.swift`
- Delete: `apps/mac/Tests/WhatTheTokenMacTests/StatusCardDisplayModelTests.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift`

- [ ] **Step 7.1: Delete the obsolete files**

```bash
git rm apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusCardDisplayModel.swift
git rm apps/mac/Sources/WhatTheTokenMac/Views/StatusCardView.swift
git rm apps/mac/Tests/WhatTheTokenMacTests/StatusCardDisplayModelTests.swift
```

- [ ] **Step 7.2: Drop the `StatusCardCopy` test in `StatusViewModelTests.swift`**

Open `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift` and delete the entire `statusCardCopyIncludesConnectorAndConfidence` test (lines 17–22 in the current file). Replace it with this section-level equivalent:

```swift
@Test func sectionTrustLineHoistsConfidenceAndConnectorLabel() throws {
    let snapshot = try StatusViewModel.loadFixtureSnapshot()
    let section = StatusSectionDisplayModel(snapshots: [snapshot], now: Date())

    #expect(section.trustLine == "Verified by Fixture · Updated 10:00")
}
```

- [ ] **Step 7.3: Build and run all tests**

```bash
cd apps/mac && swift test
```

Expected: every test passes. There should be no references to `StatusCardCopy`, `StatusCardView`, or `StatusCardDisplayModel` left in the codebase.

- [ ] **Step 7.4: Commit**

```bash
git add apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift
git commit -m "chore(mac): remove obsolete StatusCardDisplayModel/View after section refactor"
```

---

## Task 8: Final verification

- [ ] **Step 8.1: Run the full test suite**

```bash
cd apps/mac && swift test
```

Expected: all tests pass, no warnings introduced.

- [ ] **Step 8.2: Manual smoke check across states**

To validate orange/red rendering without live Claude data, temporarily extend `StatusViewModel.fixture()` in a throwaway change to load multiple synthetic snapshots — *or* point the app at a real Claude account on a session that's near a quota. Confirm:

- A row with `utilization: 0.73` renders orange bar + "Running low".
- A row with `utilization: 0.95` and `remaining: 5` renders red bar + "Almost empty" while keeping `5% remaining` as the hero.
- A row with `unit: "credits", remaining: 0` renders no bar, "Out of credits" hero, "● Empty" status word.
- A row with `undercountRisk: "likely"` while the rest of the section is `none` shows the `Undercount likely` badge.

Discard any throwaway fixture changes before opening the PR.

- [ ] **Step 8.3: No follow-up commit needed if nothing changed**

If verification revealed bugs, fix them as separate small commits referencing the failing case before opening the PR.

---

## Self-Review Notes

The plan covers every section of the spec:

- Section header + brand hoisting → Task 4 (model) + Task 5 (view).
- Window name as primary row label → Task 3 (`windowName` mapper).
- Threshold + bar color → Task 1.
- "X% remaining" hero + "Y% used" echo → Task 2.
- Empty-state hero string → Task 2 (`emptyHero`); red nonzero rows keep numeric heroes.
- Hide bar when there is no meaningful denominator → Task 3 (`showsBar`).
- Per-row exception badges → Task 3 + Task 4.
- Compare-in-Claude link → Task 4 (URL) + Task 5 (Link). Open assumption flagged at top of plan.
- Reset-hint formatting (relative vs absolute) → Task 2.
- Cleanup of old types → Task 7.

No `TODO`, `TBD`, or hand-wavy steps remain; every code step has the actual code. Type names referenced across tasks (`StatusSectionDefault`, `StatusRowBadge`, `StatusRowDisplayModel`, `StatusSectionDisplayModel`, `StatusUsageState`) are defined where first introduced and used consistently afterwards.
