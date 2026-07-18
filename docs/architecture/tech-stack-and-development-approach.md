# Tech Stack And Development Approach

Date: 2026-05-04

## Product Direction

WhatTheToken is a Mac-first developer consumption monitor for AI coding tools.

V1 starts with Claude Code and Codex because both now have explicit local connector paths that can return sanitized quota status after user opt-in. Browser assistants and other developer tools expand the same shared status model later.

## Tech Stack

| Area | Choice | Reason |
|---|---|---|
| Mac app | SwiftUI | Best fit for a native menu bar/status app, Keychain, notifications, login items, and future Apple-platform touchpoints |
| Shared domain core | TypeScript package | Fast TDD loop for quota math, schemas, confidence labels, stale detection, and future web/extension reuse |
| Package manager | pnpm workspaces pinned with `packageManager: pnpm@10.0.0` | Simple monorepo management for TypeScript packages and future web/extension apps, with deterministic lockfile behavior across parallel worktrees |
| TypeScript tests | Vitest | Fast unit tests for pure domain logic |
| Type validation | Zod | Runtime validation for events, snapshots, and ingestor payloads |
| Web dashboard later | Next.js | Good default for auth/dashboard when sync becomes active scope |
| Backend later | Supabase Postgres/Auth/Realtime | Fastest path to multi-device sync with relational data and RLS |
| Browser extension later | WXT | Modern TypeScript-first Chrome extension framework |
| Payments later | Stripe | Standard SaaS billing |
| Schema-drift reporting | Sentry Cocoa | Manual, redacted Claude parser errors only; automatic SDK collection is disabled |

## Development Approach

Use TDD for behavior changes:

1. Write a failing test.
2. Run the focused test and confirm the expected failure.
3. Implement the minimum code.
4. Run the focused test and confirm it passes.
5. Run package-level checks.
6. Commit a small coherent change.

For workspace-foundation tasks:

1. Verify the package manager before installing dependencies. `pnpm --version` must match the root `packageManager` declaration exactly.
2. Use Corepack to activate the pinned pnpm version when the local version differs.
3. Treat `pnpm-lock.yaml` as a reviewed source artifact. Inspect lockfile changes before committing.
4. Treat root workspace scaffolding as a dependency barrier for parallel Conductor work. Core, Mac, documentation, and provider-spike worktrees should branch from a base that already includes the workspace scaffold.

For TypeScript package tasks:

1. Keep package entrypoints and emitted files aligned. If `package.json` points at `dist`, the package must expose a build script that writes `dist`.
2. Use explicit `exports` for package boundaries instead of relying only on `main`.
3. Use `.js` runtime specifiers in TypeScript source for ESM files that compile to Node-loadable JavaScript.
4. Verify package boundaries with both `pnpm --filter <package> build` and a direct Node import from the package directory when adding or changing entrypoints.

## Architecture Rules

- Keep quota math, confidence logic, stale detection, deduplication, and snapshot derivation in `packages/core`.
- Treat `packages/core/src/schemas.ts` as the runtime contract for sanitized usage events and snapshots.
- Treat `docs/architecture/data-contract.md` as the human-readable companion to `packages/core/src/schemas.ts`.
- Review `docs/architecture/privacy-boundaries.md` before changing ingestion, sync, fixtures, logs, analytics, or quota UI.
- Keep provider-specific ingestion code isolated under the app or provider package that owns it.
- Keep SwiftUI views thin. Views render state; domain decisions belong in model/controller code or shared schemas.
- Use provider/product/surface taxonomy everywhere.
- Model budgets and pools, not just message counts.
- Never collect prompts, responses, conversation content, cookies, bearer tokens, auth headers, or provider session tokens.

## Frontend Trust Messaging

When frontend work starts, make secure local collection part of the primary product language rather than buried help text.

Use copy in this direction:

- "Provider credentials stay on your device."
- "WhatTheToken syncs only usage status."
- "Claude Code and Codex can be connected through the Mac connector for higher-confidence local tracking."
- "Estimated browser counters are labeled separately from verified local signals."

