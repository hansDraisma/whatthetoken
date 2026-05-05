# OpenAI ChatGPT And Codex Ingestion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a safe Codex app-server rate-limit connector path and gather the validation data needed to decide whether ChatGPT can be verified or must remain browser-estimated.

**Architecture:** Mirror the existing Claude connector: response models, client, mapper, service, smoke command, and opt-in UI integration. The first implementation reads only `account/rateLimits/read` sanitized fields and maps utilization windows into `UsageSnapshot`; ChatGPT verified support is gated on a redacted live probe.

**Tech Stack:** Swift 6, Swift Testing, SwiftUI Observation, Foundation `Process`/JSON decoding, existing TypeScript/Zod core contract for downstream schema parity.

---

## File Structure

- Create `apps/mac/Sources/WhatTheTokenMac/Codex/CodexRateLimitsResponse.swift`: strict decoded models for sanitized app-server rate-limit fields.
- Create `apps/mac/Sources/WhatTheTokenMac/Codex/CodexUsageMapper.swift`: maps decoded buckets into `UsageSnapshot`.
- Create `apps/mac/Sources/WhatTheTokenMac/Codex/CodexAppServerClient.swift`: JSON-RPC client abstraction and app-server process boundary.
- Create `apps/mac/Sources/WhatTheTokenMac/Codex/CodexConnectorService.swift`: opt-in service and source-state mapping.
- Create `apps/mac/Sources/WhatTheTokenMac/Connectors/CodexConnectorRefreshing.swift`: protocol matching Claude connector pattern.
- Create `apps/mac/Sources/WhatTheTokenMac/Connectors/CodexConnectorSmokeCommand.swift`: developer-only sanitized smoke command.
- Modify `apps/mac/Sources/WhatTheTokenMac/WhatTheTokenApp.swift`: route `--codex-connector-smoke`.
- Modify `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift`: add explicit `connectCodex()` after the smoke command proves the service path.
- Add tests under `apps/mac/Tests/WhatTheTokenMacTests/`.
- Update `docs/architecture/privacy-boundaries.md` and `docs/architecture/data-contract.md` with Codex app-server mapping after implementation is validated.

## Task 1: Decode Codex Rate-Limit Responses

**Files:**

- Create: `apps/mac/Sources/WhatTheTokenMac/Codex/CodexRateLimitsResponse.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/CodexRateLimitsResponseTests.swift`

- [ ] **Step 1: Write failing decoder tests**

Create `CodexRateLimitsResponseTests.swift`:

```swift
import Foundation
import Testing
@testable import WhatTheTokenMac

@Test func decodesSingleBucketRateLimitResponse() throws {
    let json = """
    {
      "rateLimits": {
        "limitId": "codex",
        "limitName": null,
        "planType": "plus",
        "primary": { "usedPercent": 25, "windowDurationMins": 15, "resetsAt": 1730947200 },
        "secondary": null,
        "credits": null,
        "rateLimitReachedType": null
      },
      "rateLimitsByLimitId": null
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(CodexRateLimitsResponse.self, from: json)

    #expect(response.rateLimits.limitId == "codex")
    #expect(response.rateLimits.planType == "plus")
    #expect(response.rateLimits.primary?.usedPercent == 25)
    #expect(response.rateLimits.primary?.windowDurationMins == 15)
    #expect(response.rateLimits.primary?.resetsAt == 1730947200)
}

@Test func decodesMultiBucketRateLimitResponse() throws {
    let json = """
    {
      "rateLimits": {
        "limitId": "codex",
        "primary": { "usedPercent": 25 }
      },
      "rateLimitsByLimitId": {
        "codex": {
          "limitId": "codex",
          "primary": { "usedPercent": 25, "windowDurationMins": 15, "resetsAt": 1730947200 }
        },
        "codex_other": {
          "limitId": "codex_other",
          "limitName": "codex_other",
          "primary": { "usedPercent": 42, "windowDurationMins": 60, "resetsAt": 1730950800 },
          "secondary": { "usedPercent": 10, "windowDurationMins": 1440, "resetsAt": null }
        }
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(CodexRateLimitsResponse.self, from: json)

    #expect(response.buckets.count == 2)
    #expect(response.buckets.map(\.limitId).sorted() == ["codex", "codex_other"])
    #expect(response.buckets.first { $0.limitId == "codex_other" }?.secondary?.usedPercent == 10)
}

@Test func decodesCreditsShapeWithoutAssumingNumericBalance() throws {
    let json = """
    {
      "rateLimits": {
        "limitId": "codex",
        "primary": { "usedPercent": 80 },
        "credits": { "hasCredits": true, "unlimited": false, "balance": "12.50" }
      }
    }
    """.data(using: .utf8)!

    let response = try JSONDecoder().decode(CodexRateLimitsResponse.self, from: json)

    #expect(response.rateLimits.credits?.hasCredits == true)
    #expect(response.rateLimits.credits?.unlimited == false)
    #expect(response.rateLimits.credits?.balance == "12.50")
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
swift test --filter CodexRateLimitsResponseTests
```

