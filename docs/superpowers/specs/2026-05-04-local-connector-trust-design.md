# Local Connector Trust Design

Date: 2026-05-04

## Goal

Design the secure local connector path that lets WhatTheToken show Claude Code, Codex, and browser assistant usage in one unified status surface without uploading provider credentials, prompts, responses, cookies, or session tokens.

The product promise is:

> Provider credentials stay local. WhatTheToken syncs only usage status.

## Context

The current product direction is developer-first and local-first. Claude Code and Codex are the first priority products, with ChatGPT and Gemini browser counters later. The repo already has:

- shared `UsageEvent` and `UsageSnapshot` schemas in `packages/core`
- a fixture-backed SwiftUI Mac status surface
- research spikes for Claude Code and Codex local signal availability
- privacy and confidence-label ADRs

The referenced `bramveen1/claude-usage-widget` proves a practical Claude path: read Claude Code's local macOS Keychain credential, extract `claudeAiOauth.accessToken`, call Anthropic's undocumented OAuth usage endpoint, and render utilization windows. That approach gives better Claude subscription status than browser send counting, but it must be treated as a local credential trust boundary.

## Product Decision

Use a Chrome-first unified product surface plus an optional Mac connector.

The Chrome extension should become the primary lightweight status surface and onboarding entry point. The Mac connector should not be positioned as a separate product. It is a local connector that unlocks higher-confidence Claude Code and Codex signals.

All surfaces must read from the same normalized snapshot set:

- Chrome extension popover
- Mac menu bar/status app
- web dashboard
- future mobile widgets

The user should see one product with multiple connected sources, not separate dashboards per connector.

## Architecture

### Surfaces

Surfaces display status. They should not define provider-specific collection behavior.

- Chrome extension: primary compact dashboard, browser assistant ingestor, connector onboarding.
- Mac connector: local Claude Code and Codex ingestor, optional menu bar status surface.
- Web dashboard: account, device, diagnostics, and larger status history surface after sync exists.

### Ingestors

Ingestors collect signals and produce sanitized snapshots.

- Claude Code local connector: uses local Claude Code credential in memory to poll Anthropic usage.
- Codex local connector: observes approved local Codex metadata or invocation state after schema review.
- Browser extension counters: observe send/model activity on supported provider websites and produce estimated browser snapshots.

### Shared Store

The shared store is the source of truth for surfaces. It may be local-only at first, then backed by Supabase sync.

The store contains:

- provider/product/surface
- pool and window keys
- unit, used, limit, remaining, utilization
- reset and freshness timestamps
- confidence and undercount risk
- source/parser version and device attribution

The store must not contain:

- provider credentials
- OAuth access or refresh tokens
- cookies
- bearer tokens
- prompts
- responses
- conversation contents
- browser request bodies

## Claude Code Collection

The Mac connector may support Claude Code collection with explicit user consent.

Collection flow:

1. User enables "Connect Claude Code" from onboarding or connector settings.
2. Mac connector checks whether Claude Code credentials exist in macOS Keychain.
3. Connector reads the Claude Code Keychain item locally.
4. Connector parses the credential JSON and extracts `claudeAiOauth.accessToken`.
5. Connector uses the token in memory to call Anthropic's OAuth usage endpoint.
6. Connector maps the response into one or more `UsageSnapshot` records.
7. Connector discards the token after the request.
8. Connector syncs or exposes only sanitized snapshots.

Endpoint shape observed in the referenced project:

```http
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer <local Claude Code OAuth token>
anthropic-beta: oauth-2025-04-20
User-Agent: claude-code/<installed-version>
Content-Type: application/json
```

Expected useful response fields:

- `five_hour.utilization`
- `five_hour.resets_at`
- `seven_day.utilization`
- `seven_day.resets_at`
- `seven_day_opus.utilization`
- `seven_day_sonnet.utilization`
- `extra_usage.is_enabled`
- `extra_usage.used_credits`
- `extra_usage.monthly_limit`
- `extra_usage.utilization`