Avoid claims that are too broad:

- Do not say "we never access credentials"; the local connector may access them in memory.
- Do not say "fully private" without explaining what is and is not synced.
- Do not hide confidence labels behind tooltips or settings screens.

## Phase 1 Stack Boundary

Phase 1 should create:

- `packages/core`: TypeScript schemas and quota logic.
- `apps/mac`: SwiftUI status app shell plus Claude Code and Codex local connector boundaries.
- `docs`: implementation notes, ADRs, and operating rules.

Phase 1 should not create:

- Supabase backend.
- Next.js dashboard.
- Chrome extension.
- iOS app.
- Payments.
- Production analytics.

Those are valuable, but they are not needed to prove the first Mac-visible developer quota/status signal.

## Current Claude Connector Boundary

The Mac app owns Claude-specific ingestion code under `apps/mac/Sources/WhatTheTokenMac/Claude`.

The connector is responsible for:

- reading the Claude Code Keychain credential locally only after opt-in
- using the OAuth token in memory to request Anthropic usage
- passing a detected or injected Claude Code version into the usage request
- dynamically mapping every top-level utilization window (including `five_hour`, `seven_day`, and model windows such as `seven_day_fable`) plus enabled `extra_usage` credit data into sanitized snapshots
- returning structured connector states for missing credentials, invalid tokens, rate limits, network errors, and schema changes
- reporting total or partial schema drift to Sentry using field names and a failure category only, never the response body or usage values

## Claude Connector Product Opt-In

The Mac app now starts with a live `StatusViewModel` and an explicit `Connect Claude Code` action instead of fixture snapshots. App startup injects the Claude connector dependencies but does not refresh the connector, read the Keychain item, run `claude --version`, or call Anthropic.

The user-initiated connect action is the first product path that may refresh Claude Code usage. During refresh, the app can read the installed Claude CLI version locally, read the Claude Code Keychain item locally, call the Anthropic usage endpoint with the OAuth token in memory, and render only sanitized `UsageSnapshot` values plus connector status copy.

The Claude CLI version resolver checks the launched app's `PATH` and common local install paths such as `~/.local/bin/claude`, `/opt/homebrew/bin/claude`, and `/usr/local/bin/claude`, because packaged Mac apps may start with a restricted environment. Duplicate connect attempts while a refresh is already checking are ignored so one user action cannot start overlapping provider refreshes.

The connector setup titles and trust message live in a tested copy helper so product-facing opt-in language stays consistent across disconnected, checking, connected, unavailable, and error states.

Automated tests use stub refreshers and version-command runners. They must not call the live Claude CLI, read Keychain credentials, or call Anthropic. A bounded local GUI launch smoke can be run manually with `swift run WhatTheTokenMac` to verify the app starts and renders. With default settings it must not trigger connector refresh; with persisted background refresh enabled, it may refresh enabled, unpaused connectors after launch.

## Current Codex Connector Boundary

The Mac app owns Codex-specific ingestion code under `apps/mac/Sources/WhatTheTokenMac/Codex`.

The connector is responsible for:

- starting the local Codex app-server only after opt-in
- sending JSON-RPC 2.0 initialization plus `account/rateLimits/read`
- decoding only rate-limit fields such as `limitId`, `limitName`, `primary`, `secondary`, `planType`, `rateLimitReachedType`, and `credits`
- mapping returned buckets into sanitized `UsageSnapshot` records with `provider: openai`, `product: codex`, `surface: aggregate`, and `unit: utilization` or `credits`
- deriving Codex row labels from app-server fields instead of hardcoding current model names
- returning structured connector states for missing login, app-server launch failure, transport failure, and schema changes

The connector must not parse `~/.codex` files, conversation/session/history stores, shell snapshots, prompts, responses, task titles, task summaries, auth files, cookies, or local command output. Codex authentication stays inside Codex/app-server; WhatTheToken does not own a Codex credential store.