Expected: compile fails because `CodexRateLimitsResponse` does not exist.

- [ ] **Step 3: Implement response models**

Create `CodexRateLimitsResponse.swift`:

```swift
import Foundation

struct CodexRateLimitsResponse: Decodable, Equatable, Sendable {
    let rateLimits: CodexRateLimitSnapshot
    let rateLimitsByLimitId: [String: CodexRateLimitSnapshot]?

    var buckets: [CodexRateLimitSnapshot] {
        if let rateLimitsByLimitId, !rateLimitsByLimitId.isEmpty {
            return rateLimitsByLimitId.values.sorted { ($0.limitId ?? "") < ($1.limitId ?? "") }
        }

        return [rateLimits]
    }
}

struct CodexRateLimitSnapshot: Decodable, Equatable, Sendable {
    let credits: CodexCreditsSnapshot?
    let limitId: String?
    let limitName: String?
    let planType: String?
    let primary: CodexRateLimitWindow?
    let rateLimitReachedType: String?
    let secondary: CodexRateLimitWindow?
}

struct CodexRateLimitWindow: Decodable, Equatable, Sendable {
    let resetsAt: Int?
    let usedPercent: Int
    let windowDurationMins: Int?
}

struct CodexCreditsSnapshot: Decodable, Equatable, Sendable {
    let balance: String?
    let hasCredits: Bool
    let unlimited: Bool
}
```

- [ ] **Step 4: Run tests and verify they pass**

Run:

```bash
swift test --filter CodexRateLimitsResponseTests
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/Codex/CodexRateLimitsResponse.swift apps/mac/Tests/WhatTheTokenMacTests/CodexRateLimitsResponseTests.swift
git commit -m "feat: decode codex rate limit snapshots"
```

## Task 2: Map Codex Buckets To Usage Snapshots

**Files:**

- Create: `apps/mac/Sources/WhatTheTokenMac/Codex/CodexUsageMapper.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/CodexUsageMapperTests.swift`

- [ ] **Step 1: Write failing mapper tests**

Create `CodexUsageMapperTests.swift`:

```swift
import Foundation
import Testing
@testable import WhatTheTokenMac

@Test func mapsPrimaryWindowToUtilizationSnapshot() throws {
    let response = CodexRateLimitsResponse(
        rateLimits: CodexRateLimitSnapshot(
            credits: nil,
            limitId: "codex",
            limitName: nil,
            planType: "plus",
            primary: CodexRateLimitWindow(resetsAt: 1730947200, usedPercent: 25, windowDurationMins: 15),
            rateLimitReachedType: nil,
            secondary: nil
        ),
        rateLimitsByLimitId: nil
    )
    let source = ConnectorSource(
        connector: "mac_connector",
        state: .connected,
        label: "Mac connector",
        parserVersion: "codex-app-server-rate-limits-v1",
        deviceId: "device_mac_01"
    )

    let snapshots = CodexUsageMapper.map(
        response,
        userAccountId: "local_user",
        deviceId: "device_mac_01",
        observedAt: "2026-05-05T10:00:00.000Z",
        source: source
    )

    let snapshot = try #require(snapshots.first)
    #expect(snapshot.provider == "openai")
    #expect(snapshot.product == "codex")
    #expect(snapshot.surface == "aggregate")
    #expect(snapshot.poolKey == "openai_codex_codex_d4cde064")
    #expect(snapshot.windowKey == "primary_rolling_15m")
    #expect(snapshot.unit == "utilization")
    #expect(snapshot.used == 25)
    #expect(snapshot.limit == 100)
    #expect(snapshot.remaining == 75)
    #expect(snapshot.utilization == 0.25)
    #expect(snapshot.resetAt == "2024-11-07T02:40:00Z")
    #expect(snapshot.confidence == "observed")
    #expect(snapshot.undercountRisk == "possible")
}

@Test func mapsPrimaryAndSecondaryWindowsSeparately() throws {
    let response = CodexRateLimitsResponse(
        rateLimits: CodexRateLimitSnapshot(
            credits: nil,
            limitId: "codex_other",
            limitName: "codex_other",
            planType: "business",
            primary: CodexRateLimitWindow(resetsAt: nil, usedPercent: 42, windowDurationMins: 60),
            rateLimitReachedType: nil,
            secondary: CodexRateLimitWindow(resetsAt: nil, usedPercent: 10, windowDurationMins: 1440)
        ),
        rateLimitsByLimitId: nil
    )
    let source = ConnectorSource(
        connector: "mac_connector",
        state: .connected,
        label: "Mac connector",
        parserVersion: "codex-app-server-rate-limits-v1",
        deviceId: "device_mac_01"
    )

    let snapshots = CodexUsageMapper.map(
        response,
        userAccountId: "local_user",
        deviceId: "device_mac_01",
        observedAt: "2026-05-05T10:00:00.000Z",
        source: source
    )

    #expect(snapshots.map(\.windowKey) == ["primary_rolling_60m", "secondary_rolling_1440m"])
}

@Test func ignoresBucketWithoutLimitIdOrWindows() {
    let response = CodexRateLimitsResponse(
        rateLimits: CodexRateLimitSnapshot(
            credits: nil,
            limitId: nil,
            limitName: nil,
            planType: nil,
            primary: nil,
            rateLimitReachedType: nil,
            secondary: nil
        ),
        rateLimitsByLimitId: nil
    )
    let source = ConnectorSource(
        connector: "mac_connector",
        state: .connected,
        label: "Mac connector",
        parserVersion: "codex-app-server-rate-limits-v1",
        deviceId: "device_mac_01"
    )

    let snapshots = CodexUsageMapper.map(
        response,
        userAccountId: "local_user",
        deviceId: "device_mac_01",
        observedAt: "2026-05-05T10:00:00.000Z",
        source: source
    )

    #expect(snapshots.isEmpty)
}

@Test func sanitizedLimitIdsIncludeStableHashToAvoidCollisions() throws {
    let response = CodexRateLimitsResponse(
        rateLimits: CodexRateLimitSnapshot(
            credits: nil,
            limitId: "codex.other",
            limitName: nil,
            planType: nil,
            primary: CodexRateLimitWindow(resetsAt: nil, usedPercent: 1, windowDurationMins: 15),
            rateLimitReachedType: nil,
            secondary: nil
        ),
        rateLimitsByLimitId: [
            "codex/other": CodexRateLimitSnapshot(
                credits: nil,
                limitId: "codex/other",
                limitName: nil,
                planType: nil,
                primary: CodexRateLimitWindow(resetsAt: nil, usedPercent: 2, windowDurationMins: 15),
                rateLimitReachedType: nil,
                secondary: nil
            ),
            "codex.other": CodexRateLimitSnapshot(
                credits: nil,
                limitId: "codex.other",
                limitName: nil,
                planType: nil,
                primary: CodexRateLimitWindow(resetsAt: nil, usedPercent: 1, windowDurationMins: 15),
                rateLimitReachedType: nil,
                secondary: nil
            )
        ]
    )
    let source = ConnectorSource(
        connector: "mac_connector",
        state: .connected,
        label: "Mac connector",
        parserVersion: "codex-app-server-rate-limits-v1",
        deviceId: "device_mac_01"
    )

    let snapshots = CodexUsageMapper.map(
        response,
        userAccountId: "local_user",
        deviceId: "device_mac_01",
        observedAt: "2026-05-05T10:00:00.000Z",
        source: source
    )

    #expect(Set(snapshots.map(\.poolKey)).count == 2)
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
swift test --filter CodexUsageMapperTests
```

