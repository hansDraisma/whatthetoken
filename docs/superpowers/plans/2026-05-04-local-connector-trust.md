# Local Connector Trust Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first secure local connector slice so Claude Code and Codex can appear in one normalized status surface while provider credentials stay local.

**Architecture:** `packages/core` owns the connector source metadata contract that every surface can render. `apps/mac` owns the first local connector implementation: tested parsers, in-memory Claude token handling boundaries, fixture-only mapper tests, and a SwiftUI status card that displays source, confidence, freshness, and setup state. This plan does not add Supabase, Chrome extension code, live Anthropic polling in CI, or production analytics.

**Tech Stack:** pnpm workspaces, TypeScript, Zod, Vitest, SwiftUI, Foundation networking, macOS Security command boundary, Swift Testing.

---

## Constraints

- Use TDD for behavior changes.
- Do not put real Claude credentials, tokens, prompts, responses, cookies, or session contents in fixtures, logs, tests, or docs.
- Do not call live Anthropic endpoints in automated tests.
- Keep provider credentials local to the Mac connector process.
- Keep the Chrome extension and web app as future display surfaces that consume sanitized snapshots.
- Keep Codex implementation to a visible local-connector source state until its local metadata schema has a separate redaction review.

## File Structure

Create or modify these files:

- Modify: `packages/core/src/types.ts` - add connector source and source-state types.
- Modify: `packages/core/src/schemas.ts` - validate source metadata on `UsageSnapshot`.
- Modify: `packages/core/src/snapshots.ts` - require source metadata when creating snapshots.
- Modify: `packages/core/src/fixtures.ts` - include source metadata in fixture snapshots.
- Modify: `packages/core/src/fixture-files.ts` - keep exported fixture JSON aligned with schema.
- Modify: `packages/core/src/__tests__/schemas.test.ts` - verify source metadata and sensitive-field rejection.
- Modify: `packages/core/src/__tests__/snapshots.test.ts` - verify source metadata propagation.
- Modify: `apps/mac/Sources/WhatTheTokenMac/Models/UsageSnapshot.swift` - mirror source metadata.
- Create: `apps/mac/Sources/WhatTheTokenMac/Models/ConnectorSource.swift` - Swift source metadata model.
- Create: `apps/mac/Sources/WhatTheTokenMac/Models/ConnectorSourceState.swift` - Swift source-state enum.
- Modify: `apps/mac/Sources/WhatTheTokenMac/Resources/usage-snapshot.fixture.json` - include source metadata.
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift` - assert source metadata loads.
- Create: `apps/mac/Sources/WhatTheTokenMac/Claude/ClaudeUsageResponse.swift` - sanitized Anthropic usage response DTO.
- Create: `apps/mac/Sources/WhatTheTokenMac/Claude/ClaudeUsageMapper.swift` - maps Anthropic response to `UsageSnapshot`.
- Create: `apps/mac/Tests/WhatTheTokenMacTests/ClaudeUsageMapperTests.swift` - fixture-only parser and mapper tests.
- Create: `apps/mac/Sources/WhatTheTokenMac/Claude/ClaudeCredentials.swift` - parses Claude Code credential JSON without logging token values.
- Create: `apps/mac/Sources/WhatTheTokenMac/Claude/ClaudeCredentialStore.swift` - protocol plus macOS Keychain command implementation.
- Create: `apps/mac/Tests/WhatTheTokenMacTests/ClaudeCredentialsTests.swift` - credential JSON parsing tests with synthetic tokens.
- Create: `apps/mac/Sources/WhatTheTokenMac/Claude/ClaudeUsageClient.swift` - builds and sends Anthropic usage request with injected URL loading.
- Create: `apps/mac/Tests/WhatTheTokenMacTests/ClaudeUsageClientTests.swift` - request construction and error mapping tests.
- Create: `apps/mac/Sources/WhatTheTokenMac/Connectors/ConnectorStatus.swift` - source-state result model for local connectors.
- Create: `apps/mac/Sources/WhatTheTokenMac/Connectors/LocalConnectorViewModel.swift` - combines fixture/local connector statuses into snapshots.
- Create: `apps/mac/Tests/WhatTheTokenMacTests/LocalConnectorViewModelTests.swift` - verifies unified Claude and Codex display data.
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/StatusCardView.swift` - show connector source, confidence, and undercount/freshness text.
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/ContentView.swift` - support multiple source-backed cards.
- Modify: `docs/architecture/data-contract.md` - document snapshot source metadata.
- Modify: `docs/research/claude-code-local-signal-spike.md` - link the implementation plan and security boundary.

## Task 1: Shared Snapshot Source Contract

**Files:**
- Modify: `packages/core/src/types.ts`
- Modify: `packages/core/src/schemas.ts`
- Modify: `packages/core/src/snapshots.ts`
- Modify: `packages/core/src/fixtures.ts`
- Modify: `packages/core/src/fixture-files.ts`
- Modify: `packages/core/src/__tests__/schemas.test.ts`
- Modify: `packages/core/src/__tests__/snapshots.test.ts`

- [ ] **Step 1: Write failing schema tests**

Add this test to `packages/core/src/__tests__/schemas.test.ts`:

```ts
it("requires sanitized source metadata on snapshots", () => {
  const parsed = usageSnapshotSchema.parse({
    id: "snap_with_source",
    userAccountId: "user_01",
    provider: "anthropic",
    product: "claude_code",
    surface: "cli",
    poolKey: "anthropic_claude_subscription",
    windowKey: "five_hour",
    unit: "utilization",
    used: 62,
    limit: 100,
    remaining: 38,
    utilization: 0.62,
    resetAt: "2026-05-04T15:00:00.000Z",
    lastUpdatedAt: "2026-05-04T10:00:00.000Z",
    confidence: "verified",
    undercountRisk: "possible",
    staleReason: null,
    source: {
      connector: "mac_connector",
      state: "connected",
      label: "Mac connector",
      parserVersion: "claude-code-oauth-usage-v1",
      deviceId: "device_mac_01"
    }
  });

  expect(parsed.source.connector).toBe("mac_connector");
  expect(parsed.source.parserVersion).toBe("claude-code-oauth-usage-v1");
});

