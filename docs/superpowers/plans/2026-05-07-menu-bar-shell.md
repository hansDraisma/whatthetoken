# Menu Bar Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the macOS app's primary UI from `WindowGroup` to a `MenuBarExtra` popover with status-only display, a Settings window for connector management, and a DEBUG-only developer window — implementing the locked design at `docs/superpowers/specs/2026-05-07-menu-bar-shell-design.md`.

**Architecture:** A single shared `StatusViewModel` (now `@MainActor`) is owned by an `AppModel` that wires all scenes. Pure presentation models (`BannerState`, `ProviderTabModel`, `PopoverFooterState`) project view-model state into deterministic, unit-testable display state. A `PopoverRefreshController` translates popover open/close lifecycle and a 30s in-popover timer into `refreshAll(reason:)` calls; the timer is sleeper-injected for deterministic tests. Settings drives per-provider `connectClaudeCode()` / `connectCodex()` directly; the popover's chrome refresh button drives `refreshAll`. The popover footer's "Last updated" is derived as the older of two per-provider timestamps. Old `ContentView` is deleted only after the new tree compiles and tests pass.

**Tech Stack:** Swift 6.0, SwiftUI (`MenuBarExtra(.window)`, `Settings { … }`, `Window(id:)`), `@Observable`, swift-testing (`@Test`, `#expect`, `@Suite`), AppKit interop (activation policy).

---

## File Structure

```
apps/mac/Sources/WhatTheTokenMac/
  WhatTheTokenApp.swift                              # MODIFY (Task 29, 30)
  MacAppLauncher.swift                               # MODIFY (Task 18)
  AppModel.swift                                     # CREATE (Task 20)
  ViewModels/
    StatusViewModel.swift                            # MODIFY (Tasks 4-8)
    BannerState.swift                                # CREATE (Task 1)
    ProviderTabModel.swift                           # CREATE (Task 2)
    PopoverFooterState.swift                         # CREATE (Task 3)
    PopoverRefreshController.swift                   # CREATE (Tasks 15-17)
  Views/
    Popover/
      PopoverRootView.swift                          # CREATE (Task 25)
      StatusBannerView.swift                         # CREATE (Task 21)
      ProviderTabBarView.swift                       # CREATE (Task 22)
      ProviderTabContentView.swift                   # CREATE (Task 23)
      PopoverFooterView.swift                        # CREATE (Task 24)
      StatusSectionView.swift                        # MOVE (Task 25)
    Settings/
      SettingsRootView.swift                         # CREATE (Task 27)
      ConnectorsView.swift                           # CREATE (Task 27)
      ConnectorRowView.swift                         # CREATE (Task 26)
    Developer/
      DeveloperWindowView.swift                      # CREATE (Task 28; #if DEBUG)
    ContentView.swift                                # DELETE (Task 31)

apps/mac/Tests/WhatTheTokenMacTests/
  Presentation/
    BannerStateTests.swift                           # CREATE (Tasks 11, 12)
    ProviderTabModelTests.swift                      # CREATE (Tasks 9, 10)
    PopoverFooterStateTests.swift                    # CREATE (Task 13)
    ConnectorActionTitleTests.swift                  # CREATE (Task 14)
  PopoverRefreshControllerTests.swift                # CREATE (Tasks 15-17)
  AppModelTests.swift                                # CREATE (Task 20)
  StatusViewModelTests.swift                         # MODIFY (Tasks 4, 6, 7, 8)
  MacAppLauncherTests.swift                          # MODIFY (Task 19)
```

Each file holds one focused responsibility. Tests mirror source layout under `Presentation/`.

---

## Conventions

**Test syntax:** swift-testing throughout. Top-level `@Test` functions or `@Suite struct Name { @Test func ... }`. Use `#expect(...)` for assertions, `#require(...)` for unwrapping.

**Test command (single test):**
```
cd apps/mac && swift test --filter <testFunctionName>
```

**Test command (suite):**
```
cd apps/mac && swift test --filter <SuiteName>
```

**Test command (full):**
```
cd apps/mac && swift test
```

**Commit style:** `feat(mac): ...` for code, `test(mac): ...` only when a commit is test-only. Keep messages short.

**Branch:** Stay on `hansDraisma/menubar-spend-tabs`.

---

## Phase 0 — Toolchain baseline (Task 0)

### Task 0: Enable Swift 6 language mode and verify the baseline

**Files:**
- Modify: `apps/mac/Package.swift`

`swift-tools-version: 6.0` is the *manifest API* version, not the language mode. Without `swiftLanguageModes: [.v6]`, the package compiles in Swift 5 mode with strict-concurrency *checking* — and `@MainActor`-implies-`Sendable` (SE-0434) does not apply. The Task closure patterns in Phase D and the SwiftUI views in Phase G assume Swift 6 isolation semantics. Set the language mode explicitly and confirm the existing tree still passes.

- [ ] **Step 1: Update `Package.swift`**

Replace the existing `Package(...)` block in `apps/mac/Package.swift` with:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WhatTheTokenMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "WhatTheTokenMac", targets: ["WhatTheTokenMac"])
    ],
    targets: [
        .executableTarget(
            name: "WhatTheTokenMac",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "WhatTheTokenMacTests",
            dependencies: ["WhatTheTokenMac"]
        )
    ],
    swiftLanguageModes: [.v6]
)
```

- [ ] **Step 2: Run the existing test suite**

```
cd apps/mac && swift test
```

Expected: green (no new failures introduced by switching to Swift 6 mode).

If Swift 6 mode surfaces concurrency errors in pre-existing files that this plan does not touch, fix them with the minimal annotation needed (`@MainActor` on a method, `Sendable` conformance on a value type, `@Sendable` on a closure). Keep the diff focused on isolation correctness; do not refactor structure.

If the baseline does not turn green within ~30 minutes of focused fixes, revert this task and continue under Swift 5 mode. Concretely:

```
git revert --no-edit HEAD
```

The revert commit message will read `Revert "build(mac): enable Swift 6 language mode"`. From there, every subsequent task that relied on `@MainActor`-implies-`Sendable` (the timer task in Phase D, the SwiftUI button-action `Task { ... }` closures in Phases G–I) needs explicit `@Sendable` annotations on the captured closures or `@unchecked Sendable` conformance on the `@MainActor` reference types. Add these inline as the compiler complains; do not preemptively annotate everything.

Continuing forward without a green baseline is not acceptable.

- [ ] **Step 3: Commit**

```
git add apps/mac/Package.swift
git commit -m "build(mac): enable Swift 6 language mode"
```

---

## Phase A — Pure Presentation Models (Tasks 1–3)

### Task 1: BannerState enum + BannerCopy

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/ViewModels/BannerState.swift`

- [ ] **Step 1: Write the failing test**

Add to `apps/mac/Tests/WhatTheTokenMacTests/Presentation/BannerStateTests.swift` (new file):

```swift
import Testing
@testable import WhatTheTokenMac

@Suite struct BannerStateTests {
    @Test func criticalCarriesText() {
        let state = BannerState.critical(text: "Claude Code is running critically low")
        if case let .critical(text) = state {
            #expect(text == "Claude Code is running critically low")
        } else {
            Issue.record("Expected .critical case")
        }
    }

    @Test func bannerCopyForCriticalProvider_codex() {
        #expect(BannerCopy.critical(provider: .codex) == "Codex is running critically low")
    }

    @Test func bannerCopyForLowProvider_claude() {
        #expect(BannerCopy.low(provider: .claude) == "Claude Code is running low")
    }

    @Test func bannerCopyForStale_isProviderAgnostic() {
        #expect(BannerCopy.stale == "Usage may be outdated. Refresh to check current limits.")
    }

    @Test func bannerCopyForDisconnectedSelected_codex() {
        #expect(BannerCopy.disconnected(selected: .codex) == "Codex is not connected. Open Settings to connect.")
    }

    @Test func bannerCopyForDisconnectedBoth_isBroad() {
        #expect(BannerCopy.disconnectedBoth == "Connect Claude or Codex in Settings.")
    }

    @Test func bannerCopyHintForOtherHealthy_codex() {
        #expect(BannerCopy.hint(otherHealthy: .codex) == "Codex has more room — consider switching new work.")
    }
}
```

- [ ] **Step 2: Run test — verify compile failure (no `BannerState`, `BannerCopy`, `ProviderTab`)**

```
cd apps/mac && swift test --filter BannerStateTests
```
Expected: build error — `cannot find type 'BannerState' in scope`, `cannot find 'BannerCopy' in scope`, `cannot find type 'ProviderTab' in scope`.

- [ ] **Step 3: Create `ProviderTab` and `BannerState` in `BannerState.swift`**

Create `apps/mac/Sources/WhatTheTokenMac/ViewModels/BannerState.swift`:

```swift
import Foundation

enum ProviderTab: String, CaseIterable, Identifiable, Sendable {
    case codex
    case claude

    var id: String { rawValue }
    var title: String {
        switch self {
        case .codex: return "Codex"
        case .claude: return "Claude Code"
        }
    }
}

enum BannerState: Equatable, Sendable {
    case hidden
    case critical(text: String)
    case low(text: String)
    case stale(text: String)
    case disconnected(text: String)
}

enum BannerCopy {
    static let stale = "Usage may be outdated. Refresh to check current limits."
    static let disconnectedBoth = "Connect Claude or Codex in Settings."

    static func critical(provider: ProviderTab) -> String {
        "\(provider.title) is running critically low"
    }

    static func low(provider: ProviderTab) -> String {
        "\(provider.title) is running low"
    }

    static func disconnected(selected: ProviderTab) -> String {
        "\(selected.title) is not connected. Open Settings to connect."
    }

    static func hint(otherHealthy other: ProviderTab) -> String {
        "\(other.title) has more room — consider switching new work."
    }
}
```

- [ ] **Step 4: Run tests — verify pass**

```
cd apps/mac && swift test --filter BannerStateTests
```
Expected: `Test run complete: <N> tests, 0 failures`.

- [ ] **Step 5: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/BannerState.swift apps/mac/Tests/WhatTheTokenMacTests/Presentation/BannerStateTests.swift
git commit -m "feat(mac): add BannerState and BannerCopy"
```

---

### Task 2: ProviderTabModel + nested enums

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/ViewModels/ProviderTabModel.swift`

- [ ] **Step 1: Write the failing test**

Append to `apps/mac/Tests/WhatTheTokenMacTests/Presentation/ProviderTabModelTests.swift` (new file):

```swift
import Testing
@testable import WhatTheTokenMac

@Suite struct ProviderTabModelTests {
    @Test func bodyEquatable_connected() {
        let snap: [UsageSnapshot] = []
        let a = ProviderTabModel.Body.connected(snapshots: snap, worst: .healthy)
        let b = ProviderTabModel.Body.connected(snapshots: snap, worst: .healthy)
        #expect(a == b)
    }

    @Test func disconnectedReasonsAreDistinct() {
        let a = ProviderTabModel.Body.disconnected(reason: .claude(.notConnected))
        let b = ProviderTabModel.Body.disconnected(reason: .claude(.missingCredentials))
        let c = ProviderTabModel.Body.disconnected(reason: .codex(.notConnected))
        #expect(a != b)
        #expect(a != c)
    }

    @Test func errorKindsAreDistinct() {
        let a = ProviderTabModel.Body.error(kind: .network, lastSnapshots: [])
        let b = ProviderTabModel.Body.error(kind: .schemaChanged, lastSnapshots: [])
        #expect(a != b)
    }
}
```

- [ ] **Step 2: Run test — verify compile failure**

```
cd apps/mac && swift test --filter ProviderTabModelTests
```
Expected: `cannot find type 'ProviderTabModel' in scope`.

- [ ] **Step 3: Create `ProviderTabModel.swift`**

Create `apps/mac/Sources/WhatTheTokenMac/ViewModels/ProviderTabModel.swift`:

```swift
import Foundation

struct ProviderTabModel: Equatable, Sendable {
    enum Body: Equatable, Sendable {
        case connected(snapshots: [UsageSnapshot], worst: StatusUsageState)
        case empty
        case checking
        case disconnected(reason: DisconnectedReason)
        case error(kind: ErrorKind, lastSnapshots: [UsageSnapshot])
    }

    // Provider-specific reasons keep impossible cross-provider combinations
    // unrepresentable in the type system. Mapping for Claude only constructs
    // `.claude(...)`; mapping for Codex only constructs `.codex(...)`. View
    // switches are exhaustive per provider and grow safely when Gemini lands
    // (add a `.gemini(...)` case; the compiler forces every consumer to handle it).
    enum DisconnectedReason: Equatable, Sendable {
        case claude(ClaudeDisconnectedReason)
        case codex(CodexDisconnectedReason)
    }

    enum ClaudeDisconnectedReason: Equatable, Sendable {
        case notConnected
        case missingCredentials
        case missingCLI
        case tokenInvalid
        case rateLimited
    }

    enum CodexDisconnectedReason: Equatable, Sendable {
        case notConnected
        case missingCredentials
        case permissionDenied
    }

    enum ErrorKind: Equatable, Sendable {
        case network
        case schemaChanged
    }

    let tab: ProviderTab
    let body: Body
}
```

- [ ] **Step 4: Run tests — verify pass**

```
cd apps/mac && swift test --filter ProviderTabModelTests
```
Expected: `0 failures`.

- [ ] **Step 5: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/ProviderTabModel.swift apps/mac/Tests/WhatTheTokenMacTests/Presentation/ProviderTabModelTests.swift
git commit -m "feat(mac): add ProviderTabModel and nested enums"
```

---

### Task 3: PopoverFooterState struct

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/ViewModels/PopoverFooterState.swift`

