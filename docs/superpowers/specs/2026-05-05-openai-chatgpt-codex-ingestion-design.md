# OpenAI ChatGPT And Codex Ingestion Design

Date: 2026-05-05

## Goal

Define how WhatTheToken can fetch OpenAI consumption information for Codex and ChatGPT in addition to Codex Cloud task metadata, without collecting prompts, responses, conversation URLs, cookies, auth headers, bearer tokens, provider session tokens, browser request bodies, or raw local session files.

## Decision Summary

Build Codex quota ingestion first through the Codex app-server account rate-limit protocol. Do not parse `~/.codex` local files for the first implementation. Keep `codex cloud list --json` as optional activity attribution, not quota truth. Keep ChatGPT web as estimated browser tracking unless a redacted live Codex app-server probe proves that the same `account/rateLimits/read` protocol returns ChatGPT model buckets for the signed-in account.

Recommended order:

1. Codex app-server rate-limit smoke probe.
2. Codex app-server rate-limit parser and `UsageSnapshot` mapper.
3. Mac connector/service integration for Codex quota snapshots.
4. Live redacted validation across plan types.
5. ChatGPT browser estimator spec if no verified ChatGPT buckets are returned.

## Source Facts

OpenAI's current Codex docs expose two relevant surfaces:

- `codex cloud list --json` lists recent cloud tasks and returns task metadata such as `id`, `url`, `title`, `status`, `updated_at`, `environment_id`, `environment_label`, `summary`, `is_review`, and `attempt_total`.
- The Codex app-server protocol exposes `account/rateLimits/read` and `account/rateLimits/updated` with rate-limit snapshots.

The generated local Codex app-server JSON Schema for `codex-cli 0.128.0` confirms:

- `GetAccountRateLimitsResponse.rateLimits` is required.
- `GetAccountRateLimitsResponse.rateLimitsByLimitId` is optional and keyed by metered limit id.
- `RateLimitSnapshot` may contain `limitId`, `limitName`, `planType`, `primary`, `secondary`, `credits`, and `rateLimitReachedType`.
- `RateLimitWindow.usedPercent` is required when a window exists.
- `RateLimitWindow.resetsAt` and `windowDurationMins` may be null.
- `CreditsSnapshot` contains `hasCredits`, `unlimited`, and optional string `balance`.
- `PlanType` values include `free`, `go`, `plus`, `pro`, `team`, `business`, `enterprise`, `edu`, and `unknown`.

OpenAI's current Codex help docs say Codex usage depends on plan, task size, complexity, and execution location. They also say Codex pricing moved to token-based credits for most current plans, using input, cached input, and output tokens rather than message averages.

OpenAI's current ChatGPT help docs publish model/window limits for consumer tiers, but no official consumer ChatGPT usage API was identified in this pass. Current examples include GPT-5.3 rolling message windows, GPT-5.5 Thinking weekly limits, and Pro/Business access subject to guardrails rather than a fixed normal quota.

## Existing Repo Fit

No core schema change is required for the first Codex implementation. `packages/core/src/schemas.ts` already supports:

- `provider: "openai"`
- `product: "codex"` and `product: "chatgpt"`
- `surface: "cli"`, `"desktop_app"`, `"ide"`, `"cloud_agent"`, `"browser_extension"`, and `"aggregate"`
- `unit: "utilization"`, `"credits"`, `"messages"`, `"requests"`, and `"tokens"`
- confidence values `verified`, `observed`, `estimated`, and `stale`

The Mac app already has the right connector shape from Claude:

- a provider-specific response model
- a client/parser layer
- a mapper into sanitized `UsageSnapshot`
- a connector service that handles opt-in and source states
- a developer-only smoke command that prints sanitized output
- tests using synthetic fixtures only

The Codex implementation should mirror this structure instead of inventing a new connector architecture.

## Approaches Considered

### Option A: App-Server Rate Limits First

Use the local Codex app-server JSON-RPC protocol and call `account/rateLimits/read` after explicit opt-in. Map returned buckets into quota snapshots.

Pros:

- It is an explicit Codex product protocol.
- It returns aggregate usage fields instead of raw sessions.
- It avoids reading `~/.codex` auth, history, sessions, SQLite rows, or shell snapshots.
- It supports both one-shot reads and live updates through `account/rateLimits/updated`.

Cons:

- The protocol is marked experimental.
- We need live validation to know which buckets appear for Plus, Pro, Business, and Enterprise accounts.
- The docs label the section as ChatGPT rate limits while examples use `limitId: "codex"`, so product mapping must be conservative.

