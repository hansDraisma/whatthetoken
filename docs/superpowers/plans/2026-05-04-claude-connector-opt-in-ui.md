# Claude Connector Opt-In UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an explicit Mac app `Connect Claude Code` path that calls the existing Claude connector only after user action and displays sanitized connector status or verified snapshots.

**Architecture:** Extract the shared Claude connector refresh protocol from the smoke command, inject it into `StatusViewModel`, add a small connector setup state model, render that state in `ContentView`, and instantiate a live view model from `WhatTheTokenApp` without refreshing on launch.

**Tech Stack:** Swift 6, SwiftUI, Observation, Swift Testing, existing WhatTheToken Mac package.

---

## Implementation Status

Implemented and verified on 2026-05-05.

Key implementation notes:

- `StatusViewModel.live()` injects the Claude connector but does not refresh on launch.
- `connectClaudeCode()` is the only product path that calls the connector refresher.
- Duplicate connect attempts while the connector state is `checking` return without starting another refresh.
- `InstalledClaudeVersionProvider` resolves the Claude executable from `PATH`, `~/.local/bin/claude`, `/opt/homebrew/bin/claude`, and `/usr/local/bin/claude`.
- `ClaudeConnectorSetupCopy` owns the tested setup titles and trust message used by `ContentView`.
- `ClaudeConnectorSmokeCommand` remains a developer-only local manual path behind `--claude-connector-smoke`.

Verification evidence:

- `swift test --filter StatusViewModelClaudeConnectorTests` passed with opt-in, duplicate-connect, and setup-copy coverage.
- `swift test --filter ClaudeVersionProviderTests` passed with restricted-path executable resolution coverage.
- `swift test --filter ClaudeConnectorSmokeCommandTests` passed.
- `cd apps/mac && swift test` passed with 43 Swift tests.
- `cd apps/mac && swift build` passed.
- `pnpm check` passed with 16 TypeScript core tests.
- `swift run WhatTheTokenMac` launched and stayed alive for five seconds in a bounded local GUI smoke.

## Context

Spec: `docs/superpowers/specs/2026-05-04-claude-connector-opt-in-ui-design.md`

Current state:

- `StatusViewModel` only stores fixture snapshots.
- `ContentView` only shows `No usage signal` or status cards.
- `ClaudeConnectorSmokeCommand.swift` currently declares `ClaudeConnectorRefreshing`.
- `WhatTheTokenApp` starts `ContentView(viewModel: .fixture())`.
- `ClaudeConnectorService.refresh()` already returns `ClaudeConnectorResult` with sanitized `ConnectorStatus`.

## Task 1: Add failing opt-in view-model tests

- [ ] Create `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelClaudeConnectorTests.swift`.
- [ ] Add test helpers in that file only:

```swift
private final class CountingClaudeConnectorRefresher: ClaudeConnectorRefreshing, @unchecked Sendable {
    private let lock = NSLock()
    private var storedRefreshCount = 0
    let result: Result<ClaudeConnectorResult, Error>

    var refreshCount: Int {
        lock.withLock {
            storedRefreshCount
        }
    }

    init(result: Result<ClaudeConnectorResult, Error>) {
        self.result = result
    }

    func refresh() async throws -> ClaudeConnectorResult {
        lock.withLock {
            storedRefreshCount += 1
        }

        return try result.get()
    }
}
```

- [ ] Add `liveViewModelDoesNotRefreshClaudeConnectorOnInit`.
  - Instantiate `StatusViewModel(claudeRefresher: refresher)`.
  - Assert `refresher.refreshCount == 0`.
  - Assert `viewModel.connectorState == .notConnected`.
  - Assert `viewModel.snapshots.isEmpty`.
