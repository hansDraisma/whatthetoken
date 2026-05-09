# Notifications And Background Freshness Design

Date: 2026-05-08

Status: proposed Stage 3 spec after Stage 2 refresh/cache implementation landed in `main`.

## Purpose

Stage 3 turns WhatTheToken from a status surface the user checks manually into a lightweight local guardrail that can warn before quota interrupts work.

Stage 2 already added persisted connector consent, sanitized last-known-good cache, stale evaluation, explicit auto-refresh, backoff, and no-flicker refresh. Its auto-refresh is scoped to the popover being open. That is useful for continuity while looking at the app, but it is not enough for notifications: a user cannot receive a timely low-quota warning if refresh only runs after they click the menu bar item.

Stage 3 therefore has two linked goals:

- keep enabled connectors fresh in the background while the menu bar app is running, after explicit user opt-in
- notify once when enabled providers cross user-configurable warning and critical thresholds

## Stage Boundary

In scope:

- background auto-refresh while the app process is running, not only while the popover is open
- explicit opt-in controls for background refresh and notifications
- separate Pause and Disconnect connector actions
- adaptive stale timing based on refresh mode
- notification permission flow
- warning and critical notification thresholds, defaulting to 20% and 10%
- provider-level notification settings in the first UI
- per-pool notification evaluation internally, so future advanced controls do not require rewriting the engine
- notification state that suppresses repeated alerts during flapping or rolling-window churn
- menu bar critical indicator when any enabled provider is critically low

Out of scope:

- launch-at-login
- background refresh while the app is not running
- hosted sync
- team notifications
- email, Slack, or webhook delivery
- full per-pool advanced settings UI
- burn-rate prediction
- provider expansion
- notification analytics or telemetry

Launch-at-login belongs to Stage 5 distribution hardening unless explicitly pulled forward. Stage 3 should work whenever the app is already running.

## PM Decisions

The following product decisions are locked for this spec.

### Automation And Continuity

Stage 3 is about both automation and continuity. The app should preserve the Stage 2 trust model: cached values remain visible, failed refresh does not blank the UI, stale values are labeled, and raw provider data is never stored.

Automation must be opt-in. Enabling background refresh means WhatTheToken may periodically read enabled local connector status while the app is running. It must not silently enable connectors, read disabled connectors, or start provider reads before the user consents.

### Current Auto-Refresh Difference

Stage 2 auto-refresh runs only while the popover is open. Stage 3 background refresh runs while the app process is running, even when the popover is closed.

The Stage 2 popover-open refresh should remain as a foreground freshness trigger. It should not be the only automation path once notifications exist.

### Pause Versus Disconnect

Settings must distinguish:

- **Pause**: stop refreshing a connector and keep sanitized cached values.
- **Disconnect**: stop refreshing a connector and remove that provider's cached values from WhatTheToken.

Neither action mutates provider-owned credentials, provider login state, cookies, tokens, or local provider databases.

The current Stage 2 settings UI exposes enabled providers as `Disconnect ...`, which deletes cache. Stage 3 should add an explicit pause action so users can stop reads without losing last-known-good status.

### Staleness

Staleness should reflect expected refresh cadence:

- when background auto-refresh is enabled: stale after `max(2 * refresh interval, 15 minutes)`
- when background auto-refresh is disabled: stale after 60 minutes

This keeps automatic users from seeing old values as trustworthy for too long, while manual-refresh users are not punished by an aggressively short freshness window.

### Notification Defaults

Default notification thresholds:

- warning: remaining usage below 20%
- critical: remaining usage below 10%

The existing visual health model may still use `low < 30%` for in-app caution. Notification copy should call the 20% threshold a `warning`, not `low`, so the product does not use the same word for two different thresholds. The in-app state remains `low`; the notification state is `warning`.

### Provider-Level UI, Pool-Level Engine

The first settings UI should be provider-level: users enable notifications for Claude Code and/or Codex without configuring every quota pool.

The notification evaluator should still operate per pool/window internally. If Claude has multiple windows, or Codex exposes multiple buckets, a warning or critical state in any included quota pool can trigger a provider notification. This preserves correctness while keeping the first UI simple.

