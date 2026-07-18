# Privacy Boundaries

Date: 2026-05-04

WhatTheToken is local-first and minimal-data by default. Local ingestors may observe usage signals, but they must emit only sanitized usage events and snapshots that match `docs/architecture/data-contract.md`.

Product promise:

> Provider credentials stay on the user's device. WhatTheToken syncs only usage status.

## Must Never Collect

WhatTheToken must never collect, persist, sync, log, or fixture:

- prompts
- completions
- model responses
- conversation content
- conversation URLs
- cookies
- auth headers
- bearer tokens
- provider session tokens
- browser request bodies
- provider credentials
- API keys
- access tokens
- authorization values
- secrets
- raw local database rows that include any forbidden field above
- raw browser storage dumps

This deny list applies to production code, tests, fixtures, logs, debug output, analytics, support bundles, and documentation examples.

## Allowed Sanitized Usage Data

The product may collect sanitized usage metadata required to derive quota status:

- provider
- product
- surface
- model key when detectable without reading conversation content
- event type
- usage count, utilization, request amount, token amount, or credit amount
- observed timestamp
- quota reset timestamp
- non-secret user, device, provider-account, pool, and window identifiers
- confidence level
- freshness and stale reason
- undercount risk
- source or parser version
- sync or parser error status
- limited attribution such as operating system or browser family

Identifiers must be stable enough for deduplication and display, but they must not be copied from provider secrets or session tokens.

## Local Connector Credential Rules

Local connectors may read provider state only after explicit user opt-in.

When a connector needs a local provider credential or token to retrieve usage status:

- use the credential or token only in memory
- discard the credential or token after the request
- do not log the credential or token
- do not persist the credential or token in WhatTheToken storage
- do not upload the credential or token to any backend
- do not expose the credential or token to the browser extension
- sync or expose only sanitized usage snapshots and source states

For Claude Code, the Mac connector may read the local Claude Code Keychain item with explicit user consent and use the OAuth access token in memory to request usage status from Anthropic. The current implementation isolates Keychain access behind a local command runner. The runner invokes `/usr/bin/security find-generic-password -s "Claude Code-credentials" -w`, bounds the lookup with a timeout, and returns either command output or a local connector error. The credential parser extracts only `claudeAiOauth.accessToken`; all persisted and synced output remains limited to sanitized snapshot data.

The product UI starts disconnected and must not read Claude credentials on launch. The `Connect Claude Code` action is the first product path that may refresh the Claude connector. App startup may construct connector dependencies, but it must not call the refresher, run `claude --version`, invoke the Keychain command, or call Anthropic until the user chooses to connect. While a refresh is already checking, duplicate connect attempts are ignored so repeated user actions cannot start overlapping provider requests.

The developer-only Claude smoke command must follow the same boundary. It requires `CLAUDE_CODE_VERSION` before it reads credentials or calls Anthropic, runs only when explicitly invoked with `--claude-connector-smoke`, and prints only sanitized connector state plus snapshot summaries. Smoke launch must skip live `AppModel` construction so persisted background refresh cannot start before the smoke command's explicit environment gate. The smoke command must not print tokens, authorization headers, raw provider JSON, local file contents, prompts, responses, session data, or sensitive local paths.

Diagnostics must redact provider credentials, tokens, sensitive local paths, and raw provider payloads.

The product benefit is not "we never touch credentials anywhere." The accurate claim is:

> Provider credentials stay local. WhatTheToken syncs only sanitized usage status.

This lets users get higher-confidence Claude Code and Codex status without pasting provider tokens into a website, granting backend access to provider accounts, or creating separate provider credentials just to see subscription usage.

For Codex, the Mac connector does not read a Codex credential file or own a Codex credential store. After explicit user opt-in, it starts or connects to the local Codex app-server and requests `account/rateLimits/read`. Codex authentication stays inside Codex/app-server; WhatTheToken decodes only sanitized rate-limit metadata and discards the raw JSON-RPC response after parsing.

Codex executable discovery is not credential discovery. The resolver checks the launched app's `PATH` plus common local install paths such as `~/.local/bin/codex`, `/opt/homebrew/bin/codex`, and `/usr/local/bin/codex` so a Finder-launched app can find the local Codex binary. It must not inspect Codex config files, auth files, shell history, sessions, prompts, responses, or app-server logs while locating the executable.

The developer-only Codex smoke command must follow the same boundary. It requires `CODEX_CONNECTOR_SMOKE=1` before starting Codex app-server, runs only when explicitly invoked with `--codex-connector-smoke`, and prints only sanitized connector state plus snapshot summaries. Smoke launch must skip live `AppModel` construction so persisted background refresh cannot start before the smoke command's explicit environment gate. It must not print account email, tokens, authorization values, raw JSON-RPC envelopes, raw app-server logs, prompts, responses, command output, local paths, task titles, task summaries, or token-shaped strings.

