# OpenAI ChatGPT And Codex Ingestion Spike

Date: 2026-05-05

## Goal

Kick-start the investigation for fetching OpenAI usage information beyond Codex Cloud task metadata, with separate paths for:

- Codex Cloud tasks
- Codex local/app/IDE usage
- ChatGPT web usage

The investigation must preserve the existing WhatTheToken boundary: no prompts, responses, conversation URLs, auth headers, cookies, bearer tokens, provider session tokens, browser request bodies, or raw local session files.

## Current Repo Fit

The shared contract already supports the needed OpenAI shape:

- `provider`: `openai`
- `product`: `codex`, `chatgpt`
- `surface`: `cli`, `web`, `browser_extension`, `desktop_app`, `ide`, `cloud_agent`
- `unit`: `messages`, `requests`, `tokens`, `credits`, `utilization`
- confidence levels: `verified`, `observed`, `estimated`, `stale`

This means the next work can focus on source adapters and mapping rules rather than changing the domain model first.

## Sources Checked

- OpenAI Help Center, `Using Codex with your ChatGPT plan`: https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan
- OpenAI Help Center, `Codex rate card`: https://help.openai.com/en/articles/20001106-codex-rate-card
- OpenAI Help Center, `Using Credits for Flexible Usage in ChatGPT`: https://help.openai.com/en/articles/12642688-using-credits-for-flexible-usage-in-chatgpt-freegopluspro-sora
- OpenAI Help Center, `GPT-5.3 and GPT-5.5 in ChatGPT`: https://help.openai.com/en/articles/11909943-gpt-53-and-gpt-55-in-chatgpt
- OpenAI Developers, `Codex CLI`: https://developers.openai.com/codex/cli
- OpenAI Developers, `Codex CLI command line options`: https://developers.openai.com/codex/cli/reference
- OpenAI Developers, `Codex app server`: https://developers.openai.com/codex/app-server

## Local Commands Run

Only public CLI help/version commands were run. No `~/.codex` file contents, auth files, history files, SQLite tables, sessions, shell snapshots, cookies, tokens, prompts, or responses were read.

- `codex --version`
- `codex --help`
- `codex cloud --help`
- `codex cloud list --help`
- `codex cloud status --help`
- `codex cloud exec --help`
- `codex debug --help`
- `codex app-server --help`

Observed local CLI version: `codex-cli 0.128.0`.

## Implementation Status

As of 2026-05-05, the first Codex implementation slice exists in the Mac app:

- `CodexAppServerClient` launches the local Codex app-server over stdio and sends JSON-RPC 2.0 `account/rateLimits/read`.
- `CodexRateLimitsResponse` decodes the documented single-bucket and `rateLimitsByLimitId` shapes.
- `CodexUsageMapper` maps utilization buckets, display labels, and displayable credit balances into sanitized `UsageSnapshot` records.
- `CodexConnectorService` maps app-server auth, launch, transport, and schema failures into connector states.
- `CodexConnectorSmokeCommand` provides local-only smoke verification behind `CODEX_CONNECTOR_SMOKE=1`.
- `StatusViewModel` and `ContentView` expose an explicit `Connect Codex` action and keep Codex disconnected on startup.

The live connector resolves the Codex executable from the launched app's `PATH`, `~/.local/bin/codex`, `/opt/homebrew/bin/codex`, or `/usr/local/bin/codex`. This is required for packaged or Finder-launched Mac app sessions where `PATH` may not include Homebrew.

Live smoke on 2026-05-05 returned sanitized Codex snapshots for aggregate five-hour and weekly utilization, model-specific five-hour and weekly utilization, and credits remaining. The smoke output did not include account email, tokens, authorization values, raw JSON-RPC envelopes, raw app-server logs, prompts, responses, command output, local paths, task titles, task summaries, or token-shaped strings.

## Findings

### 1. Codex Cloud Metadata Is Already Scriptable

`codex cloud list --json` is the cleanest existing cloud task inventory path. Official docs say the JSON payload includes:

- `tasks`
- optional `cursor`
- task fields such as `id`, `url`, `title`, `status`, `updated_at`, `environment_id`, `environment_label`, `summary`, `is_review`, and `attempt_total`

This is useful for cloud-agent activity status, but it is not enough for usage/quota by itself. The fields are task metadata, not credit or rate-limit telemetry.

Recommended mapping if used:

- `provider`: `openai`
- `product`: `codex`
- `surface`: `cloud_agent`
- event type candidates: `agent_run_started`, `agent_run_finished`
- confidence: `observed`
- undercount risk: `possible`, because it can miss local CLI, IDE, app, web, and other devices

Privacy note: task `title`, `summary`, and `url` may reveal prompt or repository context. The first implementation should not store or sync them. Use task `id`, status, updated time, environment id/label only if we confirm those fields are safe for the product boundary.

### 2. Codex App Server Exposes A Better Quota Path

The current Codex app-server docs expose JSON-RPC auth/account methods:

- `account/read`
- `account/rateLimits/read`
- `account/rateLimits/updated`
- `account/sendAddCreditsNudgeEmail`

The documented `account/rateLimits/read` response is directly relevant to WhatTheToken. It includes a single-bucket `rateLimits` shape and a multi-bucket `rateLimitsByLimitId` shape. Documented fields include:

- `limitId`
- `limitName`
- `primary.usedPercent`
- `primary.windowDurationMins`
- `primary.resetsAt`
- `secondary`
- `rateLimitReachedType`
- optional `planType`
- optional `credits`