## User Flow

### First-Time Notification Setup

Settings gets an `Alerts` section below Refresh.

Default state:

- notifications disabled
- warning threshold 20%
- critical threshold 10%
- provider alerts default to enabled (`providerAlerts.{claudeCode,codex}.isEnabled = true`)

Provider alerts default to true on fresh installs and during v1→v2 migration. Toggling the master notifications switch must not mutate provider-alert toggles, so an alert the user explicitly disabled stays disabled across enable/disable cycles.

When the user turns notifications on:

1. Show a short in-app explanation: WhatTheToken can alert when enabled providers drop below warning or critical usage.
2. Request macOS notification permission.
3. If permission is granted, persist `notifications.isEnabled = true`.
4. If permission is denied, keep in-app alert settings visible but show a disabled/needs-permission state with a button or copy pointing to System Settings.

The app must not request notification permission on first launch or connector connect. The prompt should follow an explicit notifications action.

### Alert Controls

The first UI should avoid advanced per-pool tuning.

Controls:

- master toggle: `Notify me before quota runs low`
- warning threshold stepper or menu: default 20%, allowed range 10-50%
- critical threshold stepper or menu: default 10%, allowed range 1-25%
- provider toggles: Claude Code, Codex

Validation:

- critical threshold must be lower than warning threshold
- if the user lowers warning below critical, clamp critical to one step below warning
- if the user raises critical above warning, raise warning to one step above critical

The settings copy should avoid promising exact quota truth for `observed` data. Codex notification copy should mention that values are observed until provider semantics are validated.

### Pause And Disconnect Flow

Each connector row should expose:

- `Pause` for enabled connectors
- `Resume` or `Connect` for paused/disabled connectors
- `Disconnect...` as a secondary destructive action

Pause confirmation is not required because it keeps cache and can be undone.

Disconnect should keep the existing confirmation dialog and explicitly say cached values will be removed from WhatTheToken.

Paused providers:

- are not refreshed manually or automatically
- keep cached snapshots visible with a paused/disconnected affordance
- do not emit notifications

Disconnect while paused still requires confirmation and still removes cached values. It also clears that provider's notification dedupe state so a later reconnect can alert again if the provider is still below threshold. Re-enabling after disconnect starts from an empty provider cache and refreshes only after the user resumes/connects the provider.

## Background Freshness

### Scheduler

Add a background refresh controller owned by `AppModel`, separate from `PopoverRefreshController`.

Responsibilities:

- load persisted state once during app startup
- start a timer only when background refresh is enabled
- refresh enabled, unpaused connectors at the configured interval
- respect per-provider backoff
- stop or restart when settings change
- avoid overlapping all-provider refreshes
- never start in developer smoke-command mode

The scheduler must run only while the app process is running. It should not create launch agents, login items, or hidden daemons in Stage 3.

### Sleep, Wake, And Clock Changes

macOS may suspend timers during sleep, lid close, or aggressive power saving. On app wake or foreground activation, the scheduler should compare the current time with the last completed background refresh:

- if background refresh is enabled and the last successful or attempted automatic refresh is older than the configured interval, run one catch-up automatic refresh
- if another refresh is already in flight, do not start a second one
- if provider backoff blocks a catch-up refresh, keep the cached values and next retry time

Timer scheduling must use monotonic sleep intervals where Swift provides them, but staleness and backoff decisions must use wall-clock `Date` because they are persisted across launches. If the system clock moves backwards, do not immediately clear stale or backoff state; wait until a refresh succeeds or the persisted retry time is reached. If the system clock moves far forward, the next scheduler wake may run a catch-up refresh, still subject to the single-refresh guard.

### Foreground Refresh

Popover open should still trigger a foreground refresh for enabled, unpaused connectors, subject to backoff. This keeps the popover useful even for users who do not enable background refresh.

Manual refresh and retry should continue to bypass automatic backoff, but they must not refresh paused or disconnected connectors.

