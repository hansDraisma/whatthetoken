# Codex Usage Dashboard Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Codex usage card match the ChatGPT Codex usage dashboard more closely by showing aggregate limits, model-specific limits such as `GPT-5.3-Codex-Spark`, and credits from live Codex app-server data.

**Architecture:** Preserve the sanitized snapshot boundary, but add minimal provider-display metadata to the shared contract so the UI does not hardcode current Codex model names. The Codex mapper will derive labels from `limitName`, `limitId`, `windowDurationMins`, and `credits`, while the shared row display model will render those labels generically.

**Tech Stack:** Swift, Swift Testing, SwiftUI, TypeScript/Zod schema tests, Codex app-server JSON-RPC.

---

## Evidence

Screenshots compared:

- ChatGPT Codex usage dashboard shows:
  - `5 hour usage limit`
  - `Weekly usage limit`
  - `GPT-5.3-Codex-Spark 5 hour usage limit`
  - `GPT-5.3-Codex-Spark Weekly usage limit`
  - `Credits remaining`
- WhatTheToken currently shows:
  - `Primary Rolling 300m`
  - `Secondary Rolling 10080m`
  - duplicate generic labels for both aggregate and model-specific buckets
  - no credits row

Live Codex app-server probe confirmed the fields needed to avoid hardcoding model names:

```text
bucket=codex limitId=codex limitName=<nil> planType=prolite
  primary: usedPercent=1 windowDurationMins=300
  secondary: usedPercent=6 windowDurationMins=10080
  credits: balance=0 hasCredits=false unlimited=false
bucket=codex_bengalfox limitId=codex_bengalfox limitName=GPT-5.3-Codex-Spark planType=prolite
  primary: usedPercent=0 windowDurationMins=300
  secondary: usedPercent=0 windowDurationMins=10080
```

OpenAI Help Center confirms Codex usage is visible in ChatGPT web under Codex Settings -> Usage Dashboard.

## File Structure

- Modify: `packages/core/src/schemas.ts`
  - Add optional `display` metadata to `usageSnapshotSchema`.
  - Relax the `credits` unit rule so credits can be represented when only a remaining balance is known.
- Modify: core schema tests under `packages/core/src` or existing core test file
  - Cover optional display metadata and credits remaining-only snapshots.
- Modify: `apps/mac/Sources/WhatTheTokenMac/Models/UsageSnapshot.swift`
  - Mirror the new optional display metadata.
- Modify: `apps/mac/Sources/WhatTheTokenMac/Codex/CodexUsageMapper.swift`
  - Populate display labels from live Codex bucket fields.
  - Emit credits snapshots from aggregate bucket credits.
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusRowDisplayModel.swift`
  - Prefer explicit display labels over generic `windowKey` formatting.
  - Keep Claude-specific labels unchanged.
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/CodexUsageMapperTests.swift`
  - Test model-specific bucket labels and credits mapping.
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/StatusRowDisplayModelTests.swift`
  - Test display metadata drives row names and credit rows.
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/StatusSectionDisplayModelTests.swift`
  - Keep the Codex usage dashboard link test.

## Task 1: Extend Snapshot Contract For Display Metadata And Credits Balance

**Files:**
- Modify: `packages/core/src/schemas.ts`
- Test: existing core schema test file for `usageSnapshotSchema`
- Modify: `apps/mac/Sources/WhatTheTokenMac/Models/UsageSnapshot.swift`

- [ ] **Step 1: Write failing TypeScript schema tests**

Add a test that accepts provider-supplied display metadata:

```ts
expect(() =>
  usageSnapshotSchema.parse({
    id: "snap_openai_codex_codex_bengalfox_primary_device",
    userAccountId: "local_user",
    provider: "openai",
    product: "codex",
    surface: "aggregate",
    poolKey: "openai_codex_codex_bengalfox_1234",
    windowKey: "primary_rolling_300m",
    unit: "utilization",
    used: 0,
    limit: 100,
    remaining: 100,
    utilization: 0,
    resetAt: "2026-05-05T18:00:00.000Z",
    lastUpdatedAt: "2026-05-05T13:00:00.000Z",
    confidence: "observed",
    undercountRisk: "possible",
    staleReason: null,
    display: {
      poolLabel: "GPT-5.3-Codex-Spark",
      windowLabel: "5 hour usage limit"
    },
    source: {
      connector: "mac_connector",
      state: "connected",
      label: "Mac connector",
      parserVersion: "codex-app-server-rate-limits-v1",
      deviceId: "local_mac"
    }
  })
).not.toThrow();
```

Add a test that accepts a credits snapshot with a known balance and no total limit:

```ts
expect(() =>
  usageSnapshotSchema.parse({
    id: "snap_openai_codex_credits_local_mac",
    userAccountId: "local_user",
    provider: "openai",
    product: "codex",
    surface: "aggregate",
    poolKey: "openai_codex_credits",
    windowKey: "credits_remaining",
    unit: "credits",
    used: null,
    limit: null,
    remaining: 0,
    utilization: null,
    resetAt: null,
    lastUpdatedAt: "2026-05-05T13:00:00.000Z",
    confidence: "observed",
    undercountRisk: "possible",
    staleReason: null,
    display: {
      poolLabel: "Codex",
      windowLabel: "Credits remaining"
    },
    source: {
      connector: "mac_connector",
      state: "connected",
      label: "Mac connector",
      parserVersion: "codex-app-server-rate-limits-v1",
      deviceId: "local_mac"
    }
  })
).not.toThrow();
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
pnpm --filter @whatthetoken/core test
```

Expected: FAIL because `display` is not in the strict schema and `remaining` is currently disallowed when `used` or `limit` is null.

- [ ] **Step 3: Implement schema extension**

In `packages/core/src/schemas.ts`, add:

```ts
export const snapshotDisplaySchema = z
  .object({
    poolLabel: z.string().min(1).optional(),
    windowLabel: z.string().min(1).optional()
  })
  .strict();
```

Add to `usageSnapshotSchema`:

```ts
display: snapshotDisplaySchema.optional(),
```

Change the `remaining` validation to allow remaining-only credits:

```ts
const isCreditsBalance = snapshot.unit === "credits" && snapshot.used === null && snapshot.limit === null;

if ((snapshot.used === null || snapshot.limit === null) && snapshot.remaining !== null && !isCreditsBalance) {
  context.addIssue({
    code: "custom",
    path: ["remaining"],
    message: "remaining must be null when used or limit is unknown unless unit is credits"
  });
}
```

- [ ] **Step 4: Mirror Swift model**

In `apps/mac/Sources/WhatTheTokenMac/Models/UsageSnapshot.swift`, add:

```swift
struct UsageSnapshotDisplay: Codable, Equatable, Sendable {
    let poolLabel: String?
    let windowLabel: String?
}
```

Add to `UsageSnapshot`:

```swift
let display: UsageSnapshotDisplay?
```

Update all test snapshot builders to pass `display: nil` by default.

- [ ] **Step 5: Run schema and Swift tests**

Run:

```bash
pnpm --filter @whatthetoken/core test
cd apps/mac && swift test
```

Expected: PASS.

