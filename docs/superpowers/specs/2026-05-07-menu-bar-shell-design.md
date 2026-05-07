# Menu Bar Shell — Design

- **Date:** 2026-05-07
- **Status:** Approved (brainstorming complete; ready for implementation plan)
- **Scope:** macOS app shell refactor — primary UI moves from `WindowGroup` to `MenuBarExtra`, with a Settings window and a DEBUG-only developer window. Tabs and a conditional banner ship as the *frame* for richer per-provider intelligence later.

## 1. Goal And Constraints

The app's job is one-second glanceability: which AI coding tools can I use right now? The menu bar surface delivers that in a popover; the Settings window owns connector configuration; richer per-provider spend or recommendation logic is out of scope and lives in a follow-up spec.

The popover is **status-only**. It carries no credential forms, no provenance details, and no setup affordances beyond a single CTA that opens Settings.

This spec covers Codex and Claude only. Gemini and any "Combined" / aggregated tab are explicitly deferred.

## 2. Locked Decisions

These are settled. Do not re-litigate during implementation.

- **Tabs Phase 1:** Codex, Claude. Gemini and Combined are out of scope.
- **Activation policy:** production runs as `.accessory` (no Dock icon, no Cmd-Tab entry, no Window menu). Bundling sets `LSUIElement = true`; the runtime call is the source of truth in dev.
- **Settings is a separate window** opened via `Cmd+,` (`SwiftUI.Settings { … }`). Connectors-only on day 1.
- **Phase 1 connector actions in Settings:** `Connect`, `Refresh`, `Retry` (state-driven; see §6 table). **No disconnect, no separate reconnect** until backing model APIs exist.
- **Chrome:** the popover footer shows "Last updated …" + a refresh icon, plus a `•••` overflow menu containing Settings, About, Quit (and, in DEBUG only, Open Developer Window).
- **Disconnected tabs are still selectable** and render a compact empty state with a primary "Open Settings" button.
- **Banner is selected-provider scoped, conditional, and deterministic.** When the active tab's body is `.disconnected`, banner shows `.disconnected`. When the active tab is connected with data, banner severity is derived from the worst-of `StatusUsageState` (`critical > low > healthy`); when data is stale or the provider is in a network/schema error state, banner shows `.stale`. The full evaluation table is in §4. A cross-provider hint is appended to a `.critical` / `.low` banner only when the *other* connected provider is `.connected(_, worst: .healthy)`. Disconnected text broadens to "Connect Claude or Codex in Settings" when both providers are disconnected.
- **Single shared `StatusViewModel`** instance, owned by an `AppModel` that's instantiated once at app startup. `MenuBarExtra`, `Settings`, and (DEBUG) the developer window all read from it.
- **Single serialized chrome refresh entry** (`StatusViewModel.refreshAll(reason:)`). Manual / popover-open / 30s in-popover timer share one outer in-flight guard. Settings actions bypass `refreshAll` and call provider-specific methods directly; the per-provider `.checking` guards prevent duplicate same-provider calls.
- **Per-provider stored state** (`lastClaudeRefreshAt`, `lastCodexRefreshAt`); footer's `lastUpdatedAt` is derived as the older of the two. "Last updated" means "the time of the most recent meaningful determination of this provider's state," including local checks like missing CLI.
- **No background polling Phase 1.** Polling runs only while the popover is open, every 30s, and is cancelled on close.
- **No production debug window.** The developer window is `#if DEBUG` only and not compiled into release builds.
- **Copy uses "remaining usage / quota"**, never "spend"; the data contract is `UsageSnapshot`, not cost.
- **Reuses existing thresholds.** `StatusUsageState` already defines `critical < 10%`, `low < 30%`, `healthy ≥ 30%`, `empty = 0`. No new thresholds.

## 3. Architecture And File Layout

Preserves the existing `Models / ViewModels / Views` discipline.