This is the recommended path.

The first implementation uses one-shot reads only. Subscribing to `account/rateLimits/updated` is deferred until the one-shot connector has live validation and UI value.

### Option B: Cloud Task Metadata First

Use `codex cloud list --json` and infer runs from task status.

Pros:

- Stable CLI command with JSON output.
- Directly covers cloud-agent activity.

Cons:

- It does not provide quota or credit usage.
- Task `title`, `summary`, and `url` may reveal prompt, repository, or task context and cannot be stored under the current privacy boundary.
- It misses local CLI, IDE, app, and other-device usage.

This should be activity attribution only.

### Option C: Local Codex File Inspection

Inspect `~/.codex` JSON and SQLite stores for counters or token usage.

Pros:

- Could eventually provide local task attribution.

Cons:

- Candidate files may contain auth, prompts, responses, command history, shell output, or raw session state.
- This requires a separate redaction-review spike and explicit user permission before reading contents.

This is deferred.

## Codex App-Server Collection Design

### User Flow

1. User chooses `Connect Codex` or runs a developer-only `--codex-connector-smoke` command.
2. WhatTheToken starts or connects to Codex app-server only after that explicit action.
3. The connector sends one JSON-RPC request: `account/rateLimits/read`.
4. The connector decodes only the sanitized rate-limit response fields.
5. The connector maps each usable bucket into `UsageSnapshot`.
6. The connector discards the raw JSON-RPC message after decoding.
7. The smoke command prints only sanitized connector state and snapshot summaries.

### Allowed Fields

The Codex connector may decode and store:

- `limitId`
- `limitName`
- `planType`
- `primary.usedPercent`
- `primary.windowDurationMins`
- `primary.resetsAt`
- `secondary.usedPercent`
- `secondary.windowDurationMins`
- `secondary.resetsAt`
- `credits.hasCredits`
- `credits.unlimited`
- `credits.balance`, only if it parses as a non-secret numeric credit balance
- `rateLimitReachedType`

The connector must not decode, store, log, sync, fixture, or print:

- account email from `account/read`
- auth mode
- access tokens
- auth refresh responses
- raw JSON-RPC envelopes
- raw app-server logs
- task `title`, `summary`, or `url`
- prompts
- responses
- command output
- local file paths
- browser request bodies
- cookies or session tokens

Unlike Claude Code, the Codex connector does not need a WhatTheToken-owned credential store. Codex authentication stays inside Codex/app-server; WhatTheToken only asks the local app-server for sanitized rate-limit metadata.

### Snapshot Mapping

For every non-null rate-limit window:

- `provider`: `openai`
- `product`: `codex` unless live validation proves a bucket is ChatGPT-specific
- `surface`: `aggregate`
- `poolKey`: `openai_codex_<sanitized-limit-id>_<stable-hash>` so upstream ids that differ only by punctuation cannot collide after sanitization
- `windowKey`: `primary_rolling_<windowDurationMins>m`, `secondary_rolling_<windowDurationMins>m`, or `primary_window_unknown` when duration is null
- `unit`: `utilization`
- `used`: `usedPercent` as `Double`
- `limit`: `100`
- `remaining`: `max(100 - usedPercent, 0)`
- `utilization`: `usedPercent / 100`
- `resetAt`: ISO datetime converted from Unix `resetsAt`, or null
- `lastUpdatedAt`: connector observation time
- `confidence`: `verified` after live validation confirms app-server values match the signed-in Codex usage UI; `observed` during pre-validation smoke work
- `undercountRisk`: `possible` during pre-validation smoke work; after live validation, change to `none` only if the bucket is confirmed to be aggregate provider usage across Codex surfaces
- `source.connector`: `mac_connector`
- `source.state`: connector state
- `source.label`: `Mac connector`
- `source.parserVersion`: `codex-app-server-rate-limits-v1`

For credits:

- If `credits.unlimited == true`, do not invent a numeric limit. Emit no credits snapshot until the UI has a design for unlimited credit state.
- If `credits.hasCredits == true` and `credits.balance` parses as a non-negative decimal, keep the parsed balance in local connector diagnostics only for the first implementation.
- If `credits.balance` is non-numeric, ignore it and preserve only rate-limit utilization snapshots.

The credits rule intentionally avoids pretending a remaining balance is a full quota model. The current `UsageSnapshot` schema requires `remaining` to be null when `used` or `limit` is unknown, so a schema change is needed before showing credit balance as a first-class snapshot.

