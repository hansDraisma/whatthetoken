# Notifications And Background Freshness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add opt-in background refresh, pause-vs-disconnect connector controls, adaptive stale timing, and local warning/critical notifications.

**Architecture:** Keep Stage 2's local-only settings/cache model and add small focused units: v2 settings migration, a background refresh controller owned by `AppModel`, a pure `NotificationEvaluator`, a local notification-state store, and a `NotificationDelivery` protocol around macOS `UserNotifications`. `StatusViewModel` remains the coordinator for settings, cache, connector refresh, and notification evaluation; SwiftUI views only render settings and user actions.

**Tech Stack:** Swift 6, SwiftUI, Observation, Foundation Codable JSON stores, UserNotifications, swift-testing.

---

## File Structure

- Modify: `apps/mac/Sources/WhatTheTokenMac/Storage/AppSettings.swift`
  - Bump settings schema to v2.
  - Add connector pause state and provider-level notification settings.
  - Decode v1 settings and migrate to v2.
- Modify: `apps/mac/Sources/WhatTheTokenMac/Storage/AppSettingsStore.swift`
  - Continue loading safe defaults on invalid/unknown settings.
- Modify: `apps/mac/Sources/WhatTheTokenMac/Storage/SnapshotCache.swift`
  - Add stale policy support and explicit failure clearing.
- Create: `apps/mac/Sources/WhatTheTokenMac/Notifications/NotificationState.swift`
  - Versioned local notification dedupe state and store.
- Create: `apps/mac/Sources/WhatTheTokenMac/Notifications/NotificationEvaluator.swift`
  - Pure threshold evaluator that returns local notification intents.
- Create: `apps/mac/Sources/WhatTheTokenMac/Notifications/NotificationDelivery.swift`
  - Protocol, in-memory test delivery, and macOS `UserNotifications` delivery implementation.
- Create: `apps/mac/Sources/WhatTheTokenMac/ViewModels/BackgroundRefreshController.swift`
  - Process-level opt-in scheduler for background refresh while app is running.
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift`
  - Add pause/resume, adaptive stale policy, background debounce timestamps, notification evaluation hooks, and notification settings actions.
- Modify: `apps/mac/Sources/WhatTheTokenMac/AppModel.swift`
  - Own and start `BackgroundRefreshController`.
  - Wire notification state/delivery stores into `StatusViewModel`.
- Modify: `apps/mac/Sources/WhatTheTokenMac/WhatTheTokenApp.swift`
  - Expose a modest critical menu-bar state.
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/Settings/ConnectorActionTitle.swift`
  - Add pause/resume copy.
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/Settings/ConnectorRowView.swift`
  - Render pause/resume plus secondary disconnect.
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/Settings/ConnectorsView.swift`
  - Add pause/resume connector flow and `Alerts` settings.
- Test: `apps/mac/Tests/WhatTheTokenMacTests/Storage/AppSettingsTests.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/Storage/SnapshotCacheTests.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/Notifications/NotificationStateTests.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/Notifications/NotificationEvaluatorTests.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/Notifications/NotificationDeliveryTests.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/BackgroundRefreshControllerTests.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/Presentation/ConnectorActionTitleTests.swift`

## Conventions

Run focused Swift tests from `apps/mac`:

```bash
swift test --filter AppSettingsTests
swift test --filter SnapshotCacheTests
swift test --filter NotificationStateTests
swift test --filter NotificationEvaluatorTests
swift test --filter NotificationDeliveryTests
swift test --filter BackgroundRefreshControllerTests
swift test --filter StatusViewModel
swift test --filter ConnectorActionTitleTests
```

Run full verification:

```bash
cd apps/mac && swift test
pnpm --filter @whatthetoken/core test
git diff --check
```

Use commit messages:

- `feat(mac): migrate settings for alerts and paused connectors`
- `feat(mac): add connector pause and adaptive staleness`
- `feat(mac): add background refresh controller`
- `feat(mac): add notification state and evaluator`
- `feat(mac): add local notification delivery`
- `feat(mac): wire alert settings and notifications`
- `feat(mac): add notification settings UI`
- `feat(mac): expose critical menu bar state`

## Task 1: Migrate App Settings To v2

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/Storage/AppSettings.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/Storage/AppSettingsTests.swift`

- [ ] **Step 1: Write failing settings migration tests**

Append these tests to `apps/mac/Tests/WhatTheTokenMacTests/Storage/AppSettingsTests.swift`:

```swift
@Test func v2DefaultsAddPausedConnectorsAndWarningThresholds() {
    let settings = AppSettings.defaults

    #expect(settings.schemaVersion == 2)
    #expect(settings.connectors.claudeCode.isEnabled == false)
    #expect(settings.connectors.claudeCode.isPaused == false)
    #expect(settings.connectors.codex.isEnabled == false)
    #expect(settings.connectors.codex.isPaused == false)
    #expect(settings.notifications.isEnabled == false)
    #expect(settings.notifications.warningThreshold == 0.20)
    #expect(settings.notifications.criticalThreshold == 0.10)
    #expect(settings.notifications.providerAlerts.claudeCode.isEnabled == false)
    #expect(settings.notifications.providerAlerts.codex.isEnabled == false)
}

@Test func decodesV1SettingsAndMigratesDefaultLowThresholdToWarningTwentyPercent() throws {
    let json = """
    {
      "schemaVersion" : 1,
      "connectors" : {
        "claudeCode" : { "isEnabled" : true },
        "codex" : { "isEnabled" : false }
      },
      "refresh" : {
        "autoRefreshEnabled" : true,
        "intervalSeconds" : 600
      },
      "notifications" : {
        "isEnabled" : true,
        "lowThreshold" : 0.3,
        "criticalThreshold" : 0.1
      },
      "menuBar" : {
        "displayMode" : "statusIcon"
      }
    }
    """.data(using: .utf8)!

    let decoded = try AppSettings.decodeValidated(from: json)

    #expect(decoded.schemaVersion == 2)
    #expect(decoded.connectors.claudeCode.isEnabled == true)
    #expect(decoded.connectors.claudeCode.isPaused == false)
    #expect(decoded.connectors.codex.isEnabled == false)
    #expect(decoded.refresh.autoRefreshEnabled == true)
    #expect(decoded.refresh.intervalSeconds == 600)
    #expect(decoded.notifications.isEnabled == true)
    #expect(decoded.notifications.warningThreshold == 0.20)
    #expect(decoded.notifications.criticalThreshold == 0.10)
    #expect(decoded.notifications.providerAlerts.claudeCode.isEnabled == true)
    #expect(decoded.notifications.providerAlerts.codex.isEnabled == false)
}

@Test func decodesV1SettingsAndPreservesCustomLowThresholdAsWarningThreshold() throws {
    let json = """
    {
      "schemaVersion" : 1,
      "connectors" : {
        "claudeCode" : { "isEnabled" : true },
        "codex" : { "isEnabled" : true }
      },
      "refresh" : {
        "autoRefreshEnabled" : false,
        "intervalSeconds" : 300
      },
      "notifications" : {
        "isEnabled" : true,
        "lowThreshold" : 0.25,
        "criticalThreshold" : 0.08
      },
      "menuBar" : {
        "displayMode" : "statusIcon"
      }
    }
    """.data(using: .utf8)!

    let decoded = try AppSettings.decodeValidated(from: json)

    #expect(decoded.notifications.warningThreshold == 0.25)
    #expect(decoded.notifications.criticalThreshold == 0.08)
    #expect(decoded.notifications.providerAlerts.claudeCode.isEnabled == true)
    #expect(decoded.notifications.providerAlerts.codex.isEnabled == true)
}
```

- [ ] **Step 2: Run failing settings tests**

```bash
cd apps/mac && swift test --filter AppSettingsTests
```

Expected: build fails because `isPaused`, `warningThreshold`, and `providerAlerts` do not exist and `schemaVersion` is still `1`.

- [ ] **Step 3: Implement v2 settings and v1 migration**

Replace `apps/mac/Sources/WhatTheTokenMac/Storage/AppSettings.swift` with:

```swift
import Foundation

