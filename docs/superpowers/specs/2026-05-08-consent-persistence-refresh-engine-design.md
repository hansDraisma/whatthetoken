# Consent, Persistence, And Refresh Engine Design

Date: 2026-05-08

Status: approved direction from brainstorming; ready for implementation plan.

## Purpose

Stage 2 makes the menu bar app feel continuous instead of session-based. Users should not have to reconnect every time they open the app, and refresh should update usage values in place instead of making the provider panel disappear.

This stage adds local settings, sanitized last-known-good cache, explicit refresh behavior, stale evaluation, and the no-flicker refresh UX chosen during brainstorming: keep current rows visible, show a thin progress line while refreshing, and replace values only after new sanitized snapshots arrive.

## Stage Boundary

This spec implements Stage 2 from `docs/roadmap/development-roadmap.md`.

In scope:

- persisted connector enabled state for Claude Code and Codex
- persisted refresh preferences, including explicit auto-refresh opt-in
- sanitized last-known-good snapshot cache
- cache staleness evaluation on load and refresh
- manual refresh that refreshes enabled connectors without changing consent
- refresh deduplication
- basic error backoff: 5 minutes, then 15 minutes, then 60 minutes
- no-flicker refresh presentation
- settings copy that explains local access, non-storage of credentials, stored sanitized data, and disconnect behavior

Out of scope:

- macOS notifications
- provider expansion
- hosted sync
- telemetry
- Sparkle updates
- signed or notarized DMG
- full history or burn-rate prediction
- storing provider credentials, cookies, provider session tokens, auth headers, raw provider responses, prompts, responses, or raw local databases

## Current Inputs

Stage 2 builds on:

- `docs/roadmap/development-roadmap.md`
- `docs/architecture/privacy-boundaries.md`
- `docs/architecture/data-contract.md`
- `docs/adr/0001-local-first-minimal-data-ingestion.md`
- `docs/adr/0002-confidence-labels-and-provenance.md`
- `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift`
- `apps/mac/Sources/WhatTheTokenMac/ViewModels/ProviderTabModel.swift`
- `apps/mac/Sources/WhatTheTokenMac/ViewModels/PopoverFooterState.swift`
- `apps/mac/Sources/WhatTheTokenMac/ViewModels/PopoverRefreshController.swift`
- `apps/mac/Sources/WhatTheTokenMac/Views/Popover/ProviderTabContentView.swift`
- `apps/mac/Sources/WhatTheTokenMac/Views/Popover/PopoverFooterView.swift`

The current refresh flicker comes from `ProviderTabModel`: when a provider enters `.checking`, the selected tab body switches from rows to a standalone "Refreshing..." view even when previous snapshots exist. Stage 2 changes that presentation contract.

## Approach Decision

Three refresh and persistence approaches were considered.

### Option A: Minimal Persistence Only

Persist enabled connectors and keep the current checking screen.

This would solve relaunch friction but leave the most visible UX problem unresolved. It also treats refresh state as a replacement for cached values, which conflicts with the last-known-good cache model.

### Option B: Cache First, UX Later

Add sanitized cache and stale evaluation now, then defer the refresh animation and checking-state polish.

This is technically clean, but it would ship a cache that still visually disappears during refresh. Users would see less confidence exactly when the app is trying to update confidence.

### Option C: Continuous Status Surface

Persist settings and sanitized last-known-good data, then make refresh a background update when existing values are available. Initial load may show a compact loading state, but normal refresh keeps rows visible, shows a thin progress line, updates footer copy to "Updating values...", and swaps in new values only after parsing succeeds.

This is the chosen approach. It matches the product promise: the menu bar app is a stable status surface, not a page that reloads.

## Data Model

### `AppSettings`

`AppSettings` is local-only, Codable, and versioned.

It stores:

- `schemaVersion`
- `connectors.claudeCode.isEnabled`
- `connectors.codex.isEnabled`
- `refresh.autoRefreshEnabled`
- `refresh.intervalSeconds`
- `notifications.isEnabled`
- `notifications.lowThreshold`
- `notifications.criticalThreshold`
- `menuBar.displayMode`