- [ ] Add `connectClaudeCodeLoadsSnapshotsAfterUserAction`.
  - Stub a `ClaudeConnectorResult` with one `UsageSnapshot` and status source state `.connected`.
  - Call `await viewModel.connectClaudeCode()`.
  - Assert `refreshCount == 1`.
  - Assert `connectorState == .connected`.
  - Assert `snapshots.count == 1`.
  - Assert `connectorStatusMessage == "Claude Code connected"`.
- [ ] Add `missingCredentialsShowsStatusWithoutSnapshots`.
  - Stub status source state `.missingCredentials` and message `Claude Code credentials were not found`.
  - Call `await viewModel.connectClaudeCode()`.
  - Assert `connectorState == .missingCredentials`.
  - Assert `snapshots.isEmpty`.
  - Assert `connectorStatusMessage == "Claude Code credentials were not found"`.
- [ ] Add `thrownRefreshErrorShowsSanitizedNetworkError`.
  - Stub `Result.failure(SyntheticRefreshError())`.
  - Call `await viewModel.connectClaudeCode()`.
  - Assert `connectorState == .networkError`.
  - Assert `connectorStatusMessage == "Claude Code usage could not be refreshed"`.
  - Assert `connectorStatusMessage` does not contain the synthetic error description.
- [ ] Run the new test file and confirm it fails because the production state and initializer do not exist yet:

```bash
cd apps/mac && swift test --filter StatusViewModelClaudeConnectorTests
```

Expected: compile failure or test failure naming the missing view-model API.

## Task 2: Extract the shared Claude refresh protocol

- [ ] Add `apps/mac/Sources/WhatTheTokenMac/Connectors/ClaudeConnectorRefreshing.swift`:

```swift
protocol ClaudeConnectorRefreshing: Sendable {
    func refresh() async throws -> ClaudeConnectorResult
}

extension ClaudeConnectorService: ClaudeConnectorRefreshing {}
```

- [ ] Remove the same protocol and extension from `apps/mac/Sources/WhatTheTokenMac/Connectors/ClaudeConnectorSmokeCommand.swift`.
- [ ] Keep `ClaudeConnectorSmokeCommand` initializer unchanged:

```swift
init(refresher: ClaudeConnectorRefreshing) {
    self.refresher = refresher
}
```

- [ ] Run smoke command tests:

```bash
cd apps/mac && swift test --filter ClaudeConnectorSmokeCommandTests
```

Expected: tests pass with no behavior change.

## Task 3: Implement connector state in StatusViewModel

- [ ] Modify `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift`.
- [ ] Add this state enum near `FixtureError`:

```swift
enum ClaudeConnectorSetupState: Equatable, Sendable {
    case notConnected
    case checking
    case connected
    case missingCredentials
    case tokenInvalid
    case rateLimited
    case networkError
    case schemaChanged
}
```

- [ ] Add view-model properties:

```swift
var connectorState: ClaudeConnectorSetupState
var connectorStatusMessage: String
private let claudeRefresher: ClaudeConnectorRefreshing?
```

- [ ] Change the initializer to accept the optional refresher without refreshing:

```swift
init(
    snapshots: [UsageSnapshot] = [],
    claudeRefresher: ClaudeConnectorRefreshing? = nil,
    connectorState: ClaudeConnectorSetupState = .notConnected,
    connectorStatusMessage: String = "Claude Code is not connected"
) {
    self.snapshots = snapshots
    self.claudeRefresher = claudeRefresher
    self.connectorState = connectorState
    self.connectorStatusMessage = connectorStatusMessage
}
```

- [ ] Add `connectClaudeCode()`:

```swift
@MainActor
func connectClaudeCode() async {
    guard let claudeRefresher else {
        connectorState = .notConnected
        connectorStatusMessage = "Claude Code is not connected"
        return
    }

    connectorState = .checking
    connectorStatusMessage = "Checking Claude Code"

    do {
        let result = try await claudeRefresher.refresh()
        snapshots = result.snapshots
        connectorState = Self.setupState(for: result.status.source.state)
        connectorStatusMessage = result.status.message
    } catch {
        snapshots = []
        connectorState = .networkError
        connectorStatusMessage = "Claude Code usage could not be refreshed"
    }
}
```