This is the implemented Codex quota path. It is safer than parsing `~/.codex` local databases because it is an explicit product protocol and returns already-aggregated usage fields.

Implemented mapping:

- `provider`: `openai`
- `product`: `codex`
- `surface`: `aggregate` for quota buckets, or surface-specific only if `limitId` proves surface-specific
- `poolKey`: `openai_codex_<sanitized-limit-id>_<stable-hash>` so ids that differ only by punctuation do not collide
- `windowKey`: `primary_rolling_<windowDurationMins>m`, `secondary_rolling_<windowDurationMins>m`, or `<prefix>_window_unknown`
- `unit`: `utilization` when only `usedPercent` is available
- `used`: `primary.usedPercent` or `secondary.usedPercent`
- `limit`: `100`
- `remaining`: `max(100 - used, 0)`
- `resetAt`: Unix `resetsAt` converted to ISO datetime
- `confidence`: `observed` until validated against the Codex usage dashboard across enough account tiers
- `undercountRisk`: `possible` until validated as authoritative across Codex surfaces
- `source.connector`: `mac_connector`
- `source.parserVersion`: `codex-app-server-rate-limits-v1`

Open question: the docs label this as ChatGPT rate limits but examples use `limitId: "codex"`. We need a live redacted protocol probe to see whether non-Codex ChatGPT buckets are returned for the current account, or whether this surface only exposes Codex-related limits.

### 3. Codex Credits Are Token-Based

OpenAI's current Codex rate card says Codex has moved to token-based credit pricing for most current customer plans. It also says usage varies by model, input tokens, cached input tokens, output tokens, fast mode, automations, number of instances, and task size.

Product implication: counting Codex messages or cloud tasks is not enough. The quota card should prefer provider-reported `usedPercent` and credit fields when available. Local task counts can still be useful as attribution, but they should be labeled `observed`, not treated as spend truth.

### 4. ChatGPT Web Still Looks Like Estimated Browser Tracking For Consumer Plans

OpenAI publishes ChatGPT model/window limits for current ChatGPT tiers. Current examples include GPT-5.3 message windows, GPT-5.5 Thinking weekly limits, and Business/Pro guardrails rather than a simple fixed quota.

No official consumer ChatGPT usage API was identified in this pass. For ChatGPT web, the repo's existing direction still holds:

- browser extension observes outbound sends and selected model
- no request bodies, prompts, responses, conversation URLs, cookies, auth headers, or session tokens
- map snapshots as `estimated`
- use `undercountRisk: likely` if mobile/native/other browsers are unobserved

Recommended mapping:

- `provider`: `openai`
- `product`: `chatgpt`
- `surface`: `browser_extension`
- `unit`: `messages`
- `poolKey`: `openai_chatgpt_<model_or_mode>`
- `windowKey`: derived from the published plan/model window
- `confidence`: `estimated`
- `source.parserVersion`: `chatgpt-browser-counter-v1`

The browser path should not attempt to reverse-engineer authenticated ChatGPT internals until legal/privacy review explicitly approves a narrower probe.

### 5. Enterprise/Edu May Have Admin Surfaces, But They Are Not V1 Consumer Tracking

OpenAI documents Enterprise/Edu usage limits and workspace controls, including role-based weekly spend limits and admin-only visibility. That is useful for future team products, but it does not solve a developer-first local consumer tracker unless the user is a workspace owner/admin and grants a workspace-level integration.

## Remaining Next Steps

1. Validate the Codex app-server bucket semantics against the ChatGPT Codex usage dashboard for more than one account tier before changing `confidence` from `observed` or `undercountRisk` from `possible`.
2. If the app-server returns only Codex buckets, keep ChatGPT web as estimated browser tracking.
3. If it returns ChatGPT model buckets, create a second parser path for `product: chatgpt` and mark it `verified` only after validating resets/fields across at least Plus/Pro/Business accounts.
4. Keep `codex cloud list --json` as activity attribution, not quota truth.
5. Defer local `~/.codex` SQLite/file inspection until there is a separate redaction-review script that lists schema names and JSON top-level keys only.

## Implemented Slice And Test Coverage

The current Mac implementation includes a Codex connector module parallel to the Claude connector:

- `CodexAppServerClient`: starts or connects to the local app-server and sends JSON-RPC requests.
- `CodexRateLimitsResponse`: strict decoded response for sanitized rate-limit fields only.
- `CodexUsageMapper`: maps rate-limit buckets into `UsageSnapshot`.
- `CodexConnectorService`: handles opt-in, source states, and error mapping.
- `CodexConnectorSmokeCommand`: developer-only, sanitized output.

Automated tests cover:

- parses single-bucket rate limit response
- parses multi-bucket `rateLimitsByLimitId`
- maps `usedPercent/windowDurationMins/resetsAt` to utilization snapshots
- maps display labels from `limitName` and window duration
- emits displayable credits remaining snapshots and skips non-displayable credits
- hashes sanitized limit ids to avoid collisions
- sends JSON-RPC 2.0 envelopes and selects the expected response id
- resolves Codex from common local install paths when `PATH` is restricted
- keeps smoke output sanitized and gated behind `CODEX_CONNECTOR_SMOKE=1`
- maps app-server auth/network/schema failures to connector states

## Privacy Decision

The first Codex implementation should use the app-server account rate-limit protocol before inspecting local Codex files. That path is more explicit, narrower, and already returns aggregate quota metadata. ChatGPT web remains an estimated browser counter unless the same protocol proves it can return ChatGPT-specific usage buckets without exposing account or conversation data.