struct AppSettings: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int
    var connectors: ConnectorSettings
    var refresh: RefreshSettings
    var notifications: NotificationSettings
    var menuBar: MenuBarSettings

    static let defaults = AppSettings(
        schemaVersion: currentSchemaVersion,
        connectors: ConnectorSettings(
            claudeCode: ConnectorConsentSettings(isEnabled: false, isPaused: false),
            codex: ConnectorConsentSettings(isEnabled: false, isPaused: false)
        ),
        refresh: RefreshSettings(autoRefreshEnabled: false, intervalSeconds: 300),
        notifications: NotificationSettings(
            isEnabled: false,
            warningThreshold: 0.20,
            criticalThreshold: 0.10,
            providerAlerts: ProviderAlertSettings(
                claudeCode: ProviderAlertToggle(isEnabled: false),
                codex: ProviderAlertToggle(isEnabled: false)
            )
        ),
        menuBar: MenuBarSettings(displayMode: .statusIcon)
    )

    static func decodeValidated(from data: Data) throws -> AppSettings {
        let envelope = try JSONDecoder().decode(SettingsVersionEnvelope.self, from: data)
        switch envelope.schemaVersion {
        case currentSchemaVersion:
            return try JSONDecoder().decode(AppSettings.self, from: data)
        case 1:
            return try migrateV1(from: data)
        default:
            throw AppSettingsDecodeError.unsupportedSchemaVersion(envelope.schemaVersion)
        }
    }

    private static func migrateV1(from data: Data) throws -> AppSettings {
        let v1 = try JSONDecoder().decode(AppSettingsV1.self, from: data)
        let warningThreshold = abs(v1.notifications.lowThreshold - 0.30) < 0.000_001
            ? 0.20
            : v1.notifications.lowThreshold
        return AppSettings(
            schemaVersion: currentSchemaVersion,
            connectors: ConnectorSettings(
                claudeCode: ConnectorConsentSettings(isEnabled: v1.connectors.claudeCode.isEnabled, isPaused: false),
                codex: ConnectorConsentSettings(isEnabled: v1.connectors.codex.isEnabled, isPaused: false)
            ),
            refresh: v1.refresh,
            notifications: NotificationSettings(
                isEnabled: v1.notifications.isEnabled,
                warningThreshold: warningThreshold,
                criticalThreshold: v1.notifications.criticalThreshold,
                providerAlerts: ProviderAlertSettings(
                    claudeCode: ProviderAlertToggle(isEnabled: v1.connectors.claudeCode.isEnabled),
                    codex: ProviderAlertToggle(isEnabled: v1.connectors.codex.isEnabled)
                )
            ),
            menuBar: v1.menuBar
        )
    }
}

private struct SettingsVersionEnvelope: Decodable {
    let schemaVersion: Int
}

private struct AppSettingsV1: Decodable {
    let schemaVersion: Int
    let connectors: ConnectorSettingsV1
    let refresh: RefreshSettings
    let notifications: NotificationSettingsV1
    let menuBar: MenuBarSettings
}

private struct ConnectorSettingsV1: Decodable {
    let claudeCode: ConnectorConsentSettingsV1
    let codex: ConnectorConsentSettingsV1
}

private struct ConnectorConsentSettingsV1: Decodable {
    let isEnabled: Bool
}

private struct NotificationSettingsV1: Decodable {
    let isEnabled: Bool
    let lowThreshold: Double
    let criticalThreshold: Double
}

struct ConnectorSettings: Codable, Equatable, Sendable {
    var claudeCode: ConnectorConsentSettings
    var codex: ConnectorConsentSettings
}

struct ConnectorConsentSettings: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var isPaused: Bool
}

struct RefreshSettings: Codable, Equatable, Sendable {
    var autoRefreshEnabled: Bool
    var intervalSeconds: Int

    var intervalDuration: Duration {
        .seconds(intervalSeconds)
    }
}

struct NotificationSettings: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var warningThreshold: Double
    var criticalThreshold: Double
    var providerAlerts: ProviderAlertSettings
}

struct ProviderAlertSettings: Codable, Equatable, Sendable {
    var claudeCode: ProviderAlertToggle
    var codex: ProviderAlertToggle

    func isEnabled(for provider: CachedProviderID) -> Bool {
        switch provider {
        case .claude: return claudeCode.isEnabled
        case .codex: return codex.isEnabled
        }
    }
}

struct ProviderAlertToggle: Codable, Equatable, Sendable {
    var isEnabled: Bool
}

struct MenuBarSettings: Codable, Equatable, Sendable {
    enum DisplayMode: String, Codable, Equatable, Sendable {
        case statusIcon
    }

    var displayMode: DisplayMode
}

enum AppSettingsDecodeError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
}
```

- [ ] **Step 4: Update existing test expectations**

In `apps/mac/Tests/WhatTheTokenMacTests/Storage/AppSettingsTests.swift`, update:

```swift
#expect(settings.schemaVersion == 2)
#expect(settings.connectors.claudeCode.isPaused == false)
#expect(settings.connectors.codex.isPaused == false)
#expect(settings.notifications.warningThreshold == 0.20)
```

Remove or replace any assertion that reads `settings.notifications.lowThreshold`.

- [ ] **Step 5: Run focused tests**

```bash
cd apps/mac && swift test --filter AppSettingsTests
```

Expected: all `AppSettingsTests` pass.

- [ ] **Step 6: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/Storage/AppSettings.swift \
  apps/mac/Tests/WhatTheTokenMacTests/Storage/AppSettingsTests.swift
git commit -m "feat(mac): migrate settings for alerts and paused connectors"
```

## Task 2: Add Pause Semantics And Adaptive Staleness

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/Storage/SnapshotCache.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/Storage/SnapshotCacheTests.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift`

- [ ] **Step 1: Add failing staleness-policy tests**

Append to `apps/mac/Tests/WhatTheTokenMacTests/Storage/SnapshotCacheTests.swift`:

```swift
@Test func stalePolicyForAutoRefreshUsesMaxOfTwoIntervalsAndFifteenMinutes() {
    #expect(SnapshotStalePolicy.from(settings: {
        var settings = AppSettings.defaults
        settings.refresh.autoRefreshEnabled = true
        settings.refresh.intervalSeconds = 300
        return settings
    }()).staleAfterMinutes == 15)

    #expect(SnapshotStalePolicy.from(settings: {
        var settings = AppSettings.defaults
        settings.refresh.autoRefreshEnabled = true
        settings.refresh.intervalSeconds = 1_200
        return settings
    }()).staleAfterMinutes == 40)
}

@Test func stalePolicyForManualOnlyUsesSixtyMinutes() {
    var settings = AppSettings.defaults
    settings.refresh.autoRefreshEnabled = false

    #expect(SnapshotStalePolicy.from(settings: settings).staleAfterMinutes == 60)
}
```

- [ ] **Step 2: Add failing pause tests**

Append to `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift`:

```swift
@MainActor
@Test func pauseConnectorKeepsCachedSnapshotsButSkipsRefresh() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    var cache = SnapshotCache.empty
    cache.replaceSnapshots([UsageSnapshotFixture.claudeSample()], for: .claude, at: Date(timeIntervalSince1970: 1))
    let counter = Counter()
    let vm = StatusViewModel(
        settings: settings,
        cache: cache,
        claudeRefresher: SlowClaudeRefresher(counter: counter),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0")
    )

    await vm.loadPersistedState()
    await vm.setConnector(.claude, paused: true)
    await vm.refreshAll(reason: .manual)

    #expect(vm.snapshots.contains(where: CachedProviderID.claude.snapshotPredicate))
    #expect(counter.value == 0)
}

@MainActor
@Test func disconnectWhilePausedRemovesProviderCache() async {
    var settings = AppSettings.defaults
    settings.connectors.codex.isEnabled = true
    settings.connectors.codex.isPaused = true
    var cache = SnapshotCache.empty
    cache.replaceSnapshots([UsageSnapshotFixture.codexSample()], for: .codex, at: Date(timeIntervalSince1970: 1))
    let cacheStore = InMemorySnapshotCacheStore(data: try! JSONEncoder.cacheEncoder.encode(cache))
    let settingsStore = InMemoryAppSettingsStore(data: try! JSONEncoder.prettyStable.encode(settings))
    let vm = StatusViewModel(settingsStore: settingsStore, cacheStore: cacheStore)

    await vm.loadPersistedState()
    await vm.disconnect(.codex)

    #expect(vm.settings.connectors.codex.isEnabled == false)
    #expect(vm.settings.connectors.codex.isPaused == false)
    #expect(vm.snapshots.contains(where: CachedProviderID.codex.snapshotPredicate) == false)
}