it("rejects source metadata that contains credential material", () => {
  expect(() =>
    usageSnapshotSchema.parse({
      id: "snap_with_token",
      userAccountId: "user_01",
      provider: "anthropic",
      product: "claude_code",
      surface: "cli",
      poolKey: "anthropic_claude_subscription",
      windowKey: "five_hour",
      unit: "utilization",
      used: 62,
      limit: 100,
      remaining: 38,
      utilization: 0.62,
      resetAt: "2026-05-04T15:00:00.000Z",
      lastUpdatedAt: "2026-05-04T10:00:00.000Z",
      confidence: "verified",
      undercountRisk: "possible",
      staleReason: null,
      source: {
        connector: "mac_connector",
        state: "connected",
        label: "Mac connector",
        parserVersion: "claude-code-oauth-usage-v1",
        deviceId: "device_mac_01",
        accessToken: "sk-do-not-allow"
      }
    })
  ).toThrow();
});
```

- [ ] **Step 2: Run focused schema tests and verify failure**

Run:

```bash
pnpm --filter @whatthetoken/core test -- schemas.test.ts
```

Expected: FAIL because `source` is not defined on `usageSnapshotSchema`.

- [ ] **Step 3: Add source types**

Update `packages/core/src/types.ts`:

```ts
export type Provider = "openai" | "anthropic" | "google" | "cursor" | "github";

export type Product =
  | "codex"
  | "chatgpt"
  | "claude_code"
  | "claude"
  | "gemini"
  | "cursor"
  | "github_copilot";

export type Surface =
  | "cli"
  | "web"
  | "browser_extension"
  | "desktop_app"
  | "ide"
  | "cloud_agent"
  | "mobile";

export type UsageConfidence = "verified" | "observed" | "estimated" | "stale";
export type UsageUnit = "messages" | "requests" | "tokens" | "credits" | "utilization";
export type UndercountRisk = "none" | "possible" | "likely";

export type Connector = "mac_connector" | "chrome_extension" | "web_dashboard" | "manual_fixture";

export type ConnectorState =
  | "connected"
  | "not_connected"
  | "missing_credentials"
  | "permission_denied"
  | "token_invalid"
  | "rate_limited"
  | "network_error"
  | "schema_changed"
  | "stale";

export type SnapshotSource = {
  connector: Connector;
  state: ConnectorState;
  label: string;
  parserVersion: string;
  deviceId: string;
};
```

- [ ] **Step 4: Add source schemas**

Update `packages/core/src/schemas.ts` by adding these schemas after `undercountRiskSchema`:

```ts
export const connectorSchema = z.enum([
  "mac_connector",
  "chrome_extension",
  "web_dashboard",
  "manual_fixture"
]);

export const connectorStateSchema = z.enum([
  "connected",
  "not_connected",
  "missing_credentials",
  "permission_denied",
  "token_invalid",
  "rate_limited",
  "network_error",
  "schema_changed",
  "stale"
]);

export const snapshotSourceSchema = z
  .object({
    connector: connectorSchema,
    state: connectorStateSchema,
    label: z.string().min(1),
    parserVersion: z.string().min(1),
    deviceId: z.string().min(1)
  })
  .strict();
```

Then add this field to `usageSnapshotSchema`:

```ts
source: snapshotSourceSchema
```

- [ ] **Step 5: Update snapshot helper**

Replace `packages/core/src/snapshots.ts` with:

```ts
import type { UsageSnapshot } from "./schemas";
import type {
  Product,
  Provider,
  SnapshotSource,
  Surface,
  UndercountRisk,
  UsageConfidence,
  UsageUnit
} from "./types";

type CreateSnapshotInput = {
  id: string;
  userAccountId: string;
  provider: Provider;
  product: Product;
  surface: Surface | "aggregate";
  poolKey: string;
  windowKey: string;
  unit: UsageUnit;
  used: number | null;
  limit: number | null;
  resetAt: string | null;
  lastUpdatedAt: string;
  confidence: UsageConfidence;
  undercountRisk: UndercountRisk;
  source: SnapshotSource;
};

export function createSnapshotFromQuotaPoll(input: CreateSnapshotInput): UsageSnapshot {
  const remaining =
    input.used === null || input.limit === null ? null : Math.max(input.limit - input.used, 0);

  const utilization = input.used === null || input.limit === null ? null : input.used / input.limit;

  return {
    ...input,
    remaining,
    utilization,
    staleReason: null
  };
}
```

- [ ] **Step 6: Update fixture builder**

Update `packages/core/src/fixtures.ts`:

```ts
import { createSnapshotFromQuotaPoll } from "./snapshots";

