# Consent, Persistence, And Refresh Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist connector consent and sanitized last-known-good usage, refresh enabled connectors safely, and keep visible values stable during refresh with a thin progress indicator.

**Architecture:** Add small Codable settings/cache models and store protocols, wire them into `StatusViewModel`, and keep provider connectors focused on fetching sanitized snapshots. Refresh semantics live in `StatusViewModel`; `PopoverRefreshController` handles popover lifecycle and optional timer scheduling; pure presentation models expose initial-loading versus background-refresh states for no-flicker SwiftUI rendering.

**Tech Stack:** Swift 6, SwiftUI, Observation, Foundation JSONEncoder/JSONDecoder, swift-testing.

---

## File Structure

- Create: `apps/mac/Sources/WhatTheTokenMac/Storage/AppSettings.swift`
  - Versioned local settings model, defaults, schema validation.
- Create: `apps/mac/Sources/WhatTheTokenMac/Storage/AppSettingsStore.swift`
  - Store protocol, JSON file store, in-memory test store.
- Create: `apps/mac/Sources/WhatTheTokenMac/Storage/SnapshotCache.swift`
  - Versioned sanitized cache model, provider metadata, stale evaluation.
- Create: `apps/mac/Sources/WhatTheTokenMac/Storage/SnapshotCacheStore.swift`
  - Store protocol, JSON file store, in-memory test store.
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift`
  - Load settings/cache, persist consent/cache changes, refresh only enabled connectors, maintain per-provider refresh/backoff state.
- Modify: `apps/mac/Sources/WhatTheTokenMac/AppModel.swift`
  - Construct live stores and inject them into `StatusViewModel`.
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/PopoverRefreshController.swift`
  - Replace hard-coded 30s timer with persisted auto-refresh preference; keep popover-open one-shot refresh.
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/ProviderTabModel.swift`
  - Replace `.checking` presentation body with `.loading` and `isRefreshing` flags.
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/PopoverFooterState.swift`
  - Scope refreshing/can-refresh state to the selected provider and expose updating copy.
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/Popover/ProviderTabContentView.swift`
  - Render thin progress line without replacing rows when snapshots exist.
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/Popover/PopoverFooterView.swift`
  - Show `Updating values...` while selected provider refreshes.
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/Settings/ConnectorsView.swift`
  - Add connector enable/disable/disconnect and auto-refresh settings.
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/Settings/ConnectorRowView.swift`
  - Render consent copy and disconnect affordance.
- Test: `apps/mac/Tests/WhatTheTokenMacTests/Storage/AppSettingsTests.swift`
- Test: `apps/mac/Tests/WhatTheTokenMacTests/Storage/SnapshotCacheTests.swift`
- Test: existing `StatusViewModelTests.swift`, connector tests, `PopoverRefreshControllerTests.swift`, `Presentation/ProviderTabModelTests.swift`, `Presentation/PopoverFooterStateTests.swift`

## Conventions

Run focused Swift tests from `apps/mac`:

```bash
swift test --filter AppSettingsTests
swift test --filter SnapshotCacheTests
swift test --filter StatusViewModel
swift test --filter PopoverRefreshControllerTests
swift test --filter ProviderTabModelTests
swift test --filter PopoverFooterStateTests
```

Run full verification:

```bash
cd apps/mac && swift test
pnpm --filter @whatthetoken/core test
```

Use commit messages:

- `feat(mac): add persisted app settings`
- `feat(mac): add sanitized snapshot cache`
- `feat(mac): persist connector consent`
- `feat(mac): add refresh backoff`
- `fix(mac): keep values visible during refresh`
- `feat(mac): add refresh settings controls`

## Task 1: Add Versioned App Settings

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/Storage/AppSettings.swift`
- Create: `apps/mac/Sources/WhatTheTokenMac/Storage/AppSettingsStore.swift`
- Create: `apps/mac/Tests/WhatTheTokenMacTests/Storage/AppSettingsTests.swift`

- [ ] **Step 1: Write failing settings tests**

Create `apps/mac/Tests/WhatTheTokenMacTests/Storage/AppSettingsTests.swift`:

```swift
import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct AppSettingsTests {
    @Test func defaultsKeepConnectorsAndAutoRefreshDisabled() {
        let settings = AppSettings.defaults

        #expect(settings.schemaVersion == 1)
        #expect(settings.connectors.claudeCode.isEnabled == false)
        #expect(settings.connectors.codex.isEnabled == false)
        #expect(settings.refresh.autoRefreshEnabled == false)
        #expect(settings.refresh.intervalSeconds == 300)
        #expect(settings.notifications.isEnabled == false)
        #expect(settings.menuBar.displayMode == .statusIcon)
    }

    @Test func roundTripPreservesSettings() throws {
        var settings = AppSettings.defaults
        settings.connectors.claudeCode.isEnabled = true
        settings.refresh.autoRefreshEnabled = true
        settings.refresh.intervalSeconds = 600

        let data = try JSONEncoder().encode(settings)
        let decoded = try AppSettings.decodeValidated(from: data)

        #expect(decoded == settings)
    }

    @Test func unknownSchemaVersionFallsBackThroughStoreLoad() async {
        let data = #"{"schemaVersion":999}"#.data(using: .utf8)!
        let store = InMemoryAppSettingsStore(data: data)

        let loaded = await store.load()

        #expect(loaded == .defaults)
    }

    @Test func invalidJSONFallsBackThroughStoreLoad() async {
        let store = InMemoryAppSettingsStore(data: Data("not json".utf8))

        let loaded = await store.load()

        #expect(loaded == .defaults)
    }

    @Test func encodedSettingsDoNotContainSensitiveKeys() throws {
        var settings = AppSettings.defaults
        settings.connectors.codex.isEnabled = true

        let data = try JSONEncoder().encode(settings)
        let json = String(decoding: data, as: UTF8.self)

        #expect(!json.contains("token"))
        #expect(!json.contains("cookie"))
        #expect(!json.contains("authHeader"))
        #expect(!json.contains("session"))
        #expect(!json.contains("prompt"))
        #expect(!json.contains("response"))
    }

    @Test func memoryStorePersistsLatestValue() async {
        let store = InMemoryAppSettingsStore()
        var settings = AppSettings.defaults
        settings.connectors.claudeCode.isEnabled = true

        await store.save(settings)
        let loaded = await store.load()

        #expect(loaded.connectors.claudeCode.isEnabled == true)
    }
}
```

- [ ] **Step 2: Run the failing settings tests**

```bash
cd apps/mac && swift test --filter AppSettingsTests
```

Expected: build fails because `AppSettings`, `InMemoryAppSettingsStore`, and related store types do not exist.

- [ ] **Step 3: Implement `AppSettings`**

Create `apps/mac/Sources/WhatTheTokenMac/Storage/AppSettings.swift`:

```swift
import Foundation

struct AppSettings: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var connectors: ConnectorSettings
    var refresh: RefreshSettings
    var notifications: NotificationSettings
    var menuBar: MenuBarSettings

    static let defaults = AppSettings(
        schemaVersion: currentSchemaVersion,
        connectors: ConnectorSettings(
            claudeCode: ConnectorConsentSettings(isEnabled: false),
            codex: ConnectorConsentSettings(isEnabled: false)
        ),
        refresh: RefreshSettings(autoRefreshEnabled: false, intervalSeconds: 300),
        notifications: NotificationSettings(isEnabled: false, lowThreshold: 0.30, criticalThreshold: 0.10),
        menuBar: MenuBarSettings(displayMode: .statusIcon)
    )

    static func decodeValidated(from data: Data) throws -> AppSettings {
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        guard decoded.schemaVersion == currentSchemaVersion else {
            throw AppSettingsDecodeError.unsupportedSchemaVersion(decoded.schemaVersion)
        }
        return decoded
    }
}

struct ConnectorSettings: Codable, Equatable, Sendable {
    var claudeCode: ConnectorConsentSettings
    var codex: ConnectorConsentSettings
}