## Task 2: Map Codex Bucket Labels From Live App-Server Fields

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/Codex/CodexUsageMapper.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/CodexUsageMapperTests.swift`

- [ ] **Step 1: Write failing mapper test for model-specific labels**

Add a Codex response with `rateLimitsByLimitId.codex_bengalfox.limitName = "GPT-5.3-Codex-Spark"` and assert:

```swift
#expect(modelPrimary.display?.poolLabel == "GPT-5.3-Codex-Spark")
#expect(modelPrimary.display?.windowLabel == "5 hour usage limit")
#expect(modelSecondary.display?.poolLabel == "GPT-5.3-Codex-Spark")
#expect(modelSecondary.display?.windowLabel == "Weekly usage limit")
```

Also assert aggregate labels:

```swift
#expect(aggregatePrimary.display?.poolLabel == nil)
#expect(aggregatePrimary.display?.windowLabel == "5 hour usage limit")
#expect(aggregateSecondary.display?.windowLabel == "Weekly usage limit")
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd apps/mac && swift test --filter CodexUsageMapperTests
```

Expected: FAIL because `display` is not populated.

- [ ] **Step 3: Implement label derivation**

In `CodexUsageMapper`, pass the bucket into `makeSnapshot` and derive:

```swift
private static func display(for bucket: CodexRateLimitSnapshot, window: CodexRateLimitWindow) -> UsageSnapshotDisplay? {
    UsageSnapshotDisplay(
        poolLabel: bucket.limitName,
        windowLabel: windowLabel(durationMins: window.windowDurationMins)
    )
}

private static func windowLabel(durationMins: Int?) -> String? {
    switch durationMins {
    case 300:
        return "5 hour usage limit"
    case 10_080:
        return "Weekly usage limit"
    case let minutes? where minutes % 60 == 0:
        return "\(minutes / 60) hour usage limit"
    case let minutes?:
        return "\(minutes) minute usage limit"
    case nil:
        return nil
    }
}
```

This keeps model names data-driven from `limitName` and only derives human period labels from numeric duration.

- [ ] **Step 4: Run mapper tests**

Run:

```bash
cd apps/mac && swift test --filter CodexUsageMapperTests
```

Expected: PASS.

## Task 3: Emit Codex Credits Remaining Snapshot

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/Codex/CodexUsageMapper.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/CodexUsageMapperTests.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/StatusRowDisplayModelTests.swift`

- [ ] **Step 1: Write failing mapper test for credits**

Use aggregate `rateLimits.credits = CodexCreditsSnapshot(balance: "0", hasCredits: false, unlimited: false)` and assert one snapshot:

```swift
#expect(creditsSnapshot.poolKey == "openai_codex_credits")
#expect(creditsSnapshot.windowKey == "credits_remaining")
#expect(creditsSnapshot.unit == "credits")
#expect(creditsSnapshot.used == nil)
#expect(creditsSnapshot.limit == nil)
#expect(creditsSnapshot.remaining == 0)
#expect(creditsSnapshot.utilization == nil)
#expect(creditsSnapshot.display?.windowLabel == "Credits remaining")
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd apps/mac && swift test --filter CodexUsageMapperTests
```

Expected: FAIL because credits are currently ignored.

- [ ] **Step 3: Implement credits mapping**

In `CodexUsageMapper.map(_ response: ...)`, append a credits snapshot only from `response.rateLimits.credits`:

```swift
if let creditsSnapshot = makeCreditsSnapshot(
    response.rateLimits.credits,
    userAccountId: userAccountId,
    deviceId: deviceId,
    observedAt: observedAt,
    source: source
) {
    snapshots.append(creditsSnapshot)
}
```

Implement:

```swift
private static func makeCreditsSnapshot(
    _ credits: CodexCreditsSnapshot?,
    userAccountId: String,
    deviceId: String,
    observedAt: String,
    source: ConnectorSource
) -> UsageSnapshot? {
    guard let credits else { return nil }

    let balance: Double?
    if credits.unlimited {
        balance = nil
    } else if let rawBalance = credits.balance {
        balance = Double(rawBalance)
    } else {
        balance = nil
    }

    return UsageSnapshot(
        id: "snap_openai_codex_credits_\(deviceId)",
        userAccountId: userAccountId,
        provider: "openai",
        product: "codex",
        surface: "aggregate",
        poolKey: "openai_codex_credits",
        windowKey: "credits_remaining",
        unit: "credits",
        used: nil,
        limit: nil,
        remaining: balance,
        utilization: nil,
        resetAt: nil,
        lastUpdatedAt: observedAt,
        confidence: "observed",
        undercountRisk: "possible",
        staleReason: nil,
        display: UsageSnapshotDisplay(poolLabel: "Codex", windowLabel: "Credits remaining"),
        source: source
    )
}
```