@MainActor
@Test func successfulManualRefreshClearsProviderBackoff() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    var cache = SnapshotCache.empty
    cache.recordFailure(for: .claude, code: .network, message: "Network", now: Date(timeIntervalSince1970: 1))
    let cacheStore = InMemorySnapshotCacheStore(data: try! JSONEncoder.cacheEncoder.encode(cache))
    let vm = StatusViewModel(
        settings: settings,
        claudeRefresher: NoopClaudeRefresher(),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        cacheStore: cacheStore,
        now: { Date(timeIntervalSince1970: 2) }
    )

    await vm.refreshAll(reason: .manual)
    let saved = await cacheStore.load()

    #expect(saved.lastErrorByProvider[CachedProviderID.claude.rawValue] == nil)
}
```

- [ ] **Step 3: Run failing focused tests**

```bash
cd apps/mac && swift test --filter SnapshotCacheTests
cd apps/mac && swift test --filter StatusViewModel
```

Expected: build fails because `SnapshotStalePolicy` and `setConnector(_:paused:)` do not exist.

- [ ] **Step 4: Implement stale policy**

In `apps/mac/Sources/WhatTheTokenMac/Storage/SnapshotCache.swift`, add:

```swift
struct SnapshotStalePolicy: Equatable, Sendable {
    let staleAfterMinutes: Int

    static func from(settings: AppSettings) -> SnapshotStalePolicy {
        guard settings.refresh.autoRefreshEnabled else {
            return SnapshotStalePolicy(staleAfterMinutes: 60)
        }
        let intervalMinutes = max(settings.refresh.intervalSeconds / 60, 1)
        return SnapshotStalePolicy(staleAfterMinutes: max(intervalMinutes * 2, 15))
    }
}
```

Change:

```swift
func snapshotsEvaluatingStaleness(now: Date, staleAfterMinutes: Int = 60) -> [UsageSnapshot]
```

to:

```swift
func snapshotsEvaluatingStaleness(now: Date, policy: SnapshotStalePolicy = SnapshotStalePolicy(staleAfterMinutes: 60)) -> [UsageSnapshot] {
    snapshots.map { $0.evaluatingStaleness(now: now, staleAfterMinutes: policy.staleAfterMinutes) }
}
```

Update existing callers/tests that pass `staleAfterMinutes:` to pass:

```swift
policy: SnapshotStalePolicy(staleAfterMinutes: 60)
```

- [ ] **Step 5: Implement pause state in `StatusViewModel`**

In `StatusViewModel`, update the enabled guards in `refreshClaude(reason:)` and `refreshCodex(reason:)`:

```swift
guard settings.connectors.claudeCode.isEnabled && !settings.connectors.claudeCode.isPaused else { return }
```

```swift
guard settings.connectors.codex.isEnabled && !settings.connectors.codex.isPaused else { return }
```

Add:

```swift
@discardableResult
func setConnector(_ provider: CachedProviderID, paused: Bool) async -> Bool {
    var nextSettings = settings
    switch provider {
    case .claude:
        guard nextSettings.connectors.claudeCode.isEnabled else { return false }
        nextSettings.connectors.claudeCode.isPaused = paused
    case .codex:
        guard nextSettings.connectors.codex.isEnabled else { return false }
        nextSettings.connectors.codex.isPaused = paused
    }

    guard await settingsStore.save(nextSettings) else { return false }
    settings = nextSettings
    applyCachedSnapshots()
    applyConnectorStatesFromSettings()
    return true
}
```

In `setConnector(_:enabled:)`, when enabling set `isPaused = false`. When disabling via this non-destructive path, leave cache intact and set `isPaused = false`:

```swift
case .claude:
    nextSettings.connectors.claudeCode.isEnabled = enabled
    if enabled { nextSettings.connectors.claudeCode.isPaused = false }
case .codex:
    nextSettings.connectors.codex.isEnabled = enabled
    if enabled { nextSettings.connectors.codex.isPaused = false }
```

In `disconnect(_:)`, set both `isEnabled = false` and `isPaused = false` for the provider.

- [ ] **Step 6: Apply adaptive stale policy**

In `applyCachedSnapshots()`, replace:

```swift
let evaluated = cache.snapshotsEvaluatingStaleness(now: now())
```

with:

```swift
let evaluated = cache.snapshotsEvaluatingStaleness(
    now: now(),
    policy: SnapshotStalePolicy.from(settings: settings)
)
```

Keep paused enabled-provider snapshots visible by continuing to filter only on `isEnabled`, not `isPaused`.

- [ ] **Step 7: Run focused tests**

```bash
cd apps/mac && swift test --filter SnapshotCacheTests
cd apps/mac && swift test --filter StatusViewModel
```

Expected: focused tests pass.

- [ ] **Step 8: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/Storage/SnapshotCache.swift \
  apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift \
  apps/mac/Tests/WhatTheTokenMacTests/Storage/SnapshotCacheTests.swift \
  apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift
git commit -m "feat(mac): add connector pause and adaptive staleness"
```

## Task 3: Add Background Refresh Controller

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/ViewModels/BackgroundRefreshController.swift`
- Create: `apps/mac/Tests/WhatTheTokenMacTests/BackgroundRefreshControllerTests.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/AppModel.swift`

- [ ] **Step 1: Write failing background refresh tests**

Create `apps/mac/Tests/WhatTheTokenMacTests/BackgroundRefreshControllerTests.swift`:

```swift
import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct BackgroundRefreshControllerTests {
    @MainActor
    @Test func startDoesNotScheduleTimerWhenAutoRefreshDisabled() async {
        let vm = StatusViewModel(settings: .defaults)
        let fake = FakeSleeper()
        let controller = BackgroundRefreshController(viewModel: vm, sleeper: { duration in await fake.sleep(duration) })

        controller.start()
        for _ in 0..<10 { await Task.yield() }

        #expect(fake.pendingTicks == 0)
    }

    @MainActor
    @Test func startSchedulesConfiguredTimerWhenAutoRefreshEnabled() async {
        var settings = AppSettings.defaults
        settings.refresh.autoRefreshEnabled = true
        settings.refresh.intervalSeconds = 300
        let vm = StatusViewModel(settings: settings)
        let fake = FakeSleeper()
        let controller = BackgroundRefreshController(viewModel: vm, sleeper: { duration in await fake.sleep(duration) })

        controller.start()
        for _ in 0..<20 {
            if fake.pendingTicks > 0 { break }
            await Task.yield()
        }

        #expect(fake.pendingTicks == 1)
        #expect(fake.lastDuration == .seconds(300))
        controller.stop()
    }

    @MainActor
    @Test func timerTickRefreshesWhilePopoverIsClosed() async {
        var settings = AppSettings.defaults
        settings.connectors.claudeCode.isEnabled = true
        settings.refresh.autoRefreshEnabled = true
        let vm = StatusViewModel(
            settings: settings,
            claudeRefresher: NoopClaudeRefresher(),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0")
        )
        let fake = FakeSleeper()
        let controller = BackgroundRefreshController(viewModel: vm, sleeper: { duration in await fake.sleep(duration) })

        controller.start()
        for _ in 0..<20 {
            if fake.pendingTicks > 0 { break }
            await Task.yield()
        }
        fake.fireOneTick()
        for _ in 0..<20 { await Task.yield() }

        #expect(vm.lastClaudeRefreshAt != nil)
        controller.stop()
    }

    @MainActor
    @Test func catchUpRefreshRunsWhenActivationFindsIntervalElapsed() async {
        var settings = AppSettings.defaults
        settings.connectors.claudeCode.isEnabled = true
        settings.refresh.autoRefreshEnabled = true
        settings.refresh.intervalSeconds = 300
        var current = Date(timeIntervalSince1970: 1_000)
        let vm = StatusViewModel(
            settings: settings,
            claudeRefresher: NoopClaudeRefresher(),
            claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
            now: { current }
        )
        let controller = BackgroundRefreshController(viewModel: vm, sleeper: { _ in })

        await controller.appBecameActive()
        let first = vm.lastClaudeRefreshAt
        current = Date(timeIntervalSince1970: 1_301)
        await controller.appBecameActive()

        #expect(first != nil)
        #expect(vm.lastClaudeRefreshAt == current)
    }
}
```

- [ ] **Step 2: Run failing background tests**

```bash
cd apps/mac && swift test --filter BackgroundRefreshControllerTests
```

Expected: build fails because `BackgroundRefreshController` does not exist.

- [ ] **Step 3: Implement background refresh controller**

Create `apps/mac/Sources/WhatTheTokenMac/ViewModels/BackgroundRefreshController.swift`:

```swift
import Foundation

@MainActor
final class BackgroundRefreshController {
    private let viewModel: StatusViewModel
    private let sleeper: SleepClosure
    private var timerTask: Task<Void, Never>?
    private var generation = 0
    private var lastAutomaticAttemptAt: Date?