- [ ] Add a private mapper:

```swift
private static func setupState(for sourceState: ConnectorSourceState) -> ClaudeConnectorSetupState {
    switch sourceState {
    case .connected:
        return .connected
    case .missingCredentials:
        return .missingCredentials
    case .tokenInvalid, .permissionDenied:
        return .tokenInvalid
    case .rateLimited:
        return .rateLimited
    case .schemaChanged:
        return .schemaChanged
    case .networkError:
        return .networkError
    case .notConnected, .stale:
        return .notConnected
    }
}
```

- [ ] Keep `fixture()` working by returning fixture snapshots with the default disconnected connector state.
- [ ] Run the new tests:

```bash
cd apps/mac && swift test --filter StatusViewModelClaudeConnectorTests
```

Expected: tests pass.

## Task 4: Render the opt-in connector surface

- [ ] Modify `apps/mac/Sources/WhatTheTokenMac/Views/ContentView.swift`.
- [ ] Keep the existing snapshot card list.
- [ ] Add a connector setup section above snapshots with:
  - title derived from `viewModel.connectorState`
  - `Text(viewModel.connectorStatusMessage)`
  - trust copy: `Reads Claude Code credentials locally only after you connect.`
  - `Button { Task { await viewModel.connectClaudeCode() } } label: { Label("Connect Claude Code", systemImage: "link") }`
- [ ] Disable the button while `viewModel.connectorState == .checking`.
- [ ] Use compact SwiftUI layout primitives already present in the app: `VStack`, `Text`, `Button`, `Divider`, and `.padding()`.
- [ ] Add a private title mapper in `ContentView`:

```swift
private func title(for state: ClaudeConnectorSetupState) -> String {
    switch state {
    case .notConnected:
        return "Claude Code is not connected"
    case .checking:
        return "Checking Claude Code"
    case .connected:
        return "Claude Code connected"
    case .missingCredentials:
        return "Claude Code credentials were not found"
    case .tokenInvalid:
        return "Claude Code credentials are invalid"
    case .rateLimited:
        return "Claude usage is rate limited"
    case .networkError:
        return "Claude Code usage could not be refreshed"
    case .schemaChanged:
        return "Claude usage response changed"
    }
}
```

- [ ] Run a Mac build:

```bash
cd apps/mac && swift build
```

Expected: build passes.

## Task 5: Add a local Claude version provider

- [ ] Add focused tests in `apps/mac/Tests/WhatTheTokenMacTests/ClaudeVersionProviderTests.swift`.
- [ ] Test `installedClaudeVersionProviderParsesClaudeCodeVersion`.
  - Stub output `2.1.126 (Claude Code)\n`.
  - Assert the provider returns `2.1.126`.
- [ ] Test `installedClaudeVersionProviderFallsBackWhenCommandFails`.
  - Stub a non-zero termination status.
  - Assert the provider returns `unknown`.
- [ ] Add `apps/mac/Sources/WhatTheTokenMac/Claude/ClaudeVersionProvider.swift`:

```swift
protocol ClaudeVersionCommandRunning: Sendable {
    func runClaudeVersion() throws -> ClaudeVersionCommandResult
}

struct ClaudeVersionCommandResult: Equatable, Sendable {
    let terminationStatus: Int32
    let standardOutput: Data
}

struct InstalledClaudeVersionProvider: ClaudeVersionProviding {
    let commandRunner: ClaudeVersionCommandRunning

    init(commandRunner: ClaudeVersionCommandRunning = ProcessClaudeVersionCommandRunner()) {
        self.commandRunner = commandRunner
    }

    var claudeVersion: String {
        guard
            let result = try? commandRunner.runClaudeVersion(),
            result.terminationStatus == 0,
            let output = String(data: result.standardOutput, encoding: .utf8),
            let version = output.split(separator: " ").first,
            !version.isEmpty
        else {
            return "unknown"
        }

        return String(version)
    }
}
```