## Local Persistence, Refresh, And Disconnect

The Mac app may persist only local app state and sanitized usage status:

- `settings.json`: connector consent and pause state, refresh preferences, notification preferences (master toggle, warning/critical thresholds, per-provider toggles), and menu bar display preferences
- `snapshot-cache.json`: sanitized usage snapshots, last successful refresh timestamps, and sanitized provider error/backoff state
- `notification-state.json`: sanitized provider/pool/window notification dedupe state and last notification timestamps

These files live in the app's Application Support directory. They must not contain provider credentials, copied OAuth tokens, raw provider payloads, prompts, responses, cookies, auth headers, provider session tokens, raw local database rows, or sensitive local paths.

Connector consent is separate from refresh. Enabling a connector allows future reads for that provider. Pausing a connector stops manual and automatic refresh while keeping sanitized cached values visible. Manual refresh may run only for enabled, unpaused connectors. Popover-open refresh is an automatic refresh trigger and must respect provider backoff. Timer-based background refresh is optional, off by default, and must run only while the app process is running after explicit user opt-in. v1 popover-only auto-refresh settings must migrate to background refresh disabled so old foreground consent does not become background consent.

Refresh must preserve previously visible sanitized values when available. The UI may show a small updating indicator, but it must not blank the provider view during a refresh with cached or last-known values. Last-updated copy belongs in the footer; provider section trust lines should not duplicate the timestamp.

Disconnect is the privacy boundary for local retention. Disconnecting a provider must disable future reads and remove that provider's cached usage snapshots and notification dedupe state from WhatTheToken storage. The app must not present disconnect as complete unless the cache write, the settings write, and the notification-state write all succeed. If any of those writes fails, the in-memory and on-disk state are rolled back to "still connected" so the UI does not claim cached data was removed.

## Local Ingestor Rules

- Prefer parsing local quota/status files or direct local client signals over inspecting authenticated browser traffic.
- If a source can contain forbidden data, parse only the minimal fields needed and discard the raw source immediately.
- Do not log raw provider responses or local file contents.
- Claude schema-drift reports may include only the failure category and sorted top-level/affected field names. They must never include the response body, usage values, reset timestamps, credentials, headers, account identifiers, or local paths. Sentry automatic crash, session, performance, network, hang, swizzling, and breadcrumb collection must remain disabled for this integration.
- The notifications subsystem may use `os_log` (subsystem `app.whatthetoken.mac`, category `notifications`) for save/load/delivery failures. Error descriptions must be interpolated as `privacy: .private` so local file paths surfaced by Cocoa errors are not exposed in `log show` or `sysdiagnose`. Sanitized identifiers such as notification intent IDs may be `privacy: .public`.
- Treat parser failures as health states with confidence/freshness impact, not as a reason to collect broader data.
- Label numbers with confidence, freshness, and undercount risk close to where users see the number.

## Source States

Connectors should report structured source states instead of raw provider or OS errors:

- `not_connected`
- `missing_credentials`
- `permission_denied`
- `token_invalid`
- `rate_limited`
- `network_error`
- `schema_changed`
- `stale`

Surfaces should translate these states into product language without exposing raw provider responses, local paths, credentials, or tokens.

## V1 Security Baseline

Ship these controls from the start:

- explicit opt-in before reading local provider state
- explicit opt-in before background refresh while the app process is running
- no backend storage of provider credentials
- no Chrome extension access to local Keychain values
- no local or remote logging of tokens, prompts, responses, or session contents
- bounded local credential lookup so connector refresh cannot hang indefinitely
- product UI starts disconnected and refreshes providers only after connect, manual refresh, foreground popover refresh, or explicit background-refresh opt-in
- duplicate connect attempts do not start overlapping Claude refreshes
- developer-only smoke testing stays local/manual, skips live app construction, and prints sanitized status only
- fixture-based tests only, with synthetic usage data
- confidence, freshness, and source labels on every status value

## Future Privacy Hardening

After the first useful local connector works, evaluate a dedicated hardening phase:

- signed and notarized Mac connector distribution
- hardened runtime and sandbox review
- signed auto-updates
- local encrypted cache for connector state
- redacted diagnostic export that users can inspect before sharing
- optional end-to-end encryption for synced snapshots if product research shows users consider usage metadata sensitive enough to justify the added complexity
- independent security review before paid beta or broader launch

Do not add these as invisible scope creep to Phase 1. Keep the V1 privacy baseline strict, then make advanced hardening a deliberate product milestone.

## Change Control

Any future change that weakens the deny list, allows a new sensitive data category, or requires broader local/browser permissions requires an ADR before implementation.

Any future legal privacy policy must be consistent with this engineering boundary, but this document is not a substitute for legal review.