```
apps/mac/Sources/WhatTheTokenMac/
  WhatTheTokenApp.swift               // modified: MenuBarExtra + Settings; DEBUG Window(id: "developer")
  MacAppLauncher.swift                // modified: activation-policy aware (.regular | .accessory | noop)
  AppModel.swift                      // NEW: owns shared dependencies
  Models/                             // unchanged
  ViewModels/
    StatusViewModel.swift             // extended: @MainActor; per-provider timestamps; refreshAll
    BannerState.swift                 // NEW
    ProviderTabModel.swift            // NEW
    PopoverFooterState.swift          // NEW
    PopoverRefreshController.swift    // NEW
  Views/
    Popover/
      PopoverRootView.swift           // NEW
      StatusBannerView.swift          // NEW
      ProviderTabBarView.swift        // NEW
      ProviderTabContentView.swift    // NEW
      PopoverFooterView.swift         // NEW
      StatusSectionView.swift         // moved here from Views/
    Settings/
      SettingsRootView.swift          // NEW
      ConnectorsView.swift            // NEW
      ConnectorRowView.swift          // NEW
    Developer/
      DeveloperWindowView.swift       // NEW; #if DEBUG only
```

`Views/ContentView.swift` is removed in the final implementation step (after the new tree compiles and tests pass), not the first.

### `MacAppLauncher`

`MacAppActivationPolicy` gains `.accessory` alongside `.regular`. `configureLaunch(arguments:application:)` selects:

- `.regular` only when the launch arg `--developer-window` is present (DEBUG builds opening the developer window directly).
- `.accessory` for normal production launch.
- `noop` (early return) for `--claude-connector-smoke` **and** `--codex-connector-smoke`.

The current Codex-smoke-activates-Dock bug (`WhatTheTokenApp.swift:11-13` runs the Codex smoke check after `configureForInteractiveLaunch()` already activated the app) is fixed by reordering: both smoke-mode checks run *before* `configureLaunch`.

### `AppModel`

```swift
@MainActor
@Observable
final class AppModel {
    let viewModel: StatusViewModel
    let refreshController: PopoverRefreshController

    init(viewModel: StatusViewModel) {
        self.viewModel = viewModel
        self.refreshController = PopoverRefreshController(viewModel: viewModel)
    }

    static func live() -> AppModel { AppModel(viewModel: .live()) }
}

@main
struct WhatTheTokenApp: App {
    @State private var app: AppModel = .live()

    init() {
        // 1. smoke-mode handling first (Claude and Codex both)
        // 2. configureLaunch second
    }

    var body: some Scene {
        MenuBarExtra(/* … */) {
            PopoverRootView(viewModel: app.viewModel, controller: app.refreshController)
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
}
```

## 4. Popover Composition

### View tree

```
PopoverRootView                                 // owns selectedTab; .onAppear / .onDisappear -> controller
├── StatusBannerView                            // rendered only when bannerState != .hidden
├── ProviderTabBarView                          // segmented control: Codex / Claude (both always selectable)
├── ProviderTabContentView                      // body switches on ProviderTabModel.body:
│   ├── .connected     → StatusSectionView for selected provider's snapshots
│   ├── .empty         → "Connected — no usage data yet" + Refresh button
│   ├── .checking      → previous body, dimmed, with spinner overlay
│   ├── .disconnected  → empty-state card + reason copy + "Open Settings" primary button
│   └── .error         → reason copy + "Retry" button (calls refreshAll(reason: .retry))
└── PopoverFooterView                           // "Last updated …" + Refresh + ••• overflow
```

### Presentation models

Pure structs / enums; no AppKit, no I/O. Each is a deterministic projection of `StatusViewModel`'s observable state.

```swift
enum ProviderTab: String, CaseIterable, Identifiable, Sendable {
    case codex, claude
    var id: String { rawValue }
    var title: String { self == .codex ? "Codex" : "Claude Code" }
}

struct ProviderTabModel: Equatable, Sendable {
    enum Body: Equatable, Sendable {
        case connected(snapshots: [UsageSnapshot], worst: StatusUsageState)
        case empty                              // connected, no snapshots
        case checking                           // refresh in flight
        case disconnected(reason: DisconnectedReason)
        case error(kind: ErrorKind, lastSnapshots: [UsageSnapshot])
    }
    enum DisconnectedReason: Equatable, Sendable {
        case notConnected, missingCredentials, missingClaudeCLI, tokenInvalid, permissionDenied, rateLimited
    }
    enum ErrorKind: Equatable, Sendable { case network, schemaChanged }
    let tab: ProviderTab
    let body: Body
}

enum BannerState: Equatable, Sendable {
    case hidden
    case critical(text: String)
    case low(text: String)
    case stale(text: String)
    case disconnected(text: String)
}

struct PopoverFooterState: Equatable, Sendable {
    let lastUpdatedAt: Date?
    let isRefreshing: Bool
    let canRefresh: Bool                        // false while isAnyRefreshing
}
```