- [ ] Implement `ProcessClaudeVersionCommandRunner` in the same file using `Process` to run `claude --version`, a five-second timeout, and `Pipe` for standard output and standard error.
- [ ] Keep this provider local-only: it must not read Keychain credentials or make network requests.
- [ ] Run the provider tests:

```bash
cd apps/mac && swift test --filter ClaudeVersionProviderTests
```

Expected: tests pass.

## Task 6: Wire the live view model into app startup

- [ ] Modify `apps/mac/Sources/WhatTheTokenMac/WhatTheTokenApp.swift`.
- [ ] Keep the existing `--claude-connector-smoke` early path unchanged.
- [ ] Replace fixture startup with a live `StatusViewModel` that injects `ClaudeConnectorService` and does not call `connectClaudeCode()`:

```swift
ContentView(viewModel: .live())
```

- [ ] Add `StatusViewModel.live()` in `StatusViewModel.swift`:

```swift
static func live() -> StatusViewModel {
    StatusViewModel(
        claudeRefresher: ClaudeConnectorService(
            settings: ClaudeConnectorSettings(isEnabled: true),
            credentialStore: MacOSClaudeCredentialStore(),
            usageFetcher: ClaudeUsageClient(),
            claudeVersionProvider: InstalledClaudeVersionProvider(),
            deviceId: "local_mac",
            userAccountId: "local_user",
            now: { ISO8601DateFormatter().string(from: Date()) }
        )
    )
}
```

- [ ] Run app build:

```bash
cd apps/mac && swift build
```

Expected: build passes and startup performs no Claude refresh.

## Task 7: Update docs after implementation

- [ ] Update `docs/architecture/tech-stack-and-development-approach.md` to add the opt-in UI path beside the smoke harness.
- [ ] Update `docs/architecture/privacy-boundaries.md` to state that the product UI does not read Claude credentials until the user chooses `Connect Claude Code`.
- [ ] Update `docs/research/claude-code-local-signal-spike.md` with the product wiring status and the no-auto-refresh boundary.

## Task 8: Full verification

- [ ] Run focused Swift tests:

```bash
cd apps/mac && swift test --filter StatusViewModelClaudeConnectorTests
cd apps/mac && swift test --filter ClaudeConnectorSmokeCommandTests
cd apps/mac && swift test --filter ClaudeVersionProviderTests
```

- [ ] Run full Swift tests:

```bash
cd apps/mac && swift test
```

- [ ] Run TypeScript checks to catch shared contract drift:

```bash
pnpm check
```

- [ ] Run a privacy grep:

```bash
rg -n "access_token|Authorization|Bearer|sessionToken|conversation|prompt|completion" apps/mac/Sources apps/mac/Tests docs
```

Expected: matches are limited to deny-list terms, synthetic test values, local credential model names, and documentation describing prohibited data.

- [ ] Inspect changed files:

```bash
git status --short
git diff --stat origin/main...
```

Expected: changes are limited to the Claude opt-in UI implementation, its tests, and documentation.

## Self-Review

Pass 1 - roadmap and scope:

- Implements the first immediate next step: explicit Claude opt-in product wiring.
- Defers installer/update flow, Chrome onboarding, Codex, background refresh, persistence, and sync.

Pass 2 - TDD and verification:

- Starts with failing view-model tests before production view-model work.
- Keeps live endpoint calls out of automated tests.
- Preserves smoke command verification after extracting the shared protocol.

Pass 3 - privacy, API fit, and implementation detail:

- No credential read happens on app launch because `StatusViewModel.live()` only injects dependencies.
- `connectClaudeCode()` is the single path that calls `refresh()`.
- State mapping covers every current `ConnectorSourceState` case.
- The plan names exact files, commands, UI copy, and expected outcomes.