Stage 2 may add notification preferences without delivering notifications; Stage 3 owns notification permission and delivery. Defaults must keep auto-refresh disabled.

`AppSettings` must not store provider credentials, provider auth state, copied cookies, bearer tokens, session tokens, raw provider payloads, prompts, responses, or local database contents.

### `SnapshotCache`

`SnapshotCache` is local-only, Codable, and versioned.

It stores only sanitized `UsageSnapshot` values and cache metadata:

- `schemaVersion`
- `snapshots`
- `updatedAtByProvider`
- `lastSuccessfulRefreshAtByProvider`
- `lastErrorByProvider`, containing a sanitized code and user-safe message only

Cached snapshots must follow the existing data contract. They may include provider, product, surface, pool/window identifiers, numeric usage fields, confidence, undercount risk, stale reason, display labels, and source metadata. They must not include raw provider responses or copied provider credentials.

## Storage

Stage 2 should use simple local JSON files through small protocols:

- `AppSettingsStore`
- `SnapshotCacheStore`

The default live stores should write under the user's application support directory for WhatTheToken. Tests use in-memory or temporary-directory stores.

Writes should be atomic from the app's perspective: encode to data, write to a temporary file in the same directory, then replace the destination. If decoding fails, the app should fall back to safe defaults for settings and an empty cache, while surfacing a sanitized local error for developer diagnostics later.

## Consent And Connector State

Connector consent is represented by each connector's persisted enabled state.

On first launch, both connectors default to disabled unless an existing app state explicitly enables them. Settings must explain, per connector:

- what local state is accessed after enabling
- that provider credentials stay in the provider's own storage
- that WhatTheToken does not copy credentials into its settings or cache
- that only sanitized usage status is stored
- how to disable or disconnect the connector

Disabling a connector stops automatic and manual refresh for that provider and clears active connector UI state for that provider. Disconnecting is stronger: it disables the connector and removes that provider's cached snapshots from `SnapshotCache`. Neither action should attempt to mutate provider-owned credentials or provider-owned auth state.

## Refresh Semantics

Manual refresh should refresh only enabled connectors. It must not enable a connector, change consent state, or require the user to reconnect.

Refresh triggers:

- user taps refresh
- user taps retry
- popover opens
- auto-refresh timer fires, only when explicit auto-refresh is enabled

Stage 2 replaces the Stage 1 in-popover 30-second polling model with the persisted refresh preference model. The default is no automatic refresh. When auto-refresh is enabled, the default interval is 5 minutes.

Refreshes are deduplicated:

- only one all-provider refresh can run at a time
- only one per-provider refresh can run at a time
- a manual refresh can run after backoff delay, but a successful manual refresh resets the provider's backoff state

Backoff is per provider:

- first failure: next automatic retry after 5 minutes
- second consecutive failure: 15 minutes
- third and later consecutive failures: 60 minutes

Manual refresh should bypass the wait until the next automatic retry, but it should not start if the same provider is already refreshing.

## Cache And Staleness

On launch, the app loads settings first, then snapshot cache.

Loaded cached snapshots should render immediately for enabled connectors. Before rendering, the app evaluates staleness using existing freshness rules and marks expired snapshots as `stale` by setting or preserving a safe `staleReason`.

On successful provider refresh:

- replace only that provider's cached snapshots
- update the provider's successful refresh timestamp
- clear that provider's sanitized last error
- persist the cache
- update the UI with the new values

On failed provider refresh:

- keep that provider's existing cached snapshots
- mark or present them as stale/error-backed
- store only sanitized error metadata
- do not delete last-known-good data unless the user disconnects the provider

## No-Flicker Refresh UX

The selected refresh UX is a thin progress line.

Rules:

- If a provider has no snapshots and is refreshing for the first time, the tab may show the compact loading state.
- If a provider has snapshots and refresh starts, keep the current rows visible.
- While background refresh is active for the selected provider, show a subtle 2px indeterminate progress line near the top of the provider content.
- While background refresh is active, the footer label changes from "Last updated ..." to "Updating values...".
- The refresh button is disabled while an all-provider or same-provider refresh is in flight.
- When new sanitized snapshots arrive, row values update in place.
- If refresh fails, existing values remain visible and stale/error copy appears through the existing banner and error affordances.