### Mapping rules

**`ProviderTabModel.from(viewModel:tab:)`** — for Claude:

| `ClaudeConnectorSetupState` | `Body` |
|---|---|
| `.checking` | `.checking` |
| `.connected` + non-empty filtered snapshots | `.connected(snapshots, worst:)` where `worst` = worst-of `StatusUsageState` |
| `.connected` + empty filtered snapshots | `.empty` |
| `.notConnected` | `.disconnected(.notConnected)` |
| `.missingCredentials` | `.disconnected(.missingCredentials)` |
| `.missingClaudeCli` | `.disconnected(.missingClaudeCLI)` |
| `.tokenInvalid` | `.disconnected(.tokenInvalid)` |
| `.rateLimited` | `.disconnected(.rateLimited)` |
| `.networkError` | `.error(.network, lastSnapshots:)` |
| `.schemaChanged` | `.error(.schemaChanged, lastSnapshots:)` |

Codex mapping mirrors this over `CodexConnectorSetupState`. `.permissionDenied` → `.disconnected(.permissionDenied)`. The `.missingClaudeCLI` and `.rateLimited` cases do not apply to Codex.

Snapshot filter predicates match the existing `replaceSnapshots` calls: `provider == "anthropic" && product == "claude_code"` for Claude; `provider == "openai" && product == "codex"` for Codex.

**`BannerState.from(viewModel:selected:)`** — looks at the *selected* tab's `ProviderTabModel.body`. The cases are mutually exclusive (a body is exactly one of these); evaluation order does not matter for correctness.

| Selected tab `body` | Banner |
|---|---|
| `.disconnected(_)` | `.disconnected(text:)`. When both providers are `.disconnected`, broaden to "Connect Claude or Codex in Settings." |
| `.error(.network, _)` or `.error(.schemaChanged, _)`, or any rendered snapshot for the selected provider has `staleReason != nil` | `.stale(text:)` |
| `.connected(_, worst: .critical)` | `.critical(text:)` |
| `.connected(_, worst: .low)` | `.low(text:)` |
| `.connected(_, worst: .healthy)` | `.hidden` |
| `.connected(_, worst: .empty)` | `.hidden` (the tab content surfaces "no usage to report"; a banner here would be noise) |
| `.empty` | `.hidden` |
| `.checking` | `.hidden` (transient; refresh will resolve) |

**Cross-provider hint** is appended to a `.critical` or `.low` banner only when the *other* provider's body is `.connected(_, worst: .healthy)`. Format: "Claude is running low — Codex has more room." If the other provider is itself low/critical/disconnected, no hint is appended.

**`PopoverFooterState`**: straight projection of `viewModel.lastUpdatedAt`, `viewModel.isAnyRefreshing`. `canRefresh = !isRefreshing`.

### Banner copy (centralized in a `BannerCopy` enum for future localization)

- critical: `"Claude is running critically low"` (+ optional cross-provider hint)
- low: `"Claude is running low"` (+ optional cross-provider hint)
- stale: `"Usage may be outdated. Refresh to check current limits."`
- disconnected (selected): `"Codex is not connected. Open Settings to connect."`
- disconnected (both): `"Connect Claude or Codex in Settings."`

## 5. Refresh Controller And Lifecycle

### `StatusViewModel` becomes `@MainActor`-isolated end-to-end

The class is UI-bound; every public method touches observable UI state. Promoting to `@MainActor` removes Sendable friction without runtime overhead in the existing call sites.