    init(
        viewModel: StatusViewModel,
        sleeper: @escaping SleepClosure = { try? await Task.sleep(for: $0) }
    ) {
        self.viewModel = viewModel
        self.sleeper = sleeper
    }

    func start() {
        generation &+= 1
        stop()
        guard viewModel.settings.refresh.autoRefreshEnabled else { return }
        let expected = generation
        let interval = viewModel.settings.refresh.intervalDuration
        let sleeper = self.sleeper
        let viewModel = self.viewModel
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                await sleeper(interval)
                if Task.isCancelled { break }
                guard let self, self.generation == expected else { break }
                self.lastAutomaticAttemptAt = viewModel.currentDate
                await viewModel.refreshAll(reason: .timerTick)
            }
        }
    }

    func settingsDidChange() {
        start()
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
    }

    func appBecameActive() async {
        guard viewModel.settings.refresh.autoRefreshEnabled else { return }
        let now = viewModel.currentDate
        let interval = TimeInterval(viewModel.settings.refresh.intervalSeconds)
        if let lastAutomaticAttemptAt, now.timeIntervalSince(lastAutomaticAttemptAt) < interval {
            return
        }
        guard !viewModel.isAnyRefreshing else { return }
        lastAutomaticAttemptAt = now
        await viewModel.refreshAll(reason: .timerTick)
    }
}
```

This needs `StatusViewModel.currentDate`; add in `StatusViewModel`:

```swift
var currentDate: Date { now() }
```

- [ ] **Step 4: Wire controller into `AppModel`**

Modify `apps/mac/Sources/WhatTheTokenMac/AppModel.swift`:

```swift
@MainActor
@Observable
final class AppModel {
    let viewModel: StatusViewModel
    let refreshController: PopoverRefreshController
    let backgroundRefreshController: BackgroundRefreshController

    init(viewModel: StatusViewModel) {
        self.viewModel = viewModel
        self.refreshController = PopoverRefreshController(viewModel: viewModel)
        let backgroundRefreshController = BackgroundRefreshController(viewModel: viewModel)
        self.backgroundRefreshController = backgroundRefreshController
        self.viewModel.onSettingsChanged = { [weak backgroundRefreshController] in
            backgroundRefreshController?.settingsDidChange()
        }
        Task {
            await viewModel.loadPersistedState()
            backgroundRefreshController.start()
        }
    }

    static func live() -> AppModel {
        let directory = applicationSupportDirectory()
        let settingsStore = JSONFileAppSettingsStore(url: directory.appendingPathComponent("settings.json"))
        let cacheStore = JSONFileSnapshotCacheStore(url: directory.appendingPathComponent("snapshot-cache.json"))
        return AppModel(viewModel: .live(settingsStore: settingsStore, cacheStore: cacheStore))
    }

    private static func applicationSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("WhatTheToken", isDirectory: true)
    }
}
```

- [ ] **Step 5: Restart scheduler when settings save changes refresh settings**

Add to `StatusViewModel`:

```swift
var onSettingsChanged: (@MainActor () -> Void)?
```

After successful `saveSettings`, `setConnector`, and `setConnector(_:paused:)`, call:

```swift
onSettingsChanged?()
```

The `AppModel.init` body from Step 4 already creates the background controller as a local value before assigning the callback so the closure does not capture an incompletely initialized property.

- [ ] **Step 6: Run focused tests**

```bash
cd apps/mac && swift test --filter BackgroundRefreshControllerTests
cd apps/mac && swift test --filter AppModelTests
```

Expected: tests pass.

- [ ] **Step 7: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/BackgroundRefreshController.swift \
  apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift \
  apps/mac/Sources/WhatTheTokenMac/AppModel.swift \
  apps/mac/Tests/WhatTheTokenMacTests/BackgroundRefreshControllerTests.swift
git commit -m "feat(mac): add background refresh controller"
```

## Task 4: Add Notification State Store

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/Notifications/NotificationState.swift`
- Create: `apps/mac/Tests/WhatTheTokenMacTests/Notifications/NotificationStateTests.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/AppModel.swift`

- [ ] **Step 1: Write failing notification state tests**

Create `apps/mac/Tests/WhatTheTokenMacTests/Notifications/NotificationStateTests.swift`:

```swift
import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct NotificationStateTests {
    @Test func emptyStateUsesCurrentSchema() {
        #expect(NotificationState.empty.schemaVersion == 1)
        #expect(NotificationState.empty.records.isEmpty)
    }

    @Test func roundTripPreservesSanitizedRecords() throws {
        var state = NotificationState.empty
        let key = NotificationDedupeKey(provider: .claude, poolKey: "anthropic_claude_subscription", windowKey: "rolling_5h")
        state.records[key.storageKey] = NotificationRecord(
            key: key,
            lastNotifiedLevel: .warning,
            lastNotifiedAt: Date(timeIntervalSince1970: 100),
            lastObservedLevel: .warning,
            recoveredAt: nil
        )

        let data = try JSONEncoder.notificationStateEncoder.encode(state)
        let decoded = try NotificationState.decodeValidated(from: data)

        #expect(decoded.records[key.storageKey]?.lastNotifiedLevel == .warning)
        #expect(String(decoding: data, as: UTF8.self).contains("token") == false)
        #expect(String(decoding: data, as: UTF8.self).contains("cookie") == false)
    }

    @Test func memoryStoreFallsBackToEmptyOnInvalidData() async {
        let store = InMemoryNotificationStateStore(data: Data("not json".utf8))

        let loaded = await store.load()

        #expect(loaded == .empty)
        #expect(store.didFallbackOnLoad == true)
    }
}
```

- [ ] **Step 2: Run failing tests**

```bash
cd apps/mac && swift test --filter NotificationStateTests
```

Expected: build fails because notification state types do not exist.

- [ ] **Step 3: Implement notification state and stores**

Create `apps/mac/Sources/WhatTheTokenMac/Notifications/NotificationState.swift`:

```swift
import Foundation

enum NotificationLevel: String, Codable, Equatable, Sendable {
    case healthy
    case warning
    case critical
}

struct NotificationDedupeKey: Codable, Equatable, Hashable, Sendable {
    var provider: CachedProviderID
    var poolKey: String
    var windowKey: String

    var storageKey: String {
        "\(provider.rawValue)|\(poolKey)|\(windowKey)"
    }
}

struct NotificationRecord: Codable, Equatable, Sendable {
    var key: NotificationDedupeKey
    var lastNotifiedLevel: NotificationLevel?
    var lastNotifiedAt: Date?
    var lastObservedLevel: NotificationLevel
    var recoveredAt: Date?
}

struct NotificationState: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var records: [String: NotificationRecord]

    static let empty = NotificationState(schemaVersion: currentSchemaVersion, records: [:])

    static func decodeValidated(from data: Data) throws -> NotificationState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(NotificationState.self, from: data)
        guard decoded.schemaVersion == currentSchemaVersion else {
            throw NotificationStateDecodeError.unsupportedSchemaVersion(decoded.schemaVersion)
        }
        return decoded
    }
}

enum NotificationStateDecodeError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
}

protocol NotificationStateStore: Sendable {
    func load() async -> NotificationState
    @discardableResult
    func save(_ state: NotificationState) async -> Bool
    var didFallbackOnLoad: Bool { get async }
}

final class JSONFileNotificationStateStore: NotificationStateStore, @unchecked Sendable {
    let url: URL
    private let lock = NSLock()
    private var fallback = false

    init(url: URL) {
        self.url = url
    }

    var didFallbackOnLoad: Bool {
        get async { lock.withLock { fallback } }
    }

    func load() async -> NotificationState {
        do {
            let data = try Data(contentsOf: url)
            let state = try NotificationState.decodeValidated(from: data)
            lock.withLock { fallback = false }
            return state
        } catch {
            lock.withLock { fallback = true }
            return .empty
        }
    }

    @discardableResult
    func save(_ state: NotificationState) async -> Bool {
        let temporaryURL = url
            .deletingLastPathComponent()
            .appendingPathComponent("\(url.lastPathComponent).\(UUID().uuidString).tmp")
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder.notificationStateEncoder.encode(state)
            try data.write(to: temporaryURL, options: [.atomic])
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: temporaryURL)
            } else {
                try FileManager.default.moveItem(at: temporaryURL, to: url)
            }
            return true
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            return false
        }
    }
}