`ProviderTabModel.Body.checking` should be replaced with explicit initial-load and background-refresh cases. The presentation model shape for Stage 2 is:

```swift
enum Body: Equatable, Sendable {
    case connected(snapshots: [UsageSnapshot], worst: StatusUsageState, isRefreshing: Bool)
    case empty(isRefreshing: Bool)
    case loading
    case disconnected(reason: DisconnectedReason)
    case error(kind: ErrorKind, lastSnapshots: [UsageSnapshot], isRefreshing: Bool)
}
```

Existing values must remain visible during refresh whenever `snapshots` or `lastSnapshots` is non-empty.

## Architecture

### `AppModel`

`AppModel` owns the live stores and wires them into `StatusViewModel` and refresh scheduling. It remains the single process-level owner used by `MenuBarExtra`, `Settings`, and the DEBUG developer window.

### `StatusViewModel`

`StatusViewModel` becomes the coordinator for:

- loaded settings
- loaded sanitized cache
- per-provider connector state
- per-provider refresh state
- per-provider backoff state
- cache updates after refresh

Provider connector services still own provider-specific fetching and mapping. They should return sanitized results and discard raw provider responses after parsing.

### `PopoverRefreshController`

`PopoverRefreshController` no longer owns a hard-coded 30-second timer. It reads the persisted auto-refresh preference from `StatusViewModel` and uses the configured interval only while the popover is open. It does not start an automatic timer when `autoRefreshEnabled` is false.

The behavior is fixed for Stage 2: no automatic refresh unless the user explicitly enables it, and the default interval is 5 minutes when enabled.

### Settings Views

Settings owns consent and refresh preferences:

- connector enabled/disabled controls
- disconnect action per connector
- consent copy per connector
- auto-refresh toggle
- refresh interval control, disabled unless auto-refresh is enabled

Settings should not expose raw file paths to provider credentials or provider-owned auth storage.

## Error Handling

Provider errors are sanitized before storage or display.

Display rules:

- missing credentials, missing CLI, permission denied, token invalid, and rate limited states use existing connector-specific copy
- network and schema errors keep cached values visible when available
- stale snapshots clearly indicate that values may be outdated
- cache decode failure falls back to empty cache and does not crash the app
- settings decode failure falls back to defaults and does not enable connectors automatically

Logs and diagnostics must not contain raw provider payloads, auth headers, cookies, bearer tokens, provider session tokens, prompts, responses, or raw local databases.

## Testing Strategy

Add focused tests for:

- default settings values keep connectors and auto-refresh disabled
- settings encode/decode round trip
- settings decode failure falls back to safe defaults
- snapshot cache encode/decode round trip
- cache never stores raw provider payload fields
- cached snapshots render on launch for enabled connectors
- stale cache evaluation marks expired snapshots as stale
- successful refresh replaces only the refreshed provider's cached snapshots
- failed refresh keeps last-known-good snapshots visible
- manual refresh does not enable disabled connectors
- auto-refresh does not run unless explicitly enabled
- auto-refresh uses the configured 5-minute default when enabled
- per-provider backoff progresses 5, 15, 60 minutes
- manual refresh bypasses automatic retry delay
- provider tab content keeps rows visible during background refresh
- footer shows "Updating values..." during selected-provider refresh
- thin progress line appears during selected-provider background refresh

Use synthetic fixtures only. Live provider checks remain manual and opt-in.

## Acceptance Criteria

- Relaunch preserves connector enabled state and sanitized last-known-good values.
- Default launch does not enable connectors or start auto-refresh without explicit consent.
- Manual refresh refreshes enabled connectors without changing consent state.
- Auto-refresh is explicit, configurable, and disabled by default.
- Provider credentials and raw provider data are never stored in WhatTheToken settings or cache.
- Cached values become visibly stale when freshness expires.
- Refreshing with existing values no longer blanks the provider panel.
- A thin progress line and "Updating values..." footer copy indicate background refresh.
- Failed refresh keeps last-known-good values visible.
- Swift tests cover settings, cache, stale evaluation, refresh deduplication, backoff, and no-flicker presentation behavior.