Expected: compile fails because `CodexUsageMapper` does not exist.

- [ ] **Step 3: Implement mapper**

Create `CodexUsageMapper.swift`:

```swift
import Foundation

enum CodexUsageMapper {
    static func map(
        _ response: CodexRateLimitsResponse,
        userAccountId: String,
        deviceId: String,
        observedAt: String,
        source: ConnectorSource
    ) -> [UsageSnapshot] {
        response.buckets.flatMap { bucket in
            map(bucket, userAccountId: userAccountId, deviceId: deviceId, observedAt: observedAt, source: source)
        }
    }

    private static func map(
        _ bucket: CodexRateLimitSnapshot,
        userAccountId: String,
        deviceId: String,
        observedAt: String,
        source: ConnectorSource
    ) -> [UsageSnapshot] {
        guard let rawLimitId = bucket.limitId,
              let limitId = sanitizedKey(rawLimitId) else {
            return []
        }

        var snapshots: [UsageSnapshot] = []
        if let primary = bucket.primary {
            snapshots.append(makeSnapshot(
                bucketKey: limitId,
                windowPrefix: "primary",
                window: primary,
                userAccountId: userAccountId,
                deviceId: deviceId,
                observedAt: observedAt,
                source: source
            ))
        }

        if let secondary = bucket.secondary {
            snapshots.append(makeSnapshot(
                bucketKey: limitId,
                windowPrefix: "secondary",
                window: secondary,
                userAccountId: userAccountId,
                deviceId: deviceId,
                observedAt: observedAt,
                source: source
            ))
        }

        return snapshots
    }

    private static func makeSnapshot(
        bucketKey: String,
        windowPrefix: String,
        window: CodexRateLimitWindow,
        userAccountId: String,
        deviceId: String,
        observedAt: String,
        source: ConnectorSource
    ) -> UsageSnapshot {
        let used = Double(window.usedPercent)
        let limit = 100.0
        let windowKey: String
        if let duration = window.windowDurationMins {
            windowKey = "\(windowPrefix)_rolling_\(duration)m"
        } else {
            windowKey = "\(windowPrefix)_window_unknown"
        }

        return UsageSnapshot(
            id: "snap_openai_codex_\(bucketKey)_\(windowKey)_\(deviceId)",
            userAccountId: userAccountId,
            provider: "openai",
            product: "codex",
            surface: "aggregate",
            poolKey: "openai_codex_\(bucketKey)",
            windowKey: windowKey,
            unit: "utilization",
            used: used,
            limit: limit,
            remaining: max(limit - used, 0),
            utilization: used / limit,
            resetAt: isoString(fromUnixSeconds: window.resetsAt),
            lastUpdatedAt: observedAt,
            confidence: "observed",
            undercountRisk: "possible",
            staleReason: nil,
            source: source
        )
    }

    private static func sanitizedKey(_ value: String) -> String? {
        let allowed = value.lowercased().map { character -> Character in
            if character.isLetter || character.isNumber || character == "_" || character == "-" {
                return character
            }
            return "_"
        }
        let key = String(allowed).trimmingCharacters(in: CharacterSet(charactersIn: "_-"))
        guard !key.isEmpty else {
            return nil
        }

        return "\(key)_\(stableHash(value))"
    }

    private static func stableHash(_ value: String) -> String {
        let hash = value.utf8.reduce(UInt32(2_166_136_261)) { partial, byte in
            (partial ^ UInt32(byte)) &* 16_777_619
        }
        return String(hash, radix: 16)
    }

    private static func isoString(fromUnixSeconds seconds: Int?) -> String? {
        guard let seconds else {
            return nil
        }

        return ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: TimeInterval(seconds)))
    }
}
```

- [ ] **Step 4: Run tests and verify they pass**

Run:

```bash
swift test --filter CodexUsageMapperTests
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/Codex/CodexUsageMapper.swift apps/mac/Tests/WhatTheTokenMacTests/CodexUsageMapperTests.swift
git commit -m "feat: map codex rate limits to snapshots"
```

## Task 3: Add App-Server Client Boundary

**Files:**