Because this endpoint is undocumented, the connector must isolate the parser, expose parser version and health, and degrade to a stale/broken-source state when the response shape changes.

## Unified Status UI

Every surface should show the same provider cards regardless of which connector produced the data.

Example cards:

```text
Claude Code
Verified by Mac connector
5-hour: 38% remaining
Weekly: 82% remaining
Updated 20s ago

Codex
Observed by Mac connector
Last run observed 1m ago
Undercount possible

ChatGPT
Estimated by Chrome extension
Based on browser sends on this device
```

The UI must show:

- product name
- source connector
- confidence label
- freshness
- undercount risk
- setup state when a higher-confidence connector is available but missing

The UI must not imply that estimated browser counters and verified local quota snapshots have equal reliability.

## Security Baseline

V1 should ship with this baseline from the first real connector:

- explicit opt-in before reading local provider state
- token used only in memory
- no token logging
- no token persistence by WhatTheToken
- no token upload to backend
- no token exposure to Chrome extension
- synthetic fixtures only in tests
- diagnostics redact provider credentials and sensitive local paths
- all synced payloads validate against the shared sanitized schema

Advanced hardening should be planned but not silently added to Phase 1:

- signed and notarized Mac connector
- signed auto-updates
- hardened runtime and sandbox review
- local encrypted cache if connector state needs persistence
- user-reviewable diagnostic export
- optional end-to-end encryption for synced snapshots if research shows usage metadata needs that level of protection
- independent security review before paid beta

## Error Handling

The connector should return structured source states:

- `not_connected`: user has not enabled this connector
- `missing_credentials`: Claude Code credential not found
- `permission_denied`: user or OS denied access
- `token_invalid`: Anthropic rejected the local token
- `rate_limited`: Anthropic returned rate limit response
- `network_error`: request failed before valid provider response
- `schema_changed`: parser could not validate the response shape
- `stale`: last valid snapshot is older than the freshness threshold

Surfaces should show the state in product language, not raw errors. Example: "Claude Code is connected, but usage could not be refreshed. Last verified 18m ago."

## Testing Strategy

Use TDD for connector behavior.

Test layers:

- parser fixtures for successful full and minimal Anthropic usage responses
- parser fixtures for missing critical fields
- mapping tests from Anthropic usage response to `UsageSnapshot`
- redaction tests for diagnostics
- source-state tests for missing credential, invalid token, rate limit, network error, and schema change
- schema contract tests to ensure synced snapshots contain only allowed fields

Do not write tests that require a real Claude credential, real Keychain contents, or live Anthropic network calls. Live smoke tests can be added later behind explicit local-only developer tooling.

## Frontend Copy Guidance

When frontend work starts, security should be part of the primary copy.

Use:

- "Provider credentials stay on your device."
- "WhatTheToken syncs only usage status."
- "Connect the Mac connector for higher-confidence Claude Code and Codex tracking."
- "Estimated browser counters are labeled separately from verified local signals."

Avoid:

- "We never access credentials."
- "Fully private" without explaining what is synced.
- hiding confidence or freshness in settings.

## Implementation Decisions

- Display Claude as one Anthropic subscription group when verified Claude Code quota data is available, with source rows for Claude Code CLI and Claude web when both exist. If only one source exists, show a single card with the source label visible.
- Support local-only mode before account sync. The product should show value as soon as one connector produces a snapshot, then ask for account creation only when the user wants sync, history, or multiple devices.
- Use a web handoff page for the first Mac connector install flow. Native Messaging detection can be added after the Chrome extension and signed Mac connector both exist.
- Do not build end-to-end encryption for snapshots in Phase 1. Revisit before paid beta after user research confirms whether usage metadata is sensitive enough to justify the added complexity.

## Out Of Scope

- ChatGPT and Gemini DOM parser implementation.
- Supabase schema implementation.
- iOS or WidgetKit surfaces.
- Payment and pricing.
- Real production analytics.
- Live Claude endpoint polling in CI.