export function createClaudeCodeFixtureSnapshot() {
  return createSnapshotFromQuotaPoll({
    id: "snap_claude_fixture",
    userAccountId: "fixture_user",
    provider: "anthropic",
    product: "claude_code",
    surface: "cli",
    poolKey: "anthropic_claude_subscription",
    windowKey: "five_hour",
    unit: "utilization",
    used: 62,
    limit: 100,
    resetAt: "2026-05-04T15:00:00.000Z",
    lastUpdatedAt: "2026-05-04T10:00:00.000Z",
    confidence: "verified",
    undercountRisk: "possible",
    source: {
      connector: "manual_fixture",
      state: "connected",
      label: "Fixture",
      parserVersion: "fixture-v1",
      deviceId: "fixture_device"
    }
  });
}
```

- [ ] **Step 7: Update remaining snapshot tests**

In every `usageSnapshotSchema.parse` fixture inside `packages/core/src/__tests__/schemas.test.ts`, add:

```ts
source: {
  connector: "manual_fixture",
  state: "connected",
  label: "Fixture",
  parserVersion: "fixture-v1",
  deviceId: "fixture_device"
}
```

In `packages/core/src/__tests__/snapshots.test.ts`, update calls to `createSnapshotFromQuotaPoll` to include:

```ts
source: {
  connector: "mac_connector",
  state: "connected",
  label: "Mac connector",
  parserVersion: "test-parser-v1",
  deviceId: "device_mac_01"
}
```

Add this assertion to the primary snapshot derivation test:

```ts
expect(snapshot.source.connector).toBe("mac_connector");
expect(snapshot.source.state).toBe("connected");
```

- [ ] **Step 8: Run focused core tests**

Run:

```bash
pnpm --filter @whatthetoken/core test -- schemas.test.ts snapshots.test.ts
```

Expected: PASS.

- [ ] **Step 9: Run full workspace check**

Run:

```bash
pnpm check
```

Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add packages/core/src
git commit -m "feat(core): add connector source metadata"
```

## Task 2: Swift Snapshot Source Model

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/Models/UsageSnapshot.swift`
- Create: `apps/mac/Sources/WhatTheTokenMac/Models/ConnectorSource.swift`
- Create: `apps/mac/Sources/WhatTheTokenMac/Models/ConnectorSourceState.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/Resources/usage-snapshot.fixture.json`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift`

- [ ] **Step 1: Write failing Swift fixture test**

Update `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift`:

```swift
import Testing
@testable import WhatTheTokenMac

@Test func loadsFixtureSnapshotWithoutSensitiveContent() throws {
    let snapshot = try StatusViewModel.loadFixtureSnapshot()

    #expect(snapshot.product == "claude_code")
    #expect(snapshot.confidence == "verified")
    #expect(snapshot.remaining == 38)
    #expect(snapshot.staleReason == nil)
    #expect(snapshot.source.connector == "manual_fixture")
    #expect(snapshot.source.state == .connected)
    #expect(snapshot.source.parserVersion == "fixture-v1")
}
```

- [ ] **Step 2: Run Swift tests and verify failure**

Run:

```bash
cd apps/mac && swift test --filter StatusViewModelTests
```

Expected: FAIL because `UsageSnapshot` has no `source` property.

- [ ] **Step 3: Add Swift source-state enum**

Create `apps/mac/Sources/WhatTheTokenMac/Models/ConnectorSourceState.swift`:

```swift
enum ConnectorSourceState: String, Codable, Equatable, Sendable {
    case connected
    case notConnected = "not_connected"
    case missingCredentials = "missing_credentials"
    case permissionDenied = "permission_denied"
    case tokenInvalid = "token_invalid"
    case rateLimited = "rate_limited"
    case networkError = "network_error"
    case schemaChanged = "schema_changed"
    case stale
}
```

- [ ] **Step 4: Add Swift source model**

Create `apps/mac/Sources/WhatTheTokenMac/Models/ConnectorSource.swift`:

```swift
struct ConnectorSource: Codable, Equatable, Sendable {
    let connector: String
    let state: ConnectorSourceState
    let label: String
    let parserVersion: String
    let deviceId: String
}
```

- [ ] **Step 5: Add source to snapshot model**

Update `apps/mac/Sources/WhatTheTokenMac/Models/UsageSnapshot.swift`:

```swift
import Foundation

struct UsageSnapshot: Codable, Equatable, Sendable {
    let id: String
    let userAccountId: String
    let provider: String
    let product: String
    let surface: String
    let poolKey: String
    let windowKey: String
    let unit: String
    let used: Double?
    let limit: Double?
    let remaining: Double?
    let utilization: Double?
    let resetAt: String?
    let lastUpdatedAt: String
    let confidence: String
    let undercountRisk: String
    let staleReason: String?
    let source: ConnectorSource
}
```

- [ ] **Step 6: Update Mac fixture JSON**

Update `apps/mac/Sources/WhatTheTokenMac/Resources/usage-snapshot.fixture.json` to include:

```json
"source": {
  "connector": "manual_fixture",
  "state": "connected",
  "label": "Fixture",
  "parserVersion": "fixture-v1",
  "deviceId": "fixture_device"
}
```

Keep the existing snapshot fields unchanged.

- [ ] **Step 7: Run Swift and core contract tests**

Run:

```bash
cd apps/mac && swift test --filter StatusViewModelTests
pnpm --filter @whatthetoken/core test -- mac-fixture-contract.test.ts
```

Expected: both PASS.

- [ ] **Step 8: Run full workspace check**

Run:

```bash
pnpm check
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/Models apps/mac/Sources/WhatTheTokenMac/Resources/usage-snapshot.fixture.json apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift
git commit -m "feat(mac): mirror connector source metadata"
```

## Task 3: Claude Usage Parser And Mapper

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/Claude/ClaudeUsageResponse.swift`
- Create: `apps/mac/Sources/WhatTheTokenMac/Claude/ClaudeUsageMapper.swift`
- Create: `apps/mac/Tests/WhatTheTokenMacTests/ClaudeUsageMapperTests.swift`

- [ ] **Step 1: Write failing mapper tests**

Create `apps/mac/Tests/WhatTheTokenMacTests/ClaudeUsageMapperTests.swift`:

```swift
import Foundation
import Testing
@testable import WhatTheTokenMac