- [ ] **Step 1: Write the failing test**

Create `apps/mac/Tests/WhatTheTokenMacTests/Presentation/PopoverFooterStateTests.swift`:

```swift
import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct PopoverFooterStateTests {
    @Test func canRefreshIsInverseOfIsRefreshing() {
        let s = PopoverFooterState(lastUpdatedAt: nil, isRefreshing: true, canRefresh: false)
        #expect(s.isRefreshing == true)
        #expect(s.canRefresh == false)
    }

    @Test func equatable() {
        let date = Date(timeIntervalSince1970: 0)
        let a = PopoverFooterState(lastUpdatedAt: date, isRefreshing: false, canRefresh: true)
        let b = PopoverFooterState(lastUpdatedAt: date, isRefreshing: false, canRefresh: true)
        #expect(a == b)
    }
}
```

- [ ] **Step 2: Run — verify compile failure**

```
cd apps/mac && swift test --filter PopoverFooterStateTests
```
Expected: `cannot find type 'PopoverFooterState'`.

- [ ] **Step 3: Create file**

Create `apps/mac/Sources/WhatTheTokenMac/ViewModels/PopoverFooterState.swift`:

```swift
import Foundation

struct PopoverFooterState: Equatable, Sendable {
    let lastUpdatedAt: Date?
    let isRefreshing: Bool
    let canRefresh: Bool
}
```

- [ ] **Step 4: Run tests — verify pass**

```
cd apps/mac && swift test --filter PopoverFooterStateTests
```
Expected: `0 failures`.

- [ ] **Step 5: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/PopoverFooterState.swift apps/mac/Tests/WhatTheTokenMacTests/Presentation/PopoverFooterStateTests.swift
git commit -m "feat(mac): add PopoverFooterState"
```

---

## Phase B — StatusViewModel changes (Tasks 4–8)

### Task 4: Mark `StatusViewModel` as `@MainActor`; add per-provider timestamps + `isRefreshAllInFlight`

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift:5`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift` (add new tests at bottom)

- [ ] **Step 1: Write the failing test**

Append to `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift`:

```swift
@MainActor
@Test func newViewModel_hasNilTimestamps_andIsNotRefreshing() {
    let vm = StatusViewModel()
    #expect(vm.lastClaudeRefreshAt == nil)
    #expect(vm.lastCodexRefreshAt == nil)
    #expect(vm.isRefreshAllInFlight == false)
}
```

- [ ] **Step 2: Run — verify compile failure**

```
cd apps/mac && swift test --filter newViewModel_hasNilTimestamps
```
Expected: `value of type 'StatusViewModel' has no member 'lastClaudeRefreshAt'`.

- [ ] **Step 3: Add stored state and `@MainActor` annotation**

In `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift`, change the class declaration from:

```swift
@Observable
final class StatusViewModel {
```

to:

```swift
@MainActor
@Observable
final class StatusViewModel {
```

Add three stored properties immediately after the existing stored properties (after line 13):

```swift
    private(set) var lastClaudeRefreshAt: Date?
    private(set) var lastCodexRefreshAt: Date?
    private(set) var isRefreshAllInFlight: Bool = false
```

- [ ] **Step 4: Run tests — verify pass; run full suite to confirm @MainActor migration is clean**

```
cd apps/mac && swift test --filter newViewModel_hasNilTimestamps
cd apps/mac && swift test
```
Expected: `0 failures` for both. If the full run reveals call sites that violate the new `@MainActor` isolation, fix each by adding `@MainActor` to the calling test or wrapping the call in a `Task { @MainActor in ... }`. The existing tests touch `connectClaudeCode` / `connectCodex` from `@MainActor` test functions already, so most should pass without modification.

- [ ] **Step 5: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift
git commit -m "feat(mac): mark StatusViewModel @MainActor; add per-provider refresh state"
```

---

### Task 5: Add per-tab `lastRefreshAt(for:)` and derived `isAnyRefreshing`

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `StatusViewModelTests.swift`:

```swift
@MainActor
@Test func lastRefreshAt_isPerTab() {
    let vm = StatusViewModel()

    let claudeAt = Date(timeIntervalSince1970: 1_000)
    let codexAt  = Date(timeIntervalSince1970: 2_000)

    #expect(vm.lastRefreshAt(for: .claude) == nil)
    #expect(vm.lastRefreshAt(for: .codex) == nil)

    vm.testSet_lastClaudeRefreshAt(claudeAt)
    vm.testSet_lastCodexRefreshAt(codexAt)

    #expect(vm.lastRefreshAt(for: .claude) == claudeAt)
    #expect(vm.lastRefreshAt(for: .codex) == codexAt)
}

@MainActor
@Test func isAnyRefreshing_reflectsAllPaths() {
    let vm = StatusViewModel()
    #expect(vm.isAnyRefreshing == false)

    vm.testSet_isRefreshAllInFlight(true)
    #expect(vm.isAnyRefreshing == true)
}
```

- [ ] **Step 2: Run — verify compile failure**

```
cd apps/mac && swift test --filter lastRefreshAt_isPerTab
```
Expected: `cannot find 'testSet_lastClaudeRefreshAt'`, `'lastRefreshAt(for:)'`, etc.

- [ ] **Step 3: Add computed props and test-only setters**

Add to `StatusViewModel.swift` immediately after the new stored properties from Task 4:

```swift
    var isAnyRefreshing: Bool {
        connectorState == .checking
            || codexConnectorState == .checking
            || isRefreshAllInFlight
    }

    // Per-tab read; the popover's footer scopes "Last updated …" to whichever
    // tab is selected so the label never claims freshness for a provider that
    // wasn't part of the most recent refresh.
    func lastRefreshAt(for tab: ProviderTab) -> Date? {
        switch tab {
        case .claude: return lastClaudeRefreshAt
        case .codex:  return lastCodexRefreshAt
        }
    }

    #if DEBUG
    func testSet_lastClaudeRefreshAt(_ date: Date?) { lastClaudeRefreshAt = date }
    func testSet_lastCodexRefreshAt(_ date: Date?) { lastCodexRefreshAt = date }
    func testSet_isRefreshAllInFlight(_ value: Bool) { isRefreshAllInFlight = value }
    #endif
```

- [ ] **Step 4: Run tests — verify pass**

```
cd apps/mac && swift test --filter lastRefreshAt_isPerTab
cd apps/mac && swift test --filter isAnyRefreshing_reflectsAllPaths
```
Expected: `0 failures` for each.

- [ ] **Step 5: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift
git commit -m "feat(mac): add per-tab lastRefreshAt and derived isAnyRefreshing"
```

---

### Task 6: Add `RefreshReason` and `refreshAll(reason:)` with outer guard

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `StatusViewModelTests.swift`:

```swift
@MainActor
@Test func refreshAll_runsBothProvidersInOrder() async {
    final class CallRecorder: @unchecked Sendable {
        var calls: [String] = []
        func record(_ name: String) { calls.append(name) }
    }
    let recorder = CallRecorder()

    let claude = RecordingClaudeRefresher { recorder.record("claude") }
    let codex  = RecordingCodexRefresher  { recorder.record("codex")  }
    let vm = StatusViewModel(
        snapshots: [],
        claudeRefresher: claude,
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        codexRefresher: codex
    )

    await vm.refreshAll(reason: .manual)

    #expect(recorder.calls == ["claude", "codex"])
}

@MainActor
@Test func refreshAll_setsBothTimestamps() async {
    let vm = StatusViewModel(
        snapshots: [],
        claudeRefresher: NoopClaudeRefresher(),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        codexRefresher: NoopCodexRefresher()
    )
    #expect(vm.lastClaudeRefreshAt == nil)
    #expect(vm.lastCodexRefreshAt == nil)

    await vm.refreshAll(reason: .manual)

    #expect(vm.lastClaudeRefreshAt != nil)
    #expect(vm.lastCodexRefreshAt != nil)
}

@MainActor
@Test func refreshAll_dropsOverlappingChromeRefresh() async {
    let counter = Counter()
    let claude = SlowClaudeRefresher(counter: counter)
    let codex  = NoopCodexRefresher()

    let vm = StatusViewModel(
        snapshots: [],
        claudeRefresher: claude,
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        codexRefresher: codex
    )

    async let first  = vm.refreshAll(reason: .manual)
    async let second = vm.refreshAll(reason: .timerTick)
    _ = await (first, second)

    #expect(counter.value == 1, "Second overlapping refreshAll should be dropped by the outer guard.")
}
```

Add the test fakes to a new file `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelFakes.swift` (if it doesn't exist) — see helpers below in Step 3.

- [ ] **Step 2: Run — verify compile failure**

```
cd apps/mac && swift test --filter refreshAll_runsBothProvidersInOrder
```
Expected: `cannot find 'refreshAll'`, `cannot find 'RefreshReason'`, missing fake types.

- [ ] **Step 3: Add `RefreshReason` and `refreshAll`; create fakes**

Add to `StatusViewModel.swift`, immediately after the test-only setters:

```swift
    enum RefreshReason: Equatable, Sendable {
        case popoverOpened
        case manual
        case timerTick
        case retry
    }

    @MainActor
    func refreshAll(reason: RefreshReason) async {
        guard !isRefreshAllInFlight else { return }
        isRefreshAllInFlight = true
        defer { isRefreshAllInFlight = false }

        await connectClaudeCode()
        await connectCodex()
    }
```

Create `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelFakes.swift`:

```swift
import Foundation
@testable import WhatTheTokenMac

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0
    var value: Int { lock.withLock { _value } }
    func increment() { lock.withLock { _value += 1 } }
}

private func stubConnectorStatus(product: String) -> ConnectorStatus {
    ConnectorStatus(
        product: product,
        source: ConnectorSource(
            connector: "test",
            state: .connected,
            label: "Test",
            parserVersion: "v1",
            deviceId: "test_device"
        ),
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
    init(onRefresh: @escaping @Sendable () -> Void = {}) { self.onRefresh = onRefresh }

    func refresh() async throws -> ClaudeConnectorResult {
        onRefresh()
        return stubClaudeResult()
    }
}

final class SlowClaudeRefresher: ClaudeConnectorRefreshing, @unchecked Sendable {
    let counter: Counter
    init(counter: Counter) { self.counter = counter }

    func refresh() async throws -> ClaudeConnectorResult {
        counter.increment()
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        return stubClaudeResult()
    }
}

final class NoopClaudeRefresher: ClaudeConnectorRefreshing, @unchecked Sendable {
    func refresh() async throws -> ClaudeConnectorResult { stubClaudeResult() }
}

final class NoopCodexRefresher: CodexConnectorRefreshing, @unchecked Sendable {
    func refresh() async throws -> CodexConnectorResult { stubCodexResult() }
}

final class RecordingCodexRefresher: CodexConnectorRefreshing, @unchecked Sendable {
    let onRefresh: @Sendable () -> Void
    init(onRefresh: @escaping @Sendable () -> Void = {}) { self.onRefresh = onRefresh }

    func refresh() async throws -> CodexConnectorResult {
        onRefresh()
        return stubCodexResult()
    }
}
```

Note: `StaticClaudeVersionProvider` already lives in `apps/mac/Sources/WhatTheTokenMac/Claude/ClaudeConnectorService.swift`. Use it directly — `StaticClaudeVersionProvider(claudeVersion: "1.0.0")` for an "OK" version, `StaticClaudeVersionProvider(claudeVersion: "unknown")` to drive the missing-CLI path. Do not introduce a new provider fake.

- [ ] **Step 4: Run tests — verify pass**

```
cd apps/mac && swift test --filter refreshAll
```
Expected: both new tests pass.

- [ ] **Step 5: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelFakes.swift
git commit -m "feat(mac): add refreshAll with serialized outer guard"
```

---

### Task 7: Refactor `connectClaudeCode` to stamp timestamps via `defer + attempted`; fix snapshot-clear bug

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift:39-71`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `StatusViewModelTests.swift`:

```swift
@MainActor
@Test func connectClaudeCode_stampsTimestamp_onMissingCLIPath() async {
    let vm = StatusViewModel(
        snapshots: [],
        claudeRefresher: NoopClaudeRefresher(),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "unknown")
    )
    #expect(vm.lastClaudeRefreshAt == nil)
    await vm.connectClaudeCode()
    #expect(vm.lastClaudeRefreshAt != nil)
    #expect(vm.connectorState == .missingClaudeCli)
}

@MainActor
@Test func connectClaudeCode_stampsTimestamp_onNoRefresherPath() async {
    let vm = StatusViewModel(snapshots: [])
    #expect(vm.lastClaudeRefreshAt == nil)
    await vm.connectClaudeCode()
    #expect(vm.lastClaudeRefreshAt != nil)
    #expect(vm.connectorState == .notConnected)
}

@MainActor
@Test func connectClaudeCode_doesNotStamp_onCheckingGuardReentry() async {
    let vm = StatusViewModel(snapshots: [])
    vm.testSet_connectorStateToChecking()
    #expect(vm.lastClaudeRefreshAt == nil)
    await vm.connectClaudeCode()
    #expect(vm.lastClaudeRefreshAt == nil, "Re-entry guard must not stamp.")
}

@MainActor
@Test func connectClaudeCode_cancelledMidRefresh_doesNotStampTimestamp() async {
    let counter = Counter()
    let vm = StatusViewModel(
        snapshots: [],
        claudeRefresher: SlowClaudeRefresher(counter: counter),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0")
    )
    #expect(vm.lastClaudeRefreshAt == nil)

    let task = Task { await vm.connectClaudeCode() }
    // Give the refresh a moment to enter the slow path (50ms sleep), then cancel.
    try? await Task.sleep(nanoseconds: 5_000_000) // 5ms — enough to be in flight
    task.cancel()
    _ = await task.value

    #expect(vm.lastClaudeRefreshAt == nil, "Cancelled mid-refresh must not stamp the timestamp.")
}

@MainActor
@Test func connectClaudeCode_missingCLI_preservesCodexSnapshots() async {
    let codexSnapshot = UsageSnapshotFixture.codexSample()
    let claudeSnapshot = UsageSnapshotFixture.claudeSample()
    let vm = StatusViewModel(
        snapshots: [claudeSnapshot, codexSnapshot],
        claudeRefresher: NoopClaudeRefresher(),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "unknown")
    )