- Create: `apps/mac/Sources/WhatTheTokenMac/Codex/CodexAppServerClient.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/CodexAppServerClientTests.swift`

- [ ] **Step 1: Write client tests with a fake transport**

Create tests that verify the client sends this JSON-RPC 2.0 request and decodes the result:

```json
{"jsonrpc":"2.0","method":"account/rateLimits/read","id":1}
```

The generated app-server schema requires `id` and `method` and does not require `jsonrpc`, but it permits extra fields; send the standard JSON-RPC 2.0 field for compatibility with stricter transports. Also verify a JSON-RPC error maps to `CodexAppServerClientError.authRequired` for auth failures and `schemaChanged` for missing `result.rateLimits`.

- [ ] **Step 2: Run failing tests**

Run:

```bash
swift test --filter CodexAppServerClientTests
```

Expected: compile fails because the client does not exist.

- [ ] **Step 3: Implement transport protocol and client**

Implement:

```swift
protocol CodexAppServerTransport: Sendable {
    func send(_ data: Data) async throws -> Data
}

enum CodexAppServerClientError: Error, Equatable {
    case authRequired
    case permissionDenied
    case networkError
    case schemaChanged
}

struct CodexAppServerClient: Sendable {
    let transport: CodexAppServerTransport

    func readRateLimits() async throws -> CodexRateLimitsResponse {
        let request = #"{"jsonrpc":"2.0","method":"account/rateLimits/read","id":1}"#.data(using: .utf8)!
        let data = try await transport.send(request)
        return try CodexJSONRPCDecoder.decodeRateLimitsResponse(from: data)
    }
}
```

The decoder must decode only `result` and never expose the raw envelope outside the client.

- [ ] **Step 4: Add live process transport behind explicit smoke-only construction**

Add `LiveCodexAppServerTransport` for smoke/live paths only. It must launch `codex app-server --listen stdio://`, write the JSON-RPC request to stdin, read one JSON-RPC response from stdout, enforce a 10-second timeout, terminate the process after the response, and return only response `Data` to `CodexAppServerClient`. It must not read `~/.codex` files directly and must not log stdout/stderr.

- [ ] **Step 5: Run tests**

Run:

```bash
swift test --filter CodexAppServerClientTests
```

Expected: tests pass with fake transport.

- [ ] **Step 6: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/Codex/CodexAppServerClient.swift apps/mac/Tests/WhatTheTokenMacTests/CodexAppServerClientTests.swift
git commit -m "feat: add codex app server rate limit client"
```

## Task 4: Add Codex Connector Service

**Files:**

- Create: `apps/mac/Sources/WhatTheTokenMac/Codex/CodexConnectorService.swift`
- Create: `apps/mac/Sources/WhatTheTokenMac/Connectors/CodexConnectorRefreshing.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/CodexConnectorServiceTests.swift`

- [ ] **Step 1: Write service tests**

Mirror Claude service tests:

- disabled connector returns `not_connected` and does not call client
- successful read returns connected snapshots
- auth-required maps to `missing_credentials` with user-facing copy that tells the user to run `codex login`
- permission denied maps to `permission_denied`
- network failure maps to `network_error`
- schema failure maps to `schema_changed`

- [ ] **Step 2: Run failing tests**

Run:

```bash
swift test --filter CodexConnectorServiceTests
```

Expected: compile fails because service does not exist.

- [ ] **Step 3: Implement service**

Create:

```swift
protocol CodexConnectorRefreshing: Sendable {
    func refresh() async throws -> CodexConnectorResult
}

struct CodexConnectorSettings: Equatable, Sendable {
    let isEnabled: Bool
}