```swift
@MainActor
@Observable
final class StatusViewModel {
    // existing stored UI state
    var snapshots: [UsageSnapshot]
    var connectorState: ClaudeConnectorSetupState
    var connectorStatusMessage: String
    var codexConnectorState: CodexConnectorSetupState
    var codexConnectorStatusMessage: String

    // NEW: per-provider stored state
    private(set) var lastClaudeRefreshAt: Date?
    private(set) var lastCodexRefreshAt: Date?
    private(set) var isRefreshAllInFlight: Bool = false

    // Derived
    var isAnyRefreshing: Bool {
        connectorState == .checking
            || codexConnectorState == .checking
            || isRefreshAllInFlight
    }

    var lastUpdatedAt: Date? {
        switch (lastClaudeRefreshAt, lastCodexRefreshAt) {
        case (nil, nil): return nil
        case (let a?, nil), (nil, let a?): return a
        case (let a?, let b?): return min(a, b)
        }
    }
}
```

### `refreshAll` keeps an outer guard; legs run sequentially

```swift
enum RefreshReason: Equatable, Sendable {
    case popoverOpened, manual, timerTick, retry
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

Sequential awaits: this is what the codebase already proves compiles under the current toolchain. Concurrent legs (`async let`) are a documented future optimization (see §10).

### Per-provider timestamps via `defer` + `attempted` flag

Stamps fire on every code path *except* the `.checking`-guard re-entry, so local-check terminal states (no refresher, missing CLI) update the timestamp correctly.

```swift
@MainActor
func connectClaudeCode() async {
    guard connectorState != .checking else { return }   // dedup re-entry; no stamp

    var attempted = false
    defer { if attempted { lastClaudeRefreshAt = Date() } }
    attempted = true

    guard let claudeRefresher else {
        connectorState = .notConnected
        connectorStatusMessage = "Claude Code is not connected"
        return
    }

    if let claudeVersionProvider, claudeVersionProvider.claudeVersion == "unknown" {
        // Provider-scoped clear: only Claude's snapshots, not Codex's, must be wiped.
        replaceSnapshots(matching: { $0.provider == "anthropic" && $0.product == "claude_code" }, with: [])
        connectorState = .missingClaudeCli
        connectorStatusMessage = ClaudeConnectorSetupCopy.title(for: .missingClaudeCli)
        return
    }

    connectorState = .checking
    connectorStatusMessage = "Checking Claude Code"

    do {
        let result = try await claudeRefresher.refresh()
        // existing success path
    } catch {
        // existing error path
    }
}
```

`connectCodex()` follows the same shape over its own state.

### `PopoverRefreshController`

Owns popover-open lifecycle and the in-popover timer. Does **not** own the in-flight guard — that lives on `StatusViewModel`. Sleeper is injected as a closure for deterministic tests.

```swift
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

    func popoverDidOpen() {
        Task { await viewModel.refreshAll(reason: .popoverOpened) }
        startTimer()
    }

    func popoverDidClose()  { stopTimer() }
    func userTappedRefresh() { Task { await viewModel.refreshAll(reason: .manual) } }
    func userTappedRetry()   { Task { await viewModel.refreshAll(reason: .retry)  } }

    private func startTimer() {
        stopTimer()
        let sleeper = self.sleeper
        let interval = self.interval
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                await sleeper(interval)
                if Task.isCancelled { break }
                await self?.viewModel.refreshAll(reason: .timerTick)
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
}
```

`PopoverRootView` drives lifecycle through `.onAppear` / `.onDisappear`. There is no public SwiftUI hook for `MenuBarExtra` popover visibility (`isInserted` controls the *menu-bar item*, not the popover); `.onAppear` on the popover content is the documented stable signal across macOS 14+. AppKit fallback (`NSStatusItem.button.window?.isVisible` observation) is documented as a back-pocket but not implemented Phase 1.

### Open-trigger debounce: not added

If a user opens the popover within seconds of a previous refresh, we re-run. The cost is one HTTP call per provider; the outer guard prevents overlap. Debouncing trades implementation complexity for sub-second savings users will not perceive.

## 6. Settings

Single-pane Settings window. No `TabView` shell yet — adding one is YAGNI until a second pane exists.

```swift
struct SettingsRootView: View {
    let viewModel: StatusViewModel
    var body: some View {
        ConnectorsView(viewModel: viewModel)
            .frame(minWidth: 480, minHeight: 360)
    }
}

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
                    action: { Task { await viewModel.connectClaudeCode() } }
                )
                ConnectorRowView(
                    title: "Codex",
                    stateTitle: CodexConnectorSetupCopy.title(for: viewModel.codexConnectorState),
                    detail: viewModel.codexConnectorStatusMessage,
                    trustMessage: CodexConnectorSetupCopy.trustMessage,
                    actionTitle: codexActionTitle(for: viewModel.codexConnectorState),
                    isWorking: viewModel.codexConnectorState == .checking,
                    action: { Task { await viewModel.connectCodex() } }
                )
            }
        }
        .formStyle(.grouped)
    }
}
```

`ConnectorRowView` displays four strings: `title` (provider name), `stateTitle` (from setup-copy enum), `detail` (from `connectorStatusMessage`), `trustMessage`. `stateTitle` and `detail` are presented as a two-line label so the row degrades when both happen to be the same string.

### `ConnectorRowView` action-title rules

| State | Button title |
|---|---|
| `.notConnected` | `Connect` |
| `.checking` | `Checking…` (button disabled) |
| `.connected` | `Refresh` |
| `.networkError`, `.schemaChanged`, `.rateLimited` (Claude) | `Retry` |
| `.missingCredentials`, `.missingClaudeCli`, `.tokenInvalid` (Claude) | `Connect` |
| `.permissionDenied`, `.missingCredentials` (Codex) | `Connect` |

Action target is the existing per-provider `connectClaudeCode()` / `connectCodex()`. Settings drives a single provider; the popover's chrome refresh button drives `refreshAll(reason: .manual)`. Two distinct entry points serving two distinct intents.

The richer source-state surface (`ConnectorSource` / `ConnectorSourceState`) already exists in the model but its UI display is **not** Phase 1; current state is conveyed through the existing setup-copy and `connectorStatusMessage` strings. A dedicated provenance view is its own follow-up spec.

## 7. DEBUG Developer Window

`Window(id: "developer")` (single, named, openable-on-demand) wrapped in `#if DEBUG`. Not compiled into release. There is no environment variable, hidden launch flag, or release-build path that exposes the developer window.