    await vm.connectClaudeCode()

    #expect(vm.snapshots.contains(where: { $0.id == codexSnapshot.id }), "Codex snapshot must survive Claude missing-CLI path.")
    #expect(!vm.snapshots.contains(where: { $0.id == claudeSnapshot.id }), "Claude snapshot must be cleared.")
    #expect(vm.connectorState == .missingClaudeCli)
}
```

Append to `StatusViewModelFakes.swift`:

```swift
private func testConnectorSource() -> ConnectorSource {
    ConnectorSource(
        connector: "test",
        state: .connected,
        label: "Test",
        parserVersion: "v1",
        deviceId: "test_device"
    )
}

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
            used: 0, limit: 100, remaining: 100, utilization: 0.0,
            resetAt: nil, lastUpdatedAt: "2026-05-07T00:00:00Z",
            confidence: "verified", undercountRisk: "none", staleReason: nil,
            display: nil, source: testConnectorSource()
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
            used: 0, limit: 100, remaining: 100, utilization: 0.0,
            resetAt: nil, lastUpdatedAt: "2026-05-07T00:00:00Z",
            confidence: "verified", undercountRisk: "none", staleReason: nil,
            display: nil, source: testConnectorSource()
        )
    }
}
```

The `ConnectorSource` initializer signature is `(connector:state:label:parserVersion:deviceId:)` — verified against `apps/mac/Sources/WhatTheTokenMac/Models/ConnectorSource.swift`. `NoopClaudeRefresher` is already defined in the previous fakes block from Task 6 — do not redeclare.

Add a test-only setter to `StatusViewModel.swift` (DEBUG block):

```swift
    func testSet_connectorStateToChecking() { connectorState = .checking }
```

- [ ] **Step 2: Run — verify compile + behavior failure**

```
cd apps/mac && swift test --filter connectClaudeCode_missingCLI_preservesCodexSnapshots
```
Expected: test fails because the existing code path uses `snapshots = []`, wiping Codex.

- [ ] **Step 3: Refactor `connectClaudeCode`**

Replace the body of `connectClaudeCode()` in `StatusViewModel.swift` with:

```swift
@MainActor
func connectClaudeCode() async {
    guard connectorState != .checking else { return }   // dedup re-entry; no stamp

    var attempted = false
    // Skip the timestamp stamp if the surrounding Task was cancelled mid-refresh.
    // Otherwise the user sees "Last updated: just now" for a refresh that never
    // completed authoritatively. State mutations that already happened above
    // remain in place — we only refuse to claim freshness we don't have.
    defer {
        if attempted && !Task.isCancelled {
            lastClaudeRefreshAt = Date()
        }
    }
    attempted = true

    guard let claudeRefresher else {
        connectorState = .notConnected
        connectorStatusMessage = "Claude Code is not connected"
        return
    }

    if let claudeVersionProvider, claudeVersionProvider.claudeVersion == "unknown" {
        replaceSnapshots(matching: { $0.provider == "anthropic" && $0.product == "claude_code" }, with: [])
        connectorState = .missingClaudeCli
        connectorStatusMessage = ClaudeConnectorSetupCopy.title(for: .missingClaudeCli)
        return
    }

    connectorState = .checking
    connectorStatusMessage = "Checking Claude Code"

    do {
        let result = try await claudeRefresher.refresh()
        replaceSnapshots(matching: { $0.provider == "anthropic" && $0.product == "claude_code" }, with: result.snapshots)
        connectorState = Self.setupState(for: result.status.source.state)
        connectorStatusMessage = result.status.message
    } catch {
        replaceSnapshots(matching: { $0.provider == "anthropic" && $0.product == "claude_code" }, with: [])
        connectorState = .networkError
        connectorStatusMessage = "Claude Code usage could not be refreshed"
    }
}
```

The key changes are:
1. `snapshots = []` → `replaceSnapshots(matching:with:)` with the Claude predicate (fixes the existing bug at the previous `:52`).
2. `defer + attempted` pattern stamps `lastClaudeRefreshAt` on every path past the `.checking` guard.

- [ ] **Step 4: Run tests — verify all pass**

```
cd apps/mac && swift test --filter connectClaudeCode
cd apps/mac && swift test
```
Expected: `0 failures`. Ensure existing Claude connector tests still pass.

- [ ] **Step 5: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelFakes.swift
git commit -m "feat(mac): scope Claude missing-CLI snapshot clear; stamp Claude timestamp via defer"
```

---

### Task 8: Refactor `connectCodex` symmetrically

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift:73-98`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

Append:

```swift
@MainActor
@Test func connectCodex_stampsTimestamp_onNoRefresherPath() async {
    let vm = StatusViewModel(snapshots: [])
    #expect(vm.lastCodexRefreshAt == nil)
    await vm.connectCodex()
    #expect(vm.lastCodexRefreshAt != nil)
    #expect(vm.codexConnectorState == .notConnected)
}

@MainActor
@Test func connectCodex_doesNotStamp_onCheckingGuardReentry() async {
    let vm = StatusViewModel(snapshots: [])
    vm.testSet_codexConnectorStateToChecking()
    #expect(vm.lastCodexRefreshAt == nil)
    await vm.connectCodex()
    #expect(vm.lastCodexRefreshAt == nil)
}
```

Add to the `#if DEBUG` block in `StatusViewModel.swift`:

```swift
    func testSet_codexConnectorStateToChecking() { codexConnectorState = .checking }
```

- [ ] **Step 2: Run — verify failure**

```
cd apps/mac && swift test --filter connectCodex_stampsTimestamp_onNoRefresherPath
```
Expected: failure — `lastCodexRefreshAt` is still nil because the current code does not stamp.

- [ ] **Step 3: Refactor `connectCodex`**

Replace the body of `connectCodex()` with:

```swift
@MainActor
func connectCodex() async {
    guard codexConnectorState != .checking else { return }

    var attempted = false
    defer {
        if attempted && !Task.isCancelled {
            lastCodexRefreshAt = Date()
        }
    }
    attempted = true

    guard let codexRefresher else {
        codexConnectorState = .notConnected
        codexConnectorStatusMessage = "Codex is not connected"
        return
    }

    codexConnectorState = .checking
    codexConnectorStatusMessage = "Checking Codex"

    do {
        let result = try await codexRefresher.refresh()
        replaceSnapshots(matching: { $0.provider == "openai" && $0.product == "codex" }, with: result.snapshots)
        codexConnectorState = Self.codexSetupState(for: result.status.source.state)
        codexConnectorStatusMessage = result.status.message
    } catch {
        replaceSnapshots(matching: { $0.provider == "openai" && $0.product == "codex" }, with: [])
        codexConnectorState = .networkError
        codexConnectorStatusMessage = "Codex usage could not be refreshed"
    }
}
```

- [ ] **Step 4: Run tests — verify pass**

```
cd apps/mac && swift test --filter connectCodex
cd apps/mac && swift test
```

- [ ] **Step 5: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift
git commit -m "feat(mac): stamp Codex timestamp via defer"
```

---

## Phase C — Mapping functions (Tasks 9–14)

### Task 9: `ProviderTabModel.from(viewModel:tab:)` — Claude mapping

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/ProviderTabModel.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/Presentation/ProviderTabModelTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `ProviderTabModelTests.swift` (inside the existing `@Suite struct ProviderTabModelTests`):

```swift
    @MainActor
    @Test func claude_notConnected_mapsToDisconnectedNotConnected() {
        let vm = StatusViewModel(snapshots: [], connectorState: .notConnected)
        let model = ProviderTabModel.from(viewModel: vm, tab: .claude)
        #expect(model.body == .disconnected(reason: .claude(.notConnected)))
    }

    @MainActor
    @Test func claude_checking_mapsToChecking() {
        let vm = StatusViewModel(snapshots: [], connectorState: .checking)
        let model = ProviderTabModel.from(viewModel: vm, tab: .claude)
        #expect(model.body == .checking)
    }

    @MainActor
    @Test func claude_connectedWithSnapshots_mapsToConnectedWithWorst() {
        let vm = StatusViewModel(snapshots: [UsageSnapshotFixture.claudeSample()], connectorState: .connected)
        let model = ProviderTabModel.from(viewModel: vm, tab: .claude)
        if case let .connected(snapshots, worst) = model.body {
            #expect(snapshots.count == 1)
            #expect(worst == .healthy)
        } else {
            Issue.record("Expected .connected body")
        }
    }

    @MainActor
    @Test func claude_connectedWithoutSnapshots_mapsToEmpty() {
        let vm = StatusViewModel(snapshots: [], connectorState: .connected)
        let model = ProviderTabModel.from(viewModel: vm, tab: .claude)
        #expect(model.body == .empty)
    }

    @MainActor
    @Test func claude_missingClaudeCli_mapsToDisconnectedMissingCLI() {
        let vm = StatusViewModel(snapshots: [], connectorState: .missingClaudeCli)
        let model = ProviderTabModel.from(viewModel: vm, tab: .claude)
        #expect(model.body == .disconnected(reason: .claude(.missingCLI)))
    }

    @MainActor
    @Test func claude_missingCredentials_mapsToDisconnected() {
        let vm = StatusViewModel(snapshots: [], connectorState: .missingCredentials)
        let model = ProviderTabModel.from(viewModel: vm, tab: .claude)
        #expect(model.body == .disconnected(reason: .claude(.missingCredentials)))
    }

    @MainActor
    @Test func claude_tokenInvalid_mapsToDisconnected() {
        let vm = StatusViewModel(snapshots: [], connectorState: .tokenInvalid)
        let model = ProviderTabModel.from(viewModel: vm, tab: .claude)
        #expect(model.body == .disconnected(reason: .claude(.tokenInvalid)))
    }

    @MainActor
    @Test func claude_rateLimited_mapsToDisconnectedRateLimited() {
        let vm = StatusViewModel(snapshots: [], connectorState: .rateLimited)
        let model = ProviderTabModel.from(viewModel: vm, tab: .claude)
        #expect(model.body == .disconnected(reason: .claude(.rateLimited)))
    }

    @MainActor
    @Test func claude_networkError_mapsToErrorNetwork() {
        let cached = [UsageSnapshotFixture.claudeSample()]
        let vm = StatusViewModel(snapshots: cached, connectorState: .networkError)
        let model = ProviderTabModel.from(viewModel: vm, tab: .claude)
        #expect(model.body == .error(kind: .network, lastSnapshots: cached))
    }

    @MainActor
    @Test func claude_schemaChanged_mapsToErrorSchemaChanged() {
        let vm = StatusViewModel(snapshots: [], connectorState: .schemaChanged)
        let model = ProviderTabModel.from(viewModel: vm, tab: .claude)
        #expect(model.body == .error(kind: .schemaChanged, lastSnapshots: []))
    }
```

- [ ] **Step 2: Run — verify compile failure**

```
cd apps/mac && swift test --filter claude_notConnected_mapsToDisconnectedNotConnected
```
Expected: `cannot find 'ProviderTabModel.from'`.

- [ ] **Step 3: Implement Claude mapping**

Append to `ProviderTabModel.swift`:

```swift
extension ProviderTabModel {
    @MainActor
    static func from(viewModel: StatusViewModel, tab: ProviderTab) -> ProviderTabModel {
        switch tab {
        case .claude:
            return fromClaude(viewModel: viewModel)
        case .codex:
            return fromCodex(viewModel: viewModel)
        }
    }

    @MainActor
    private static func fromClaude(viewModel: StatusViewModel) -> ProviderTabModel {
        let claudeSnapshots = viewModel.snapshots.filter {
            $0.provider == "anthropic" && $0.product == "claude_code"
        }

        let body: Body
        switch viewModel.connectorState {
        case .checking:
            body = .checking
        case .connected:
            if claudeSnapshots.isEmpty {
                body = .empty
            } else {
                let worst = claudeSnapshots.map { StatusUsageState(snapshot: $0) }.worstCase()
                body = .connected(snapshots: claudeSnapshots, worst: worst)
            }
        case .notConnected:
            body = .disconnected(reason: .claude(.notConnected))
        case .missingCredentials:
            body = .disconnected(reason: .claude(.missingCredentials))
        case .missingClaudeCli:
            body = .disconnected(reason: .claude(.missingCLI))
        case .tokenInvalid:
            body = .disconnected(reason: .claude(.tokenInvalid))
        case .rateLimited:
            body = .disconnected(reason: .claude(.rateLimited))
        case .networkError:
            body = .error(kind: .network, lastSnapshots: claudeSnapshots)
        case .schemaChanged:
            body = .error(kind: .schemaChanged, lastSnapshots: claudeSnapshots)
        }

        return ProviderTabModel(tab: .claude, body: body)
    }