final class InMemoryNotificationStateStore: NotificationStateStore, @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?
    private var fallback = false

    init(data: Data? = nil) {
        self.data = data
    }

    var didFallbackOnLoad: Bool {
        get async { lock.withLock { fallback } }
    }

    func load() async -> NotificationState {
        lock.withLock {
            guard let data else { return .empty }
            do {
                return try NotificationState.decodeValidated(from: data)
            } catch {
                fallback = true
                return .empty
            }
        }
    }

    @discardableResult
    func save(_ state: NotificationState) async -> Bool {
        guard let encoded = try? JSONEncoder.notificationStateEncoder.encode(state) else { return false }
        lock.withLock {
            data = encoded
        }
        return true
    }
}

extension JSONEncoder {
    static var notificationStateEncoder: JSONEncoder {
        let encoder = JSONEncoder.prettyStable
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
```

- [ ] **Step 4: Wire live notification state store path**

In `AppModel.live()`, add:

```swift
let notificationStateStore = JSONFileNotificationStateStore(url: directory.appendingPathComponent("notification-state.json"))
```

The store will be injected into `StatusViewModel` in Task 6.

- [ ] **Step 5: Run focused tests**

```bash
cd apps/mac && swift test --filter NotificationStateTests
```

Expected: tests pass.

- [ ] **Step 6: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/Notifications/NotificationState.swift \
  apps/mac/Tests/WhatTheTokenMacTests/Notifications/NotificationStateTests.swift \
  apps/mac/Sources/WhatTheTokenMac/AppModel.swift
git commit -m "feat(mac): add notification state store"
```

## Task 5: Add Pure Notification Evaluator

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/Notifications/NotificationEvaluator.swift`
- Create: `apps/mac/Tests/WhatTheTokenMacTests/Notifications/NotificationEvaluatorTests.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelFakes.swift`

- [ ] **Step 1: Add focused evaluator tests**

Create `apps/mac/Tests/WhatTheTokenMacTests/Notifications/NotificationEvaluatorTests.swift`:

```swift
import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct NotificationEvaluatorTests {
    @Test func warningFiresOnceBelowTwentyPercent() {
        let snapshot = UsageSnapshotFixture.claudeIncludedSample(remaining: 19, utilization: 0.81)
        var state = NotificationState.empty
        let result = NotificationEvaluator.evaluate(
            snapshots: [snapshot],
            settings: alertSettings(),
            state: state,
            now: Date(timeIntervalSince1970: 1_000),
            suppressDelivery: false
        )

        #expect(result.intents.count == 1)
        #expect(result.intents.first?.level == .warning)
        state = result.state

        let second = NotificationEvaluator.evaluate(
            snapshots: [snapshot],
            settings: alertSettings(),
            state: state,
            now: Date(timeIntervalSince1970: 1_060),
            suppressDelivery: false
        )
        #expect(second.intents.isEmpty)
    }

    @Test func criticalFiresAfterWarningAndDirectlyFromHealthy() {
        let warning = UsageSnapshotFixture.claudeIncludedSample(remaining: 19, utilization: 0.81)
        let critical = UsageSnapshotFixture.claudeIncludedSample(remaining: 9, utilization: 0.91)
        let first = NotificationEvaluator.evaluate(
            snapshots: [warning],
            settings: alertSettings(),
            state: .empty,
            now: Date(timeIntervalSince1970: 1_000),
            suppressDelivery: false
        )
        let second = NotificationEvaluator.evaluate(
            snapshots: [critical],
            settings: alertSettings(),
            state: first.state,
            now: Date(timeIntervalSince1970: 1_060),
            suppressDelivery: false
        )
        let direct = NotificationEvaluator.evaluate(
            snapshots: [critical],
            settings: alertSettings(),
            state: .empty,
            now: Date(timeIntervalSince1970: 1_000),
            suppressDelivery: false
        )

        #expect(second.intents.first?.level == .critical)
        #expect(direct.intents.first?.level == .critical)
    }

    @Test func stalePausedDisabledAndFallbackCreditSnapshotsDoNotNotify() {
        var pausedSettings = alertSettings()
        pausedSettings.connectors.claudeCode.isPaused = true
        let stale = UsageSnapshotFixture.claudeIncludedSample(remaining: 5, utilization: 0.95, staleReason: "old")
        let fallback = UsageSnapshotFixture.claudeCreditsSample(remaining: 0)

        #expect(NotificationEvaluator.evaluate(snapshots: [stale], settings: alertSettings(), state: .empty, now: Date(), suppressDelivery: false).intents.isEmpty)
        #expect(NotificationEvaluator.evaluate(snapshots: [UsageSnapshotFixture.claudeIncludedSample(remaining: 5, utilization: 0.95)], settings: pausedSettings, state: .empty, now: Date(), suppressDelivery: false).intents.isEmpty)
        #expect(NotificationEvaluator.evaluate(snapshots: [fallback], settings: alertSettings(), state: .empty, now: Date(), suppressDelivery: false).intents.isEmpty)
    }

    @Test func cacheLoadSuppressionUpdatesStateWithoutDelivering() {
        let snapshot = UsageSnapshotFixture.codexIncludedSample(remaining: 8, utilization: 0.92)
        let result = NotificationEvaluator.evaluate(
            snapshots: [snapshot],
            settings: alertSettings(),
            state: .empty,
            now: Date(timeIntervalSince1970: 1_000),
            suppressDelivery: true
        )

        #expect(result.intents.isEmpty)
        #expect(result.state.records.isEmpty == false)
    }
}

private func alertSettings() -> AppSettings {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    settings.connectors.codex.isEnabled = true
    settings.notifications.isEnabled = true
    settings.notifications.providerAlerts.claudeCode.isEnabled = true
    settings.notifications.providerAlerts.codex.isEnabled = true
    return settings
}
```

- [ ] **Step 2: Run failing evaluator tests**

```bash
cd apps/mac && swift test --filter NotificationEvaluatorTests
```

Expected: build fails because `NotificationEvaluator` and `NotificationIntent` do not exist.

- [ ] **Step 3: Implement evaluator**

Create `apps/mac/Sources/WhatTheTokenMac/Notifications/NotificationEvaluator.swift`:

```swift
import Foundation

struct NotificationIntent: Equatable, Sendable {
    var id: String
    var provider: CachedProviderID
    var level: NotificationLevel
    var title: String
    var body: String
}

struct NotificationEvaluationResult: Equatable, Sendable {
    var intents: [NotificationIntent]
    var state: NotificationState
}

enum NotificationEvaluator {
    static func evaluate(
        snapshots: [UsageSnapshot],
        settings: AppSettings,
        state: NotificationState,
        now: Date,
        suppressDelivery: Bool
    ) -> NotificationEvaluationResult {
        guard settings.notifications.isEnabled else {
            return NotificationEvaluationResult(intents: [], state: state)
        }

        var nextState = state
        var intents: [NotificationIntent] = []

        for snapshot in snapshots {
            guard let provider = provider(for: snapshot) else { continue }
            guard isProviderEnabled(provider, settings: settings) else { continue }
            guard !isProviderPaused(provider, settings: settings) else { continue }
            guard settings.notifications.providerAlerts.isEnabled(for: provider) else { continue }
            guard snapshot.staleReason == nil else { continue }
            guard isIncludedQuota(snapshot) else { continue }
            guard let remainingRatio = remainingRatio(snapshot) else { continue }

            let level = levelFor(remainingRatio: remainingRatio, settings: settings)
            let key = NotificationDedupeKey(
                provider: provider,
                poolKey: snapshot.poolKey,
                windowKey: normalizedWindowKey(snapshot.windowKey)
            )
            let storageKey = key.storageKey
            let previous = nextState.records[storageKey]
            let shouldNotify = shouldNotify(
                previous: previous,
                level: level,
                settings: settings,
                now: now
            )
            nextState.records[storageKey] = NotificationRecord(
                key: key,
                lastNotifiedLevel: shouldNotify && !suppressDelivery ? level : previous?.lastNotifiedLevel,
                lastNotifiedAt: shouldNotify && !suppressDelivery ? now : previous?.lastNotifiedAt,
                lastObservedLevel: level,
                recoveredAt: recoveredAt(previous: previous, level: level, settings: settings, now: now)
            )

            if shouldNotify && !suppressDelivery {
                intents.append(intent(provider: provider, level: level, snapshot: snapshot))
            }
        }

        return NotificationEvaluationResult(intents: intents, state: nextState)
    }

    private static func provider(for snapshot: UsageSnapshot) -> CachedProviderID? {
        if CachedProviderID.claude.snapshotPredicate(snapshot) { return .claude }
        if CachedProviderID.codex.snapshotPredicate(snapshot) { return .codex }
        return nil
    }

    private static func isProviderEnabled(_ provider: CachedProviderID, settings: AppSettings) -> Bool {
        switch provider {
        case .claude: return settings.connectors.claudeCode.isEnabled
        case .codex: return settings.connectors.codex.isEnabled
        }
    }

    private static func isProviderPaused(_ provider: CachedProviderID, settings: AppSettings) -> Bool {
        switch provider {
        case .claude: return settings.connectors.claudeCode.isPaused
        case .codex: return settings.connectors.codex.isPaused
        }
    }

    private static func isIncludedQuota(_ snapshot: UsageSnapshot) -> Bool {
        snapshot.unit == "utilization"
    }

    private static func remainingRatio(_ snapshot: UsageSnapshot) -> Double? {
        if let remaining = snapshot.remaining, let limit = snapshot.limit, limit > 0 {
            return remaining / limit
        }
        if let utilization = snapshot.utilization {
            return max(1 - utilization, 0)
        }
        return nil
    }

    private static func levelFor(remainingRatio: Double, settings: AppSettings) -> NotificationLevel {
        if remainingRatio < settings.notifications.criticalThreshold { return .critical }
        if remainingRatio < settings.notifications.warningThreshold { return .warning }
        return .healthy
    }

    private static func shouldNotify(
        previous: NotificationRecord?,
        level: NotificationLevel,
        settings: AppSettings,
        now: Date
    ) -> Bool {
        guard level == .warning || level == .critical else { return false }
        if previous?.lastNotifiedLevel == level {
            return false
        }
        if previous?.lastNotifiedLevel == .warning && level == .critical {
            return true
        }
        return previous?.lastNotifiedLevel == nil
    }

    private static func recoveredAt(
        previous: NotificationRecord?,
        level: NotificationLevel,
        settings: AppSettings,
        now: Date
    ) -> Date? {
        if level == .healthy { return now }
        return previous?.recoveredAt
    }

    private static func normalizedWindowKey(_ windowKey: String) -> String {
        if windowKey.contains("300m") { return "rolling_5h" }
        if windowKey.contains("10080m") || windowKey.contains("seven_day") { return "rolling_7d" }
        return windowKey
    }

    private static func intent(provider: CachedProviderID, level: NotificationLevel, snapshot: UsageSnapshot) -> NotificationIntent {
        let percent = level == .critical ? "10%" : "20%"
        let title = "\(provider.displayName) is below \(percent) remaining"
        let provenance: String = snapshot.confidence == "verified"
            ? "Verified from local \(provider.displayName) usage status."
            : "Based on observed local \(provider.displayName) status."
        return NotificationIntent(
            id: "\(provider.rawValue).\(snapshot.poolKey).\(snapshot.windowKey).\(level.rawValue)",
            provider: provider,
            level: level,
            title: title,
            body: "\(title). \(provenance)"
        )
    }
}
```

- [ ] **Step 4: Run focused tests**

```bash
cd apps/mac && swift test --filter NotificationEvaluatorTests
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/Notifications/NotificationEvaluator.swift \
  apps/mac/Tests/WhatTheTokenMacTests/Notifications/NotificationEvaluatorTests.swift
git commit -m "feat(mac): add notification evaluator"
```

## Task 6: Add Notification Delivery Boundary

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/Notifications/NotificationDelivery.swift`
- Create: `apps/mac/Tests/WhatTheTokenMacTests/Notifications/NotificationDeliveryTests.swift`

- [ ] **Step 1: Write failing delivery tests**

Create `apps/mac/Tests/WhatTheTokenMacTests/Notifications/NotificationDeliveryTests.swift`:

```swift
import Testing
@testable import WhatTheTokenMac

@Suite struct NotificationDeliveryTests {
    @Test func recordingDeliveryRequestsPermissionOnlyWhenAsked() async {
        let delivery = RecordingNotificationDelivery(permissionResult: .granted)

        #expect(await delivery.authorizationStatus() == .notDetermined)
        #expect(await delivery.requestAuthorization() == .granted)
        #expect(await delivery.authorizationStatus() == .granted)
    }

    @Test func recordingDeliveryRecordsDeliveredIntents() async {
        let delivery = RecordingNotificationDelivery(permissionResult: .granted)
        let intent = NotificationIntent(
            id: "test",
            provider: .claude,
            level: .warning,
            title: "Claude Code is below 20% remaining",
            body: "Claude Code is below 20% remaining. Verified from local Claude Code usage status."
        )

        await delivery.deliver([intent])

        #expect(await delivery.deliveredIntents == [intent])
    }
}
```

- [ ] **Step 2: Run failing tests**

```bash
cd apps/mac && swift test --filter NotificationDeliveryTests
```

Expected: build fails because delivery types do not exist.

- [ ] **Step 3: Implement delivery boundary**

Create `apps/mac/Sources/WhatTheTokenMac/Notifications/NotificationDelivery.swift`:

```swift
import Foundation
import UserNotifications

enum NotificationAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case denied
    case granted
}

protocol NotificationDelivery: Sendable {
    func authorizationStatus() async -> NotificationAuthorizationStatus
    func requestAuthorization() async -> NotificationAuthorizationStatus
    func deliver(_ intents: [NotificationIntent]) async
}

actor RecordingNotificationDelivery: NotificationDelivery {
    private let permissionResult: NotificationAuthorizationStatus
    private var status: NotificationAuthorizationStatus = .notDetermined
    private var storedDeliveredIntents: [NotificationIntent] = []

    init(permissionResult: NotificationAuthorizationStatus) {
        self.permissionResult = permissionResult
    }

    var deliveredIntents: [NotificationIntent] {
        storedDeliveredIntents
    }

    func authorizationStatus() async -> NotificationAuthorizationStatus {
        status
    }

    func requestAuthorization() async -> NotificationAuthorizationStatus {
        status = permissionResult
        return status
    }

    func deliver(_ intents: [NotificationIntent]) async {
        storedDeliveredIntents.append(contentsOf: intents)
    }
}

struct UserNotificationDelivery: NotificationDelivery {
    func authorizationStatus() async -> NotificationAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .granted
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    func requestAuthorization() async -> NotificationAuthorizationStatus {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            return granted ? .granted : .denied
        } catch {
            return .denied
        }
    }

    func deliver(_ intents: [NotificationIntent]) async {
        for intent in intents {
            let content = UNMutableNotificationContent()
            content.title = intent.title
            content.body = intent.body
            content.sound = .default
            let request = UNNotificationRequest(identifier: intent.id, content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}
```

- [ ] **Step 4: Run focused tests**

```bash
cd apps/mac && swift test --filter NotificationDeliveryTests
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/Notifications/NotificationDelivery.swift \
  apps/mac/Tests/WhatTheTokenMacTests/Notifications/NotificationDeliveryTests.swift
git commit -m "feat(mac): add local notification delivery"
```

## Task 7: Wire Notification Evaluation Into Refresh

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/AppModel.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift`

- [ ] **Step 1: Write failing integration tests**

Append to `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift`:

```swift
@MainActor
@Test func successfulRefreshEvaluatesAndDeliversNotifications() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    settings.notifications.isEnabled = true
    settings.notifications.providerAlerts.claudeCode.isEnabled = true
    let delivery = RecordingNotificationDelivery(permissionResult: .granted)
    let vm = StatusViewModel(
        settings: settings,
        claudeRefresher: FixtureClaudeRefresher(snapshots: [UsageSnapshotFixture.claudeIncludedSample(remaining: 8, utilization: 0.92)]),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        notificationStateStore: InMemoryNotificationStateStore(),
        notificationDelivery: delivery
    )

    await vm.refreshAll(reason: .manual)

    #expect(await delivery.deliveredIntents.count == 1)
    #expect(await delivery.deliveredIntents.first?.level == .critical)
}

@MainActor
@Test func loadPersistedStateSuppressesNotificationsWhenNotificationStateDecodeFails() async {
    var settings = AppSettings.defaults
    settings.connectors.codex.isEnabled = true
    settings.notifications.isEnabled = true
    settings.notifications.providerAlerts.codex.isEnabled = true
    var cache = SnapshotCache.empty
    cache.replaceSnapshots([UsageSnapshotFixture.codexIncludedSample(remaining: 8, utilization: 0.92)], for: .codex, at: Date())
    let delivery = RecordingNotificationDelivery(permissionResult: .granted)
    let vm = StatusViewModel(
        settingsStore: InMemoryAppSettingsStore(data: try! JSONEncoder.prettyStable.encode(settings)),
        cacheStore: InMemorySnapshotCacheStore(data: try! JSONEncoder.cacheEncoder.encode(cache)),
        notificationStateStore: InMemoryNotificationStateStore(data: Data("bad json".utf8)),
        notificationDelivery: delivery
    )

    await vm.loadPersistedState()

    #expect(await delivery.deliveredIntents.isEmpty)
}
```

Add this test helper to `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelFakes.swift`:

```swift
struct FixtureClaudeRefresher: ClaudeConnectorRefreshing {
    let snapshots: [UsageSnapshot]

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
```

- [ ] **Step 2: Run failing integration tests**

```bash
cd apps/mac && swift test --filter StatusViewModel
```

Expected: build fails because `StatusViewModel` has no notification state/delivery initializer parameters.

- [ ] **Step 3: Inject notification state and delivery**

In `StatusViewModel`, add stored properties:

```swift
private var notificationState: NotificationState
private let notificationStateStore: NotificationStateStore
private let notificationDelivery: NotificationDelivery
private var suppressCacheLoadNotifications = false
```

Add initializer parameters with safe defaults:

```swift
notificationState: NotificationState = .empty,
notificationStateStore: NotificationStateStore = InMemoryNotificationStateStore(),
notificationDelivery: NotificationDelivery = RecordingNotificationDelivery(permissionResult: .denied),
```

Set stored properties in `init`.

- [ ] **Step 4: Load notification state and suppress unsafe cache-load delivery**

In `loadPersistedState()`, after loading cache:

```swift
notificationState = await notificationStateStore.load()
suppressCacheLoadNotifications = await notificationStateStore.didFallbackOnLoad
```

After `applyConnectorStatesFromSettings()`, evaluate cache with:

```swift
await evaluateNotifications(suppressDelivery: true)
```

This intentionally suppresses delivery on cache load while still rebuilding state.

- [ ] **Step 5: Evaluate notifications after successful refresh**

Add private method:

```swift
private func evaluateNotifications(suppressDelivery: Bool) async {
    let result = NotificationEvaluator.evaluate(
        snapshots: snapshots,
        settings: settings,
        state: notificationState,
        now: now(),
        suppressDelivery: suppressDelivery || suppressCacheLoadNotifications
    )
    notificationState = result.state
    _ = await notificationStateStore.save(result.state)
    if !result.intents.isEmpty {
        await notificationDelivery.deliver(result.intents)
    }
    suppressCacheLoadNotifications = false
}
```

Call this after successful Claude and Codex refresh cache saves:

```swift
await evaluateNotifications(suppressDelivery: false)
```

- [ ] **Step 6: Wire live stores in `AppModel` and `StatusViewModel.live`**

Update `StatusViewModel.live` signature:

```swift
static func live(
    settingsStore: AppSettingsStore = InMemoryAppSettingsStore(),
    cacheStore: SnapshotCacheStore = InMemorySnapshotCacheStore(),
    notificationStateStore: NotificationStateStore = InMemoryNotificationStateStore(),
    notificationDelivery: NotificationDelivery = UserNotificationDelivery()
) -> StatusViewModel
```

Pass the new arguments into `StatusViewModel(...)`.

In `AppModel.live()`, pass:

```swift
notificationStateStore: notificationStateStore,
notificationDelivery: UserNotificationDelivery()
```

- [ ] **Step 7: Run focused tests**

```bash
cd apps/mac && swift test --filter StatusViewModel
```

Expected: tests pass.

- [ ] **Step 8: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift \
  apps/mac/Sources/WhatTheTokenMac/AppModel.swift \
  apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift \
  apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelFakes.swift
git commit -m "feat(mac): wire notification evaluation into refresh"
```

## Task 8: Add Notification Permission And Settings UI

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/Settings/ConnectorActionTitle.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/Settings/ConnectorRowView.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/Settings/ConnectorsView.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/Presentation/ConnectorActionTitleTests.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift`

- [ ] **Step 1: Add failing action-title tests**

Update `apps/mac/Tests/WhatTheTokenMacTests/Presentation/ConnectorActionTitleTests.swift`:

```swift
@Test func connectorConnectionActionTitleNamesPauseForEnabledActiveProviders() {
    #expect(connectorConnectionActionTitle(for: .claude, isEnabled: true, isPaused: false) == "Pause Claude Code")
    #expect(connectorConnectionActionTitle(for: .codex, isEnabled: true, isPaused: false) == "Pause Codex")
}

@Test func connectorConnectionActionTitleNamesResumeForEnabledPausedProviders() {
    #expect(connectorConnectionActionTitle(for: .claude, isEnabled: true, isPaused: true) == "Resume Claude Code")
    #expect(connectorConnectionActionTitle(for: .codex, isEnabled: true, isPaused: true) == "Resume Codex")
}
```

Replace existing calls to `connectorConnectionActionTitle(for:isEnabled:)` with the new `isPaused:` argument.

- [ ] **Step 2: Add failing permission-action test**

Append to `StatusViewModelTests.swift`:

```swift
@MainActor
@Test func enableNotificationsRequestsPermissionBeforeSavingEnabledState() async {
    let delivery = RecordingNotificationDelivery(permissionResult: .granted)
    let store = InMemoryAppSettingsStore()
    let vm = StatusViewModel(settingsStore: store, notificationDelivery: delivery)

    let result = await vm.setNotificationsEnabled(true)

    #expect(result == .granted)
    #expect(vm.settings.notifications.isEnabled == true)
}

@MainActor
@Test func deniedNotificationPermissionKeepsNotificationsDisabled() async {
    let delivery = RecordingNotificationDelivery(permissionResult: .denied)
    let vm = StatusViewModel(notificationDelivery: delivery)

    let result = await vm.setNotificationsEnabled(true)

    #expect(result == .denied)
    #expect(vm.settings.notifications.isEnabled == false)
}
```

- [ ] **Step 3: Run failing tests**

```bash
cd apps/mac && swift test --filter ConnectorActionTitleTests
cd apps/mac && swift test --filter StatusViewModel
```

Expected: build fails because signatures and `setNotificationsEnabled` do not exist.

- [ ] **Step 4: Update action-title helper**

In `ConnectorActionTitle.swift`, replace:

```swift
func connectorConnectionActionTitle(for provider: CachedProviderID, isEnabled: Bool) -> String
```

with:

```swift
func connectorConnectionActionTitle(for provider: CachedProviderID, isEnabled: Bool, isPaused: Bool) -> String {
    if isEnabled && isPaused {
        return "Resume \(provider.displayName)"
    }
    if isEnabled {
        return "Pause \(provider.displayName)"
    }
    return "Connect \(provider.displayName)"
}

func connectorDisconnectActionTitle(for provider: CachedProviderID) -> String {
    "Disconnect \(provider.displayName)..."
}
```

- [ ] **Step 5: Add notification settings method**

In `StatusViewModel`, add:

```swift
@discardableResult
func setNotificationsEnabled(_ enabled: Bool) async -> NotificationAuthorizationStatus {
    if enabled {
        let status = await notificationDelivery.requestAuthorization()
        guard status == .granted else {
            var disabled = settings
            disabled.notifications.isEnabled = false
            _ = await saveSettings(disabled)
            return status
        }
    }

    var nextSettings = settings
    nextSettings.notifications.isEnabled = enabled
    _ = await saveSettings(nextSettings)
    return enabled ? .granted : .denied
}
```

- [ ] **Step 6: Update settings view**

In `ConnectorsView`, change each connector row to use pause/resume for the primary connection action and a separate disconnect action. Extend `ConnectorRowView` with:

```swift
let disconnectActionTitle: String?
let disconnectAction: (() -> Void)?
```

Render the disconnect button below pause/resume:

```swift
if let disconnectActionTitle, let disconnectAction {
    Button(disconnectActionTitle, role: .destructive, action: disconnectAction)
}
```

Add an `Alerts` section:

```swift
Section("Alerts") {
    Toggle("Notify me before quota runs low", isOn: Binding(
        get: { viewModel.settings.notifications.isEnabled },
        set: { enabled in
            let viewModel = self.viewModel
            Task { _ = await viewModel.setNotificationsEnabled(enabled) }
        }
    ))

    Stepper(
        "Warning: \(Int(viewModel.settings.notifications.warningThreshold * 100))%",
        value: Binding(
            get: { viewModel.settings.notifications.warningThreshold },
            set: { value in
                var settings = viewModel.settings
                settings.notifications.warningThreshold = max(value, settings.notifications.criticalThreshold + 0.01)
                Task { await viewModel.saveSettings(settings) }
            }
        ),
        in: 0.10...0.50,
        step: 0.05
    )

    Stepper(
        "Critical: \(Int(viewModel.settings.notifications.criticalThreshold * 100))%",
        value: Binding(
            get: { viewModel.settings.notifications.criticalThreshold },
            set: { value in
                var settings = viewModel.settings
                settings.notifications.criticalThreshold = min(value, settings.notifications.warningThreshold - 0.01)
                Task { await viewModel.saveSettings(settings) }
            }
        ),
        in: 0.01...0.25,
        step: 0.01
    )
}
```

- [ ] **Step 7: Run focused tests**

```bash
cd apps/mac && swift test --filter ConnectorActionTitleTests
cd apps/mac && swift test --filter StatusViewModel
```

Expected: tests pass.

- [ ] **Step 8: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift \
  apps/mac/Sources/WhatTheTokenMac/Views/Settings/ConnectorActionTitle.swift \
  apps/mac/Sources/WhatTheTokenMac/Views/Settings/ConnectorRowView.swift \
  apps/mac/Sources/WhatTheTokenMac/Views/Settings/ConnectorsView.swift \
  apps/mac/Tests/WhatTheTokenMacTests/Presentation/ConnectorActionTitleTests.swift \
  apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift
git commit -m "feat(mac): add notification settings UI"
```

## Task 9: Debounce Popover Refresh After Background Refresh

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/PopoverRefreshControllerTests.swift`

- [ ] **Step 1: Add failing debounce test**

Append to `PopoverRefreshControllerTests.swift`:

```swift
@MainActor
@Test func popoverOpenSkipsRefreshAfterRecentBackgroundRefresh() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    var current = Date(timeIntervalSince1970: 1_000)
    let counter = Counter()
    let vm = StatusViewModel(
        settings: settings,
        claudeRefresher: SlowClaudeRefresher(counter: counter),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        now: { current }
    )
    await vm.refreshAll(reason: .timerTick)
    current = Date(timeIntervalSince1970: 1_030)
    let controller = PopoverRefreshController(viewModel: vm, sleeper: { _ in })