struct CodexConnectorResult: Equatable, Sendable {
    let snapshots: [UsageSnapshot]
    let status: ConnectorStatus
}
```

`CodexConnectorService.refresh()` should mirror `ClaudeConnectorService.refresh()` and use source:

```swift
ConnectorSource(
    connector: "mac_connector",
    state: state,
    label: "Mac connector",
    parserVersion: "codex-app-server-rate-limits-v1",
    deviceId: deviceId
)
```

For auth-required failures, use status message `Sign in to Codex locally with codex login, then retry.` This avoids implying that WhatTheToken stores or needs Codex credentials.

- [ ] **Step 4: Run tests**

Run:

```bash
swift test --filter CodexConnectorServiceTests
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/Codex/CodexConnectorService.swift apps/mac/Sources/WhatTheTokenMac/Connectors/CodexConnectorRefreshing.swift apps/mac/Tests/WhatTheTokenMacTests/CodexConnectorServiceTests.swift
git commit -m "feat: add codex connector service"
```

## Task 5: Add Sanitized Codex Smoke Command

**Files:**

- Create: `apps/mac/Sources/WhatTheTokenMac/Connectors/CodexConnectorSmokeCommand.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/WhatTheTokenApp.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/CodexConnectorSmokeCommandTests.swift`

- [ ] **Step 1: Write smoke tests**

Tests must assert output contains state, status, snapshot count, and snapshot summaries. Tests must assert output does not contain:

- `Authorization`
- `accessToken`
- token-shaped substrings such as `eyJ`
- `refresh`
- `email`
- `prompt`
- `response`
- raw JSON snippets such as `"rateLimits"`

- [ ] **Step 2: Run failing tests**

Run:

```bash
swift test --filter CodexConnectorSmokeCommandTests
```

Expected: compile fails because smoke command does not exist.

- [ ] **Step 3: Implement smoke command**

Match `ClaudeConnectorSmokeCommand` structure:

- command flag: `--codex-connector-smoke`
- setup guard: require `CODEX_CONNECTOR_SMOKE=1` before live app-server access
- exit `0` only when connected and at least one snapshot exists
- exit `2` for expected not-connected/missing/auth/schema states
- exit `1` for unexpected failures

The smoke tests should assert that no token-shaped string such as `eyJ` appears in output.

- [ ] **Step 4: Wire app entry**

In `WhatTheTokenApp.swift`, check `CodexConnectorSmokeCommand.shouldRun(arguments:)` next to the Claude smoke command and start it before UI launch.

- [ ] **Step 5: Run tests**

Run:

```bash
swift test --filter CodexConnectorSmokeCommandTests
swift test --filter ClaudeConnectorSmokeCommandTests
```

Expected: tests pass.

- [ ] **Step 6: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/Connectors/CodexConnectorSmokeCommand.swift apps/mac/Sources/WhatTheTokenMac/WhatTheTokenApp.swift apps/mac/Tests/WhatTheTokenMacTests/CodexConnectorSmokeCommandTests.swift
git commit -m "feat: add codex connector smoke command"
```

## Task 6: Run Manual Redacted Live Probe

**Files:**

- Modify: `docs/research/openai-chatgpt-codex-ingestion-spike.md`
- Create if needed: `.context/codex-live-probe-redacted.md`

- [ ] **Step 1: Run live smoke only with explicit local opt-in**

Run:

```bash
CODEX_CONNECTOR_SMOKE=1 swift run WhatTheTokenMac --codex-connector-smoke
```

Expected: sanitized lines only. No raw JSON, email, tokens, prompts, responses, auth refresh values, local paths, task titles, or task summaries.

- [ ] **Step 2: Record required validation facts**

Record only:

- connector state
- bucket ids
- bucket names
- plan type if present
- primary/secondary used percent
- primary/secondary window duration
- whether reset timestamps are present
- whether credits are present and whether balance is numeric
- whether any bucket clearly maps to ChatGPT rather than Codex

- [ ] **Step 3: Update research doc**

Update `docs/research/openai-chatgpt-codex-ingestion-spike.md` with a sanitized validation summary. Do not paste raw output if it contains any unreviewed field.

- [ ] **Step 4: Commit**

```bash
git add docs/research/openai-chatgpt-codex-ingestion-spike.md
git commit -m "docs: record codex rate limit validation"
```

## Task 7: Decide ChatGPT Path And Confidence

**Files:**

- Modify: `docs/superpowers/specs/2026-05-05-openai-chatgpt-codex-ingestion-design.md`
- Modify if validation succeeds: `apps/mac/Sources/WhatTheTokenMac/Codex/CodexUsageMapper.swift`
- Modify if validation succeeds: `apps/mac/Tests/WhatTheTokenMacTests/CodexUsageMapperTests.swift`
- Add later if needed: `docs/superpowers/specs/YYYY-MM-DD-chatgpt-browser-counter-design.md`