    @MainActor
    private static func fromCodex(viewModel: StatusViewModel) -> ProviderTabModel {
        // Implemented in Task 10.
        return ProviderTabModel(tab: .codex, body: .checking)
    }
}

private extension Array where Element == StatusUsageState {
    func worstCase() -> StatusUsageState {
        // critical < empty < low < healthy by severity (empty == 0% remaining)
        if contains(.empty) { return .empty }
        if contains(.critical) { return .critical }
        if contains(.low) { return .low }
        return .healthy
    }
}
```

- [ ] **Step 4: Run tests — verify pass**

```
cd apps/mac && swift test --filter claude_
```
Expected: all 10 Claude mapping tests pass.

- [ ] **Step 5: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/ProviderTabModel.swift apps/mac/Tests/WhatTheTokenMacTests/Presentation/ProviderTabModelTests.swift
git commit -m "feat(mac): map StatusViewModel state to ProviderTabModel for Claude"
```

---

### Task 10: `ProviderTabModel.from(viewModel:tab:)` — Codex mapping

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/ProviderTabModel.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/Presentation/ProviderTabModelTests.swift`

- [ ] **Step 1: Write the failing tests**

Append:

```swift
    @MainActor
    @Test func codex_notConnected_mapsToDisconnected() {
        let vm = StatusViewModel(snapshots: [], codexConnectorState: .notConnected)
        let model = ProviderTabModel.from(viewModel: vm, tab: .codex)
        #expect(model.body == .disconnected(reason: .codex(.notConnected)))
    }

    @MainActor
    @Test func codex_checking_mapsToChecking() {
        let vm = StatusViewModel(snapshots: [], codexConnectorState: .checking)
        let model = ProviderTabModel.from(viewModel: vm, tab: .codex)
        #expect(model.body == .checking)
    }

    @MainActor
    @Test func codex_connectedWithSnapshots_mapsToConnected() {
        let vm = StatusViewModel(snapshots: [UsageSnapshotFixture.codexSample()], codexConnectorState: .connected)
        let model = ProviderTabModel.from(viewModel: vm, tab: .codex)
        if case let .connected(snapshots, _) = model.body {
            #expect(snapshots.count == 1)
        } else {
            Issue.record("Expected .connected")
        }
    }

    @MainActor
    @Test func codex_connectedWithoutSnapshots_mapsToEmpty() {
        let vm = StatusViewModel(snapshots: [], codexConnectorState: .connected)
        let model = ProviderTabModel.from(viewModel: vm, tab: .codex)
        #expect(model.body == .empty)
    }

    @MainActor
    @Test func codex_missingCredentials_mapsToDisconnected() {
        let vm = StatusViewModel(snapshots: [], codexConnectorState: .missingCredentials)
        let model = ProviderTabModel.from(viewModel: vm, tab: .codex)
        #expect(model.body == .disconnected(reason: .codex(.missingCredentials)))
    }

    @MainActor
    @Test func codex_permissionDenied_mapsToDisconnectedPermissionDenied() {
        let vm = StatusViewModel(snapshots: [], codexConnectorState: .permissionDenied)
        let model = ProviderTabModel.from(viewModel: vm, tab: .codex)
        #expect(model.body == .disconnected(reason: .codex(.permissionDenied)))
    }

    @MainActor
    @Test func codex_networkError_mapsToErrorNetwork() {
        let vm = StatusViewModel(snapshots: [], codexConnectorState: .networkError)
        let model = ProviderTabModel.from(viewModel: vm, tab: .codex)
        #expect(model.body == .error(kind: .network, lastSnapshots: []))
    }

    @MainActor
    @Test func codex_schemaChanged_mapsToErrorSchema() {
        let vm = StatusViewModel(snapshots: [], codexConnectorState: .schemaChanged)
        let model = ProviderTabModel.from(viewModel: vm, tab: .codex)
        #expect(model.body == .error(kind: .schemaChanged, lastSnapshots: []))
    }
```

- [ ] **Step 2: Run — verify failure**

```
cd apps/mac && swift test --filter codex_
```
Expected: tests fail because `fromCodex` is the stub from Task 9.

- [ ] **Step 3: Implement Codex mapping**

Replace the `fromCodex` stub in `ProviderTabModel.swift`:

```swift
    @MainActor
    private static func fromCodex(viewModel: StatusViewModel) -> ProviderTabModel {
        let codexSnapshots = viewModel.snapshots.filter {
            $0.provider == "openai" && $0.product == "codex"
        }

        let body: Body
        switch viewModel.codexConnectorState {
        case .checking:
            body = .checking
        case .connected:
            if codexSnapshots.isEmpty {
                body = .empty
            } else {
                let worst = codexSnapshots.map { StatusUsageState(snapshot: $0) }.worstCase()
                body = .connected(snapshots: codexSnapshots, worst: worst)
            }
        case .notConnected:
            body = .disconnected(reason: .codex(.notConnected))
        case .missingCredentials:
            body = .disconnected(reason: .codex(.missingCredentials))
        case .permissionDenied:
            body = .disconnected(reason: .codex(.permissionDenied))
        case .networkError:
            body = .error(kind: .network, lastSnapshots: codexSnapshots)
        case .schemaChanged:
            body = .error(kind: .schemaChanged, lastSnapshots: codexSnapshots)
        }

        return ProviderTabModel(tab: .codex, body: body)
    }
```

- [ ] **Step 4: Run tests — verify pass**

```
cd apps/mac && swift test --filter codex_
cd apps/mac && swift test --filter ProviderTabModelTests
```
Expected: all Codex tests pass; full suite still green.

- [ ] **Step 5: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/ProviderTabModel.swift apps/mac/Tests/WhatTheTokenMacTests/Presentation/ProviderTabModelTests.swift
git commit -m "feat(mac): map StatusViewModel state to ProviderTabModel for Codex"
```

---

### Task 11: `BannerState.from(viewModel:selected:)` — body cases

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/BannerState.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/Presentation/BannerStateTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `BannerStateTests.swift` (inside the existing suite):

```swift
    @MainActor
    @Test func banner_disconnectedSelected_codex_yieldsDisconnected() {
        let vm = StatusViewModel(snapshots: [], codexConnectorState: .notConnected)
        let banner = BannerState.from(viewModel: vm, selected: .codex)
        #expect(banner == .disconnected(text: "Codex is not connected. Open Settings to connect."))
    }

    @MainActor
    @Test func banner_bothDisconnected_broadensCopy() {
        let vm = StatusViewModel(snapshots: [], connectorState: .notConnected, codexConnectorState: .notConnected)
        let banner = BannerState.from(viewModel: vm, selected: .codex)
        #expect(banner == .disconnected(text: "Connect Claude or Codex in Settings."))
    }

    @MainActor
    @Test func banner_networkError_yieldsStale() {
        let vm = StatusViewModel(snapshots: [], codexConnectorState: .networkError)
        let banner = BannerState.from(viewModel: vm, selected: .codex)
        #expect(banner == .stale(text: BannerCopy.stale))
    }

    @MainActor
    @Test func banner_connectedHealthy_yieldsHidden() {
        var snap = UsageSnapshotFixture.claudeSample()
        // healthy by default (utilization 0)
        let vm = StatusViewModel(snapshots: [snap], connectorState: .connected)
        let banner = BannerState.from(viewModel: vm, selected: .claude)
        #expect(banner == .hidden)
    }

    @MainActor
    @Test func banner_emptyBody_isHidden() {
        let vm = StatusViewModel(snapshots: [], connectorState: .connected)
        let banner = BannerState.from(viewModel: vm, selected: .claude)
        #expect(banner == .hidden)
    }

    @MainActor
    @Test func banner_checkingBody_isHidden() {
        let vm = StatusViewModel(snapshots: [], connectorState: .checking)
        let banner = BannerState.from(viewModel: vm, selected: .claude)
        #expect(banner == .hidden)
    }

    @MainActor
    @Test func banner_critical_yieldsCritical() {
        let snap = UsageSnapshotFixture.claudeCriticalSample()
        let vm = StatusViewModel(snapshots: [snap], connectorState: .connected)
        let banner = BannerState.from(viewModel: vm, selected: .claude)
        if case .critical = banner { } else { Issue.record("Expected .critical") }
    }

    @MainActor
    @Test func banner_low_yieldsLow() {
        let snap = UsageSnapshotFixture.claudeLowSample()
        let vm = StatusViewModel(snapshots: [snap], connectorState: .connected)
        let banner = BannerState.from(viewModel: vm, selected: .claude)
        if case .low = banner { } else { Issue.record("Expected .low") }
    }

    @MainActor
    @Test func banner_empty_yieldsCriticalNotHidden() {
        // 0% remaining must surface as a critical banner, not be silenced.
        let snap = UsageSnapshotFixture.claudeEmptySample()
        let vm = StatusViewModel(snapshots: [snap], connectorState: .connected)
        let banner = BannerState.from(viewModel: vm, selected: .claude)
        if case .critical = banner { } else { Issue.record("Expected .critical for 0% remaining") }
    }

    @MainActor
    @Test func banner_connectedWithStaleReason_yieldsStale_overridingWorst() {
        // Even if `worst` is .healthy, a snapshot carrying a non-nil
        // `staleReason` must surface as `.stale` because the underlying data
        // is not authoritative.
        let snap = UsageSnapshotFixture.claudeStaleSample()
        let vm = StatusViewModel(snapshots: [snap], connectorState: .connected)
        let banner = BannerState.from(viewModel: vm, selected: .claude)
        if case let .stale(text) = banner {
            #expect(text == BannerCopy.stale)
        } else {
            Issue.record("Expected .stale when snapshot has staleReason")
        }
    }
```

Add to `StatusViewModelFakes.swift` (under `UsageSnapshotFixture`):

```swift
    static func claudeCriticalSample() -> UsageSnapshot {
        let s = claudeSample()
        // critical < 10% remaining → utilization > 0.90
        return UsageSnapshot(
            id: s.id, userAccountId: s.userAccountId, provider: s.provider, product: s.product,
            surface: s.surface, poolKey: s.poolKey, windowKey: s.windowKey, unit: "utilization",
            used: 95, limit: 100, remaining: 5, utilization: 0.95,
            resetAt: s.resetAt, lastUpdatedAt: s.lastUpdatedAt,
            confidence: s.confidence, undercountRisk: s.undercountRisk, staleReason: s.staleReason,
            display: s.display, source: s.source
        )
    }

    static func claudeLowSample() -> UsageSnapshot {
        let s = claudeSample()
        return UsageSnapshot(
            id: s.id, userAccountId: s.userAccountId, provider: s.provider, product: s.product,
            surface: s.surface, poolKey: s.poolKey, windowKey: s.windowKey, unit: "utilization",
            used: 80, limit: 100, remaining: 20, utilization: 0.80,
            resetAt: s.resetAt, lastUpdatedAt: s.lastUpdatedAt,
            confidence: s.confidence, undercountRisk: s.undercountRisk, staleReason: s.staleReason,
            display: s.display, source: s.source
        )
    }

    static func claudeEmptySample() -> UsageSnapshot {
        let s = claudeSample()
        return UsageSnapshot(
            id: s.id, userAccountId: s.userAccountId, provider: s.provider, product: s.product,
            surface: s.surface, poolKey: s.poolKey, windowKey: s.windowKey, unit: "utilization",
            used: 100, limit: 100, remaining: 0, utilization: 1.0,
            resetAt: s.resetAt, lastUpdatedAt: s.lastUpdatedAt,
            confidence: s.confidence, undercountRisk: s.undercountRisk, staleReason: s.staleReason,
            display: s.display, source: s.source
        )
    }

    /// A healthy-looking snapshot whose `staleReason` is non-nil. Banner mapping
    /// must honour the stale signal even when worst-case is healthy.
    static func claudeStaleSample() -> UsageSnapshot {
        let s = claudeSample()
        return UsageSnapshot(
            id: s.id, userAccountId: s.userAccountId, provider: s.provider, product: s.product,
            surface: s.surface, poolKey: s.poolKey, windowKey: s.windowKey, unit: s.unit,
            used: s.used, limit: s.limit, remaining: s.remaining, utilization: s.utilization,
            resetAt: s.resetAt, lastUpdatedAt: s.lastUpdatedAt,
            confidence: s.confidence, undercountRisk: s.undercountRisk,
            staleReason: "test_stale",
            display: s.display, source: s.source
        )
    }
```

- [ ] **Step 2: Run — verify compile failure**

```
cd apps/mac && swift test --filter banner_disconnectedSelected_codex_yieldsDisconnected
```
Expected: `cannot find 'BannerState.from'`.

- [ ] **Step 3: Implement `BannerState.from`**

Append to `BannerState.swift`:

```swift
extension BannerState {
    @MainActor
    static func from(viewModel: StatusViewModel, selected: ProviderTab) -> BannerState {
        let selectedModel = ProviderTabModel.from(viewModel: viewModel, tab: selected)
        let otherTab: ProviderTab = (selected == .claude) ? .codex : .claude
        let otherModel = ProviderTabModel.from(viewModel: viewModel, tab: otherTab)

        let bothDisconnected: Bool = {
            if case .disconnected = selectedModel.body, case .disconnected = otherModel.body { return true }
            return false
        }()

        switch selectedModel.body {
        case .disconnected:
            let text = bothDisconnected
                ? BannerCopy.disconnectedBoth
                : BannerCopy.disconnected(selected: selected)
            return .disconnected(text: text)

        case .error(.network, _), .error(.schemaChanged, _):
            return .stale(text: BannerCopy.stale)

        case let .connected(snapshots, worst):
            // staleReason check on rendered snapshots overrides healthy/low to .stale.
            if snapshots.contains(where: { $0.staleReason != nil }) {
                return .stale(text: BannerCopy.stale)
            }
            switch worst {
            case .empty, .critical:
                // .empty means 0% remaining — semantically more severe than
                // critical, not "no data." Both surface as a critical banner.
                let text = BannerCopy.critical(provider: selected)
                return .critical(text: appendHintIfApplicable(text, otherTab: otherTab, otherBody: otherModel.body))
            case .low:
                let text = BannerCopy.low(provider: selected)
                return .low(text: appendHintIfApplicable(text, otherTab: otherTab, otherBody: otherModel.body))
            case .healthy:
                return .hidden
            }

        case .empty, .checking:
            return .hidden
        }
    }

    private static func appendHintIfApplicable(_ base: String, otherTab: ProviderTab, otherBody: ProviderTabModel.Body) -> String {
        if case .connected(_, .healthy) = otherBody {
            return base + " — " + BannerCopy.hint(otherHealthy: otherTab)
        }
        return base
    }
}
```

- [ ] **Step 4: Run tests — verify pass**

```
cd apps/mac && swift test --filter banner_
```
Expected: all banner-body tests pass.

- [ ] **Step 5: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/BannerState.swift apps/mac/Tests/WhatTheTokenMacTests/Presentation/BannerStateTests.swift apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelFakes.swift
git commit -m "feat(mac): derive BannerState from StatusViewModel"
```

---

### Task 12: BannerState — cross-provider hint logic (focused tests)

**Files:**
- Test: `apps/mac/Tests/WhatTheTokenMacTests/Presentation/BannerStateTests.swift`

The mapping is implemented in Task 11; this task locks the hint behavior with focused tests.

- [ ] **Step 1: Write the failing tests**

Append:

```swift
    @MainActor
    @Test func banner_critical_appendsHint_whenOtherIsHealthy() {
        let claudeCrit = UsageSnapshotFixture.claudeCriticalSample()
        let codexHealthy = UsageSnapshotFixture.codexSample()  // healthy
        let vm = StatusViewModel(
            snapshots: [claudeCrit, codexHealthy],
            connectorState: .connected,
            codexConnectorState: .connected
        )
        let banner = BannerState.from(viewModel: vm, selected: .claude)
        if case let .critical(text) = banner {
            #expect(text.contains("Codex has more room"))
        } else {
            Issue.record("Expected .critical with hint")
        }
    }

    @MainActor
    @Test func banner_critical_doesNotAppendHint_whenOtherIsAlsoCritical() {
        let claudeCrit = UsageSnapshotFixture.claudeCriticalSample()
        let codexCrit = UsageSnapshotFixture.codexCriticalSample()
        let vm = StatusViewModel(
            snapshots: [claudeCrit, codexCrit],
            connectorState: .connected,
            codexConnectorState: .connected
        )
        let banner = BannerState.from(viewModel: vm, selected: .claude)
        if case let .critical(text) = banner {
            #expect(!text.contains("more room"))
        } else {
            Issue.record("Expected .critical")
        }
    }

    @MainActor
    @Test func banner_critical_doesNotAppendHint_whenOtherIsDisconnected() {
        let claudeCrit = UsageSnapshotFixture.claudeCriticalSample()
        let vm = StatusViewModel(
            snapshots: [claudeCrit],
            connectorState: .connected,
            codexConnectorState: .notConnected
        )
        let banner = BannerState.from(viewModel: vm, selected: .claude)
        if case let .critical(text) = banner {
            #expect(!text.contains("more room"))
        } else {
            Issue.record("Expected .critical")
        }
    }
```

Add `codexCriticalSample()` to `UsageSnapshotFixture`:

```swift
    static func codexCriticalSample() -> UsageSnapshot {
        let s = codexSample()
        return UsageSnapshot(
            id: s.id, userAccountId: s.userAccountId, provider: s.provider, product: s.product,
            surface: s.surface, poolKey: s.poolKey, windowKey: s.windowKey, unit: "utilization",
            used: 95, limit: 100, remaining: 5, utilization: 0.95,
            resetAt: s.resetAt, lastUpdatedAt: s.lastUpdatedAt,
            confidence: s.confidence, undercountRisk: s.undercountRisk, staleReason: s.staleReason,
            display: s.display, source: s.source
        )
    }
```

- [ ] **Step 2: Run — verify pass (mapping was implemented in Task 11)**

```
cd apps/mac && swift test --filter banner_critical_
```
Expected: all three pass; if any fails, return to the mapping in Task 11 and fix `appendHintIfApplicable`.

- [ ] **Step 3: Commit**

```
git add apps/mac/Tests/WhatTheTokenMacTests/Presentation/BannerStateTests.swift apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelFakes.swift
git commit -m "test(mac): cover cross-provider hint precedence"
```

---

### Task 13: `PopoverFooterState.from(viewModel:)`

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/PopoverFooterState.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/Presentation/PopoverFooterStateTests.swift`

- [ ] **Step 1: Write the failing tests**

Append:

```swift
    @MainActor
    @Test func footer_emptyState_hasNilTimestampAndCanRefresh() {
        let vm = StatusViewModel()
        let s = PopoverFooterState.from(viewModel: vm, selected: .claude)
        #expect(s.lastUpdatedAt == nil)
        #expect(s.isRefreshing == false)
        #expect(s.canRefresh == true)
    }

    @MainActor
    @Test func footer_whileRefreshing_disablesRefresh() {
        let vm = StatusViewModel()
        vm.testSet_isRefreshAllInFlight(true)
        let s = PopoverFooterState.from(viewModel: vm, selected: .claude)
        #expect(s.isRefreshing == true)
        #expect(s.canRefresh == false)
    }

    @MainActor
    @Test func footer_lastUpdatedAt_isScopedToSelectedTab() {
        // The asymmetric case: Claude refreshed long ago, Codex just refreshed.
        // The footer must reflect the selected tab, not min(claude, codex).
        let vm = StatusViewModel()
        let oldClaude = Date(timeIntervalSince1970: 1_000)
        let freshCodex = Date(timeIntervalSince1970: 2_000)
        vm.testSet_lastClaudeRefreshAt(oldClaude)
        vm.testSet_lastCodexRefreshAt(freshCodex)

        #expect(PopoverFooterState.from(viewModel: vm, selected: .claude).lastUpdatedAt == oldClaude)
        #expect(PopoverFooterState.from(viewModel: vm, selected: .codex).lastUpdatedAt == freshCodex)
    }
```

- [ ] **Step 2: Run — verify compile failure**

```
cd apps/mac && swift test --filter footer_emptyState_hasNilTimestampAndCanRefresh
```
Expected: `cannot find 'PopoverFooterState.from'`.

- [ ] **Step 3: Implement**

Append to `PopoverFooterState.swift`:

```swift
extension PopoverFooterState {
    @MainActor
    static func from(viewModel: StatusViewModel, selected: ProviderTab) -> PopoverFooterState {
        PopoverFooterState(
            lastUpdatedAt: viewModel.lastRefreshAt(for: selected),
            isRefreshing: viewModel.isAnyRefreshing,
            canRefresh: !viewModel.isAnyRefreshing
        )
    }
}
```

- [ ] **Step 4: Run tests — verify pass**

```
cd apps/mac && swift test --filter footer_
```
Expected: all 3 pass.

- [ ] **Step 5: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/PopoverFooterState.swift apps/mac/Tests/WhatTheTokenMacTests/Presentation/PopoverFooterStateTests.swift
git commit -m "feat(mac): derive PopoverFooterState from StatusViewModel"
```

---

### Task 14: Connector action-title functions (`claudeActionTitle` / `codexActionTitle`)

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/Views/Settings/ConnectorActionTitle.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/Presentation/ConnectorActionTitleTests.swift`

- [ ] **Step 1: Write the failing tests**

Create test file:

```swift
import Testing
@testable import WhatTheTokenMac

@Suite struct ConnectorActionTitleTests {
    @Test func claude_notConnected_isConnect() {
        #expect(claudeActionTitle(for: .notConnected) == "Connect")
    }
    @Test func claude_checking_isCheckingEllipsis() {
        #expect(claudeActionTitle(for: .checking) == "Checking…")
    }
    @Test func claude_connected_isRefresh() {
        #expect(claudeActionTitle(for: .connected) == "Refresh")
    }
    @Test func claude_networkError_isRetry() {
        #expect(claudeActionTitle(for: .networkError) == "Retry")
    }
    @Test func claude_schemaChanged_isRetry() {
        #expect(claudeActionTitle(for: .schemaChanged) == "Retry")
    }
    @Test func claude_rateLimited_isRetry() {
        #expect(claudeActionTitle(for: .rateLimited) == "Retry")
    }
    @Test func claude_missingCredentials_isConnect() {
        #expect(claudeActionTitle(for: .missingCredentials) == "Connect")
    }
    @Test func claude_missingClaudeCli_isConnect() {
        #expect(claudeActionTitle(for: .missingClaudeCli) == "Connect")
    }
    @Test func claude_tokenInvalid_isConnect() {
        #expect(claudeActionTitle(for: .tokenInvalid) == "Connect")
    }

    @Test func codex_notConnected_isConnect() {
        #expect(codexActionTitle(for: .notConnected) == "Connect")
    }
    @Test func codex_connected_isRefresh() {
        #expect(codexActionTitle(for: .connected) == "Refresh")
    }
    @Test func codex_networkError_isRetry() {
        #expect(codexActionTitle(for: .networkError) == "Retry")
    }
    @Test func codex_schemaChanged_isRetry() {
        #expect(codexActionTitle(for: .schemaChanged) == "Retry")
    }
    @Test func codex_permissionDenied_isConnect() {
        #expect(codexActionTitle(for: .permissionDenied) == "Connect")
    }
    @Test func codex_missingCredentials_isConnect() {
        #expect(codexActionTitle(for: .missingCredentials) == "Connect")
    }
    @Test func codex_checking_isCheckingEllipsis() {
        #expect(codexActionTitle(for: .checking) == "Checking…")
    }
}
```

- [ ] **Step 2: Run — verify compile failure**

```
cd apps/mac && swift test --filter ConnectorActionTitleTests
```
Expected: `cannot find 'claudeActionTitle'`.

- [ ] **Step 3: Implement**

Create `apps/mac/Sources/WhatTheTokenMac/Views/Settings/ConnectorActionTitle.swift`:

```swift
import Foundation

func claudeActionTitle(for state: ClaudeConnectorSetupState) -> String {
    switch state {
    case .notConnected, .missingCredentials, .missingClaudeCli, .tokenInvalid:
        return "Connect"
    case .checking:
        return "Checking…"
    case .connected:
        return "Refresh"
    case .networkError, .schemaChanged, .rateLimited:
        return "Retry"
    }
}

func codexActionTitle(for state: CodexConnectorSetupState) -> String {
    switch state {
    case .notConnected, .missingCredentials, .permissionDenied:
        return "Connect"
    case .checking:
        return "Checking…"
    case .connected:
        return "Refresh"
    case .networkError, .schemaChanged:
        return "Retry"
    }
}
```

- [ ] **Step 4: Run tests — verify pass**

```
cd apps/mac && swift test --filter ConnectorActionTitleTests
```
Expected: all 16 tests pass.

- [ ] **Step 5: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/Views/Settings/ConnectorActionTitle.swift apps/mac/Tests/WhatTheTokenMacTests/Presentation/ConnectorActionTitleTests.swift
git commit -m "feat(mac): add connector action-title rules"
```

---

## Phase D — `PopoverRefreshController` (Tasks 15–17)

### Task 15: Controller scaffolding + sleeper injection + manual/retry routing

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/ViewModels/PopoverRefreshController.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/PopoverRefreshControllerTests.swift`

- [ ] **Step 1: Write the failing tests**

Create test file:

```swift
import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct PopoverRefreshControllerTests {
    @MainActor
    @Test func userTappedRefresh_routesThroughRefreshAll() async {
        let vm = StatusViewModel(
            snapshots: [],
            claudeRefresher: NoopClaudeRefresher(),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
            codexRefresher: NoopCodexRefresher()
        )
        let controller = PopoverRefreshController(viewModel: vm, sleeper: { _ in })

        controller.userTappedRefresh()
        await Task.yield()
        await Task.yield()

        // Either lastClaudeRefreshAt or lastCodexRefreshAt set proves refreshAll executed.
        #expect(vm.lastClaudeRefreshAt != nil || vm.lastCodexRefreshAt != nil)
    }

    @MainActor
    @Test func userTappedRetry_routesThroughRefreshAll() async {
        let vm = StatusViewModel(
            snapshots: [],
            claudeRefresher: NoopClaudeRefresher(),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
            codexRefresher: NoopCodexRefresher()
        )
        let controller = PopoverRefreshController(viewModel: vm, sleeper: { _ in })

        controller.userTappedRetry()
        await Task.yield()
        await Task.yield()

        #expect(vm.lastClaudeRefreshAt != nil || vm.lastCodexRefreshAt != nil)
    }
}
```

- [ ] **Step 2: Run — verify compile failure**

```
cd apps/mac && swift test --filter PopoverRefreshControllerTests
```
Expected: `cannot find 'PopoverRefreshController'`.

- [ ] **Step 3: Implement controller scaffolding**