Popover-open refresh should be debounced against background refresh. If any provider completed a background refresh within the last 60 seconds, popover-open should not immediately refresh that provider again. Manual refresh and retry bypass this debounce.

### Backoff

Stage 2 backoff remains per provider:

- first failure: 5 minutes
- second failure: 15 minutes
- third and later failures: 60 minutes

Background refresh must use the same persisted backoff metadata. Manual refresh can bypass the next automatic retry time, but a failed manual refresh still increments failure count.

A successful manual refresh resets that provider's failure count and clears its next automatic retry time, exactly like a successful automatic refresh.

### Stale Evaluation

`SnapshotCache.snapshotsEvaluatingStaleness` should accept a policy rather than a fixed minute count.

Policy:

- automatic/background enabled: `max(2 * refresh interval, 15 minutes)`
- manual-only: 60 minutes

The stale reason should remain user-safe and avoid provider internals. Example: `Last update was 17 minutes ago.`

## Notification Evaluation

### Inputs

Evaluate notifications after every successful refresh and after cached snapshots are loaded.

Cache-load evaluation is state restoration, not a new quota observation. The current implementation never delivers notifications on cache load: `evaluateNotifications(suppressDelivery: true)` runs once during `loadPersistedState` so the evaluator can rebuild dedupe records from the cached snapshots without firing user-visible notifications, regardless of whether the prior notification-state file existed, decoded successfully, or was absent.

This blanket suppression is deliberate. It avoids startup notification storms when a user reopens the app to a critical state, and it keeps a corrupted notification-state file from manifesting as duplicate alerts. The trade-off is that legitimate first-time critical states observed only via the cache (no fresh refresh yet) wait for the next successful provider refresh before notifying.

If notification state decode fails, the in-memory state falls back to empty and `suppressCacheLoadNotifications` is also set so the next refresh's evaluation continues to suppress delivery for one cycle. Subsequent refreshes deliver normally.

Inputs:

- enabled provider settings
- notification settings
- current sanitized snapshots
- notification state cache
- provider/pool availability
- confidence and stale status

Do not evaluate notifications for:

- disabled providers
- paused providers
- stale snapshots
- snapshots without usable remaining/utilization data
- fallback credit pools when included quota is still available

### Pool Selection

The evaluator should classify snapshots into the same lanes as `ProviderAvailability`:

- included quota pools
- fallback credit pools

The current implementation approximates this by treating any snapshot with `unit == "utilization"` as included quota. Today's connectors satisfy this (Claude included has `unit: utilization` and `poolKey: anthropic_claude_subscription`; Codex included has `unit: utilization` and a non-credits poolKey; both fallback pools use `unit: credits`). When a future connector emits a `utilization`-unit snapshot that is not part of the included pool, this helper must be tightened to use `ProviderAvailability`'s lane definitions directly.

Notifications fire on included quota pressure only. Fallback credit pools are intentionally not notified in Stage 3, even when fallback credits hit zero — the menu bar critical state and in-app banners surface that case instead.

### Thresholds

Use remaining percentage as the threshold basis:

- if `remaining` and `limit` are known: `remaining / limit`
- if only utilization is known: `1 - utilization`
- if neither can be derived: do not notify

Threshold states:

- healthy: at or above warning threshold
- warning: below warning threshold and at or above critical threshold
- critical: below critical threshold

### Deduplication And Recovery

Notify once per provider/pool/window/threshold crossing.

Notification state should store sanitized identifiers only:

- provider id
- pool key
- window key
- last notified level
- last notified timestamp
- last observed level
- recovery timestamp when applicable

For rolling-window providers, the deduplication key should not include a moving timestamp. Use the stable provider/product/pool key and a normalized window kind such as `rolling_5h`, `rolling_7d`, or the connector's stable `windowKey` when it is already normalized. This keeps rolling windows from producing a new dedupe key on every refresh.

Recovery rules:

- warning alert can fire again only after the pool recovers to at least `warning + 5 percentage points`
- critical alert can fire again only after the pool recovers to at least `critical + 5 percentage points`
- for rolling-window providers, use recovery threshold plus a minimum 60-minute cooldown to avoid repeated alerts during churn

