# Notifications And Background Freshness Design

Date: 2026-05-08

Status: proposed Stage 3 spec after Stage 2 refresh/cache implementation landed in `main`.

## Purpose

Stage 3 turns WhatTheToken from a status surface the user checks manually into a lightweight local guardrail that can warn before quota interrupts work.

Stage 2 already added persisted connector consent, sanitized last-known-good cache, stale evaluation, explicit auto-refresh, backoff, and no-flicker refresh. Its auto-refresh is scoped to the popover being open. That is useful for continuity while looking at the app, but it is not enough for notifications: a user cannot receive a timely low-quota warning if refresh only runs after they click the menu bar item.

Stage 3 therefore has two linked goals:

- keep enabled connectors fresh in the background while the menu bar app is running, after explicit user opt-in
- notify once when enabled providers cross user-configurable low and critical thresholds

## Stage Boundary

In scope:

- background auto-refresh while the app process is running, not only while the popover is open
- explicit opt-in controls for background refresh and notifications
- separate Pause and Disconnect connector actions
- adaptive stale timing based on refresh mode
- notification permission flow
- low and critical notification thresholds, defaulting to 20% and 10%
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

- low warning: remaining usage below 20%
- critical warning: remaining usage below 10%

The existing visual health model may still use `low < 30%` for in-app caution. Notifications should be less noisy and more action-oriented.

### Provider-Level UI, Pool-Level Engine

The first settings UI should be provider-level: users enable notifications for Claude Code and/or Codex without configuring every quota pool.

The notification evaluator should still operate per pool/window internally. If Claude has multiple windows, or Codex exposes multiple buckets, a low state in any included quota pool can trigger a provider notification. This preserves correctness while keeping the first UI simple.

## User Flow

### First-Time Notification Setup

Settings gets an `Alerts` section below Refresh.

Default state:

- notifications disabled
- low threshold 20%
- critical threshold 10%
- provider alerts enabled for each enabled connector by default once notifications are enabled

When the user turns notifications on:

1. Show a short in-app explanation: WhatTheToken can alert when enabled providers drop below low or critical usage.
2. Request macOS notification permission.
3. If permission is granted, persist `notifications.isEnabled = true`.
4. If permission is denied, keep in-app alert settings visible but show a disabled/needs-permission state with a button or copy pointing to System Settings.

The app must not request notification permission on first launch or connector connect. The prompt should follow an explicit notifications action.

### Alert Controls

The first UI should avoid advanced per-pool tuning.

Controls:

- master toggle: `Notify me before quota runs low`
- low threshold stepper or menu: default 20%, allowed range 10-50%
- critical threshold stepper or menu: default 10%, allowed range 1-25%
- provider toggles: Claude Code, Codex

Validation:

- critical threshold must be lower than low threshold
- if the user lowers low below critical, clamp critical to one step below low
- if the user raises critical above low, raise low to one step above critical

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

The scheduler must run only while the app process is running. It should not create launch agents, login items, or hidden daemons in Stage 3.

### Foreground Refresh

Popover open should still trigger a foreground refresh for enabled, unpaused connectors, subject to backoff. This keeps the popover useful even for users who do not enable background refresh.

Manual refresh and retry should continue to bypass automatic backoff, but they must not refresh paused or disconnected connectors.

### Backoff

Stage 2 backoff remains per provider:

- first failure: 5 minutes
- second failure: 15 minutes
- third and later failures: 60 minutes

Background refresh must use the same persisted backoff metadata. Manual refresh can bypass the next automatic retry time, but a failed manual refresh still increments failure count.

### Stale Evaluation

`SnapshotCache.snapshotsEvaluatingStaleness` should accept a policy rather than a fixed minute count.

Policy:

- automatic/background enabled: `max(2 * refresh interval, 15 minutes)`
- manual-only: 60 minutes

The stale reason should remain user-safe and avoid provider internals. Example: `Last update was 17 minutes ago.`

## Notification Evaluation

### Inputs

Evaluate notifications after every successful refresh and after cached snapshots are loaded.

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

The evaluator should classify snapshots into the same lanes used by `ProviderAvailability`:

- included quota pools
- fallback credit pools

Notifications should fire on included quota pressure first. Fallback-only states may produce different copy later, but Stage 3 should not alert on zero fallback credits while included quota is healthy.

### Thresholds

Use remaining percentage as the threshold basis:

- if `remaining` and `limit` are known: `remaining / limit`
- if only utilization is known: `1 - utilization`
- if neither can be derived: do not notify

Threshold states:

- healthy: at or above low threshold
- low: below low threshold and at or above critical threshold
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

Recovery rules:

- low alert can fire again only after the pool recovers to at least `low + 5 percentage points`
- critical alert can fire again only after the pool recovers to at least `critical + 5 percentage points`
- if a provider has a discrete `resetAt`, recovery after reset also clears notification state for that pool/window
- for rolling-window providers, use recovery threshold plus a minimum 60-minute cooldown to avoid repeated alerts during churn

Critical escalation:

- if a low notification has already fired, a later critical crossing may still fire once
- critical should not be suppressed by a previous low notification

### Confidence Copy

Notification copy must include provenance without being verbose.

Examples:

- verified: `Claude Code is below 20% remaining. Verified from local Claude Code usage status.`
- observed: `Codex is below 20% remaining. Based on observed local Codex rate-limit status.`
- stale: no notification; show stale state in the app instead
- estimated: reserve copy shape for future providers; do not emit estimated notifications in Stage 3 unless a Stage 3 implementation explicitly introduces estimated snapshots

## Notification Delivery

Add a notification service behind a protocol.

Live implementation:

- uses `UserNotifications`
- requests permission only after user action
- schedules local notifications
- relies on macOS Focus and notification settings for interruption behavior

Test implementation:

- records requested notifications
- records permission request outcomes
- does not call macOS APIs

Stage 3 should not implement custom quiet hours unless product testing shows macOS Focus is insufficient. The settings copy can say notifications follow macOS notification and Focus settings.

## Menu Bar Indicator

When any enabled, unpaused provider has a critical included quota pool, the menu bar item should expose a critical state.

The visual design should stay modest:

- keep the existing gauge symbol
- add a short status title or accessibility label if SwiftUI supports it cleanly
- avoid a complex dynamic badge until the visual polish stage

The indicator must use `ProviderAvailability`, not raw worst-row state, so fallback credits do not make a provider look critical while included quota is healthy.

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
- `notifications.lowThreshold`
- `notifications.criticalThreshold`
- `notifications.providerAlerts`

Add connector paused state separately from destructive disconnect:

- `connectors.claudeCode.isEnabled`
- `connectors.claudeCode.isPaused`
- `connectors.codex.isEnabled`
- `connectors.codex.isPaused`

If a migration is required, existing Stage 2 users should keep enabled connectors enabled and unpaused.

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

New process-level controller owned by `AppModel`.

It should observe settings through explicit method calls from `StatusViewModel` or a lightweight callback. Avoid making SwiftUI views responsible for background scheduling.

### `NotificationEvaluator`

Pure Swift domain service:

- accepts sanitized snapshots and settings
- returns notification intents
- updates notification state

No macOS APIs, no I/O, no SwiftUI.

### `NotificationDelivery`

Boundary around macOS notification APIs.

The evaluator decides whether a notification should exist. The delivery service requests permission and delivers it.

## Error Handling

- If notification permission is denied, do not retry prompts automatically.
- If delivery fails, keep notification settings enabled but expose a settings status message.
- If background refresh fails, keep Stage 2 cached values and backoff behavior.
- If notification state decode fails, fall back to empty notification state; do not delete snapshot cache.
- If settings migration fails, fall back to safe defaults: connectors disabled, background refresh disabled, notifications disabled.

## Testing Strategy

Add focused tests for:

- background refresh does not start unless explicitly enabled
- background refresh runs while popover is closed
- background refresh respects paused connectors
- manual refresh skips paused connectors
- pause keeps cached snapshots
- disconnect removes cached snapshots
- stale policy is `max(2 * interval, 15 minutes)` for automatic users
- stale policy is 60 minutes for manual-only users
- notification settings defaults are 20% and 10%
- notification permission is requested only after user action
- evaluator fires low once below 20%
- evaluator fires critical once below 10%, even after a prior low alert
- evaluator does not alert on stale snapshots
- evaluator does not alert for disabled or paused providers
- evaluator suppresses repeat alerts until recovery threshold or reset
- rolling-window cooldown suppresses flapping alerts
- notification copy includes confidence-specific provenance
- notification state stores only sanitized provider/pool/window metadata

Manual verification:

- enable background refresh and confirm refresh still occurs with popover closed
- enable notifications and confirm macOS permission prompt follows explicit action
- use fixture states below 20% and 10% to confirm notifications
- confirm macOS Focus controls notification interruption behavior
- pause connector and confirm cached values remain visible but no refresh/notification occurs
- disconnect connector and confirm cached values are removed

## Acceptance Criteria

- Background refresh works while the app is running and the popover is closed.
- Background refresh is disabled by default and requires explicit opt-in.
- Auto-refresh still respects connector consent, pause state, and provider backoff.
- Pause keeps sanitized cached values and stops refresh/notifications.
- Disconnect removes sanitized cached values for that provider.
- Stale timing adapts to refresh mode.
- Notifications are disabled by default and request macOS permission only after user action.
- Low notification defaults to less than 20% remaining.
- Critical notification defaults to less than 10% remaining.
- Notifications fire once per relevant provider/pool/window threshold crossing.
- Notifications do not fire for stale, disabled, paused, or unsupported snapshots.
- Notification copy reflects confidence and does not overclaim observed data.
- No raw provider data or credentials are stored or included in notification content.

## Open Decisions

None before implementation planning.

The first implementation plan should keep the UI provider-level and the evaluator pool-level. Advanced per-pool alert controls can be a later spec after users have tried the simpler flow.