## Codex Connector Product Opt-In

The Mac app starts with an explicit `Connect Codex` action. App startup injects Codex connector dependencies but does not start Codex app-server, read Codex auth state, or request rate limits until the user chooses to connect.

The user-initiated connect action is the first product path that may start Codex app-server. During refresh, the app can launch the local Codex executable, call the app-server rate-limit method over stdio, and render only sanitized snapshots plus connector status copy. If app-server reports auth failure, product copy directs the user to sign in to Codex locally with `codex login`.

The Codex executable resolver checks the launched app's `PATH` and common local install paths such as `~/.local/bin/codex`, `/opt/homebrew/bin/codex`, and `/usr/local/bin/codex`, because packaged Mac apps may start with a restricted environment. If no executable can be found or started, the connector reports `permission_denied` without exposing local paths in UI or smoke output. Duplicate connect attempts while a refresh is already checking are ignored so one user action cannot start overlapping app-server reads.

Automated tests use stub app-server transports and rate-limit fetchers. They must not call live Codex, start app-server, inspect `~/.codex`, or depend on a signed-in OpenAI account. Local live validation stays behind the manual smoke command below.

## Local Mac App Run

Run the Mac app locally through Swift Package Manager:

```bash
cd apps/mac
swift run WhatTheTokenMac
```

The SwiftPM target is a Mach-O executable, not an `.app` bundle. Interactive launch sets `NSApplication` activation policy to `.accessory` so the app behaves as a menu-bar-only utility with no Dock icon; the menu bar item appears immediately. The `--developer-window` flag opts into `.regular` activation for the DEBUG developer window. The `--claude-connector-smoke` and `--codex-connector-smoke` paths skip both activation and live `AppModel` construction, returning before any persisted background refresh can start.

For deterministic fixture UI checks, inject a fixture-backed `StatusViewModel` through `AppModel` in a temporary local patch, run the command above, then restore the live app model before committing.

The usage area renders one row-based section per provider/product pair, so Claude Code and Codex snapshots do not share a mixed card. Each section hoists uniform trust metadata, uses local time for updated/reset copy, refreshes reset hints every minute in the UI, and keeps existing values visible while foreground or opted-in background refresh is running.

## Claude Connector Smoke Testing

The Mac app includes a developer-only Claude connector smoke path behind the explicit `--claude-connector-smoke` flag. It is for local manual verification only and must not run in CI because it can read the local Claude Code Keychain item and call Anthropic's usage endpoint.

Before running the smoke command, set `CLAUDE_CODE_VERSION` from the installed Claude CLI version. If the variable is missing, the command exits before credential access or networking.

Example:

```bash
cd apps/mac
CLAUDE_CODE_VERSION="$(claude --version | awk '{print $1}')" swift run WhatTheTokenMac --claude-connector-smoke
```

Expected output is limited to sanitized status and snapshot summary lines. It must not print the OAuth token, authorization header, raw provider response, local file contents, prompts, responses, or session data.

## Codex Connector Smoke Testing

The Mac app includes a developer-only Codex connector smoke path behind the explicit `--codex-connector-smoke` flag. It is for local manual verification only and must not run in CI because it starts the local Codex app-server and depends on the user's local Codex login state.

Before running the smoke command, set `CODEX_CONNECTOR_SMOKE=1`. If the variable is missing, the command exits before starting Codex app-server.

Example:

```bash
cd apps/mac
CODEX_CONNECTOR_SMOKE=1 swift run WhatTheTokenMac --codex-connector-smoke
```

Expected output is limited to sanitized status and snapshot summary lines. It must not print account email, tokens, authorization values, raw JSON-RPC envelopes, raw app-server logs, prompts, responses, command output, local paths, task titles, task summaries, or token-shaped strings.

Successful local smoke currently proves only the signed-in account's Codex app-server shape. Keep Codex snapshots at `confidence: observed` and `undercountRisk: possible` until product validation confirms these buckets are authoritative across Codex surfaces. ChatGPT remains out of scope for the Codex connector unless the app-server returns unambiguous ChatGPT-specific buckets.