- [ ] **Step 4: Add display test for credits row**

In `StatusRowDisplayModelTests`, create a `credits` snapshot with `display.windowLabel = "Credits remaining"` and assert:

```swift
#expect(row.name == "Credits remaining")
#expect(row.heroText == "0")
#expect(row.showsBar == false)
```

- [ ] **Step 5: Run focused tests**

Run:

```bash
cd apps/mac && swift test --filter CodexUsageMapperTests
cd apps/mac && swift test --filter StatusRowDisplayModelTests
```

Expected: PASS.

## Task 4: Render Context-Specific Codex Row Names

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusRowDisplayModel.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/StatusRowDisplayModelTests.swift`

- [ ] **Step 1: Write failing row-name tests**

Add tests for:

```swift
#expect(aggregatePrimaryRow.name == "5 hour usage limit")
#expect(aggregateWeeklyRow.name == "Weekly usage limit")
#expect(modelPrimaryRow.name == "GPT-5.3-Codex-Spark 5 hour usage limit")
#expect(modelWeeklyRow.name == "GPT-5.3-Codex-Spark Weekly usage limit")
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd apps/mac && swift test --filter StatusRowDisplayModelTests
```

Expected: FAIL because rows still derive names from `windowKey`.

- [ ] **Step 3: Implement generic display label preference**

In `StatusRowDisplayModel.windowName(for:)`, before provider-specific fallback:

```swift
if let windowLabel = snapshot.display?.windowLabel {
    if let poolLabel = snapshot.display?.poolLabel, !poolLabel.isEmpty, poolLabel != "Codex" {
        return "\(poolLabel) \(windowLabel)"
    }

    return windowLabel
}
```

Keep the existing Claude-specific switch after this only for snapshots without display metadata.

- [ ] **Step 4: Run focused tests**

Run:

```bash
cd apps/mac && swift test --filter StatusRowDisplayModelTests
cd apps/mac && swift test --filter Codex
```

Expected: PASS.

## Task 5: Verify Live Codex Correspondence

**Files:**
- No production file changes.

- [ ] **Step 1: Run sanitized live smoke**

Run:

```bash
cd apps/mac
CODEX_CONNECTOR_SMOKE=1 swift run WhatTheTokenMac --codex-connector-smoke
```

Expected sanitized output includes aggregate and model-specific snapshots. No raw `rateLimits`, token-shaped strings, account email, local paths, prompts, or app-server logs.

- [ ] **Step 2: Manually compare UI against dashboard**

Open the app, click `Connect Codex`, and verify the card shows:

```text
Openai · Codex
Open Codex usage →
5 hour usage limit
Weekly usage limit
GPT-5.3-Codex-Spark 5 hour usage limit
GPT-5.3-Codex-Spark Weekly usage limit
Credits remaining
```

Percentages and reset hints should match the Codex web usage dashboard within expected polling freshness.

- [ ] **Step 3: Run full verification**

Run:

```bash
pnpm --filter @whatthetoken/core test
cd apps/mac && swift test
```

Expected: all tests pass.

## Risks And Decisions

- Do not hardcode `GPT-5.3-Codex-Spark` in UI code. It must come from `CodexRateLimitSnapshot.limitName`.
- It is acceptable to map numeric durations like `300` and `10080` into human period labels because those are generic window durations, not model-specific product names.
- Credits require a small shared-contract change because the current strict schema cannot represent a known remaining credit balance without a known total limit.
- Keep `confidence = observed` and `undercountRisk = possible` until live validation proves the app-server buckets are fully authoritative across Codex surfaces.
- Do not store or print raw JSON-RPC envelopes. The smoke command remains sanitized.