Reset-driven clearing (re-fire notification state when a provider crosses its discrete `resetAt`) is documented as a follow-up: today's evaluator only relies on threshold-based recovery and the rolling-window cooldown. Rolling windows are detected by a normalized window key starting with `rolling_` (e.g., `rolling_5h`, `rolling_7d`).

Critical escalation:

- if a warning notification has already fired, a later critical crossing may still fire once
- if a pool drops directly from healthy to critical, fire the critical notification; do not require a prior warning notification
- critical should not be suppressed by a previous warning notification

Dismissal behavior:

- dismissing a macOS notification does not reset notification state
- do not re-fire the same provider/pool/window level until recovery or reset rules clear that state
- if the app is still below threshold on the next refresh, keep the state suppressed

### Confidence Copy

Notification copy must include provenance without being verbose.

Examples:

- verified: `Claude Code is below 20% remaining. Verified from local Claude Code usage status.`
- observed: `Codex is below 20% remaining. Based on observed local Codex rate-limit status.`
- stale: no notification; show stale state in the app instead
- estimated: no estimated notifications in Stage 3

## Notification Delivery

Add a notification service behind a protocol.

Live implementation:

- uses `UserNotifications`
- requests permission only after user action
- schedules local notifications
- relies on macOS Focus and notification settings for interruption behavior
- bails out without contacting `UNUserNotificationCenter` when the binary is not running from a real `.app` bundle (`Bundle.main.bundleURL.pathExtension != "app"` or no `bundleIdentifier`); this keeps SPM-built CLI runs from trapping
- when permission is denied, the master toggle persists `notifications.isEnabled = false` and the per-provider/threshold controls are disabled in Settings. A System Settings deeplink (`x-apple.systempreferences:com.apple.preference.notifications`) is documented as a follow-up; today's UI does not surface a button or copy directing users to System Settings.

Test implementation:

- records requested notifications
- records permission request outcomes
- does not call macOS APIs

Stage 3 should not implement custom quiet hours unless product testing shows macOS Focus is insufficient. The settings copy can say notifications follow macOS notification and Focus settings.

## Menu Bar Indicator

When any enabled, unpaused provider has an exhausted-or-critical included quota pool, the menu bar item should expose a critical state.

Critical here is defined via `ProviderAvailability`:

- `.critical` (included pool below critical threshold, no fallback) → critical
- `.criticalWithFallback` (included pool below critical threshold, fallback positive) → critical
- `.fallbackOnly` (included pool fully exhausted, fallback positive) → critical
- `.available`, `.low`, `.stale` → not critical

Paused providers are excluded from the indicator regardless of pool state, since refresh is intentionally suspended for them.

The visual design should stay modest:

- keep the existing gauge symbol
- add a short status title or accessibility label if SwiftUI supports it cleanly
- include a visible critical affordance in the menu bar item if it can be implemented without private API or layout instability
- avoid a complex dynamic badge until the visual polish stage

The indicator must use `ProviderAvailability`, not raw worst-row state, so a healthy included pool with low fallback credits does not flip the menu bar to critical.

## Data And Privacy

Stage 3 may persist:

- notification settings
- provider-level alert enablement
- sanitized notification state for deduplication
- last notification timestamps
- pool/window identifiers already present in sanitized snapshots

Stage 3 must not persist:

- provider credentials
- provider auth state
- copied cookies
- bearer tokens
- provider session tokens
- auth headers
- raw provider responses
- prompts
- responses
- raw local databases
- notification delivery analytics

Notification content should not include sensitive local paths, raw payload values, prompt text, response text, or account identifiers.

## Architecture

### `AppSettings`

Extend notification settings from inert Stage 2 fields into active settings:

- `notifications.isEnabled`
- `notifications.warningThreshold`
- `notifications.criticalThreshold`
- `notifications.providerAlerts`

Add connector paused state separately from destructive disconnect:

- `connectors.claudeCode.isEnabled`
- `connectors.claudeCode.isPaused`
- `connectors.codex.isEnabled`
- `connectors.codex.isPaused`