## Persistence, Refresh, And Notifications Architecture

Stage 2 and Stage 3 added a small set of view-model-owned services that sit between SwiftUI and the connectors. None of them call provider APIs directly.

- `AppSettings` (Codable, schema v2) — persists connector consent and pause state, refresh preferences, notification preferences (master toggle, warning/critical thresholds, per-provider toggles), and menu bar display preferences. `decodeValidated` migrates v1 → v2 (forces `autoRefreshEnabled = false`, renames `lowThreshold` to `warningThreshold`, defaults provider alerts to true). Unknown future versions throw and the store falls back to safe defaults.
- `SnapshotCache` — sanitized last-known-good snapshots, `lastSuccessfulRefreshAtByProvider`, and per-provider failure/backoff metadata. `SnapshotStalePolicy.from(settings:)` returns `max(2 * interval, 15 min)` when auto-refresh is on and 60 minutes otherwise.
- `NotificationState` — sanitized dedupe records keyed by provider/normalized-pool/normalized-window. `NotificationDedupeKey.storageKey` is stable across refreshes; rolling-window keys collapse `300m` → `rolling_5h`, `10080m`/`seven_day` → `rolling_7d`. `JSONFileNotificationStateStore` writes atomically and emits `os_log` warnings on failure with `privacy: .private` interpolation.
- `BackgroundRefreshController` — owned by `AppModel`, runs only when `settings.refresh.autoRefreshEnabled` is true. `start()` schedules the timer, registers an `NSApplication.willBecomeActiveNotification` observer, and runs an immediate `appBecameActive()` so opting in does not wait a full interval. `appBecameActive()` skips refresh if a previous automatic attempt was within the configured interval and another refresh is already in flight.
- `PopoverRefreshController` — popover-open and manual refresh. `recentlyBackgroundRefreshed(_:)` debounces `.popoverOpened` refreshes for providers refreshed by the background timer in the last 60 seconds; `.manual` and `.retry` bypass the debounce and provider backoff but still skip paused providers.
- `NotificationEvaluator` — pure Swift. Accepts snapshots, settings, prior state, and an optional `scopedTo` provider. Single-provider refreshes pass `scopedTo: .claude` or `.codex` so a Claude refresh cannot fire a Codex notification for a stale-but-not-yet-stale cached snapshot. Cache-load and bulk evaluations pass `nil`. Recovery rules require `threshold + 5pp` plus a 60-minute cooldown for rolling windows.
- `NotificationDelivery` — protocol around `UserNotifications`. The live `UserNotificationDelivery` short-circuits to `.denied` when not running from a real `.app` bundle so SPM-built CLI runs do not trap. `RecordingNotificationDelivery` is the test double.
- `StatusViewModel` — coordinator. `evaluateNotifications(suppressDelivery: true)` runs once on cache load (blanket suppression). After each successful provider refresh, `evaluateNotifications(suppressDelivery: false, scopedTo: .claude/.codex)` runs. Notification-state save failures set `unsavedNotificationState`; the next evaluation retries once at least 60 seconds have passed since the last failure.
- `PopoverChromeState.hasCriticalProvider(viewModel:)` — drives the menu bar critical state. Treats `.critical`, `.criticalWithFallback`, and `.fallbackOnly` from `ProviderAvailability` as critical; paused providers are excluded.

Disconnect is the privacy boundary: it sequentially writes the snapshot cache, the settings file, and the notification-state file. If any write fails, the prior on-disk state is restored and the UI stays connected.

## Connector Verification Commands

Use focused tests first, then package-level verification:

```bash
cd apps/mac
swift test --filter Codex
swift test

cd ../..
pnpm --filter @whatthetoken/core test
```

Run live smoke commands manually only on a developer machine with explicit opt-in environment variables. Do not add live Claude, live Codex, Keychain, or app-server dependencies to CI.