struct ConnectorConsentSettings: Codable, Equatable, Sendable {
    var isEnabled: Bool
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
    var lowThreshold: Double
    var criticalThreshold: Double
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

- [ ] **Step 4: Implement settings stores**

Create `apps/mac/Sources/WhatTheTokenMac/Storage/AppSettingsStore.swift`:

```swift
import Foundation

protocol AppSettingsStore: Sendable {
    func load() async -> AppSettings
    func save(_ settings: AppSettings) async
}

struct JSONFileAppSettingsStore: AppSettingsStore {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    func load() async -> AppSettings {
        do {
            let data = try Data(contentsOf: url)
            return try AppSettings.decodeValidated(from: data)
        } catch {
            return .defaults
        }
    }

    func save(_ settings: AppSettings) async {
        let temporaryURL = url
            .deletingLastPathComponent()
            .appendingPathComponent("\(url.lastPathComponent).\(UUID().uuidString).tmp")
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder.prettyStable.encode(settings)
            try data.write(to: temporaryURL, options: [.atomic])
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: temporaryURL)
            } else {
                try FileManager.default.moveItem(at: temporaryURL, to: url)
            }
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
        }
    }
}

final class InMemoryAppSettingsStore: AppSettingsStore, @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?

    init(data: Data? = nil) {
        self.data = data
    }

    func load() async -> AppSettings {
        lock.withLock {
            guard let data else { return .defaults }
            return (try? AppSettings.decodeValidated(from: data)) ?? .defaults
        }
    }

    func save(_ settings: AppSettings) async {
        let encoded = try? JSONEncoder.prettyStable.encode(settings)
        lock.withLock {
            data = encoded
        }
    }
}

extension JSONEncoder {
    static var prettyStable: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
```

- [ ] **Step 5: Run settings tests**

```bash
cd apps/mac && swift test --filter AppSettingsTests
```

Expected: pass.

- [ ] **Step 6: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/Storage/AppSettings.swift \
  apps/mac/Sources/WhatTheTokenMac/Storage/AppSettingsStore.swift \
  apps/mac/Tests/WhatTheTokenMacTests/Storage/AppSettingsTests.swift
git commit -m "feat(mac): add persisted app settings"
```

## Task 2: Add Sanitized Snapshot Cache And Staleness Evaluation

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/Storage/SnapshotCache.swift`
- Create: `apps/mac/Sources/WhatTheTokenMac/Storage/SnapshotCacheStore.swift`
- Create: `apps/mac/Tests/WhatTheTokenMacTests/Storage/SnapshotCacheTests.swift`

- [ ] **Step 1: Write failing cache tests**

Create `apps/mac/Tests/WhatTheTokenMacTests/Storage/SnapshotCacheTests.swift`:

```swift
import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct SnapshotCacheTests {
    @Test func emptyCacheUsesCurrentSchema() {
        #expect(SnapshotCache.empty.schemaVersion == 1)
        #expect(SnapshotCache.empty.snapshots.isEmpty)
        #expect(SnapshotCache.empty.lastErrorByProvider.isEmpty)
    }

    @Test func roundTripPreservesSanitizedSnapshotsAndBackoff() throws {
        var cache = SnapshotCache.empty
        let provider = CachedProviderID.claude
        let updatedAt = Date(timeIntervalSince1970: 1_000)
        cache.replaceSnapshots([UsageSnapshotFixture.claudeSample()], for: provider, at: updatedAt)
        cache.recordFailure(
            for: provider,
            code: .network,
            message: "Claude Code usage could not be refreshed",
            now: updatedAt
        )

        let data = try JSONEncoder.cacheEncoder.encode(cache)
        let decoded = try SnapshotCache.decodeValidated(from: data)

        #expect(decoded.snapshots.count == 1)
        #expect(decoded.lastSuccessfulRefreshAtByProvider[provider.rawValue] == updatedAt)
        #expect(decoded.lastErrorByProvider[provider.rawValue]?.consecutiveFailureCount == 1)
        #expect(decoded.lastErrorByProvider[provider.rawValue]?.nextAutomaticRefreshAt == Date(timeIntervalSince1970: 1_300))
    }

    @Test func unknownSchemaFallsBackThroughStoreLoad() async {
        let data = #"{"schemaVersion":999}"#.data(using: .utf8)!
        let store = InMemorySnapshotCacheStore(data: data)

        let loaded = await store.load()

        #expect(loaded == .empty)
    }

    @Test func replaceSnapshotsOnlyReplacesMatchingProvider() {
        var cache = SnapshotCache.empty
        cache.replaceSnapshots([UsageSnapshotFixture.claudeSample()], for: .claude, at: Date(timeIntervalSince1970: 1))
        cache.replaceSnapshots([UsageSnapshotFixture.codexSample()], for: .codex, at: Date(timeIntervalSince1970: 2))

        let replacement = UsageSnapshotFixture.claudeLowSample()
        cache.replaceSnapshots([replacement], for: .claude, at: Date(timeIntervalSince1970: 3))

        #expect(cache.snapshots.map(\.id).sorted() == [replacement.id, UsageSnapshotFixture.codexSample().id].sorted())
    }

    @Test func removeSnapshotsClearsProviderOnly() {
        var cache = SnapshotCache.empty
        cache.replaceSnapshots([UsageSnapshotFixture.claudeSample()], for: .claude, at: Date(timeIntervalSince1970: 1))
        cache.replaceSnapshots([UsageSnapshotFixture.codexSample()], for: .codex, at: Date(timeIntervalSince1970: 2))

        cache.removeProvider(.claude)

        #expect(cache.snapshots.map(\.provider) == ["openai"])
        #expect(cache.lastSuccessfulRefreshAtByProvider[CachedProviderID.claude.rawValue] == nil)
    }

    @Test func staleEvaluationMarksExpiredSnapshots() {
        var cache = SnapshotCache.empty
        cache.replaceSnapshots([UsageSnapshotFixture.claudeSample()], for: .claude, at: Date(timeIntervalSince1970: 1))

        let stale = cache.snapshotsEvaluatingStaleness(
            now: ISO8601DateFormatter().date(from: "2026-05-07T01:01:00Z")!,
            staleAfterMinutes: 60
        )

        #expect(stale.first?.confidence == "stale")
        #expect(stale.first?.staleReason == "Last update was 61 minutes ago.")
    }

    @Test func cachedJSONDoesNotContainSensitiveKeys() throws {
        var cache = SnapshotCache.empty
        cache.replaceSnapshots([UsageSnapshotFixture.codexSample()], for: .codex, at: Date(timeIntervalSince1970: 1))

        let json = String(decoding: try JSONEncoder.cacheEncoder.encode(cache), as: UTF8.self)

        #expect(!json.contains("authHeader"))
        #expect(!json.contains("bearerToken"))
        #expect(!json.contains("sessionToken"))
        #expect(!json.contains("cookie"))
        #expect(!json.contains("prompt"))
        #expect(!json.contains("completion"))
        #expect(!json.contains("conversation"))
    }
}
```

- [ ] **Step 2: Run the failing cache tests**

```bash
cd apps/mac && swift test --filter SnapshotCacheTests
```

Expected: build fails because `SnapshotCache`, `CachedProviderID`, and stores do not exist.

- [ ] **Step 3: Implement cache model**

Create `apps/mac/Sources/WhatTheTokenMac/Storage/SnapshotCache.swift`:

```swift
import Foundation

enum CachedProviderID: String, Codable, Equatable, Sendable {
    case claude = "anthropic_claude_code"
    case codex = "openai_codex"

    var snapshotPredicate: @Sendable (UsageSnapshot) -> Bool {
        switch self {
        case .claude:
            return { $0.provider == "anthropic" && $0.product == "claude_code" }
        case .codex:
            return { $0.provider == "openai" && $0.product == "codex" }
        }
    }

    static func from(tab: ProviderTab) -> CachedProviderID {
        switch tab {
        case .claude: return .claude
        case .codex: return .codex
        }
    }
}

struct SnapshotCache: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var snapshots: [UsageSnapshot]
    var updatedAtByProvider: [String: Date]
    var lastSuccessfulRefreshAtByProvider: [String: Date]
    var lastErrorByProvider: [String: CachedProviderError]

    static let empty = SnapshotCache(
        schemaVersion: currentSchemaVersion,
        snapshots: [],
        updatedAtByProvider: [:],
        lastSuccessfulRefreshAtByProvider: [:],
        lastErrorByProvider: [:]
    )

    static func decodeValidated(from data: Data) throws -> SnapshotCache {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SnapshotCache.self, from: data)
        guard decoded.schemaVersion == currentSchemaVersion else {
            throw SnapshotCacheDecodeError.unsupportedSchemaVersion(decoded.schemaVersion)
        }
        return decoded
    }

    mutating func replaceSnapshots(_ replacement: [UsageSnapshot], for provider: CachedProviderID, at date: Date) {
        snapshots = snapshots.filter { !provider.snapshotPredicate($0) } + replacement
        updatedAtByProvider[provider.rawValue] = date
        lastSuccessfulRefreshAtByProvider[provider.rawValue] = date
        lastErrorByProvider[provider.rawValue] = nil
    }

    mutating func removeProvider(_ provider: CachedProviderID) {
        snapshots = snapshots.filter { !provider.snapshotPredicate($0) }
        updatedAtByProvider[provider.rawValue] = nil
        lastSuccessfulRefreshAtByProvider[provider.rawValue] = nil
        lastErrorByProvider[provider.rawValue] = nil
    }

    mutating func recordFailure(for provider: CachedProviderID, code: CachedProviderError.Code, message: String, now: Date) {
        let previousCount = lastErrorByProvider[provider.rawValue]?.consecutiveFailureCount ?? 0
        let nextCount = previousCount + 1
        let delay: TimeInterval
        switch nextCount {
        case 1: delay = 5 * 60
        case 2: delay = 15 * 60
        default: delay = 60 * 60
        }
        lastErrorByProvider[provider.rawValue] = CachedProviderError(
            code: code,
            message: message,
            consecutiveFailureCount: nextCount,
            nextAutomaticRefreshAt: now.addingTimeInterval(delay)
        )
    }

    func allowsAutomaticRefresh(for provider: CachedProviderID, now: Date) -> Bool {
        guard let next = lastErrorByProvider[provider.rawValue]?.nextAutomaticRefreshAt else { return true }
        return now >= next
    }

    func snapshotsEvaluatingStaleness(now: Date, staleAfterMinutes: Int = 60) -> [UsageSnapshot] {
        snapshots.map { $0.evaluatingStaleness(now: now, staleAfterMinutes: staleAfterMinutes) }
    }
}

struct CachedProviderError: Codable, Equatable, Sendable {
    enum Code: String, Codable, Equatable, Sendable {
        case network
        case schemaChanged
        case unavailable
    }

    var code: Code
    var message: String
    var consecutiveFailureCount: Int
    var nextAutomaticRefreshAt: Date
}

enum SnapshotCacheDecodeError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
}

extension UsageSnapshot {
    func evaluatingStaleness(now: Date, staleAfterMinutes: Int) -> UsageSnapshot {
        guard staleReason == nil else { return self }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]

        guard let updatedAt = fractional.date(from: lastUpdatedAt) ?? plain.date(from: lastUpdatedAt) else {
            return copy(confidence: "stale", staleReason: "Last update timestamp is invalid.")
        }

        let ageSeconds = now.timeIntervalSince(updatedAt)
        if ageSeconds < 0 {
            return copy(confidence: "stale", staleReason: "Last update timestamp is in the future.")
        }

        let ageMinutes = Int(ageSeconds / 60)
        if ageMinutes > staleAfterMinutes {
            return copy(confidence: "stale", staleReason: "Last update was \(ageMinutes) minutes ago.")
        }

        return self
    }

    func copy(confidence: String, staleReason: String?) -> UsageSnapshot {
        UsageSnapshot(
            id: id,
            userAccountId: userAccountId,
            provider: provider,
            product: product,
            surface: surface,
            poolKey: poolKey,
            windowKey: windowKey,
            unit: unit,
            used: used,
            limit: limit,
            remaining: remaining,
            utilization: utilization,
            resetAt: resetAt,
            lastUpdatedAt: lastUpdatedAt,
            confidence: confidence,
            undercountRisk: undercountRisk,
            staleReason: staleReason,
            display: display,
            source: source
        )
    }
}
```

- [ ] **Step 4: Implement cache store**

Create `apps/mac/Sources/WhatTheTokenMac/Storage/SnapshotCacheStore.swift`:

```swift
import Foundation

protocol SnapshotCacheStore: Sendable {
    func load() async -> SnapshotCache
    func save(_ cache: SnapshotCache) async
}

struct JSONFileSnapshotCacheStore: SnapshotCacheStore {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    func load() async -> SnapshotCache {
        do {
            let data = try Data(contentsOf: url)
            return try SnapshotCache.decodeValidated(from: data)
        } catch {
            return .empty
        }
    }

    func save(_ cache: SnapshotCache) async {
        let temporaryURL = url
            .deletingLastPathComponent()
            .appendingPathComponent("\(url.lastPathComponent).\(UUID().uuidString).tmp")
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder.cacheEncoder.encode(cache)
            try data.write(to: temporaryURL, options: [.atomic])
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: temporaryURL)
            } else {
                try FileManager.default.moveItem(at: temporaryURL, to: url)
            }
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
        }
    }
}

final class InMemorySnapshotCacheStore: SnapshotCacheStore, @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?

    init(data: Data? = nil) {
        self.data = data
    }

    func load() async -> SnapshotCache {
        lock.withLock {
            guard let data else { return .empty }
            return (try? SnapshotCache.decodeValidated(from: data)) ?? .empty
        }
    }

    func save(_ cache: SnapshotCache) async {
        let encoded = try? JSONEncoder.cacheEncoder.encode(cache)
        lock.withLock {
            data = encoded
        }
    }
}

extension JSONEncoder {
    static var cacheEncoder: JSONEncoder {
        let encoder = JSONEncoder.prettyStable
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
```

- [ ] **Step 5: Run cache tests**

```bash
cd apps/mac && swift test --filter SnapshotCacheTests
```

Expected: pass.

- [ ] **Step 6: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/Storage/SnapshotCache.swift \
  apps/mac/Sources/WhatTheTokenMac/Storage/SnapshotCacheStore.swift \
  apps/mac/Tests/WhatTheTokenMacTests/Storage/SnapshotCacheTests.swift
git commit -m "feat(mac): add sanitized snapshot cache"
```

## Task 3: Wire Settings And Cache Into `StatusViewModel`

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/AppModel.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelFakes.swift`

- [ ] **Step 1: Add failing view-model persistence tests**

Append to `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift`:

```swift
@MainActor
@Test func loadPersistedStateAppliesSettingsAndEnabledCachedSnapshots() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    var cache = SnapshotCache.empty
    cache.replaceSnapshots([UsageSnapshotFixture.claudeSample()], for: .claude, at: Date(timeIntervalSince1970: 1_000))

    let vm = StatusViewModel(
        settingsStore: InMemoryAppSettingsStore(data: try! JSONEncoder.prettyStable.encode(settings)),
        cacheStore: InMemorySnapshotCacheStore(data: try! JSONEncoder.cacheEncoder.encode(cache)),
        now: { ISO8601DateFormatter().date(from: "2026-05-07T00:10:00Z")! }
    )

    await vm.loadPersistedState()

    #expect(vm.settings.connectors.claudeCode.isEnabled == true)
    #expect(vm.connectorState == .connected)
    #expect(vm.snapshots.map(\.id) == [UsageSnapshotFixture.claudeSample().id])
}

@MainActor
@Test func loadPersistedStateDoesNotRenderDisabledProviderCache() async {
    var cache = SnapshotCache.empty
    cache.replaceSnapshots([UsageSnapshotFixture.codexSample()], for: .codex, at: Date(timeIntervalSince1970: 1_000))
    let vm = StatusViewModel(
        settingsStore: InMemoryAppSettingsStore(),
        cacheStore: InMemorySnapshotCacheStore(data: try! JSONEncoder.cacheEncoder.encode(cache))
    )

    await vm.loadPersistedState()

    #expect(vm.settings.connectors.codex.isEnabled == false)
    #expect(vm.snapshots.isEmpty)
    #expect(vm.codexConnectorState == .notConnected)
}

@MainActor
@Test func loadPersistedStateRestoresSanitizedErrorStateWithCachedSnapshots() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    var cache = SnapshotCache.empty
    cache.replaceSnapshots([UsageSnapshotFixture.claudeSample()], for: .claude, at: Date(timeIntervalSince1970: 1_000))
    cache.recordFailure(
        for: .claude,
        code: .network,
        message: "Claude Code usage could not be refreshed",
        now: Date(timeIntervalSince1970: 1_100)
    )
    let vm = StatusViewModel(
        settingsStore: InMemoryAppSettingsStore(data: try! JSONEncoder.prettyStable.encode(settings)),
        cacheStore: InMemorySnapshotCacheStore(data: try! JSONEncoder.cacheEncoder.encode(cache)),
        now: { Date(timeIntervalSince1970: 1_120) }
    )

    await vm.loadPersistedState()

    #expect(vm.connectorState == .networkError)
    #expect(vm.connectorStatusMessage == "Claude Code usage could not be refreshed")
    #expect(vm.snapshots.map(\.id) == [UsageSnapshotFixture.claudeSample().id])
}

@MainActor
@Test func setConnectorEnabledPersistsConsentWithoutRefreshing() async {
    let settingsStore = InMemoryAppSettingsStore()
    let refresher = RecordingClaudeRefresher()
    let vm = StatusViewModel(
        claudeRefresher: refresher,
        settingsStore: settingsStore,
        cacheStore: InMemorySnapshotCacheStore()
    )

    await vm.setConnector(.claude, enabled: true)
    let persisted = await settingsStore.load()

    #expect(persisted.connectors.claudeCode.isEnabled == true)
    #expect(vm.connectorState == .connected)
    #expect(vm.snapshots.isEmpty)
}

@MainActor
@Test func disconnectClearsConsentAndProviderCache() async {
    var settings = AppSettings.defaults
    settings.connectors.codex.isEnabled = true
    var cache = SnapshotCache.empty
    cache.replaceSnapshots([UsageSnapshotFixture.codexSample()], for: .codex, at: Date(timeIntervalSince1970: 1_000))
    let cacheStore = InMemorySnapshotCacheStore(data: try! JSONEncoder.cacheEncoder.encode(cache))
    let settingsStore = InMemoryAppSettingsStore(data: try! JSONEncoder.prettyStable.encode(settings))
    let vm = StatusViewModel(settingsStore: settingsStore, cacheStore: cacheStore)

    await vm.loadPersistedState()
    await vm.disconnect(.codex)

    let persistedSettings = await settingsStore.load()
    let persistedCache = await cacheStore.load()
    #expect(persistedSettings.connectors.codex.isEnabled == false)
    #expect(!persistedCache.snapshots.contains { $0.provider == "openai" })
    #expect(vm.codexConnectorState == .notConnected)
}
```

- [ ] **Step 2: Run failing tests**

```bash
cd apps/mac && swift test --filter loadPersistedState
```

Expected: build fails because `StatusViewModel` does not expose settings/cache injection or `loadPersistedState`.

- [ ] **Step 3: Add stores and settings state to `StatusViewModel` initializer**

In `StatusViewModel.swift`, add stored properties:

```swift
var settings: AppSettings
private var cache: SnapshotCache
private let settingsStore: AppSettingsStore
private let cacheStore: SnapshotCacheStore
private let now: @MainActor () -> Date
private(set) var hasLoadedPersistedState = false
```

Update `init(...)` parameters:

```swift
settings: AppSettings = .defaults,
cache: SnapshotCache = .empty,
settingsStore: AppSettingsStore = InMemoryAppSettingsStore(),
cacheStore: SnapshotCacheStore = InMemorySnapshotCacheStore(),
now: @escaping @MainActor () -> Date = Date.init
```

Set the stored properties in `init`.

- [ ] **Step 4: Add persistence loading and consent methods**

Add to `StatusViewModel`:

```swift
func loadPersistedState() async {
    settings = await settingsStore.load()
    cache = await cacheStore.load()
    applyCachedSnapshots()
    applyConnectorStatesFromSettings()
    hasLoadedPersistedState = true
}

func loadPersistedStateIfNeeded() async {
    guard !hasLoadedPersistedState else { return }
    await loadPersistedState()
}

func setConnector(_ provider: CachedProviderID, enabled: Bool) async {
    switch provider {
    case .claude:
        settings.connectors.claudeCode.isEnabled = enabled
    case .codex:
        settings.connectors.codex.isEnabled = enabled
    }
    await settingsStore.save(settings)
    applyCachedSnapshots()
    applyConnectorStatesFromSettings()
}

func disconnect(_ provider: CachedProviderID) async {
    await setConnector(provider, enabled: false)
    cache.removeProvider(provider)
    await cacheStore.save(cache)
    applyCachedSnapshots()
    applyConnectorStatesFromSettings()
}

private func applyCachedSnapshots() {
    let evaluated = cache.snapshotsEvaluatingStaleness(now: now())
    snapshots = evaluated.filter { snapshot in
        if CachedProviderID.claude.snapshotPredicate(snapshot) {
            return settings.connectors.claudeCode.isEnabled
        }
        if CachedProviderID.codex.snapshotPredicate(snapshot) {
            return settings.connectors.codex.isEnabled
        }
        return false
    }
}

private func applyConnectorStatesFromSettings() {
    if !settings.connectors.claudeCode.isEnabled {
        connectorState = .notConnected
        connectorStatusMessage = ClaudeConnectorSetupCopy.title(for: .notConnected)
    } else if let error = cache.lastErrorByProvider[CachedProviderID.claude.rawValue] {
        connectorState = error.code == .schemaChanged ? .schemaChanged : .networkError
        connectorStatusMessage = error.message
    } else {
        connectorState = .connected
        connectorStatusMessage = ClaudeConnectorSetupCopy.title(for: .connected)
    }

    if !settings.connectors.codex.isEnabled {
        codexConnectorState = .notConnected
        codexConnectorStatusMessage = CodexConnectorSetupCopy.title(for: .notConnected)
    } else if let error = cache.lastErrorByProvider[CachedProviderID.codex.rawValue] {
        codexConnectorState = error.code == .schemaChanged ? .schemaChanged : .networkError
        codexConnectorStatusMessage = error.message
    } else {
        codexConnectorState = .connected
        codexConnectorStatusMessage = CodexConnectorSetupCopy.title(for: .connected)
    }
}
```

- [ ] **Step 5: Wire live stores in `AppModel` and `StatusViewModel.live()`**

Add to `AppModel.swift`:

```swift
private static func applicationSupportDirectory() -> URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return base.appendingPathComponent("WhatTheToken", isDirectory: true)
}

static func live() -> AppModel {
    let directory = applicationSupportDirectory()
    let settingsStore = JSONFileAppSettingsStore(url: directory.appendingPathComponent("settings.json"))
    let cacheStore = JSONFileSnapshotCacheStore(url: directory.appendingPathComponent("snapshot-cache.json"))
    return AppModel(viewModel: .live(settingsStore: settingsStore, cacheStore: cacheStore))
}
```

Change `StatusViewModel.live()` signature:

```swift
static func live(
    settingsStore: AppSettingsStore = InMemoryAppSettingsStore(),
    cacheStore: SnapshotCacheStore = InMemorySnapshotCacheStore()
) -> StatusViewModel
```

Pass `settingsStore` and `cacheStore` into the returned `StatusViewModel`.

- [ ] **Step 6: Load persisted state on app startup**

In `AppModel.init(viewModel:)`, start a task:

```swift
init(viewModel: StatusViewModel) {
    self.viewModel = viewModel
    self.refreshController = PopoverRefreshController(viewModel: viewModel)
    Task { await viewModel.loadPersistedState() }
}
```

The popover controller will also call `loadPersistedStateIfNeeded()` before its one-shot open refresh in Task 6. That avoids a race where a very fast first popover open would refresh against default disabled settings before persisted consent has loaded.

- [ ] **Step 7: Run focused tests**

```bash
cd apps/mac && swift test --filter StatusViewModel
```

Expected: pass. If a compile error reports a missing argument in a `StatusViewModel(...)` call, keep that call unchanged and add the missing parameter as a default in the initializer signature from Step 3.

- [ ] **Step 8: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift \
  apps/mac/Sources/WhatTheTokenMac/AppModel.swift \
  apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift
git commit -m "feat(mac): persist connector consent"
```

## Task 4: Refresh Only Enabled Connectors And Persist Cache Results

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelFakes.swift`

- [ ] **Step 1: Add failing refresh gating and cache tests**

Append to `StatusViewModelTests.swift`:

```swift
@MainActor
@Test func refreshAllSkipsDisabledConnectors() async {
    let claudeCounter = Counter()
    let codexCounter = Counter()
    let vm = StatusViewModel(
        claudeRefresher: SlowClaudeRefresher(counter: claudeCounter),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        codexRefresher: SlowCodexRefresher(counter: codexCounter)
    )

    await vm.refreshAll(reason: .manual)

    #expect(claudeCounter.value == 0)
    #expect(codexCounter.value == 0)
}

@MainActor
@Test func refreshAllRefreshesOnlyEnabledConnector() async {
    var settings = AppSettings.defaults
    settings.connectors.codex.isEnabled = true
    let codexCounter = Counter()
    let vm = StatusViewModel(
        codexRefresher: SlowCodexRefresher(counter: codexCounter),
        settings: settings
    )

    await vm.refreshAll(reason: .manual)

    #expect(codexCounter.value == 1)
}

@MainActor
@Test func successfulRefreshPersistsProviderSnapshotsToCache() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    let cacheStore = InMemorySnapshotCacheStore()
    let vm = StatusViewModel(
        claudeRefresher: SnapshotClaudeRefresher(snapshots: [UsageSnapshotFixture.claudeLowSample()]),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        settings: settings,
        cacheStore: cacheStore,
        now: { Date(timeIntervalSince1970: 2_000) }
    )

    await vm.refreshAll(reason: .manual)
    let cache = await cacheStore.load()

    #expect(cache.snapshots.map(\.id) == [UsageSnapshotFixture.claudeLowSample().id])
    #expect(cache.lastSuccessfulRefreshAtByProvider[CachedProviderID.claude.rawValue] == Date(timeIntervalSince1970: 2_000))
}

@MainActor
@Test func failedRefreshKeepsLastKnownGoodSnapshotsAndStoresSanitizedError() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    var cache = SnapshotCache.empty
    cache.replaceSnapshots([UsageSnapshotFixture.claudeSample()], for: .claude, at: Date(timeIntervalSince1970: 1_000))
    let cacheStore = InMemorySnapshotCacheStore(data: try! JSONEncoder.cacheEncoder.encode(cache))
    let vm = StatusViewModel(
        claudeRefresher: ThrowingClaudeRefresher(),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        settings: settings,
        cache: cache,
        cacheStore: cacheStore,
        now: { Date(timeIntervalSince1970: 2_000) }
    )

    await vm.refreshAll(reason: .manual)
    let persisted = await cacheStore.load()

    #expect(vm.snapshots.map(\.id) == [UsageSnapshotFixture.claudeSample().id])
    #expect(persisted.lastErrorByProvider[CachedProviderID.claude.rawValue]?.code == .network)
    #expect(persisted.lastErrorByProvider[CachedProviderID.claude.rawValue]?.message == "Claude Code usage could not be refreshed")
}
```

Add fakes to `StatusViewModelFakes.swift`:

```swift
final class SnapshotClaudeRefresher: ClaudeConnectorRefreshing, @unchecked Sendable {
    let snapshots: [UsageSnapshot]
    init(snapshots: [UsageSnapshot]) { self.snapshots = snapshots }
    func refresh() async throws -> ClaudeConnectorResult {
        ClaudeConnectorResult(snapshots: snapshots, status: ConnectorStatus(product: "claude_code", source: testConnectorSource(), message: "Claude Code connected"))
    }
}

final class ThrowingClaudeRefresher: ClaudeConnectorRefreshing, @unchecked Sendable {
    func refresh() async throws -> ClaudeConnectorResult {
        throw SyntheticStatusViewModelError()
    }
}

struct SyntheticStatusViewModelError: Error {}
```

- [ ] **Step 2: Run failing tests**

```bash
cd apps/mac && swift test --filter refreshAll
```

Expected: tests fail because `refreshAll` still calls both connector methods regardless of settings and failure currently clears snapshots.

- [ ] **Step 3: Refactor provider refresh helpers**

In `StatusViewModel`, split connector refresh into provider-returning helpers:

```swift
private func refreshClaude(reason: RefreshReason) async {
    guard settings.connectors.claudeCode.isEnabled else { return }
    guard connectorState != .checking else { return }
    guard reason.isManual || cache.allowsAutomaticRefresh(for: .claude, now: now()) else { return }

    if let claudeVersionProvider, claudeVersionProvider.claudeVersion == "unknown" {
        replaceSnapshots(matching: CachedProviderID.claude.snapshotPredicate, with: [])
        cache.removeProvider(.claude)
        await cacheStore.save(cache)
        connectorState = .missingClaudeCli
        connectorStatusMessage = ClaudeConnectorSetupCopy.title(for: .missingClaudeCli)
        lastClaudeRefreshAt = now()
        return
    }

    let previousState = connectorState
    let previousMessage = connectorStatusMessage
    connectorState = .checking
    connectorStatusMessage = "Checking Claude Code"

    do {
        let result = try await requireClaudeRefreshResult()
        guard !Task.isCancelled else {
            connectorState = previousState
            connectorStatusMessage = previousMessage
            return
        }
        replaceSnapshots(matching: CachedProviderID.claude.snapshotPredicate, with: result.snapshots)
        connectorState = Self.setupState(for: result.status.source.state)
        connectorStatusMessage = result.status.message
        lastClaudeRefreshAt = now()
        // Keep cache in sync before later settings changes can re-derive snapshots from cache.
        cache.replaceSnapshots(result.snapshots, for: .claude, at: lastClaudeRefreshAt!)
        await cacheStore.save(cache)
    } catch {
        guard !Task.isCancelled else {
            connectorState = previousState
            connectorStatusMessage = previousMessage
            return
        }
        connectorState = .networkError
        connectorStatusMessage = "Claude Code usage could not be refreshed"
        cache.recordFailure(for: .claude, code: .network, message: connectorStatusMessage, now: now())
        await cacheStore.save(cache)
        applyCachedSnapshots()
    }
}
```

Add `refreshCodex(reason:)`:

```swift
private func refreshCodex(reason: RefreshReason) async {
    guard settings.connectors.codex.isEnabled else { return }
    guard codexConnectorState != .checking else { return }
    guard reason.isManual || cache.allowsAutomaticRefresh(for: .codex, now: now()) else { return }

    let previousState = codexConnectorState
    let previousMessage = codexConnectorStatusMessage
    codexConnectorState = .checking
    codexConnectorStatusMessage = "Checking Codex"

    do {
        let result = try await requireCodexRefreshResult()
        guard !Task.isCancelled else {
            codexConnectorState = previousState
            codexConnectorStatusMessage = previousMessage
            return
        }
        replaceSnapshots(matching: CachedProviderID.codex.snapshotPredicate, with: result.snapshots)
        codexConnectorState = Self.codexSetupState(for: result.status.source.state)
        codexConnectorStatusMessage = result.status.message
        lastCodexRefreshAt = now()
        // Keep cache in sync before later settings changes can re-derive snapshots from cache.
        cache.replaceSnapshots(result.snapshots, for: .codex, at: lastCodexRefreshAt!)
        await cacheStore.save(cache)
    } catch {
        guard !Task.isCancelled else {
            codexConnectorState = previousState
            codexConnectorStatusMessage = previousMessage
            return
        }
        codexConnectorState = .networkError
        codexConnectorStatusMessage = "Codex usage could not be refreshed"
        cache.recordFailure(for: .codex, code: .network, message: codexConnectorStatusMessage, now: now())
        await cacheStore.save(cache)
        applyCachedSnapshots()
    }
}
```

Keep `connectClaudeCode()` and `connectCodex()` as settings actions by enabling the provider before refreshing:

```swift
func connectClaudeCode() async {
    if !settings.connectors.claudeCode.isEnabled {
        await setConnector(.claude, enabled: true)
    }
    await refreshClaude(reason: .manual)
}

func connectCodex() async {
    if !settings.connectors.codex.isEnabled {
        await setConnector(.codex, enabled: true)
    }
    await refreshCodex(reason: .manual)
}
```

Add:

```swift
private func requireClaudeRefreshResult() async throws -> ClaudeConnectorResult {
    guard let claudeRefresher else {
        return ClaudeConnectorResult(
            snapshots: [],
            status: ConnectorStatus(
                product: "claude_code",
                source: ConnectorSource(connector: "claude_code", state: .notConnected, label: "Claude Code", parserVersion: "unknown", deviceId: "local_mac"),
                message: "Claude Code is not connected"
            )
        )
    }
    return try await claudeRefresher.refresh()
}
```

Add:

```swift
private func requireCodexRefreshResult() async throws -> CodexConnectorResult {
    guard let codexRefresher else {
        return CodexConnectorResult(
            snapshots: [],
            status: ConnectorStatus(
                product: "codex",
                source: ConnectorSource(connector: "codex", state: .notConnected, label: "Codex", parserVersion: "unknown", deviceId: "local_mac"),
                message: "Codex is not connected"
            )
        )
    }
    return try await codexRefresher.refresh()
}
```

- [ ] **Step 4: Update `refreshAll`**

Replace `refreshAll` body:

```swift
func refreshAll(reason: RefreshReason) async {
    guard !isRefreshAllInFlight else { return }
    isRefreshAllInFlight = true
    defer { isRefreshAllInFlight = false }

    await refreshClaude(reason: reason)
    guard !Task.isCancelled else { return }
    await refreshCodex(reason: reason)
}
```

Add:

```swift
extension StatusViewModel.RefreshReason {
    var isManual: Bool {
        switch self {
        case .manual, .retry:
            return true
        case .popoverOpened, .timerTick:
            return false
        }
    }
}
```

- [ ] **Step 5: Run focused tests**

```bash
cd apps/mac && swift test --filter StatusViewModel
```

Expected: pass. Update existing `connectClaudeCode` and `connectCodex` tests for the new semantics:

- Connect actions persist the provider's enabled setting as `true`.
- Thrown refresh errors keep existing provider snapshots visible instead of clearing them.
- Missing CLI still clears Claude snapshots because the connector cannot produce a meaningful Claude status without the local CLI.

- [ ] **Step 6: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift \
  apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift \
  apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelFakes.swift
git commit -m "feat(mac): refresh enabled connectors with cache persistence"
```

## Task 5: Add Backoff Semantics

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift`

- [ ] **Step 1: Add failing backoff tests**

Append:

```swift
@MainActor
@Test func popoverOpenRefreshRespectsPersistedBackoff() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    var cache = SnapshotCache.empty
    cache.recordFailure(for: .claude, code: .network, message: "Claude Code usage could not be refreshed", now: Date(timeIntervalSince1970: 1_000))
    let counter = Counter()
    let vm = StatusViewModel(
        claudeRefresher: SlowClaudeRefresher(counter: counter),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        settings: settings,
        cache: cache,
        now: { Date(timeIntervalSince1970: 1_100) }
    )

    await vm.refreshAll(reason: .popoverOpened)

    #expect(counter.value == 0)
}

@MainActor
@Test func manualRefreshBypassesBackoff() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    var cache = SnapshotCache.empty
    cache.recordFailure(for: .claude, code: .network, message: "Claude Code usage could not be refreshed", now: Date(timeIntervalSince1970: 1_000))
    let counter = Counter()
    let vm = StatusViewModel(
        claudeRefresher: SlowClaudeRefresher(counter: counter),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        settings: settings,
        cache: cache,
        now: { Date(timeIntervalSince1970: 1_100) }
    )

    await vm.refreshAll(reason: .manual)

    #expect(counter.value == 1)
}

@MainActor
@Test func repeatedFailuresProgressBackoffToSixtyMinutes() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    let cacheStore = InMemorySnapshotCacheStore()
    let vm = StatusViewModel(
        claudeRefresher: ThrowingClaudeRefresher(),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        settings: settings,
        cacheStore: cacheStore,
        now: { Date(timeIntervalSince1970: 1_000) }
    )

    await vm.refreshAll(reason: .manual)
    await vm.refreshAll(reason: .manual)
    await vm.refreshAll(reason: .manual)
    let cache = await cacheStore.load()
    let error = cache.lastErrorByProvider[CachedProviderID.claude.rawValue]

    #expect(error?.consecutiveFailureCount == 3)
    #expect(error?.nextAutomaticRefreshAt == Date(timeIntervalSince1970: 4_600))
}
```

- [ ] **Step 2: Run failing backoff tests**

```bash
cd apps/mac && swift test --filter Backoff
```

Expected: at least the repeated-failure test fails if cache state is not retained between failures.

- [ ] **Step 3: Ensure failure records mutate in-memory cache before saving**

In each provider `catch` path, update the in-memory `cache` before saving so consecutive manual failures advance the persisted backoff count:

```swift
cache.recordFailure(for: .claude, code: .network, message: connectorStatusMessage, now: now())
await cacheStore.save(cache)
```

Use the corresponding Codex line in the Codex `catch` path:

```swift
cache.recordFailure(for: .codex, code: .network, message: codexConnectorStatusMessage, now: now())
await cacheStore.save(cache)
```

Do not create a backoff error entry for a successful connector result whose source state is `.schemaChanged`. In the current connector contract, that is still a sanitized provider determination, not a thrown refresh failure; the success path writes the returned snapshots and clears prior automatic backoff.

- [ ] **Step 4: Ensure successful refresh resets backoff**

Use these lines in the provider success paths after the connector state/message are updated:

```swift
cache.replaceSnapshots(result.snapshots, for: .claude, at: lastClaudeRefreshAt!)
await cacheStore.save(cache)
```

```swift
cache.replaceSnapshots(result.snapshots, for: .codex, at: lastCodexRefreshAt!)
await cacheStore.save(cache)
```

- [ ] **Step 5: Run tests**

```bash
cd apps/mac && swift test --filter StatusViewModel
```

Expected: pass.

- [ ] **Step 6: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift \
  apps/mac/Tests/WhatTheTokenMacTests/StatusViewModelTests.swift
git commit -m "feat(mac): add provider refresh backoff"
```

## Task 6: Update Popover Refresh Controller For Persisted Auto-Refresh

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/PopoverRefreshController.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/PopoverRefreshControllerTests.swift`

- [ ] **Step 1: Replace timer tests**

In `PopoverRefreshControllerTests.swift`, replace `popoverDidOpen_runsImmediateRefresh_andStartsTimer` with:

```swift
@MainActor
@Test func popoverDidOpen_runsImmediateRefresh_withoutStartingTimerWhenAutoRefreshDisabled() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    let vm = StatusViewModel(
        claudeRefresher: NoopClaudeRefresher(),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        settings: settings
    )
    let fake = FakeSleeper()
    let controller = PopoverRefreshController(viewModel: vm, sleeper: { duration in await fake.sleep(duration) })

    controller.popoverDidOpen()
    for _ in 0..<10 { await Task.yield() }

    #expect(vm.lastClaudeRefreshAt != nil)
    #expect(fake.pendingTicks == 0)
}
```

Add:

```swift
@MainActor
@Test func popoverDidOpen_startsConfiguredTimerWhenAutoRefreshEnabled() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    settings.refresh.autoRefreshEnabled = true
    settings.refresh.intervalSeconds = 300
    let vm = StatusViewModel(
        claudeRefresher: NoopClaudeRefresher(),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        settings: settings
    )
    let fake = FakeSleeper()
    let controller = PopoverRefreshController(viewModel: vm, sleeper: { duration in await fake.sleep(duration) })

    controller.popoverDidOpen()
    for _ in 0..<20 {
        if fake.pendingTicks > 0 { break }
        await Task.yield()
    }

    #expect(fake.pendingTicks == 1)
    #expect(fake.lastDuration == .seconds(300))
}
```

Add a load-before-refresh test:

```swift
@MainActor
@Test func popoverDidOpen_loadsPersistedStateBeforeImmediateRefresh() async {
    var settings = AppSettings.defaults
    settings.connectors.claudeCode.isEnabled = true
    let settingsStore = InMemoryAppSettingsStore(data: try! JSONEncoder.prettyStable.encode(settings))
    let counter = Counter()
    let vm = StatusViewModel(
        claudeRefresher: SlowClaudeRefresher(counter: counter),
        claudeVersionProvider: StaticClaudeVersionProvider(claudeVersion: "1.0.0"),
        settingsStore: settingsStore
    )
    let controller = PopoverRefreshController(viewModel: vm, sleeper: { _ in })

    controller.popoverDidOpen()
    for _ in 0..<30 {
        if counter.value > 0 { break }
        await Task.yield()
    }

    #expect(vm.hasLoadedPersistedState == true)
    #expect(counter.value == 1)
}
```

Update `FakeSleeper`:

```swift
private var storedLastDuration: Duration?

func sleep(_ duration: Duration) async {
    await withCheckedContinuation { continuation in
        lock.withLock {
            storedLastDuration = duration
            continuations.append(continuation)
        }
    }
}

var lastDuration: Duration? {
    lock.withLock { storedLastDuration }
}
```

Delete the old tests whose assertions depend on the Stage 1 always-on timer:

- `timer_skipsRefresh_ifGenerationChangedDuringSleep`
- `popoverDidOpen_startsTimerBeforeImmediateRefreshCompletes`

Keep `popoverDidClose_cancelsBeforeNextTick`, but set `settings.refresh.autoRefreshEnabled = true` in that test setup so there is a timer to cancel. Keep `popoverDidClose_cancelsImmediateRefreshBeforeItClaimsFreshness`; it still validates the one-shot popover-open task.

- [ ] **Step 2: Run failing controller tests**

```bash
cd apps/mac && swift test --filter PopoverRefreshControllerTests
```

Expected: old hard-coded timer behavior fails.

- [ ] **Step 3: Modify controller timer setup**

In `PopoverRefreshController.popoverDidOpen()`, remove the immediate `startTimer(...)` call. Start the timer from the one-shot task after persisted state has loaded, then refresh:

```swift
openRefreshTask = Task { [weak self] in
    await viewModel.loadPersistedStateIfNeeded()
    guard let self, self.isCurrentGeneration(expected) else { return }
    if viewModel.settings.refresh.autoRefreshEnabled {
        self.startTimer(expectedGeneration: expected, interval: viewModel.settings.refresh.intervalDuration)
    }
    await viewModel.refreshAll(reason: .popoverOpened)
    guard self.isCurrentGeneration(expected) else { return }
    self.clearOpenRefreshTask()
}
```

Change `startTimer` signature:

```swift
private func startTimer(expectedGeneration expected: Int, interval: Duration)
```

Remove the stored `interval` property and the initializer `interval` parameter. Tests should control timing by setting `viewModel.settings.refresh.intervalSeconds`. Run `rg "PopoverRefreshController\\(" apps/mac` and update every call site that still passes `interval:`.

- [ ] **Step 4: Run controller tests**

```bash
cd apps/mac && swift test --filter PopoverRefreshControllerTests
```

Expected: pass with the deleted timer-assumption tests and the updated `popoverDidClose_cancelsBeforeNextTick` setup from Step 1.

- [ ] **Step 5: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/PopoverRefreshController.swift \
  apps/mac/Tests/WhatTheTokenMacTests/PopoverRefreshControllerTests.swift
git commit -m "feat(mac): honor auto-refresh preference"
```

## Task 7: Add No-Flicker Presentation Models

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/ProviderTabModel.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/PopoverChromeState.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/BannerState.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/Presentation/ProviderTabModelTests.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/Presentation/BannerStateTests.swift`

- [ ] **Step 1: Update failing presentation tests**

In `ProviderTabModelTests.swift`, change body equality test:

```swift
@Test func bodyEquatable_connected() {
    let snap: [UsageSnapshot] = []
    let a = ProviderTabModel.Body.connected(snapshots: snap, worst: .healthy, isRefreshing: true)
    let b = ProviderTabModel.Body.connected(snapshots: snap, worst: .healthy, isRefreshing: true)
    #expect(a == b)
}
```

Replace checking tests:

```swift
@MainActor
@Test func claude_checkingWithNoSnapshots_mapsToLoading() {
    let vm = StatusViewModel(snapshots: [], connectorState: .checking)
    let model = ProviderTabModel.from(viewModel: vm, tab: .claude)
    #expect(model.body == .loading)
}

@MainActor
@Test func claude_checkingWithSnapshots_keepsRowsVisibleAndMarksRefreshing() {
    let snapshots = [UsageSnapshotFixture.claudeSample()]
    let vm = StatusViewModel(snapshots: snapshots, connectorState: .checking)
    let model = ProviderTabModel.from(viewModel: vm, tab: .claude)
    #expect(model.body == .connected(snapshots: snapshots, worst: .healthy, isRefreshing: true))
}

@MainActor
@Test func codex_checkingWithSnapshots_keepsRowsVisibleAndMarksRefreshing() {
    let snapshots = [UsageSnapshotFixture.codexSample()]
    let vm = StatusViewModel(snapshots: snapshots, codexConnectorState: .checking)
    let model = ProviderTabModel.from(viewModel: vm, tab: .codex)
    #expect(model.body == .connected(snapshots: snapshots, worst: .healthy, isRefreshing: true))
}
```

Update connected and error expectations to include `isRefreshing: false`.

- [ ] **Step 2: Run failing model tests**

```bash
cd apps/mac && swift test --filter ProviderTabModelTests
```

Expected: compile failures due to old enum shape.

- [ ] **Step 3: Update `ProviderTabModel.Body`**

Replace body enum:

```swift
enum Body: Equatable, Sendable {
    case connected(snapshots: [UsageSnapshot], worst: StatusUsageState, isRefreshing: Bool)
    case empty
    case loading
    case disconnected(reason: DisconnectedReason)
    case error(kind: ErrorKind, lastSnapshots: [UsageSnapshot], isRefreshing: Bool)
}
```

Update Claude mapping:

```swift
case .checking:
    if claudeSnapshots.isEmpty {
        body = .loading
    } else {
        body = .connected(snapshots: claudeSnapshots, worst: claudeSnapshots.worstUsageState(), isRefreshing: true)
    }
case .connected:
    body = claudeSnapshots.isEmpty
        ? .empty
        : .connected(snapshots: claudeSnapshots, worst: claudeSnapshots.worstUsageState(), isRefreshing: false)
case .networkError:
    body = .error(kind: .network, lastSnapshots: claudeSnapshots, isRefreshing: false)
case .schemaChanged:
    body = .error(kind: .schemaChanged, lastSnapshots: claudeSnapshots, isRefreshing: false)
```

Update Codex mapping:

```swift
case .checking:
    if codexSnapshots.isEmpty {
        body = .loading
    } else {
        body = .connected(snapshots: codexSnapshots, worst: codexSnapshots.worstUsageState(), isRefreshing: true)
    }
case .connected:
    body = codexSnapshots.isEmpty
        ? .empty
        : .connected(snapshots: codexSnapshots, worst: codexSnapshots.worstUsageState(), isRefreshing: false)
case .networkError:
    body = .error(kind: .network, lastSnapshots: codexSnapshots, isRefreshing: false)
case .schemaChanged:
    body = .error(kind: .schemaChanged, lastSnapshots: codexSnapshots, isRefreshing: false)
```

- [ ] **Step 4: Update chrome/banner switches**

In `PopoverChromeState.indicator(for:)`, replace:

```swift
case let .connected(snapshots, _):
```

with:

```swift
case let .connected(snapshots, _, _):
```

Replace `.checking` switch cases with `.loading`.

In `BannerState.from`, update connected and error pattern matches to include `isRefreshing` and replace `.checking` with `.loading`.

- [ ] **Step 5: Run presentation tests**

```bash
cd apps/mac && swift test --filter ProviderTabModelTests
cd apps/mac && swift test --filter BannerStateTests
cd apps/mac && swift test --filter PopoverChromeStateTests
```

Expected: pass.

- [ ] **Step 6: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/ProviderTabModel.swift \
  apps/mac/Sources/WhatTheTokenMac/ViewModels/PopoverChromeState.swift \
  apps/mac/Sources/WhatTheTokenMac/ViewModels/BannerState.swift \
  apps/mac/Tests/WhatTheTokenMacTests/Presentation/ProviderTabModelTests.swift \
  apps/mac/Tests/WhatTheTokenMacTests/Presentation/BannerStateTests.swift
git commit -m "fix(mac): keep provider values during refresh state"
```

## Task 8: Render Thin Progress Line And Updating Footer Copy

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/PopoverFooterState.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/Popover/ProviderTabContentView.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/Popover/PopoverFooterView.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/Presentation/PopoverFooterStateTests.swift`

- [ ] **Step 1: Add failing footer-state tests**

In `PopoverFooterStateTests.swift`, add:

```swift
@MainActor
@Test func footerRefreshingIsScopedToSelectedProvider() {
    let vm = StatusViewModel(
        snapshots: [UsageSnapshotFixture.claudeSample()],
        connectorState: .checking,
        codexConnectorState: .connected
    )

    let claude = PopoverFooterState.from(viewModel: vm, selected: .claude)
    let codex = PopoverFooterState.from(viewModel: vm, selected: .codex)

    #expect(claude.isRefreshing == true)
    #expect(claude.labelText(now: Date(timeIntervalSince1970: 1_000)) == "Updating values...")
    #expect(codex.isRefreshing == false)
}

@Test func footerLabelUsesLastUpdatedWhenNotRefreshing() {
    let date = Date(timeIntervalSince1970: 1_000)
    let state = PopoverFooterState(lastUpdatedAt: date, isRefreshing: false, canRefresh: true)

    #expect(state.labelText(now: Date(timeIntervalSince1970: 1_060)).hasPrefix("Last updated"))
}
```

- [ ] **Step 2: Run failing footer tests**

```bash
cd apps/mac && swift test --filter PopoverFooterStateTests
```

Expected: fails because footer refresh state is global and `labelText(now:)` does not exist.

- [ ] **Step 3: Update footer state**

In `PopoverFooterState.swift`, add:

```swift
func labelText(now: Date = Date()) -> String {
    guard !isRefreshing else { return "Updating values..." }
    guard let lastUpdatedAt else { return "-" }
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return "Last updated " + formatter.localizedString(for: lastUpdatedAt, relativeTo: now)
}
```

Update `from(viewModel:selected:)`:

```swift
let isSelectedRefreshing = viewModel.isRefreshing(selected)
return PopoverFooterState(
    lastUpdatedAt: viewModel.lastRefreshAt(for: selected),
    isRefreshing: isSelectedRefreshing,
    canRefresh: !viewModel.isAnyRefreshing
)
```

Add `StatusViewModel.isRefreshing(_:)`:

```swift
func isRefreshing(_ tab: ProviderTab) -> Bool {
    switch tab {
    case .claude:
        return connectorState == .checking
    case .codex:
        return codexConnectorState == .checking
    }
}
```

- [ ] **Step 4: Update footer view**

Replace `updatedLabel` body in `PopoverFooterView.swift` with:

```swift
private var updatedLabel: some View {
    Text(state.labelText())
        .font(.caption2)
        .foregroundStyle(.secondary)
}
```

- [ ] **Step 5: Update provider content view**

In `ProviderTabContentView.body`, replace cases:

```swift
case let .connected(snapshots, _, isRefreshing):
    VStack(spacing: 0) {
        refreshProgressLine(isVisible: isRefreshing)
        StatusSectionView(snapshots: snapshots)
    }
case .loading:
    checking
case let .error(kind, lastSnapshots, isRefreshing):
    VStack(spacing: 0) {
        refreshProgressLine(isVisible: isRefreshing)
        errorBody(kind: kind, lastSnapshots: lastSnapshots)
    }
```

Add:

```swift
@ViewBuilder
private func refreshProgressLine(isVisible: Bool) -> some View {
    if isVisible {
        ProgressView()
            .progressViewStyle(.linear)
            .controlSize(.small)
            .frame(height: 2)
            .padding(.horizontal, 12)
            .accessibilityLabel("Updating values")
    }
}
```

- [ ] **Step 6: Run UI-adjacent tests and build**

```bash
cd apps/mac && swift test --filter PopoverFooterStateTests
cd apps/mac && swift build
```

Expected: pass/build succeeds.

- [ ] **Step 7: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/ViewModels/PopoverFooterState.swift \
  apps/mac/Sources/WhatTheTokenMac/Views/Popover/ProviderTabContentView.swift \
  apps/mac/Sources/WhatTheTokenMac/Views/Popover/PopoverFooterView.swift \
  apps/mac/Tests/WhatTheTokenMacTests/Presentation/PopoverFooterStateTests.swift
git commit -m "fix(mac): show subtle refresh progress"
```

## Task 9: Add Settings Controls For Consent, Disconnect, And Auto-Refresh

**Files:**
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/Settings/ConnectorsView.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/Settings/ConnectorRowView.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/Settings/SettingsRootView.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/Presentation/ConnectorActionTitleTests.swift`

- [ ] **Step 1: Add copy tests**

Append to `ConnectorActionTitleTests.swift`:

```swift
@Test func connectorConsentCopyStatesStoredDataBoundary() {
    let claude = ConnectorConsentCopy.claude.lowercased()
    let codex = ConnectorConsentCopy.codex.lowercased()

    #expect(claude.contains("credentials"))
    #expect(claude.contains("claude code storage"))
    #expect(claude.contains("sanitized usage status"))
    #expect(codex.contains("auth"))
    #expect(codex.contains("inside codex"))
    #expect(codex.contains("sanitized usage status"))
}
```

- [ ] **Step 2: Run failing copy tests**

```bash
cd apps/mac && swift test --filter ConnectorActionTitleTests
```

Expected: fails because `ConnectorConsentCopy` does not exist.

- [ ] **Step 3: Add consent copy**

Add to `ConnectorActionTitle.swift`:

```swift
enum ConnectorConsentCopy {
    static let claude = "Reads Claude Code local usage status only after you enable it. Provider credentials stay in Claude Code storage. WhatTheToken stores only sanitized usage status. Disconnect removes cached Claude Code usage from WhatTheToken."
    static let codex = "Reads Codex local rate-limit status only after you enable it. Codex auth stays inside Codex. WhatTheToken stores only sanitized usage status. Disconnect removes cached Codex usage from WhatTheToken."
}
```

- [ ] **Step 4: Update connector row view**

Change `ConnectorRowView` properties:

```swift
let isEnabled: Bool
let canDisconnect: Bool
let onEnabledChange: (Bool) -> Void
let onDisconnect: () -> Void
```

Replace `ConnectorRowView.body` with:

```swift
var body: some View {
    HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(stateTitle)
                .font(.subheadline)
            if detail != stateTitle {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(trustMessage)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Toggle("Enabled", isOn: Binding(
                get: { isEnabled },
                set: onEnabledChange
            ))

            Button("Disconnect", role: .destructive, action: onDisconnect)
                .disabled(!canDisconnect)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Button(actionTitle, action: action)
            .disabled(isWorking || !isEnabled)
    }
    .padding(.vertical, 6)
}
```

- [ ] **Step 5: Update settings view call sites**

In `ConnectorsView`, pass Claude values:

```swift
isEnabled: viewModel.settings.connectors.claudeCode.isEnabled,
canDisconnect: viewModel.settings.connectors.claudeCode.isEnabled || viewModel.snapshots.contains(where: CachedProviderID.claude.snapshotPredicate),
onEnabledChange: { enabled in
    let viewModel = self.viewModel
    Task { await viewModel.setConnector(.claude, enabled: enabled) }
},
onDisconnect: {
    let viewModel = self.viewModel
    Task { await viewModel.disconnect(.claude) }
}
```

Pass Codex values using `.codex`:

```swift
isEnabled: viewModel.settings.connectors.codex.isEnabled,
canDisconnect: viewModel.settings.connectors.codex.isEnabled || viewModel.snapshots.contains(where: CachedProviderID.codex.snapshotPredicate),
onEnabledChange: { enabled in
    let viewModel = self.viewModel
    Task { await viewModel.setConnector(.codex, enabled: enabled) }
},
onDisconnect: {
    let viewModel = self.viewModel
    Task { await viewModel.disconnect(.codex) }
}
```

Add a `Section("Refresh")`:

```swift
Section("Refresh") {
    Toggle("Auto-refresh while app is running", isOn: Binding(
        get: { viewModel.settings.refresh.autoRefreshEnabled },
        set: { enabled in
            var settings = viewModel.settings
            settings.refresh.autoRefreshEnabled = enabled
            Task { await viewModel.saveSettings(settings) }
        }
    ))

    Stepper(
        "Interval: \(viewModel.settings.refresh.intervalSeconds / 60) min",
        value: Binding(
            get: { viewModel.settings.refresh.intervalSeconds },
            set: { seconds in
                var settings = viewModel.settings
                settings.refresh.intervalSeconds = max(300, seconds)
                Task { await viewModel.saveSettings(settings) }
            }
        ),
        in: 300...3600,
        step: 300
    )
    .disabled(!viewModel.settings.refresh.autoRefreshEnabled)
}
```

Stage 2 applies `autoRefreshEnabled` and `intervalSeconds` changes on the next popover open. Do not add controller callbacks from Settings in this plan; the popover controller reads the latest persisted settings when it opens and when it starts a timer.

Add `StatusViewModel.saveSettings(_:)`:

```swift
func saveSettings(_ newSettings: AppSettings) async {
    settings = newSettings
    await settingsStore.save(settings)
    applyCachedSnapshots()
    applyConnectorStatesFromSettings()
}
```

- [ ] **Step 6: Run tests and build**

```bash
cd apps/mac && swift test --filter ConnectorActionTitleTests
cd apps/mac && swift build
```

Expected: pass/build succeeds.

- [ ] **Step 7: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac/Views/Settings/ConnectorsView.swift \
  apps/mac/Sources/WhatTheTokenMac/Views/Settings/ConnectorRowView.swift \
  apps/mac/Sources/WhatTheTokenMac/Views/Settings/SettingsRootView.swift \
  apps/mac/Sources/WhatTheTokenMac/Views/Settings/ConnectorActionTitle.swift \
  apps/mac/Tests/WhatTheTokenMacTests/Presentation/ConnectorActionTitleTests.swift
git commit -m "feat(mac): add connector consent settings"
```

## Task 10: Full Verification And Manual Smoke

**Files:**
- Review all changed files.

- [ ] **Step 1: Run Swift tests**

```bash
cd apps/mac && swift test
```

Expected: all tests pass.

- [ ] **Step 2: Run core tests**

```bash
pnpm --filter @whatthetoken/core test
```

Expected: all tests pass.

- [ ] **Step 3: Run build**

```bash
cd apps/mac && swift build
```

Expected: build succeeds.

- [ ] **Step 4: Privacy scan**

```bash
rg -n "bearerToken|authHeader|sessionToken|cookie|prompt|completion|conversation" apps/mac/Sources apps/mac/Tests
```

Expected: matches only deny-list tests, privacy copy, or fixture-scan assertions; no settings/cache model stores sensitive fields.

- [ ] **Step 5: Manual app smoke**

```bash
cd apps/mac && swift run WhatTheTokenMac
```

Check:

- First launch shows both connectors disabled/not connected.
- Enabling a connector in Settings persists after relaunch.
- Refresh with existing values keeps rows visible.
- A thin progress line appears during refresh.
- Footer shows `Updating values...` during selected-provider refresh.
- Disconnect disables the connector and removes cached values for that provider.
- Auto-refresh timer does not run until enabled.

- [ ] **Step 6: Review diff**

```bash
git status --short
git diff --stat origin/main...HEAD
git diff origin/main...HEAD -- docs/superpowers/specs/2026-05-08-consent-persistence-refresh-engine-design.md docs/superpowers/plans/2026-05-08-consent-persistence-refresh-engine.md
```

Expected: implementation matches the spec and plan; no unrelated files changed.

- [ ] **Step 7: Final commit if verification changed files**

If manual smoke or verification required small fixes:

```bash
git add apps/mac/Sources apps/mac/Tests
git commit -m "fix(mac): finish refresh persistence verification"
```

If no files changed, no commit is needed.