Create `apps/mac/Sources/WhatTheTokenMac/ViewModels/PopoverRefreshController.swift`:

```swift
import Foundation

typealias SleepClosure = @Sendable (Duration) async -> Void

@MainActor
final class PopoverRefreshController {
    private let viewModel: StatusViewModel
    private let interval: Duration
    private let sleeper: SleepClosure
    private var timerTask: Task<Void, Never>?

    init(
        viewModel: StatusViewModel,
        interval: Duration = .seconds(30),
        sleeper: @escaping SleepClosure = { try? await Task.sleep(for: $0) }
    ) {
        self.viewModel = viewModel
        self.interval = interval
        self.sleeper = sleeper
    }

    func userTappedRefresh() {
        let viewModel = self.viewModel
        Task { await viewModel.refreshAll(reason: .manual) }
    }

    func userTappedRetry() {
        let viewModel = self.viewModel
        Task { await viewModel.refreshAll(reason: .retry) }
    }

    func popoverDidOpen()  { /* implemented in Task 16 */ }
    func popoverDidClose() { /* implemented in Task 16 */ }
}
```

The Task closures capture `viewModel` directly (not `self`) so they're plain Sendable closures whose only cross-actor access is the explicit `await viewModel.refreshAll(...)` hop onto `@MainActor`. `StatusViewModel` is `@MainActor`-isolated, which makes it implicitly `Sendable` for cross-actor reference passing.

- [ ] **Step 4: Run tests — verify pass**

```
cd apps/mac && swift test --filter PopoverRefreshControllerTests
```
Expected: both pass.

- [ ] **Step 5: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/PopoverRefreshController.swift apps/mac/Tests/WhatTheTokenMacTests/PopoverRefreshControllerTests.swift
git commit -m "feat(mac): add PopoverRefreshController scaffold and manual/retry routing"
```

---

### Task 16: Open / close lifecycle and 30s timer with `FakeSleeper`

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/PopoverRefreshController.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/PopoverRefreshControllerTests.swift`

- [ ] **Step 1: Write the failing tests**

Add a `FakeSleeper` and tests:

```swift
final class FakeSleeper: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func sleep(_: Duration) async {
        await withCheckedContinuation { c in
            lock.withLock { continuations.append(c) }
        }
    }

    func fireOneTick() {
        let c: CheckedContinuation<Void, Never>? = lock.withLock {
            continuations.isEmpty ? nil : continuations.removeFirst()
        }
        c?.resume()
    }

    var pendingTicks: Int { lock.withLock { continuations.count } }
}

extension PopoverRefreshControllerTests {
    @MainActor
    @Test func popoverDidOpen_runsImmediateRefresh_andStartsTimer() async {
        let vm = StatusViewModel(
            snapshots: [],
            claudeRefresher: NoopClaudeRefresher(),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
            codexRefresher: NoopCodexRefresher()
        )
        let fake = FakeSleeper()
        let controller = PopoverRefreshController(viewModel: vm, sleeper: { d in await fake.sleep(d) })

        controller.popoverDidOpen()
        // Allow the immediate Task to land:
        for _ in 0..<5 { await Task.yield() }
        let firstStamp = vm.lastClaudeRefreshAt
        #expect(firstStamp != nil)

        // Wait for the timer task to register a sleep:
        for _ in 0..<10 {
            if fake.pendingTicks > 0 { break }
            await Task.yield()
        }
        #expect(fake.pendingTicks == 1)

        // Advance time and confirm a second refresh fires:
        let stampedBefore = vm.lastClaudeRefreshAt
        fake.fireOneTick()
        for _ in 0..<10 { await Task.yield() }
        #expect(vm.lastClaudeRefreshAt != stampedBefore)
    }

    @MainActor
    @Test func popoverDidClose_cancelsBeforeNextTick() async {
        let vm = StatusViewModel(
            snapshots: [],
            claudeRefresher: NoopClaudeRefresher(),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
            codexRefresher: NoopCodexRefresher()
        )
        let fake = FakeSleeper()
        let controller = PopoverRefreshController(viewModel: vm, sleeper: { d in await fake.sleep(d) })

        controller.popoverDidOpen()
        for _ in 0..<10 { await Task.yield() }
        controller.popoverDidClose()

        let stampAfterClose = vm.lastClaudeRefreshAt
        fake.fireOneTick()                       // Resumes the cancelled sleeper continuation, but the loop exits.
        for _ in 0..<10 { await Task.yield() }

        #expect(vm.lastClaudeRefreshAt == stampAfterClose, "Timer must not refresh after close.")
    }
}
```

- [ ] **Step 2: Run — verify compile/behavior failure**

```
cd apps/mac && swift test --filter popoverDidOpen_runsImmediateRefresh_andStartsTimer
```
Expected: failure — current `popoverDidOpen` is a no-op.

- [ ] **Step 3: Implement open/close + timer**

Replace the placeholder `popoverDidOpen` / `popoverDidClose` and add private helpers:

```swift
    // Generation counter: incremented on every open/close. Each timer task
    // captures the generation at start; if a tick fires after a close-then-open
    // (or after a stale `.onAppear` re-fire on macOS regressions), the captured
    // generation no longer matches and the loop exits before triggering a refresh.
    // This is defense in depth on top of `Task.cancel()` in case
    // `.onDisappear` fails to fire on `MenuBarExtra(.window)` content under
    // future macOS versions — see Risk H1 in the spec.
    private var generation: Int = 0

    func popoverDidOpen() {
        generation &+= 1
        let viewModel = self.viewModel
        Task { await viewModel.refreshAll(reason: .popoverOpened) }
        startTimer(expectedGeneration: generation)
    }

    func popoverDidClose() {
        generation &+= 1
        stopTimer()
    }

    private func startTimer(expectedGeneration expected: Int) {
        stopTimer()
        let sleeper = self.sleeper
        let interval = self.interval
        let viewModel = self.viewModel
        // `[weak self]` keeps the controller deallocatable independent of
        // the in-flight Task. The generation re-check goes through a single
        // `@MainActor` helper, which is the only call that crosses into the
        // controller's isolation domain — clearer than an inline
        // `MainActor.run` block, and easier to step through in a debugger.
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                await sleeper(interval)
                if Task.isCancelled { break }
                guard let self, await self.isCurrentGeneration(expected) else { break }
                await viewModel.refreshAll(reason: .timerTick)
            }
        }
    }

    @MainActor
    private func isCurrentGeneration(_ expected: Int) -> Bool {
        return generation == expected
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
```

- [ ] **Step 4: Run tests — verify pass**

```
cd apps/mac && swift test --filter PopoverRefreshControllerTests
```
Expected: all 4 pass. If timing-flaky, increase `await Task.yield()` loop counts to 20.

- [ ] **Step 5: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/PopoverRefreshController.swift apps/mac/Tests/WhatTheTokenMacTests/PopoverRefreshControllerTests.swift
git commit -m "feat(mac): add popover lifecycle and 30s timer to refresh controller"
```

---

### Task 17: Manual refresh during in-flight is dropped

**Files:**
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/PopoverRefreshControllerTests.swift`

- [ ] **Step 1: Write the failing test**

Add:

```swift
extension PopoverRefreshControllerTests {
    @MainActor
    @Test func timer_skipsRefresh_ifGenerationChangedDuringSleep() async {
        // If `popoverDidClose()` (or another `popoverDidOpen()`) increments the
        // generation while the timer is sleeping, the next tick must NOT fire a
        // refresh. This protects against `.onDisappear` regressions on
        // `MenuBarExtra(.window)` where the timer task isn't cancelled directly.
        let counter = Counter()
        let vm = StatusViewModel(
            snapshots: [],
            claudeRefresher: SlowClaudeRefresher(counter: counter),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
            codexRefresher: NoopCodexRefresher()
        )
        let fake = FakeSleeper()
        let controller = PopoverRefreshController(viewModel: vm, sleeper: { d in await fake.sleep(d) })

        controller.popoverDidOpen()
        // Wait for the immediate refresh to land and the timer task to register a sleep.
        for _ in 0..<20 {
            if fake.pendingTicks > 0 { break }
            await Task.yield()
        }
        let immediateCount = counter.value

        // Mutate the generation while the timer is sleeping (simulates a missed
        // close + reopen, or any reason `popoverDidClose` could not run).
        controller.popoverDidOpen()  // generation increments; old timer's `expected` is now stale

        // Fire the OLD timer's continuation. Its generation check should fail
        // and the refresh should NOT execute.
        fake.fireOneTick()
        for _ in 0..<20 { await Task.yield() }

        #expect(counter.value == immediateCount + 1, "Old timer must not refresh after generation invalidation; only the new immediate refresh from the second popoverDidOpen should add one increment.")
    }

    @MainActor
    @Test func userTappedRefreshDuringInFlight_isDropped() async {
        let counter = Counter()
        let vm = StatusViewModel(
            snapshots: [],
            claudeRefresher: SlowClaudeRefresher(counter: counter),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
            codexRefresher: NoopCodexRefresher()
        )
        let controller = PopoverRefreshController(viewModel: vm, sleeper: { _ in })

        controller.userTappedRefresh()  // starts a slow refresh
        controller.userTappedRefresh()  // attempts a second; should be dropped by isRefreshAllInFlight
        for _ in 0..<20 { await Task.yield() }

        #expect(counter.value == 1, "Outer guard must drop overlapping manual refresh.")
    }
}
```

- [ ] **Step 2: Run — verify pass (mapping was implemented in earlier tasks)**

```
cd apps/mac && swift test --filter userTappedRefreshDuringInFlight_isDropped
```
Expected: pass on the first run because Task 6's outer guard already protects this case.

- [ ] **Step 3: Commit**

```
git add apps/mac/Tests/WhatTheTokenMacTests/PopoverRefreshControllerTests.swift
git commit -m "test(mac): cover manual-refresh-during-in-flight is dropped"
```

---

## Phase E — `MacAppLauncher` amendments (Tasks 18–19)

### Task 18: Add `.accessory` policy and `configureLaunch`; reorder smoke checks

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/MacAppLauncher.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/MacAppLauncherTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `MacAppLauncherTests.swift`:

```swift
@MainActor
@Test func accessoryLaunchSetsAccessoryPolicy_noActivate() {
    let app = RecordingMacApplication()
    MacAppLauncher.configureLaunch(arguments: ["WhatTheTokenMac"], application: app)
    #expect(app.policies == [.accessory])
    #expect(app.activateCount == 0)
}

@MainActor
@Test func developerWindowFlagSetsRegularAndActivates() {
    let app = RecordingMacApplication()
    MacAppLauncher.configureLaunch(arguments: ["WhatTheTokenMac", "--developer-window"], application: app)
    #expect(app.policies == [.regular])
    #expect(app.activateCount == 1)
}

@MainActor
@Test func claudeSmokeIsNoop() {
    let app = RecordingMacApplication()
    MacAppLauncher.configureLaunch(arguments: ["WhatTheTokenMac", "--claude-connector-smoke"], application: app)
    #expect(app.policies.isEmpty)
    #expect(app.activateCount == 0)
}

@MainActor
@Test func codexSmokeIsNoop() {
    let app = RecordingMacApplication()
    MacAppLauncher.configureLaunch(arguments: ["WhatTheTokenMac", "--codex-connector-smoke"], application: app)
    #expect(app.policies.isEmpty)
    #expect(app.activateCount == 0)
}
```

- [ ] **Step 2: Run — verify compile failure**

```
cd apps/mac && swift test --filter accessoryLaunchSetsAccessoryPolicy_noActivate
```
Expected: `cannot find 'configureLaunch'`, `'accessory'`.

- [ ] **Step 3: Replace launcher**

Replace the contents of `apps/mac/Sources/WhatTheTokenMac/MacAppLauncher.swift` with:

```swift
import Foundation

#if canImport(AppKit)
import AppKit
#endif

enum MacAppActivationPolicy: Equatable, Sendable {
    case regular
    case accessory
}

@MainActor
protocol MacApplicationActivating: AnyObject {
    func setActivationPolicy(_ policy: MacAppActivationPolicy)
    func activateIgnoringOtherApps()
}

enum MacAppLauncher {
    @MainActor
    static func configureLaunch(
        arguments: [String] = CommandLine.arguments,
        application: MacApplicationActivating = SystemMacApplication.shared
    ) {
        // Smoke modes short-circuit before any activation.
        if ClaudeConnectorSmokeCommand.shouldRun(arguments: arguments) { return }
        if CodexConnectorSmokeCommand.shouldRun(arguments: arguments) { return }

        if arguments.contains("--developer-window") {
            application.setActivationPolicy(.regular)
            application.activateIgnoringOtherApps()
        } else {
            application.setActivationPolicy(.accessory)
        }
    }

    // Backwards-compatible alias for any call site that still references the old name.
    @MainActor
    static func configureForInteractiveLaunch(
        arguments: [String] = CommandLine.arguments,
        application: MacApplicationActivating = SystemMacApplication.shared
    ) {
        configureLaunch(arguments: arguments, application: application)
    }
}

@MainActor
private final class SystemMacApplication: MacApplicationActivating {
    static let shared = SystemMacApplication()
    private init() {}

    func setActivationPolicy(_ policy: MacAppActivationPolicy) {
        #if canImport(AppKit)
        switch policy {
        case .regular:   NSApplication.shared.setActivationPolicy(.regular)
        case .accessory: NSApplication.shared.setActivationPolicy(.accessory)
        }
        #endif
    }

    func activateIgnoringOtherApps() {
        #if canImport(AppKit)
        NSApplication.shared.activate(ignoringOtherApps: true)
        #endif
    }
}
```