`DeveloperWindowView` Phase 1 contents:

- Header line: `"Build: DEBUG · Bundle: \(bundleId) · macOS \(version)"`.
- Per-provider section: setup state (raw enum case), `connectorStatusMessage`, `lastClaudeRefreshAt` / `lastCodexRefreshAt`, plus a per-provider "Refresh now" button calling `connectClaudeCode()` / `connectCodex()`.
- A "Refresh all" button calling `viewModel.refreshAll(reason: .manual)`.
- A scrolling list of `UsageSnapshot` JSON dumps (one card per snapshot).

The developer window is **diagnostic-only**, limited to refresh actions and state inspection that are already available in production. No mutating affordances (no credential clear, no fixture toggle, no state injection).

The popover's `•••` overflow menu adds, in DEBUG builds only, an `Open Developer Window` item via `openWindow(id: "developer")`.

`.accessory` activation policy hosts windows without a Dock icon, so opening the developer window does not require flipping to `.regular`. Developers needing a Dock icon can launch with `--developer-window` (Section 3).

## 8. Implementation Sequencing

1. Introduce `AppModel`, presentation models (`BannerState`, `ProviderTabModel`, `PopoverFooterState`), `PopoverRefreshController`, the new view files, and amended `MacAppLauncher`. Old `ContentView` still compiles and is still referenced.
2. Switch `WhatTheTokenApp`'s scene tree to `MenuBarExtra` + `Settings` + (DEBUG) `Window(id: "developer")`. Old `ContentView` is no longer referenced from the scene tree.
3. Run `swift test`; manual smoke checklist (§9). Both green.
4. Delete `Views/ContentView.swift`. Run tests again.

## 9. Testing Plan

### Pure-function tests — `apps/mac/Tests/WhatTheTokenMacTests/Presentation/`

| Subject | Coverage |
|---|---|
| `ProviderTabModel.from(viewModel:tab:)` | One case per `ClaudeConnectorSetupState` (×9) and `CodexConnectorSetupState` (×7). For `.connected`, sub-cases with and without snapshots. |
| `BannerState.from(viewModel:selected:)` | One assert per `Body` case (table in §4); both-providers-disconnected broadens copy; cross-provider hint fires only when other provider is `.connected(_, worst: .healthy)`; `.hidden` when active tab is healthy and no hint applies; `.hidden` for `.empty` and `.checking`. |
| `PopoverFooterState.from(viewModel:)` | `lastUpdatedAt` projection (nil/one/two timestamps → `min`); `canRefresh` mirrors `!isAnyRefreshing`. |
| `claudeActionTitle(for:)` / `codexActionTitle(for:)` | One assert per setup-state case (table in §6). |