Stage 3 must bump `AppSettings.schemaVersion` from `1` to `2`.

Migration rules for v1 settings:

- preserve `connectors.*.isEnabled`
- set new `connectors.*.isPaused = false`
- migrate `refresh.autoRefreshEnabled` to `false`; v1 auto-refresh only covered popover-open foreground refresh, so background refresh requires a fresh opt-in
- preserve `refresh.intervalSeconds`
- preserve `notifications.isEnabled`
- rename or map `notifications.lowThreshold` to `notifications.warningThreshold`
- if the v1 `lowThreshold` is the old default `0.30`, migrate it to the new warning default `0.20`
- if the user had changed `lowThreshold` to a non-default value, preserve that value as `warningThreshold`
- preserve `notifications.criticalThreshold`
- set both provider alert toggles to enabled regardless of v1 connector enabled state, matching the new fresh-install default
- preserve `menuBar.displayMode`

`decodeValidated` should decode v2 directly, migrate v1 into v2, and reject unknown future schema versions by falling back to safe defaults through the store. Safe defaults remain: connectors disabled, paused false, background refresh disabled, notifications disabled.

### `SnapshotCache`

Keep sanitized last-known-good snapshots.

Add or pair with a small notification-state store. Notification state can live in the snapshot cache only if that does not make the cache concept muddy. Prefer a separate `NotificationStateStore` if the implementation plan becomes clearer with a separate file.

### `StatusViewModel`

Continue to coordinate settings, cache, connector state, and refresh results.

New responsibilities:

- expose pause/resume actions
- compute stale policy from settings
- call notification evaluator after successful refresh
- keep manual refresh from running paused providers

### `BackgroundRefreshController`

Process-level controller owned by `AppModel`. Lifecycle:

- `AppModel.init` constructs the controller, wires `StatusViewModel.onSettingsChanged` to call `controller.settingsDidChange()`, then `Task { await viewModel.loadPersistedState(); controller.start() }`
- `start()` increments a generation, stops any prior timer, and only schedules a new timer when `settings.refresh.autoRefreshEnabled` is true. It also registers an `NSApplication.willBecomeActiveNotification` observer (when AppKit is available) and immediately runs one `appBecameActive()` so enabling auto-refresh does not wait a full interval for the first refresh.
- `settingsDidChange()` re-runs `start()`, which is how interval/auto-refresh-toggle changes propagate.
- `stop()` cancels the timer task and removes the activation observer.

The controller never owns settings state directly; SwiftUI views never observe it. View models trigger `settingsDidChange` via the `onSettingsChanged` callback.

### `NotificationEvaluator`

Pure Swift domain service:

- accepts sanitized snapshots, settings, prior notification state, and an optional `scopedTo` provider
- returns notification intents and the updated notification state
- when `scopedTo` is set, processes only snapshots matching that provider; cache-load and cross-provider scans pass `nil`
- callers must scope evaluator runs to the provider that just refreshed so a single-provider refresh cannot fire notifications for a different provider's cached snapshot

No macOS APIs, no I/O, no SwiftUI.

### `NotificationDelivery`

Boundary around macOS notification APIs.

The evaluator decides whether a notification should exist. The delivery service requests permission and delivers it.

## Error Handling

- If notification permission is denied, do not retry prompts automatically.
- If delivery fails, keep notification settings enabled but expose a settings status message.
- If background refresh fails, keep Stage 2 cached values and backoff behavior.
- If notification state decode fails, fall back to empty notification state; do not delete snapshot cache.
- If notification state decode fails during app startup, suppress cache-load notification delivery until the next successful provider refresh.
- If a notification state save fails, retain the in-memory state, mark it unsaved, and retry on the next evaluation. Skip retry-only saves for at least 60 seconds after the last failure to avoid log spam from persistent disk errors.
- If settings migration fails, fall back to safe defaults: connectors disabled, background refresh disabled, notifications disabled.
- If a developer smoke flag is present, skip live app model construction so persisted background refresh cannot run before smoke-command environment gates.