- [ ] **Step 4: Run tests — verify pass**

```
cd apps/mac && swift test --filter MacAppLauncherTests
```
Expected: all 4 new tests pass; existing tests (which call `configureForInteractiveLaunch`) still pass via the alias.

- [ ] **Step 5: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/MacAppLauncher.swift apps/mac/Tests/WhatTheTokenMacTests/MacAppLauncherTests.swift
git commit -m "feat(mac): add accessory activation policy; configureLaunch covers Codex smoke"
```

---

### Task 19: Update existing launcher test to assert accessory by default

**Files:**
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/MacAppLauncherTests.swift`

The pre-existing `interactiveLaunchConfiguresRegularForegroundApp` test asserts `.regular` — that's the OLD behavior. Production launch is now `.accessory`. Update or replace the old test so it reflects the new contract.

- [ ] **Step 1: Replace the obsolete test**

Edit `MacAppLauncherTests.swift` — replace:

```swift
@MainActor
@Test func interactiveLaunchConfiguresRegularForegroundApp() {
    let application = RecordingMacApplication()
    MacAppLauncher.configureForInteractiveLaunch(
        arguments: ["WhatTheTokenMac"],
        application: application
    )
    #expect(application.policies == [.regular])
    #expect(application.activateCount == 1)
}
```

with:

```swift
@MainActor
@Test func interactiveLaunchConfiguresAccessoryByDefault() {
    let application = RecordingMacApplication()
    MacAppLauncher.configureForInteractiveLaunch(
        arguments: ["WhatTheTokenMac"],
        application: application
    )
    #expect(application.policies == [.accessory])
    #expect(application.activateCount == 0)
}
```

- [ ] **Step 2: Run tests — verify pass**

```
cd apps/mac && swift test --filter MacAppLauncherTests
```
Expected: all pass.

- [ ] **Step 3: Commit**

```
git add apps/mac/Tests/WhatTheTokenMacTests/MacAppLauncherTests.swift
git commit -m "test(mac): default launch is now accessory, not regular"
```

---

## Phase F — `AppModel` (Task 20)

### Task 20: `AppModel` wiring object + smoke test

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/AppModel.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/AppModelTests.swift`

- [ ] **Step 1: Write the failing test**

Create `apps/mac/Tests/WhatTheTokenMacTests/AppModelTests.swift`:

```swift
import Testing
@testable import WhatTheTokenMac

@Suite struct AppModelTests {
    @MainActor
    @Test func live_initializesWiredDependencies() {
        let app = AppModel.live()
        #expect(app.viewModel.isRefreshAllInFlight == false)
        // Smoke: tapping refresh through the controller does not crash and returns synchronously.
        app.refreshController.userTappedRefresh()
    }
}
```

- [ ] **Step 2: Run — verify compile failure**

```
cd apps/mac && swift test --filter AppModelTests
```
Expected: `cannot find 'AppModel'`.

- [ ] **Step 3: Implement**

Create `apps/mac/Sources/WhatTheTokenMac/AppModel.swift`:

```swift
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    let viewModel: StatusViewModel
    let refreshController: PopoverRefreshController

    init(viewModel: StatusViewModel) {
        self.viewModel = viewModel
        self.refreshController = PopoverRefreshController(viewModel: viewModel)
    }

    static func live() -> AppModel {
        AppModel(viewModel: .live())
    }
}
```

- [ ] **Step 4: Run tests — verify pass**

```
cd apps/mac && swift test --filter AppModelTests
cd apps/mac && swift test
```
Expected: passes; full suite still green.

- [ ] **Step 5: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/AppModel.swift apps/mac/Tests/WhatTheTokenMacTests/AppModelTests.swift
git commit -m "feat(mac): add AppModel wiring StatusViewModel and PopoverRefreshController"
```

---

## Phase G — Popover SwiftUI views (Tasks 21–25)

These views have no automated tests (per spec §9 — Phase 1 has no SwiftUI snapshot/inspector tests). Coverage comes from the presentation-model tests above. Each task: implement the view, run `swift build` to confirm compilation, commit.

### Task 21: `StatusBannerView`

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/Views/Popover/StatusBannerView.swift`

- [ ] **Step 1: Implement**

```swift
import SwiftUI

struct StatusBannerView: View {
    let state: BannerState

    var body: some View {
        switch state {
        case .hidden:
            EmptyView()
        case let .critical(text):
            banner(text: text, foreground: .red, background: Color.red.opacity(0.15))
        case let .low(text):
            banner(text: text, foreground: .orange, background: Color.orange.opacity(0.15))
        case let .stale(text):
            banner(text: text, foreground: .secondary, background: Color.gray.opacity(0.12))
        case let .disconnected(text):
            banner(text: text, foreground: .accentColor, background: Color.accentColor.opacity(0.12))
        }
    }

    private func banner(text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(background)
    }
}
```

- [ ] **Step 2: Verify build**

```
cd apps/mac && swift build
```
Expected: no errors.

- [ ] **Step 3: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/Views/Popover/StatusBannerView.swift
git commit -m "feat(mac): add StatusBannerView"
```

---

### Task 22: `ProviderTabBarView`

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/Views/Popover/ProviderTabBarView.swift`

- [ ] **Step 1: Implement**

```swift
import SwiftUI

struct ProviderTabBarView: View {
    @Binding var selected: ProviderTab