- [ ] **Step 1: If live probe returns ChatGPT buckets**

Update the design with exact bucket classification rules and add mapper tests for `product: "chatgpt"`.

- [ ] **Step 2: If live probe proves Codex buckets are aggregate provider buckets**

Change Codex mapper confidence from `observed` to `verified` and undercount risk from `possible` to `none`. Update `CodexUsageMapperTests` expected values in the same commit.

- [ ] **Step 3: If live probe returns only Codex or ambiguous buckets**

Create a separate ChatGPT browser counter spec. Keep ChatGPT snapshots `estimated` and do not implement browser tracking inside the Codex connector.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs
git commit -m "docs: decide chatgpt ingestion path"
```

## Task 8: Add Explicit Codex UI Hook

**Files:**

- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/ContentView.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelCodexConnectorTests.swift`

- [ ] **Step 1: Write view-model tests**

Create tests mirroring `StatusViewModelClaudeConnectorTests`:

- initializing live/fixture view model does not refresh Codex
- calling `connectCodex()` calls the injected `CodexConnectorRefreshing` once
- duplicate calls while checking do not start overlapping refreshes
- connected result appends or replaces Codex snapshots without dropping existing Claude snapshots unless product keys collide
- auth-required status surfaces `Sign in to Codex locally with codex login, then retry.`

- [ ] **Step 2: Run failing tests**

Run:

```bash
swift test --filter StatusViewModelCodexConnectorTests
```

Expected: compile fails because `connectCodex()` and Codex view-model state do not exist.

- [ ] **Step 3: Implement view-model hook**

Add optional `codexRefresher: CodexConnectorRefreshing?`, Codex setup state, and `connectCodex()` to `StatusViewModel`. Keep Codex disconnected on startup. The method must mirror Claude's duplicate-connect guard and must only call the refresher from the explicit Codex action.

- [ ] **Step 4: Add UI action**

In `ContentView.swift`, add a `Connect Codex` action near the Claude connector setup. Copy must say Codex auth stays inside Codex and ask the user to run `codex login` when auth is missing.

- [ ] **Step 5: Run tests**

Run:

```bash
swift test --filter StatusViewModelCodexConnectorTests
swift test --filter StatusViewModelClaudeConnectorTests
```

Expected: Codex and existing Claude view-model tests pass.

- [ ] **Step 6: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift apps/mac/Sources/WhatTheTokenMac/Views/ContentView.swift apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelCodexConnectorTests.swift
git commit -m "feat: add codex connector UI hook"
```

## Task 9: Final Verification

**Files:**

- All files changed above.

- [ ] **Step 1: Run focused Swift tests**

Run:

```bash
swift test --filter Codex
```

Expected: all Codex tests pass.

- [ ] **Step 2: Run existing connector tests**

Run:

```bash
swift test --filter ClaudeConnector
swift test --filter ClaudeUsage
swift test --filter StatusViewModel
```

Expected: existing Claude and status tests pass.

- [ ] **Step 3: Run core contract tests**

Run:

```bash
pnpm --filter @whatthetoken/core test
```

Expected: core schema tests pass.

- [ ] **Step 4: Privacy scan**

Run:

```bash
rg -n "Authorization|Bearer|accessToken|refreshToken|cookie|session|prompt|response|email|rateLimits\\\"" apps/mac/Sources apps/mac/Tests docs
```

Expected allowlist:

- privacy/data-contract deny-list documentation
- tests asserting redaction
- synthetic JSON fixtures in tests
- the Codex JSON-RPC client request literal containing `"rateLimits"`
- decoder model names and parser tests that contain rate-limit field names

No match may appear in logging, sync payload construction, smoke output formatting, diagnostics export, or persisted app resources.

- [ ] **Step 5: Review git diff**

Run:

```bash
git diff origin/main...
```

Expected: diff contains only Codex connector code, tests, and docs.

## Self-Review

- The plan implements the spec's Codex path and leaves ChatGPT verified support behind a validation gate.
- The plan avoids local Codex file inspection.
- The plan keeps live provider access manual and opt-in.
- The plan includes tests before implementation for every production component.
- The plan calls out the current schema limitation for credits instead of forcing a misleading credits snapshot.