### `StatusViewModel` async tests

- `refreshAll_runsBothProvidersInOrder` — fakes record sequence; Claude before Codex.
- `refreshAll_dropsOverlappingChromeRefresh` — two `refreshAll` back-to-back; second returns immediately.
- `refreshAll_doesNotBlockSettingsAction` — kick `refreshAll`; while in flight, call `connectCodex()`; per-provider `.checking` dedup applies but `isRefreshAllInFlight` is unaffected; no crash.
- `refreshAll_setsIsRefreshAllInFlight_falseOnExit` — observes `false → true → false`.
- `refreshAll_isolatesProviderFailures` — Claude leg throws → Claude state goes `.networkError`; Codex leg still completes.
- `connectClaudeCode_stampsTimestamp_onMissingCLIPath`.
- `connectClaudeCode_stampsTimestamp_onNoRefresherPath`.
- `connectClaudeCode_doesNotStamp_onCheckingGuardReentry`.
- `connectCodex_stampsTimestamp_onNoRefresherPath`.
- `lastUpdatedAt_isMinOfPerProviderTimestamps`.
- `connectClaudeCode_missingCLI_preservesCodexSnapshots` — seed `snapshots` with one Claude snapshot and one Codex snapshot; trigger the missing-CLI path; assert the Claude snapshot is gone and the Codex snapshot is unchanged. **(Fixes the existing bug at `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift:52` where `snapshots = []` wipes both providers' rows.)**

### `PopoverRefreshController` tests

A `FakeSleeper` exposes `fireOneTick()` and a `pendingTicks` count to drive the timer deterministically.

- `popoverDidOpen_runsImmediateRefresh_andStartsTimer` — open → one `refreshAll`; `fakeSleeper.fireOneTick()` → second; again → third.
- `popoverDidClose_cancelsBeforeNextTick` — open → close → fire tick → no further refresh.
- `userTappedRefresh_routesThroughRefreshAll` — manual tap during in-flight refresh is dropped by the outer guard.
- `userTappedRetry_routesThroughRefreshAll` — same with `.retry` reason.

### `MacAppLauncher` tests

A `FakeMacApplication` records `setActivationPolicy` and `activateIgnoringOtherApps` calls.

- `configureLaunch_setsAccessoryPolicy_onProductionLaunch` — no special args → `.accessory`, no activate.
- `configureLaunch_setsRegularPolicy_onDeveloperWindowFlag` — `--developer-window` arg → `.regular` + activate.
- `configureLaunch_skipsActivation_onClaudeSmoke` — `--claude-connector-smoke` → no policy / no activate.
- `configureLaunch_skipsActivation_onCodexSmoke` — `--codex-connector-smoke` → no policy / no activate. **(Fixes the existing bug at `WhatTheTokenApp.swift:11-13`.)**

### `AppModel` test

- `live_initializesWiredDependencies` — smoke that `AppModel.live()` constructs without crashing; behavioral wiring covered by ViewModel and Controller tests above; no `viewModel === viewModel` identity assertion.

### View-level testing

Phase 1 does not add SwiftUI snapshot or `ViewInspector` tests. Coverage comes from the presentation-model layer.

### Manual smoke checklist (release-build, before merge)

1. App launches, no Dock icon, no Cmd-Tab entry, menu-bar icon visible.
2. Click menu-bar icon → popover opens with Codex + Claude tabs.
3. Codex tab not connected → "Open Settings" CTA. Click → Settings opens to Connectors.
4. In Settings → Connect Codex → state transitions in both Settings and the popover.
5. Repeat for Claude.
6. With both connected, popover shows snapshot rows; banner is hidden when both providers are healthy.
7. Tap refresh → spinner; "Last updated" moves.
8. Leave popover open 30s → second refresh fires. Close popover, wait 60s, reopen → exactly one refresh fires (open trigger), not three.
9. `Cmd+,` from any state → Settings opens.
10. `•••` overflow → Settings, About (system About panel), Quit work.
11. DEBUG build only: `Open Developer Window` item present in `•••`. Release build: absent.

## 10. Risk Register

| # | Risk | L | I | Mitigation |
|---|------|---|---|---|
| 1 | `.onAppear` / `.onDisappear` on popover root unreliable across macOS versions | Low | Medium | AppKit fallback (`NSStatusItem.button.window?.isVisible`) documented but not implemented Phase 1; manual smoke on macOS 14 + 15 in the release checklist. |
| 2 | Future move to concurrent provider legs hits Swift 6 strict-concurrency diagnostics | Low | Low (Phase 1 stays sequential) | Phase 1 ships sequential awaits, which the existing codebase already proves compile under the current toolchain. Concurrent legs are a documented future optimization, not a Phase 1 dependency. Re-validate against the then-current Swift before promoting. |
| 3 | `LSUIElement` only takes effect at bundle build; SwiftPM `swift run` shows Dock | High | Low | Programmatic `.accessory` in `MacAppLauncher` is the runtime source of truth; bundle-time `Info.plist` mirrors it. Documented in the dev README. |
| 4 | Refresh stampede when popover is opened/closed rapidly | Low | Low | `popoverDidClose` cancels the timer; `isRefreshAllInFlight` drops re-entrant `refreshAll`; per-provider `.checking` dedups inside legs. Covered by tests. |
| 5 | Disconnect deferred → users with stale Keychain credentials have no in-app clear path | Medium | Medium | Existing `tokenInvalid` / `missingCredentials` setup-states already surface "credentials are invalid"; user fixes credentials in the source CLI and clicks Retry. Disconnect/reconnect is a follow-up spec; gap is documented. |
| 6 | `lastUpdatedAt = min(...)` shows the older provider — feels stale if one provider lags | Medium | Low | Correct semantics ("everything you see is at least this fresh"). Per-provider tooltip is a follow-up. |
| 7 | DEBUG developer window introduces dev/prod behavior divergence | Medium | Low (intended) | Diagnostic-only: limited to refresh actions and state inspection that are already available in production. No mutating affordances. Reviewed before merge. |
| 8 | Banner / setup-copy strings hardcoded (no localization) | High | Low | Strings centralized in setup-copy enums and a new `BannerCopy` enum so localization is a future change without touching views. |
| 9 | Cross-provider hint copy could mislead in edge cases | Low | Medium | Hint fires only when other provider's body is `.connected(_, worst: .healthy)`; `.rateLimited` is `.disconnected`, not connected. Unit-tested. |
| 10 | First-launch with no providers connected — empty popover may feel broken | Medium | Medium | Disconnected empty state shows a clear CTA + setup copy + trust message. (A menu-bar-icon badge until at least one provider is connected is a follow-up; not Phase 1.) |

## 11. Out Of Scope

Explicit anti-scope, for any future agent reading this spec.

- Per-provider spend / cost data model.
- Combined / aggregated tab.
- Gemini connector and tab.
- Disconnect / reconnect actions in Settings.
- Background polling (any cadence) when the popover is closed.
- Auto-opening Settings on first launch.
- Localization (English-only Phase 1).
- ViewInspector / SwiftUI snapshot tests.
- AppKit-bridged popover-visibility observation (only the `.onAppear` / `.onDisappear` path is in Phase 1).
- Login items / launch-at-login support.
- Dock-mode toggling at runtime.
- Menu-bar-icon badge for unconnected state.
- Provenance / source-state UI surface in Settings.

## 12. Future Optimizations

- **Concurrent provider legs in `refreshAll`** via `async let` — re-validate under the then-current Swift toolchain before promoting; saves `min(Claude, Codex)` of refresh latency.
- **Menu-bar-icon badge** until at least one provider is connected.
- **Per-provider `lastUpdatedAt` tooltip** in the footer when one provider lags the other.
- **Provenance UI** in Settings showing the existing `ConnectorSourceState` detail.
- **Keyboard shortcuts** — `Cmd+R` (refresh), `Cmd+1` / `Cmd+2` (tab switching).
- **Disconnect / reconnect** actions in Settings, once backing model APIs exist.