    var body: some View {
        Picker("", selection: $selected) {
            ForEach(ProviderTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
```

- [ ] **Step 2: Verify build**

```
cd apps/mac && swift build
```

- [ ] **Step 3: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/Views/Popover/ProviderTabBarView.swift
git commit -m "feat(mac): add ProviderTabBarView"
```

---

### Task 23: `ProviderTabContentView`

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/Views/Popover/ProviderTabContentView.swift`

- [ ] **Step 1: Implement**

```swift
import SwiftUI

struct ProviderTabContentView: View {
    let model: ProviderTabModel
    let onOpenSettings: () -> Void
    let onRetry: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        switch model.body {
        case let .connected(snapshots, _):
            StatusSectionView(snapshots: snapshots)
        case .empty:
            empty
        case .checking:
            checking
        case let .disconnected(reason):
            disconnected(reason: reason)
        case let .error(kind, lastSnapshots):
            errorBody(kind: kind, lastSnapshots: lastSnapshots)
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Text("Connected — no usage data yet").font(.callout)
            Button("Refresh now", action: onRefresh).buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    private var checking: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text("Refreshing…").font(.callout).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    private func disconnected(reason: ProviderTabModel.DisconnectedReason) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(headline(for: reason)).font(.headline)
            Text(detail(for: reason)).font(.caption).foregroundStyle(.secondary)
            Button("Open Settings", action: onOpenSettings).buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func errorBody(kind: ProviderTabModel.ErrorKind, lastSnapshots: [UsageSnapshot]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(errorHeadline(kind: kind)).font(.headline)
            if !lastSnapshots.isEmpty {
                StatusSectionView(snapshots: lastSnapshots).opacity(0.6)
            }
            Button("Retry", action: onRetry).buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func headline(for reason: ProviderTabModel.DisconnectedReason) -> String {
        switch (model.tab, reason) {
        case let (.claude, .claude(claudeReason)):
            switch claudeReason {
            case .notConnected:       return "Claude Code is not connected"
            case .missingCredentials: return "Claude Code credentials were not found"
            case .missingCLI:         return "Claude Code CLI was not found"
            case .tokenInvalid:       return "Claude Code credentials are invalid"
            case .rateLimited:        return "Claude usage is rate limited"
            }
        case let (.codex, .codex(codexReason)):
            switch codexReason {
            case .notConnected:       return "Codex is not connected"
            case .missingCredentials: return "Sign in to Codex locally"
            case .permissionDenied:   return "Codex app-server could not be started"
            }
        case (.claude, .codex), (.codex, .claude):
            // Mapping invariant violation. Covered by ProviderTabModel mapping
            // tests; if we ever hit this in production it's a programmer error.
            assertionFailure("ProviderTabModel invariant violated: tab=\(model.tab) but reason=\(reason); see ProviderTabModel.from mapping in ProviderTabModel.swift")
            return "\(model.tab.title) is unavailable"
        }
    }

    private func detail(for reason: ProviderTabModel.DisconnectedReason) -> String {
        switch model.tab {
        case .claude: return "Connect Claude Code in Settings to see remaining usage."
        case .codex:  return "Connect Codex in Settings to see remaining usage and rate-limit status."
        }
    }

    private func errorHeadline(kind: ProviderTabModel.ErrorKind) -> String {
        switch (model.tab, kind) {
        case (.claude, .network):       return "Claude Code usage could not be refreshed"
        case (.claude, .schemaChanged): return "Claude usage response changed"
        case (.codex,  .network):       return "Codex usage could not be refreshed"
        case (.codex,  .schemaChanged): return "Codex usage response changed"
        }
    }
}
```

- [ ] **Step 2: Verify build**

```
cd apps/mac && swift build
```

- [ ] **Step 3: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/Views/Popover/ProviderTabContentView.swift
git commit -m "feat(mac): add ProviderTabContentView with all body states"
```

---

### Task 24: `PopoverFooterView`

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/Views/Popover/PopoverFooterView.swift`

- [ ] **Step 1: Implement**

```swift
import SwiftUI

struct PopoverFooterView: View {
    let state: PopoverFooterState
    let onRefresh: () -> Void
    let onOpenSettings: () -> Void
    let onOpenDeveloperWindow: (() -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            updatedLabel
                .frame(maxWidth: .infinity, alignment: .leading)
            refreshButton
            Menu {
                Button("Settings…", action: onOpenSettings)
                Button("About WhatTheToken") {
                    NSApplication.shared.orderFrontStandardAboutPanel(nil)
                }
                #if DEBUG
                if let onOpenDeveloperWindow {
                    Button("Open Developer Window", action: onOpenDeveloperWindow)
                }
                #endif
                Divider()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
        }
        .padding(.vertical, 8)
        .padding(.leading, 12)
        .padding(.trailing, 6)
    }

    private var updatedLabel: some View {
        // Build the formatter inline rather than as a static let.
        // A `static let` of a non-Sendable Foundation class trips
        // Swift 6 strict-concurrency diagnostics, and SwiftUI views
        // are recreated cheaply enough that per-render allocation is
        // not measurable.
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let text: String = {
            guard let date = state.lastUpdatedAt else { return "—" }
            return "Last updated " + formatter.localizedString(for: date, relativeTo: Date())
        }()
        return Text(text).font(.caption2).foregroundStyle(.secondary)
    }

    private var refreshButton: some View {
        Button(action: onRefresh) {
            if state.isRefreshing {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
        .buttonStyle(.borderless)
        .disabled(!state.canRefresh)
    }
}
```

- [ ] **Step 2: Verify build**

```
cd apps/mac && swift build
```

- [ ] **Step 3: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/Views/Popover/PopoverFooterView.swift
git commit -m "feat(mac): add PopoverFooterView with last-updated and overflow menu"
```

---

### Task 25: `PopoverRootView` + move `StatusSectionView`

**Files:**
- Move: `apps/mac/Sources/WhatTheTokenMac/Views/StatusSectionView.swift` → `apps/mac/Sources/WhatTheTokenMac/Views/Popover/StatusSectionView.swift`
- Create: `apps/mac/Sources/WhatTheTokenMac/Views/Popover/PopoverRootView.swift`

- [ ] **Step 1: Move `StatusSectionView`**

```
git mv apps/mac/Sources/WhatTheTokenMac/Views/StatusSectionView.swift apps/mac/Sources/WhatTheTokenMac/Views/Popover/StatusSectionView.swift
```

- [ ] **Step 2: Verify build still passes**

```
cd apps/mac && swift build
```
Expected: no errors. (Swift package targets process all `.swift` under the target's source root regardless of subfolder.)

- [ ] **Step 3: Implement `PopoverRootView`**

Create `apps/mac/Sources/WhatTheTokenMac/Views/Popover/PopoverRootView.swift`:

```swift
import SwiftUI

struct PopoverRootView: View {
    let viewModel: StatusViewModel
    let controller: PopoverRefreshController
    let onOpenSettings: () -> Void
    let onOpenDeveloperWindow: (() -> Void)?

    @State private var selectedTab: ProviderTab = .codex

    var body: some View {
        let bannerState = BannerState.from(viewModel: viewModel, selected: selectedTab)
        let tabModel    = ProviderTabModel.from(viewModel: viewModel, tab: selectedTab)
        let footerState = PopoverFooterState.from(viewModel: viewModel, selected: selectedTab)

        VStack(spacing: 0) {
            StatusBannerView(state: bannerState)
            ProviderTabBarView(selected: $selectedTab)
            Divider()
            ProviderTabContentView(
                model: tabModel,
                onOpenSettings: onOpenSettings,
                onRetry:   { controller.userTappedRetry() },
                onRefresh: { controller.userTappedRefresh() }
            )
            Divider()
            PopoverFooterView(
                state: footerState,
                onRefresh: { controller.userTappedRefresh() },
                onOpenSettings: onOpenSettings,
                onOpenDeveloperWindow: onOpenDeveloperWindow
            )
        }
        .frame(width: 320)
        .onAppear  { controller.popoverDidOpen() }
        .onDisappear { controller.popoverDidClose() }
    }
}
```

- [ ] **Step 4: Verify build**

```
cd apps/mac && swift build
```

- [ ] **Step 5: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/Views/
git commit -m "feat(mac): add PopoverRootView; relocate StatusSectionView"
```

---

## Phase H — Settings views (Tasks 26–27)

### Task 26: `ConnectorRowView`

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/Views/Settings/ConnectorRowView.swift`

- [ ] **Step 1: Implement**

```swift
import SwiftUI

struct ConnectorRowView: View {
    let title: String
    let stateTitle: String
    let detail: String
    let trustMessage: String
    let actionTitle: String
    let isWorking: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(stateTitle).font(.subheadline)
                if detail != stateTitle {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Text(trustMessage).font(.caption2).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(actionTitle, action: action)
                .disabled(isWorking)
        }
        .padding(.vertical, 6)
    }
}
```

- [ ] **Step 2: Verify build**

```
cd apps/mac && swift build
```

- [ ] **Step 3: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/Views/Settings/ConnectorRowView.swift
git commit -m "feat(mac): add ConnectorRowView"
```

---

### Task 27: `ConnectorsView` + `SettingsRootView`

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/Views/Settings/ConnectorsView.swift`
- Create: `apps/mac/Sources/WhatTheTokenMac/Views/Settings/SettingsRootView.swift`

- [ ] **Step 1: Implement `ConnectorsView`**

```swift
import SwiftUI

struct ConnectorsView: View {
    let viewModel: StatusViewModel

    var body: some View {
        Form {
            Section("Connectors") {
                ConnectorRowView(
                    title: "Claude Code",
                    stateTitle: ClaudeConnectorSetupCopy.title(for: viewModel.connectorState),
                    detail: viewModel.connectorStatusMessage,
                    trustMessage: ClaudeConnectorSetupCopy.trustMessage,
                    actionTitle: claudeActionTitle(for: viewModel.connectorState),
                    isWorking: viewModel.connectorState == .checking,
                    action: {
                        let viewModel = self.viewModel
                        Task { await viewModel.connectClaudeCode() }
                    }
                )

                ConnectorRowView(
                    title: "Codex",
                    stateTitle: CodexConnectorSetupCopy.title(for: viewModel.codexConnectorState),
                    detail: viewModel.codexConnectorStatusMessage,
                    trustMessage: CodexConnectorSetupCopy.trustMessage,
                    actionTitle: codexActionTitle(for: viewModel.codexConnectorState),
                    isWorking: viewModel.codexConnectorState == .checking,
                    action: {
                        let viewModel = self.viewModel
                        Task { await viewModel.connectCodex() }
                    }
                )
            }
        }
        .formStyle(.grouped)
    }
}
```

- [ ] **Step 2: Implement `SettingsRootView`**

```swift
import SwiftUI

struct SettingsRootView: View {
    let viewModel: StatusViewModel

    var body: some View {
        ConnectorsView(viewModel: viewModel)
            .frame(minWidth: 480, minHeight: 360)
    }
}
```

- [ ] **Step 3: Verify build**

```
cd apps/mac && swift build
```

- [ ] **Step 4: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/Views/Settings/ConnectorsView.swift apps/mac/Sources/WhatTheTokenMac/Views/Settings/SettingsRootView.swift
git commit -m "feat(mac): add ConnectorsView and SettingsRootView"
```

---

## Phase I — DEBUG developer window (Task 28)

### Task 28: `DeveloperWindowView`

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/Views/Developer/DeveloperWindowView.swift`

- [ ] **Step 1: Implement (DEBUG only)**

```swift
#if DEBUG
import SwiftUI

struct DeveloperWindowView: View {
    let viewModel: StatusViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Build: DEBUG · Bundle: \(Bundle.main.bundleIdentifier ?? "?") · macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                providerSection(
                    title: "Claude Code",
                    state: "\(viewModel.connectorState)",
                    message: viewModel.connectorStatusMessage,
                    timestamp: viewModel.lastClaudeRefreshAt,
                    action: {
                        let viewModel = self.viewModel
                        Task { await viewModel.connectClaudeCode() }
                    }
                )

                providerSection(
                    title: "Codex",
                    state: "\(viewModel.codexConnectorState)",
                    message: viewModel.codexConnectorStatusMessage,
                    timestamp: viewModel.lastCodexRefreshAt,
                    action: {
                        let viewModel = self.viewModel
                        Task { await viewModel.connectCodex() }
                    }
                )

                globalSection

                snapshotsSection
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 600, minHeight: 480)
    }

    private func providerSection(title: String, state: String, message: String, timestamp: Date?, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            keyValueRow("setupState", state)
            keyValueRow("connectorStatusMessage", message)
            keyValueRow("lastRefreshAt", timestamp.map { "\($0)" } ?? "nil")
            Button("Refresh now", action: action).buttonStyle(.bordered).controlSize(.small)
        }
        .padding(12)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var globalSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Global").font(.headline)
            keyValueRow("isRefreshAllInFlight", "\(viewModel.isRefreshAllInFlight)")
            keyValueRow("isAnyRefreshing", "\(viewModel.isAnyRefreshing)")
            keyValueRow("lastUpdatedAt (min)", viewModel.lastUpdatedAt.map { "\($0)" } ?? "nil")
            Button("Refresh all") {
                let viewModel = self.viewModel
                Task { await viewModel.refreshAll(reason: .manual) }
            }
            .buttonStyle(.borderedProminent).controlSize(.small)
        }
        .padding(12)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var snapshotsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Snapshots (\(viewModel.snapshots.count))").font(.headline)
            ForEach(viewModel.snapshots, id: \.id) { snap in
                Text(jsonString(for: snap))
                    .font(.system(.caption2, design: .monospaced))
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func keyValueRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(.caption, design: .monospaced))
        }
    }

    private func jsonString(for snapshot: UsageSnapshot) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(snapshot), let s = String(data: data, encoding: .utf8) {
            return s
        }
        return "<encoding failed>"
    }
}
#endif
```

- [ ] **Step 2: Verify build (release config too)**

```
cd apps/mac && swift build
cd apps/mac && swift build -c release
```
Expected: both pass. The release build excludes `DeveloperWindowView` because of the `#if DEBUG` wrap.

- [ ] **Step 3: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/Views/Developer/DeveloperWindowView.swift
git commit -m "feat(mac): add DeveloperWindowView (DEBUG only)"
```

---

## Phase J — Scene swap (Tasks 29–30)

### Task 29: Reorder `WhatTheTokenApp.init()` so Codex smoke skips activation

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/WhatTheTokenApp.swift`

- [ ] **Step 1: Update `init()`**

Replace the existing `init()` body in `apps/mac/Sources/WhatTheTokenMac/WhatTheTokenApp.swift`:

```swift
    init() {
        if ClaudeConnectorSmokeCommand.shouldRun(arguments: CommandLine.arguments) {
            ClaudeConnectorSmokeCommand.startCommandLineSmoke()
            return
        }
        if CodexConnectorSmokeCommand.shouldRun(arguments: CommandLine.arguments) {
            CodexConnectorSmokeCommand.startCommandLineSmoke()
            return
        }
        MacAppLauncher.configureLaunch()
    }
```

This puts both smoke checks first; either smoke path returns before `configureLaunch` runs. Fixes the bug at the previous `WhatTheTokenApp.swift:11-13` where Codex smoke went through interactive activation.

- [ ] **Step 2: Verify build + tests**

```
cd apps/mac && swift build
cd apps/mac && swift test
```

- [ ] **Step 3: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/WhatTheTokenApp.swift
git commit -m "fix(mac): codex smoke launch must skip interactive activation"
```

---

### Task 30: Replace `WindowGroup` with `MenuBarExtra` + `Settings` + DEBUG `Window`

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/WhatTheTokenApp.swift`

- [ ] **Step 1: Replace the `body` scene tree**

Replace the entire `WhatTheTokenApp` `body` (and add `@State` for the shared `AppModel`):

```swift
import SwiftUI

@main
struct WhatTheTokenApp: App {
    // Use `let`, not `@State`. The App is constructed once per process; observation
    // tracking flows through the @Observable reads inside the views, not through
    // the App's storage. `@State` would add a Sendable requirement on the wrapped
    // class and call the @MainActor `.live()` factory through SwiftUI's State init,
    // which is unnecessary friction here.
    private let app: AppModel = .live()

    @Environment(\.openWindow) private var openWindow

    init() {
        if ClaudeConnectorSmokeCommand.shouldRun(arguments: CommandLine.arguments) {
            ClaudeConnectorSmokeCommand.startCommandLineSmoke()
            return
        }
        if CodexConnectorSmokeCommand.shouldRun(arguments: CommandLine.arguments) {
            CodexConnectorSmokeCommand.startCommandLineSmoke()
            return
        }
        MacAppLauncher.configureLaunch()
    }

    var body: some Scene {
        MenuBarExtra("WhatTheToken", systemImage: "gauge") {
            PopoverRootView(
                viewModel: app.viewModel,
                controller: app.refreshController,
                onOpenSettings: openSettings,
                onOpenDeveloperWindow: developerWindowOpener
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsRootView(viewModel: app.viewModel)
        }

        #if DEBUG
        Window("WhatTheToken — Developer", id: "developer") {
            DeveloperWindowView(viewModel: app.viewModel)
        }
        #endif
    }

    private func openSettings() {
        #if canImport(AppKit)
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        #endif
    }

    private var developerWindowOpener: (() -> Void)? {
        #if DEBUG
        return { openWindow(id: "developer") }
        #else
        return nil
        #endif
    }
}
```

- [ ] **Step 2: Verify build (debug + release)**

```
cd apps/mac && swift build
cd apps/mac && swift build -c release
cd apps/mac && swift test
```
Expected: all pass. The previous `ContentView` is no longer referenced from the scene tree.

- [ ] **Step 3: Manual smoke (run the app)**

```
cd apps/mac && swift run
```

Confirm: menu-bar icon appears (no Dock icon), clicking it opens the popover with both tabs, `Cmd+,` opens Settings. Quit by terminating the process.

- [ ] **Step 4: Commit**

```
git add apps/mac/Sources/WhatTheTokenMac/WhatTheTokenApp.swift
git commit -m "feat(mac): switch primary scene to MenuBarExtra with Settings and DEBUG developer window"
```

---

## Phase K — Cleanup (Task 31)

### Task 31: Delete `ContentView.swift`; final test + manual smoke pass

**Files:**
- Delete: `apps/mac/Sources/WhatTheTokenMac/Views/ContentView.swift`

- [ ] **Step 1: Confirm no remaining references**

```
cd apps/mac && grep -rn "ContentView" Sources Tests || echo "no references"
```
Expected: `no references`. If any remain, replace them with the appropriate new view name and re-run before deleting.

- [ ] **Step 2: Delete the file**

```
git rm apps/mac/Sources/WhatTheTokenMac/Views/ContentView.swift
```

- [ ] **Step 3: Verify build (debug + release) and full test suite**

```
cd apps/mac && swift build
cd apps/mac && swift build -c release
cd apps/mac && swift test
```
Expected: all green.

- [ ] **Step 4: Manual smoke checklist (release-build)**

Walk through the 11-item smoke checklist from spec §9:

1. App launches; no Dock icon; no Cmd-Tab entry; menu-bar icon visible.
2. Click menu-bar icon → popover opens with Codex + Claude tabs.
3. Codex tab not connected → "Open Settings" CTA. Click → Settings opens.
4. Connect Codex in Settings → state transitions in both Settings and popover.
5. Repeat for Claude.
6. Both connected & healthy → banner hidden; snapshot rows render.
7. Tap refresh → spinner shows; "Last updated" advances.
8. Leave popover open ~30s → second refresh fires. Close, wait 60s, reopen → exactly one refresh fires. **Watch the "Last updated" label across the close → wait → reopen cycle: it must not advance during the closed period. If it does, `.onDisappear` is not firing reliably on this macOS version and the AppKit fallback (Risk H1, spec §13 follow-up) needs to land before ship.**
9. `Cmd+,` opens Settings.
10. `•••` overflow → Settings, About (system panel), Quit each work.
11. DEBUG build only: `Open Developer Window` item present in `•••`. Release build: absent.

If any step fails, file the failure as a follow-up issue and either fix in this branch (preferred for blocking issues) or note in the PR description.

- [ ] **Step 5: Commit**

```
git commit -m "feat(mac): remove legacy ContentView"
```

---

## Self-Review Checklist (run after writing this plan)

- **Spec coverage:** every spec section maps to one or more tasks.
  - §3 file layout → Task list above
  - §4 view tree, presentation models, mapping rules → Tasks 1–3, 9–13
  - §5 refreshAll, per-provider timestamps → Tasks 4–8, 15–17
  - §6 Settings → Tasks 14, 26, 27
  - §7 developer window → Task 28
  - §8 sequencing → Phases A–K respect "introduce → switch scenes → smoke → delete ContentView"
  - §9 testing plan → all named tests appear in their respective tasks; manual smoke is Task 31
  - §10 risks → no new tasks needed; risks documented in spec only
  - §11 out of scope → nothing implemented
  - §13 future optimizations → not addressed in plan (correct)
- **Type consistency:** types referenced in later tasks (e.g. `ProviderTab`, `ProviderTabModel.Body.connected`, `BannerCopy.disconnectedBoth`) are defined in earlier tasks.
- **No placeholders:** every code-step shows runnable code. Test names in `--filter` arguments match the test function names.
- **Bug fixes folded in:** Codex-smoke activation bug (Task 29), Claude missing-CLI snapshot wipe bug (Task 7), per the spec §3 and §4 corrections.