    controller.popoverDidOpen()
    for _ in 0..<20 { await Task.yield() }

    #expect(counter.value == 1)
}
```

- [ ] **Step 2: Run failing popover tests**

```bash
cd apps/mac && swift test --filter PopoverRefreshControllerTests
```

Expected: test fails because popover-open refresh runs again.

- [ ] **Step 3: Add recent background refresh debounce**

In `StatusViewModel`, add:

```swift
private var lastBackgroundRefreshAtByProvider: [CachedProviderID: Date] = [:]
```

When a provider succeeds for `.timerTick`, record:

```swift
if reason == .timerTick {
    lastBackgroundRefreshAtByProvider[.claude] = now()
}
```

and similarly for Codex.

Before automatic popover refresh, skip if recent:

```swift
private func recentlyBackgroundRefreshed(_ provider: CachedProviderID) -> Bool {
    guard let last = lastBackgroundRefreshAtByProvider[provider] else { return false }
    return now().timeIntervalSince(last) < 60
}
```

In each provider refresh, after the enabled/paused checks:

```swift
if reason == .popoverOpened && recentlyBackgroundRefreshed(.claude) { return }
```

and similarly for Codex.

- [ ] **Step 4: Run focused tests**

```bash
cd apps/mac && swift test --filter PopoverRefreshControllerTests
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift \
  apps/mac/Tests/WhatTheTokenMacTests/PopoverRefreshControllerTests.swift
git commit -m "feat(mac): debounce popover refresh after background refresh"
```

## Task 10: Add Menu Bar Critical Indicator

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/PopoverChromeState.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/WhatTheTokenApp.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/Presentation/PopoverChromeStateTests.swift`

- [ ] **Step 1: Add failing critical indicator test**

Append to `PopoverChromeStateTests.swift`:

```swift
@MainActor
@Test func menuBarTitleReflectsCriticalProvider() {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    let vm = StatusViewModel(
        snapshots: [UsageSnapshotFixture.claudeIncludedSample(remaining: 5, utilization: 0.95)],
        settings: settings,
        connectorState: .connected
    )

    #expect(PopoverChromeState.menuBarTitle(viewModel: vm) == "WhatTheToken - Critical")
    #expect(PopoverChromeState.menuBarSystemImage(viewModel: vm) == "gauge.with.dots.needle.67percent")
}
```

- [ ] **Step 2: Run failing chrome tests**

```bash
cd apps/mac && swift test --filter PopoverChromeStateTests
```

Expected: build fails because the menu bar helpers do not exist.

- [ ] **Step 3: Implement modest menu bar state helper**

In `PopoverChromeState.swift`, add:

```swift
@MainActor
static func menuBarTitle(viewModel: StatusViewModel) -> String {
    hasCriticalProvider(viewModel: viewModel) ? "WhatTheToken - Critical" : "WhatTheToken"
}

@MainActor
static func menuBarSystemImage(viewModel: StatusViewModel) -> String {
    hasCriticalProvider(viewModel: viewModel) ? "gauge.with.dots.needle.67percent" : "gauge"
}

@MainActor
private static func hasCriticalProvider(viewModel: StatusViewModel) -> Bool {
    let claude = ProviderAvailability.from(
        snapshots: viewModel.snapshots.filter(CachedProviderID.claude.snapshotPredicate),
        tab: .claude
    )
    let codex = ProviderAvailability.from(
        snapshots: viewModel.snapshots.filter(CachedProviderID.codex.snapshotPredicate),
        tab: .codex
    )
    return claude == .critical || codex == .critical
}
```

- [ ] **Step 4: Wire `WhatTheTokenApp` menu bar label**

Replace:

```swift
MenuBarExtra("WhatTheToken", systemImage: "gauge") {
```

with:

```swift
MenuBarExtra(
    PopoverChromeState.menuBarTitle(viewModel: app.viewModel),
    systemImage: PopoverChromeState.menuBarSystemImage(viewModel: app.viewModel)
) {
```

- [ ] **Step 5: Run focused tests**

```bash
cd apps/mac && swift test --filter PopoverChromeStateTests
```

Expected: tests pass. If `gauge.with.dots.needle.67percent` is unavailable on macOS 14, use `exclamationmark.triangle` for critical and update the test.

- [ ] **Step 6: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/PopoverChromeState.swift \
  apps/mac/Sources/WhatTheTokenMac/WhatTheTokenApp.swift \
  apps/mac/Tests/WhatTheTokenMacTests/Presentation/PopoverChromeStateTests.swift
git commit -m "feat(mac): expose critical menu bar state"
```

## Task 11: Full Verification And Manual Smoke

**Files:**
- Read: `docs/superpowers/specs/2026-05-08-notifications-background-freshness-design.md`
- Run: full test commands

- [ ] **Step 1: Run Swift tests**

```bash
cd apps/mac && swift test
```

Expected: all Swift tests pass.

- [ ] **Step 2: Run TypeScript core tests**

```bash
pnpm --filter @whatthetoken/core test
```

Expected: 4 core test files pass.

- [ ] **Step 3: Check whitespace**

```bash
git diff --check
```

Expected: no output.

- [ ] **Step 4: Sensitive-data scan**

```bash
LC_ALL=C rg -in '(access[_-]?token|api[_-]?key|authorization[[:space:]]*:|bearer [A-Za-z0-9._-]{12,}|cookie[[:space:]]*:|set-cookie[[:space:]]*:|sk-[A-Za-z0-9_-]{10,}|xox[baprs]-|ghp_[A-Za-z0-9]|github_pat_)' apps/mac/Sources apps/mac/Tests docs/superpowers/specs/2026-05-08-notifications-background-freshness-design.md docs/superpowers/plans/2026-05-08-notifications-background-freshness.md
```

Expected: matches are limited to deny-list/privacy wording or synthetic test strings; no real secrets.

- [ ] **Step 5: Manual app smoke**

```bash
cd apps/mac && swift run WhatTheTokenMac
```

Manual checks:

- Settings opens.
- Refresh section shows background refresh copy, not popover-only copy.
- Enabling notifications prompts only after toggling notifications on.
- Pausing a connector keeps cached rows visible and stops refresh.
- Disconnecting a paused connector asks for confirmation and removes cached rows.
- With background refresh enabled, refresh occurs after the configured interval even if the popover is closed.
- Reopening the popover within 60 seconds of a background refresh does not immediately refresh again.
- Fixture/test states below 20% and 10% produce warning/critical notification intents in tests.

- [ ] **Step 6: Commit verification doc nits if needed**

If manual smoke reveals copy drift, patch only the affected copy/tests and commit:

```bash
git add apps/mac/Sources apps/mac/Tests
git commit -m "fix(mac): polish alert refresh copy"
```

If no changes are needed, do not create an empty commit.