## ChatGPT Collection Design

ChatGPT has two possible paths.

### Path 1: Verified Buckets If App-Server Returns Them

The redacted live probe must determine whether `account/rateLimits/read` returns buckets that clearly correspond to ChatGPT model windows. If it does:

- map ChatGPT buckets only when the bucket id/name can be classified without prompts, conversation metadata, or account email
- use `provider: "openai"`
- use `product: "chatgpt"`
- use `surface: "aggregate"`
- use the same utilization mapping as Codex
- set `confidence: "verified"` only after cross-checking against the ChatGPT UI on at least Plus, Pro, and Business accounts

Required validation: bucket names, reset windows, and percentages must be stable enough to distinguish ChatGPT from Codex.

### Path 2: Estimated Browser Counter

If the app-server returns only Codex buckets or ambiguous buckets, ChatGPT remains estimated browser tracking:

- browser extension observes send events and selected model/mode on `chatgpt.com`
- no prompt text, response text, request body, conversation URL, cookies, auth headers, local storage dump, or session token is read
- public plan/model limits supply the limit and window
- local send counts supply `used`
- `confidence: "estimated"`
- `undercountRisk: "likely"` when mobile, native app, or other browsers can be missed

This path needs its own browser-extension spec before implementation. It is not part of the Codex app-server connector implementation.

## Required Information Before Production Implementation

The spec is implementable for a local smoke and parser with synthetic fixtures now. These facts are required before production UI or sync:

1. Live sanitized `account/rateLimits/read` result shape for at least one ChatGPT Plus or Pro account using Codex.
2. Whether `rateLimitsByLimitId` includes only Codex buckets or also ChatGPT model buckets.
3. Whether `limitId` and `limitName` are stable enough to map product and pool keys without hardcoding user-specific labels.
4. Whether `primary` and `secondary` represent separate quota windows, fallback limits, or soft/hard throttles.
5. Whether `credits.balance` is numeric across plans and locales.
6. Whether `credits.balance` is remaining credits, purchased credits, workspace credits, or another balance type.
7. Whether app-server can be launched by the Mac app in production without exposing auth refresh payloads to WhatTheToken.
8. Whether using the Codex app-server protocol for third-party local quota display is acceptable under product/legal review.
9. Whether ChatGPT consumer usage buckets are available anywhere official; no such public API was found in this pass.
10. Whether a schema change is desired to represent remaining credits when used and limit are unknown.

## Error Handling

Codex connector states:

- `not_connected`: user has not enabled Codex.
- `missing_credentials`: app-server reports no ChatGPT account or requires OpenAI auth.
- `permission_denied`: app-server cannot be launched or connected due to OS restrictions.
- `token_invalid`: app-server reports unauthorized after refresh cannot recover.
- `rate_limited`: rate-limit read is itself throttled.
- `network_error`: app-server transport fails or exits unexpectedly.
- `schema_changed`: response is missing usable `rateLimits` fields.
- `stale`: last successful snapshot is older than the freshness threshold.

The connector should not expose raw app-server errors in product UI or smoke output.

Stale snapshots are not implemented in this slice because the Codex connector does not yet persist a last-known-good cache. `stale` remains a future state for the cached-refresh path.

## Testing Strategy

Use TDD and synthetic fixtures only.

Required tests:

- decode single-bucket `GetAccountRateLimitsResponse`
- decode multi-bucket `rateLimitsByLimitId`
- ignore null windows and null limit ids safely
- map primary and secondary windows into distinct utilization snapshots
- convert Unix `resetsAt` to ISO datetime
- reject or ignore malformed credit balance strings
- ensure raw account email/auth fields cannot enter snapshots or smoke output
- map app-server process, transport, schema, and auth failures to connector states
- ensure disabled connector does not launch app-server
- ensure duplicate connect attempts do not start overlapping app-server reads

Live smoke tests remain manual and local-only. CI must not call live OpenAI or Codex endpoints.

## Out Of Scope

- Reading `~/.codex` file contents.
- Parsing Codex conversation/session/history stores.
- Browser extension implementation for ChatGPT.
- Sync/backend changes.
- Native Messaging install flow.
- Team/admin Enterprise analytics.
- Legal approval itself.

## Self-Review

- No core schema change is required for the first rate-limit utilization snapshots.
- Credit balance display is intentionally gated because the current snapshot contract cannot cleanly represent remaining-only balances.
- ChatGPT verified collection is intentionally gated on live bucket validation.
- The design follows the existing Claude connector pattern and preserves the privacy boundary.