@Test func decodesClaudeUsageResponseWithoutSensitiveFields() throws {
    let json = """
    {
      "five_hour": { "utilization": 42.5, "resets_at": "2026-05-04T15:00:00Z" },
      "seven_day": { "utilization": 15.2, "resets_at": "2026-05-11T10:00:00Z" },
      "seven_day_opus": { "utilization": 20.0, "resets_at": null },
      "seven_day_sonnet": { "utilization": 10.0, "resets_at": null },
      "extra_usage": {
        "is_enabled": true,
        "utilization": 30.0,
        "used_credits": 422.0,
        "monthly_limit": 1000.0
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(ClaudeUsageResponse.self, from: json)

    #expect(response.fiveHour?.utilization == 42.5)
    #expect(response.sevenDay?.utilization == 15.2)
    #expect(response.extraUsage?.usedCredits == 422.0)
}

@Test func mapsFiveHourClaudeUsageToSanitizedSnapshot() throws {
    let response = ClaudeUsageResponse(
        fiveHour: ClaudeWindowUsage(utilization: 42.5, resetsAt: "2026-05-04T15:00:00Z"),
        sevenDay: nil,
        sevenDayOpus: nil,
        sevenDaySonnet: nil,
        extraUsage: nil
    )

    let source = ConnectorSource(
        connector: "mac_connector",
        state: .connected,
        label: "Mac connector",
        parserVersion: "claude-code-oauth-usage-v1",
        deviceId: "device_mac_01"
    )

    let snapshots = ClaudeUsageMapper.map(
        response,
        userAccountId: "local_user",
        deviceId: "device_mac_01",
        observedAt: "2026-05-04T10:00:00.000Z",
        source: source
    )

    #expect(snapshots.count == 1)
    #expect(snapshots[0].provider == "anthropic")
    #expect(snapshots[0].product == "claude_code")
    #expect(snapshots[0].poolKey == "anthropic_claude_subscription")
    #expect(snapshots[0].windowKey == "five_hour")
    #expect(snapshots[0].unit == "utilization")
    #expect(snapshots[0].used == 42.5)
    #expect(snapshots[0].limit == 100)
    #expect(snapshots[0].remaining == 57.5)
    #expect(snapshots[0].confidence == "verified")
    #expect(snapshots[0].source == source)
}
```

- [ ] **Step 2: Run mapper tests and verify failure**

Run:

```bash
cd apps/mac && swift test --filter ClaudeUsageMapperTests
```

Expected: FAIL because `ClaudeUsageResponse`, `ClaudeWindowUsage`, and `ClaudeUsageMapper` do not exist.

- [ ] **Step 3: Add response DTOs**

Create `apps/mac/Sources/WhatTheTokenMac/Claude/ClaudeUsageResponse.swift`:

```swift
import Foundation

struct ClaudeUsageResponse: Codable, Equatable, Sendable {
    let fiveHour: ClaudeWindowUsage?
    let sevenDay: ClaudeWindowUsage?
    let sevenDayOpus: ClaudeWindowUsage?
    let sevenDaySonnet: ClaudeWindowUsage?
    let extraUsage: ClaudeExtraUsage?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
        case extraUsage = "extra_usage"
    }
}

struct ClaudeWindowUsage: Codable, Equatable, Sendable {
    let utilization: Double
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

struct ClaudeExtraUsage: Codable, Equatable, Sendable {
    let isEnabled: Bool
    let utilization: Double?
    let usedCredits: Double?
    let monthlyLimit: Double?

    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case utilization
        case usedCredits = "used_credits"
        case monthlyLimit = "monthly_limit"
    }
}
```

- [ ] **Step 4: Add mapper**

Create `apps/mac/Sources/WhatTheTokenMac/Claude/ClaudeUsageMapper.swift`:

```swift
import Foundation

enum ClaudeUsageMapper {
    static func map(
        _ response: ClaudeUsageResponse,
        userAccountId: String,
        deviceId: String,
        observedAt: String,
        source: ConnectorSource
    ) -> [UsageSnapshot] {
        var snapshots: [UsageSnapshot] = []

        if let fiveHour = response.fiveHour {
            snapshots.append(makeUtilizationSnapshot(
                id: "snap_anthropic_claude_code_five_hour_\(deviceId)",
                windowKey: "five_hour",
                usage: fiveHour,
                userAccountId: userAccountId,
                observedAt: observedAt,
                source: source
            ))
        }

        if let sevenDay = response.sevenDay {
            snapshots.append(makeUtilizationSnapshot(
                id: "snap_anthropic_claude_code_seven_day_\(deviceId)",
                windowKey: "seven_day",
                usage: sevenDay,
                userAccountId: userAccountId,
                observedAt: observedAt,
                source: source
            ))
        }

        return snapshots
    }

    private static func makeUtilizationSnapshot(
        id: String,
        windowKey: String,
        usage: ClaudeWindowUsage,
        userAccountId: String,
        observedAt: String,
        source: ConnectorSource
    ) -> UsageSnapshot {
        let used = usage.utilization
        let limit = 100.0
        let remaining = max(limit - used, 0)

        return UsageSnapshot(
            id: id,
            userAccountId: userAccountId,
            provider: "anthropic",
            product: "claude_code",
            surface: "cli",
            poolKey: "anthropic_claude_subscription",
            windowKey: windowKey,
            unit: "utilization",
            used: used,
            limit: limit,
            remaining: remaining,
            utilization: used / limit,
            resetAt: usage.resetsAt,
            lastUpdatedAt: observedAt,
            confidence: "verified",
            undercountRisk: "possible",
            staleReason: nil,
            source: source
        )
    }
}
```

- [ ] **Step 5: Run mapper tests**

Run:

```bash
cd apps/mac && swift test --filter ClaudeUsageMapperTests
```

Expected: PASS.

- [ ] **Step 6: Run all Swift tests**

Run:

```bash
cd apps/mac && swift test
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/Claude apps/mac/Tests/WhatTheTokenMacTests/ClaudeUsageMapperTests.swift
git commit -m "feat(mac): map Claude usage snapshots"
```

## Task 4: Claude Credential Boundary

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/Claude/ClaudeCredentials.swift`
- Create: `apps/mac/Sources/WhatTheTokenMac/Claude/ClaudeCredentialStore.swift`
- Create: `apps/mac/Tests/WhatTheTokenMacTests/ClaudeCredentialsTests.swift`

- [ ] **Step 1: Write failing credential tests**

Create `apps/mac/Tests/WhatTheTokenMacTests/ClaudeCredentialsTests.swift`:

```swift
import Foundation
import Testing
@testable import WhatTheTokenMac

@Test func extractsAccessTokenFromClaudeCodeCredentialJson() throws {
    let json = """
    {
      "claudeAiOauth": {
        "accessToken": "synthetic-access-token"
      }
    }
    """.data(using: .utf8)!

    let credentials = try JSONDecoder().decode(ClaudeCredentials.self, from: json)

    #expect(credentials.accessToken == "synthetic-access-token")
}

@Test func missingClaudeOauthEntryHasNoAccessToken() throws {
    let json = "{}".data(using: .utf8)!

    let credentials = try JSONDecoder().decode(ClaudeCredentials.self, from: json)

    #expect(credentials.accessToken == nil)
}

@Test func syntheticTokenIsRedactedForDescriptions() {
    let credentials = ClaudeCredentials(claudeAiOauth: ClaudeOAuthCredential(accessToken: "synthetic-access-token"))

    #expect(String(describing: credentials) == "ClaudeCredentials(accessToken: redacted)")
}
```

- [ ] **Step 2: Run credential tests and verify failure**

Run:

```bash
cd apps/mac && swift test --filter ClaudeCredentialsTests
```

Expected: FAIL because credential types do not exist.

- [ ] **Step 3: Add credential DTOs with redacted description**

Create `apps/mac/Sources/WhatTheTokenMac/Claude/ClaudeCredentials.swift`:

```swift
import Foundation

struct ClaudeCredentials: Codable, Equatable, Sendable, CustomStringConvertible {
    let claudeAiOauth: ClaudeOAuthCredential?

    var accessToken: String? {
        claudeAiOauth?.accessToken
    }

    var description: String {
        "ClaudeCredentials(accessToken: \(accessToken == nil ? "missing" : "redacted"))"
    }
}

struct ClaudeOAuthCredential: Codable, Equatable, Sendable {
    let accessToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken
    }
}
```

- [ ] **Step 4: Add credential store boundary**

Create `apps/mac/Sources/WhatTheTokenMac/Claude/ClaudeCredentialStore.swift`:

```swift
import Foundation

protocol ClaudeCredentialStore: Sendable {
    func readAccessToken() throws -> String?
}

enum ClaudeCredentialStoreError: Error, Equatable {
    case commandFailed
    case invalidUtf8
    case invalidCredentialJson
}

struct MacOSClaudeCredentialStore: ClaudeCredentialStore {
    private let serviceName = "Claude Code-credentials"

    func readAccessToken() throws -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", serviceName, "-w"]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else {
            throw ClaudeCredentialStoreError.invalidUtf8
        }

        guard let jsonData = text.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8) else {
            throw ClaudeCredentialStoreError.invalidUtf8
        }

        do {
            let credentials = try JSONDecoder().decode(ClaudeCredentials.self, from: jsonData)
            return credentials.accessToken?.isEmpty == false ? credentials.accessToken : nil
        } catch {
            throw ClaudeCredentialStoreError.invalidCredentialJson
        }
    }
}
```

- [ ] **Step 5: Run credential tests**

Run:

```bash
cd apps/mac && swift test --filter ClaudeCredentialsTests
```

Expected: PASS.

- [ ] **Step 6: Run all Swift tests**

Run:

```bash
cd apps/mac && swift test
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/Claude/ClaudeCredentials.swift apps/mac/Sources/WhatTheTokenMac/Claude/ClaudeCredentialStore.swift apps/mac/Tests/WhatTheTokenMacTests/ClaudeCredentialsTests.swift
git commit -m "feat(mac): add Claude credential boundary"
```

## Task 5: Claude Usage HTTP Client

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/Claude/ClaudeUsageClient.swift`
- Create: `apps/mac/Tests/WhatTheTokenMacTests/ClaudeUsageClientTests.swift`

- [ ] **Step 1: Write failing client tests**

Create `apps/mac/Tests/WhatTheTokenMacTests/ClaudeUsageClientTests.swift`:

```swift
import Foundation
import Testing
@testable import WhatTheTokenMac

@Test func buildsClaudeUsageRequestWithoutPersistingToken() throws {
    let request = ClaudeUsageRequestFactory.makeRequest(
        accessToken: "synthetic-access-token",
        claudeVersion: "2.1.126"
    )

    #expect(request.url?.absoluteString == "https://api.anthropic.com/api/oauth/usage")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-access-token")
    #expect(request.value(forHTTPHeaderField: "anthropic-beta") == "oauth-2025-04-20")
    #expect(request.value(forHTTPHeaderField: "User-Agent") == "claude-code/2.1.126")
    #expect(request.httpBody == nil)
}

@Test func mapsUnauthorizedToTokenInvalid() async throws {
    let loader = StubClaudeURLLoader(result: (
        Data(),
        HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/api/oauth/usage")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )!
    ))

    let client = ClaudeUsageClient(loader: loader)

    await #expect(throws: ClaudeUsageClientError.tokenInvalid) {
        try await client.fetchUsage(accessToken: "synthetic-access-token", claudeVersion: "2.1.126")
    }
}

private struct StubClaudeURLLoader: ClaudeURLLoading {
    let result: (Data, URLResponse)

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        result
    }
}
```

- [ ] **Step 2: Run client tests and verify failure**

Run:

```bash
cd apps/mac && swift test --filter ClaudeUsageClientTests
```

Expected: FAIL because `ClaudeUsageRequestFactory`, `ClaudeUsageClient`, and `ClaudeURLLoading` do not exist.

- [ ] **Step 3: Add HTTP client**

Create `apps/mac/Sources/WhatTheTokenMac/Claude/ClaudeUsageClient.swift`:

```swift
import Foundation

protocol ClaudeURLLoading: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: ClaudeURLLoading {}

enum ClaudeUsageClientError: Error, Equatable {
    case tokenInvalid
    case rateLimited
    case networkError
    case schemaChanged
}

enum ClaudeUsageRequestFactory {
    static func makeRequest(accessToken: String, claudeVersion: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-code/\(claudeVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        return request
    }
}

struct ClaudeUsageClient: Sendable {
    private let loader: ClaudeURLLoading

    init(loader: ClaudeURLLoading = URLSession.shared) {
        self.loader = loader
    }

    func fetchUsage(accessToken: String, claudeVersion: String) async throws -> ClaudeUsageResponse {
        let request = ClaudeUsageRequestFactory.makeRequest(
            accessToken: accessToken,
            claudeVersion: claudeVersion
        )

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await loader.data(for: request)
        } catch {
            throw ClaudeUsageClientError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeUsageClientError.networkError
        }

        switch httpResponse.statusCode {
        case 200..<300:
            do {
                return try JSONDecoder().decode(ClaudeUsageResponse.self, from: data)
            } catch {
                throw ClaudeUsageClientError.schemaChanged
            }
        case 401, 403:
            throw ClaudeUsageClientError.tokenInvalid
        case 429:
            throw ClaudeUsageClientError.rateLimited
        default:
            throw ClaudeUsageClientError.networkError
        }
    }
}
```

- [ ] **Step 4: Add successful-response test**

Add this test to `ClaudeUsageClientTests.swift`:

```swift
@Test func decodesSuccessfulUsageResponse() async throws {
    let json = """
    { "five_hour": { "utilization": 42.5, "resets_at": "2026-05-04T15:00:00Z" } }
    """.data(using: .utf8)!

    let loader = StubClaudeURLLoader(result: (
        json,
        HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/api/oauth/usage")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
    ))

    let client = ClaudeUsageClient(loader: loader)
    let response = try await client.fetchUsage(
        accessToken: "synthetic-access-token",
        claudeVersion: "2.1.126"
    )

    #expect(response.fiveHour?.utilization == 42.5)
}
```

- [ ] **Step 5: Run client tests**

Run:

```bash
cd apps/mac && swift test --filter ClaudeUsageClientTests
```

Expected: PASS.

- [ ] **Step 6: Run all Swift tests**

Run:

```bash
cd apps/mac && swift test
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/Claude/ClaudeUsageClient.swift apps/mac/Tests/WhatTheTokenMacTests/ClaudeUsageClientTests.swift
git commit -m "feat(mac): add Claude usage client"
```

## Task 6: Local Connector View Model And Codex Source State

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/Connectors/ConnectorStatus.swift`
- Create: `apps/mac/Sources/WhatTheTokenMac/Connectors/LocalConnectorViewModel.swift`
- Create: `apps/mac/Tests/WhatTheTokenMacTests/LocalConnectorViewModelTests.swift`

- [ ] **Step 1: Write failing unified connector tests**

Create `apps/mac/Tests/WhatTheTokenMacTests/LocalConnectorViewModelTests.swift`:

```swift
import Foundation
import Testing
@testable import WhatTheTokenMac

@Test func exposesClaudeAndCodexInOneConnectorStatusList() {
    let claudeSource = ConnectorSource(
        connector: "mac_connector",
        state: .connected,
        label: "Mac connector",
        parserVersion: "claude-code-oauth-usage-v1",
        deviceId: "device_mac_01"
    )

    let claudeSnapshot = UsageSnapshot(
        id: "snap_claude",
        userAccountId: "local_user",
        provider: "anthropic",
        product: "claude_code",
        surface: "cli",
        poolKey: "anthropic_claude_subscription",
        windowKey: "five_hour",
        unit: "utilization",
        used: 42.5,
        limit: 100,
        remaining: 57.5,
        utilization: 0.425,
        resetAt: "2026-05-04T15:00:00Z",
        lastUpdatedAt: "2026-05-04T10:00:00.000Z",
        confidence: "verified",
        undercountRisk: "possible",
        staleReason: nil,
        source: claudeSource
    )

    let viewModel = LocalConnectorViewModel(
        snapshots: [claudeSnapshot],
        statuses: [
            ConnectorStatus(product: "claude_code", source: claudeSource, message: "Connected"),
            ConnectorStatus(
                product: "codex",
                source: ConnectorSource(
                    connector: "mac_connector",
                    state: .notConnected,
                    label: "Mac connector",
                    parserVersion: "codex-local-review-v1",
                    deviceId: "device_mac_01"
                ),
                message: "Codex local metadata needs review before tracking"
            )
        ]
    )

    #expect(viewModel.snapshots.count == 1)
    #expect(viewModel.statuses.map(\\.product) == ["claude_code", "codex"])
    #expect(viewModel.statuses[1].source.state == .notConnected)
}
```

- [ ] **Step 2: Run connector tests and verify failure**

Run:

```bash
cd apps/mac && swift test --filter LocalConnectorViewModelTests
```

Expected: FAIL because `ConnectorStatus` and `LocalConnectorViewModel` do not exist.

- [ ] **Step 3: Add connector status model**

Create `apps/mac/Sources/WhatTheTokenMac/Connectors/ConnectorStatus.swift`:

```swift
struct ConnectorStatus: Equatable, Sendable {
    let product: String
    let source: ConnectorSource
    let message: String
}
```

- [ ] **Step 4: Add local connector view model**

Create `apps/mac/Sources/WhatTheTokenMac/Connectors/LocalConnectorViewModel.swift`:

```swift
import Observation

@Observable
final class LocalConnectorViewModel {
    var snapshots: [UsageSnapshot]
    var statuses: [ConnectorStatus]

    init(snapshots: [UsageSnapshot] = [], statuses: [ConnectorStatus] = []) {
        self.snapshots = snapshots
        self.statuses = statuses
    }
}
```

- [ ] **Step 5: Run connector tests**

Run:

```bash
cd apps/mac && swift test --filter LocalConnectorViewModelTests
```

Expected: PASS.

- [ ] **Step 6: Run all Swift tests**

Run:

```bash
cd apps/mac && swift test
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/Connectors apps/mac/Tests/WhatTheTokenMacTests/LocalConnectorViewModelTests.swift
git commit -m "feat(mac): model local connector statuses"
```

## Task 7: Source-Aware Status UI

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/StatusCardView.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/ContentView.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift`

- [ ] **Step 1: Write a display string test**

Add this test to `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift`:

```swift
@Test func statusCardCopyIncludesConnectorAndConfidence() throws {
    let snapshot = try StatusViewModel.loadFixtureSnapshot()

    #expect(StatusCardCopy.sourceLine(for: snapshot) == "Verified by Fixture")
    #expect(StatusCardCopy.riskLine(for: snapshot) == "Undercount possible")
}
```

- [ ] **Step 2: Run test and verify failure**

Run:

```bash
cd apps/mac && swift test --filter StatusViewModelTests/statusCardCopyIncludesConnectorAndConfidence
```

Expected: FAIL because `StatusCardCopy` does not exist.

- [ ] **Step 3: Add status card copy helper**

Add this helper at the bottom of `apps/mac/Sources/WhatTheTokenMac/Views/StatusCardView.swift`:

```swift
enum StatusCardCopy {
    static func sourceLine(for snapshot: UsageSnapshot) -> String {
        "\(snapshot.confidence.capitalized) by \(snapshot.source.label)"
    }

    static func riskLine(for snapshot: UsageSnapshot) -> String {
        switch snapshot.undercountRisk {
        case "none":
            return "No undercount risk"
        case "possible":
            return "Undercount possible"
        case "likely":
            return "Undercount likely"
        default:
            return "Undercount risk unknown"
        }
    }
}
```

- [ ] **Step 4: Update status card UI**

Replace `apps/mac/Sources/WhatTheTokenMac/Views/StatusCardView.swift` with:

```swift
import SwiftUI

struct StatusCardView: View {
    let snapshot: UsageSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(snapshot.confidence.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Text(primaryMetric)
                .font(.system(size: 28, weight: .semibold))

            ProgressView(value: snapshot.utilization ?? 0)
                .progressViewStyle(.linear)

            Text(StatusCardCopy.sourceLine(for: snapshot))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(StatusCardCopy.riskLine(for: snapshot))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Updated \(snapshot.lastUpdatedAt)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 320, alignment: .leading)
    }

    private var title: String {
        "\(snapshot.provider.capitalized) / \(snapshot.product.replacingOccurrences(of: "_", with: " "))"
    }

    private var primaryMetric: String {
        guard let remaining = snapshot.remaining else {
            return "Usage observed"
        }

        switch snapshot.unit {
        case "utilization":
            return "\(Int(remaining))% remaining"
        case "credits":
            return "\(remaining.formatted()) credits remaining"
        case "tokens":
            return "\(Int(remaining)) tokens remaining"
        case "requests":
            return "\(Int(remaining)) requests remaining"
        case "messages":
            return "\(Int(remaining)) messages remaining"
        default:
            return "\(remaining.formatted()) remaining"
        }
    }
}

enum StatusCardCopy {
    static func sourceLine(for snapshot: UsageSnapshot) -> String {
        "\(snapshot.confidence.capitalized) by \(snapshot.source.label)"
    }

    static func riskLine(for snapshot: UsageSnapshot) -> String {
        switch snapshot.undercountRisk {
        case "none":
            return "No undercount risk"
        case "possible":
            return "Undercount possible"
        case "likely":
            return "Undercount likely"
        default:
            return "Undercount risk unknown"
        }
    }
}
```

- [ ] **Step 5: Run Swift tests**

Run:

```bash
cd apps/mac && swift test
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/Views/StatusCardView.swift apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift
git commit -m "feat(mac): show connector provenance on status cards"
```

## Task 8: Data Contract Documentation And Final Verification

**Files:**
- Modify: `docs/architecture/data-contract.md`
- Modify: `docs/research/claude-code-local-signal-spike.md`

- [ ] **Step 1: Update data contract doc**

Update `docs/architecture/data-contract.md` to include this section:

```markdown
## Snapshot Source Metadata

Every `UsageSnapshot` includes sanitized source metadata:

- `connector`: `mac_connector`, `chrome_extension`, `web_dashboard`, or `manual_fixture`
- `state`: connector state such as `connected`, `missing_credentials`, `token_invalid`, `schema_changed`, or `stale`
- `label`: user-facing source label
- `parserVersion`: source/parser version used to produce the snapshot
- `deviceId`: local device identifier

Source metadata must never contain credentials, OAuth tokens, cookies, prompts, responses, or browser request bodies.
```

- [ ] **Step 2: Update Claude spike doc**

Append this section to `docs/research/claude-code-local-signal-spike.md`:

```markdown
## Implementation Follow-Up

The local connector plan is documented in `docs/superpowers/plans/2026-05-04-local-connector-trust.md`.

Implementation must keep the Claude Code OAuth token local to the Mac connector process. Tests use synthetic credentials and fixture responses only. Synced and displayed data is limited to sanitized `UsageSnapshot` records with connector source metadata.
```

- [ ] **Step 3: Run full verification**

Run:

```bash
pnpm check
cd apps/mac && swift test
```

Expected:

- `pnpm check` exits 0.
- Swift tests exit 0.
- No test output contains real credential material.

- [ ] **Step 4: Inspect git status and diff**

Run:

```bash
git status --short
git diff --stat origin/main...
```

Expected: only files from this plan changed.

- [ ] **Step 5: Commit docs**

```bash
git add docs/architecture/data-contract.md docs/research/claude-code-local-signal-spike.md
git commit -m "docs: document connector source contract"
```

- [ ] **Step 6: Push branch**

```bash
git push
```

Expected: branch updates successfully.

## Self-Review

Spec coverage:

- Unified status surface: Tasks 1, 2, 6, and 7 add source metadata and UI copy.
- Claude Code collection path: Tasks 3, 4, and 5 add parser, credential boundary, and request client with fixture-only tests.
- Local credential boundary: Tasks 4, 5, and 8 document and test local-only token handling.
- Codex visibility: Task 6 adds a visible local connector status without parsing unreviewed Codex local files.
- Frontend trust language: Task 7 implements initial Mac provenance copy; Task 8 updates data-contract docs.

Placeholder scan:

- This plan intentionally excludes Supabase, Chrome extension implementation, live endpoint polling in CI, iOS, payments, and production analytics.
- No unresolved markers remain in the plan.

Type consistency:

- TypeScript uses `ConnectorState`; Swift uses `ConnectorSourceState`.
- Both contracts use `ConnectorSource` fields: `connector`, `state`, `label`, `parserVersion`, `deviceId`.
- Snapshot source metadata is named `source` in both TypeScript and Swift.