## Testing Strategy

Add focused tests for:

- background refresh does not start unless explicitly enabled
- background refresh runs while popover is closed
- background refresh respects paused connectors
- wake/activation catch-up refresh runs when the last automatic attempt is older than the configured interval
- popover-open refresh skips a provider refreshed by background refresh in the last 60 seconds
- manual refresh skips paused connectors
- successful manual refresh clears provider backoff
- pause keeps cached snapshots
- disconnect while paused still removes cached snapshots after confirmation
- disconnect removes cached snapshots
- disconnect removes provider notification dedupe state
- stale policy is `max(2 * interval, 15 minutes)` for automatic users
- stale policy is 60 minutes for manual-only users
- settings migration preserves v1 connector consent, migrates the old 30% notification default to 20%, and forces background refresh disabled for fresh opt-in
- notification settings defaults are 20% warning and 10% critical
- notification permission is requested only after user action
- evaluator fires warning once below 20%
- evaluator fires critical once below 10%, even after a prior warning alert
- evaluator fires critical when a pool drops directly from healthy to critical
- evaluator does not alert on stale snapshots
- evaluator does not alert for disabled or paused providers
- evaluator does not re-fire after notification dismissal until recovery or reset
- cache-load evaluation does not create startup notification storms
- evaluator suppresses repeat alerts until recovery threshold or reset
- rolling-window cooldown suppresses flapping alerts
- rolling-window dedupe keys stay stable across refreshes
- notification copy includes confidence-specific provenance
- notification state stores only sanitized provider/pool/window metadata
- a single-provider refresh does not deliver notifications for another provider's cached snapshot (scopedTo enforcement)
- notification state save retries after a transient store failure
- menu bar critical state covers `critical`, `criticalWithFallback`, and `fallbackOnly`, and ignores paused providers

Manual verification:

- enable background refresh and confirm refresh still occurs with popover closed
- sleep/wake or reactivate the Mac app and confirm a single catch-up refresh occurs when due
- enable notifications and confirm macOS permission prompt follows explicit action
- use fixture states below 20% and 10% to confirm notifications
- confirm macOS Focus controls notification interruption behavior
- pause connector and confirm cached values remain visible but no refresh/notification occurs
- disconnect connector and confirm cached values and provider notification dedupe state are removed

## Acceptance Criteria

- Background refresh works while the app is running and the popover is closed.
- Background refresh is disabled by default and requires explicit opt-in.
- v1 popover-only auto-refresh consent does not migrate into enabled background refresh.
- Smoke-command launch does not construct the live app model or start background refresh.
- Auto-refresh still respects connector consent, pause state, and provider backoff.
- Foreground and background refresh do not double-refresh providers immediately after a recent background refresh.
- Wake or app activation performs at most one catch-up refresh when background refresh is overdue.
- Pause keeps sanitized cached values and stops refresh/notifications.
- Disconnect removes sanitized cached values and notification dedupe state for that provider.
- Stale timing adapts to refresh mode.
- Stage 2 v1 settings migrate to Stage 3 v2 settings without losing enabled connector consent.
- Notifications are disabled by default and request macOS permission only after user action.
- Warning notification defaults to less than 20% remaining.
- Critical notification defaults to less than 10% remaining.
- Notifications fire once per relevant provider/pool/window threshold crossing.
- Startup cache loading does not repeatedly notify for already-notified warning/critical states.
- Dismissed notifications do not re-fire until recovery or reset.
- Notifications do not fire for stale, disabled, paused, or unsupported snapshots.
- Notification copy reflects confidence and does not overclaim observed data.
- No raw provider data or credentials are stored or included in notification content.

## Open Decisions

None before implementation planning. The review risks around migration, threshold naming, sleep/wake, startup notification storms, foreground/background overlap, manual backoff reset, dismissal, direct critical drops, rolling-window keys, pause/disconnect edge cases, and permission-denial recovery are resolved above.

The first implementation plan should keep the UI provider-level and the evaluator pool-level. Advanced per-pool alert controls can be a later spec after users have tried the simpler flow.
