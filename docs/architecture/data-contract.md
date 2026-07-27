# Data Contract

Date: 2026-05-04

`packages/core/src/schemas.ts` is the Phase 1 source of truth for usage event and usage snapshot shape. `packages/core/README.md` explains the package boundary and validation rules for developers consuming the shared contract. Swift models, fixtures, provider ingestors, sync payloads, and UI state must mirror this contract instead of defining provider-specific shapes.

## Taxonomy

Provider, product, and surface are separate fields. Do not collapse them into labels such as "OpenAI usage" because a provider can expose multiple products and a product can appear on multiple surfaces.

| Field | Allowed values |
|---|---|
| `provider` | `openai`, `anthropic`, `google`, `cursor`, `github` |
| `product` | `codex`, `chatgpt`, `claude_code`, `claude`, `gemini`, `cursor`, `github_copilot` |
| `surface` | `cli`, `web`, `browser_extension`, `desktop_app`, `ide`, `cloud_agent`, `mobile` |
| Snapshot aggregate surface | `aggregate` |

## Confidence

Every event and snapshot must include one confidence value.

| Value | Meaning |
|---|---|
| `verified` | Derived from authoritative provider or local quota data. |
| `observed` | Counted directly from a local client action. |
| `estimated` | Inferred from observed activity and public or user-supplied limits. |
| `stale` | Last signal is too old to trust. |

When confidence is `stale`, `staleReason` is required. When confidence is not `stale`, `staleReason` must be `null`.

## Units And Risk

Allowed usage units:

- `messages`
- `requests`
- `tokens`
- `credits`
- `utilization`

Allowed undercount risk values:

- `none`
- `possible`
- `likely`

Use `possible` or `likely` when local observation can miss other devices, browsers, IDEs, cloud agents, or mobile activity.

## Usage Event

A usage event is a sanitized observation or quota poll. It must not contain prompt text, response text, conversation identifiers that reveal content, cookies, auth headers, bearer tokens, provider session tokens, or browser request bodies.

Event payloads are strict. Unknown fields are rejected so sensitive data cannot quietly enter the domain model by accident.

Required fields:

| Field | Type and constraints |
|---|---|
| `id` | Non-empty string |
| `userAccountId` | Non-empty string |
| `deviceId` | Non-empty string |
| `providerAccountId` | Non-empty string or `null` |
| `provider` | Allowed provider value |
| `product` | Allowed product value |
| `surface` | Allowed surface value |
| `eventType` | Allowed event type |
| `modelKey` | Non-empty string or `null` |
| `count` | Non-negative integer |
| `observedAt` | ISO datetime string |
| `confidence` | Allowed confidence value |
| `sourceVersion` | Non-empty string |
| `attribution` | Strict attribution object |

Allowed `eventType` values:

- `message_sent`
- `agent_run_started`
- `agent_run_finished`
- `quota_polled`

Attribution fields:

| Field | Type and constraints |
|---|---|
| `canMissOtherDevices` | Required boolean |
| `deviceName` | Optional non-empty string |
| `os` | Optional value: `macos`, `windows`, `linux`, `ios`, `android`, `unknown` |
| `browser` | Optional value: `chrome`, `edge`, `brave`, `firefox`, `safari`, `unknown` |

## Usage Snapshot

A usage snapshot is the display-ready state for a quota pool and window.

Required fields:

| Field | Type and constraints |
|---|---|
| `id` | Non-empty string |
| `userAccountId` | Non-empty string |
| `provider` | Allowed provider value |
| `product` | Allowed product value |
| `surface` | Allowed surface value or `aggregate` |
| `poolKey` | Non-empty string |
| `windowKey` | Non-empty string |
| `unit` | Allowed usage unit |
| `used` | Non-negative number or `null` |
| `limit` | Positive number or `null` |
| `remaining` | Non-negative number or `null` |
| `utilization` | Number greater than or equal to `0`, or `null` |
| `resetAt` | ISO datetime string or `null` |
| `lastUpdatedAt` | ISO datetime string |
| `confidence` | Allowed confidence value |
| `undercountRisk` | Allowed undercount risk value |
| `staleReason` | Non-empty string or `null` |
| `display` | Optional strict display metadata object |
| `source` | Strict sanitized source metadata object |

Snapshot math rules:

- When `used` and `limit` are known, `remaining` must equal `max(limit - used, 0)`.
- When `used` and `limit` are known, `utilization` must equal `used / limit`.
- When `used` or `limit` is unknown, `remaining` must be `null` unless the snapshot is a remaining-only `credits` balance.
- When `used` or `limit` is unknown, `utilization` must be `null`.
- `limit` must be positive when known.
- `used` and `remaining` must never be negative.
- Fractional usage measurements belong in snapshot fields such as `used`, not in event `count`.

Optional `display` metadata may include:

- `poolLabel`: sanitized provider display label for the quota pool, such as a Codex model limit name.
- `windowLabel`: sanitized provider or connector display label for the quota window, such as "5 hour usage limit".

Display metadata is presentation-only. Consumers must continue to use `poolKey` and `windowKey` as stable identifiers.

## Snapshot Source Metadata

Every `UsageSnapshot` includes sanitized source metadata:

- `connector`: `mac_connector`, `chrome_extension`, `web_dashboard`, or `manual_fixture`
- `state`: connector state such as `connected`, `missing_credentials`, `token_invalid`, `session_expired`, `schema_changed`, or `stale`
- `label`: user-facing source label
- `parserVersion`: source/parser version used to produce the snapshot
- `deviceId`: local device identifier

Source metadata must never contain credentials, OAuth tokens, cookies, prompts, responses, browser request bodies, raw provider payloads, or sensitive local paths.

## Claude Code Snapshot Mapping

The Mac connector maps Claude Code usage into sanitized `UsageSnapshot` records.

Subscription utilization windows use:

- `provider`: `anthropic`
- `product`: `claude_code`
- `surface`: `cli`
- `poolKey`: `anthropic_claude_subscription`
- `unit`: `utilization`
- `limit`: `100`
- `used`: the provider utilization percentage
- `remaining`: `max(100 - used, 0)`
- `confidence`: `verified`

Window keys are provider-defined and discovered dynamically from top-level objects with a numeric `utilization` field. Current examples include:

- `five_hour`
- `seven_day`
- `seven_day_fable`

Future model-specific windows must flow through without requiring a compiled key list. `five_hour` sorts first, aggregate `seven_day` second, and additional windows sort by provider key.

Enabled extra usage credits use:

- `poolKey`: `anthropic_claude_extra_usage`
- `windowKey`: `monthly_extra_usage`
- `unit`: `credits`
- `used`: `extra_usage.used_credits`
- `limit`: `extra_usage.monthly_limit`
- `remaining`: `max(limit - used, 0)`

The connector must ignore disabled or incomplete extra-usage credit records rather than inventing a limit.

## Codex Snapshot Mapping

The Mac connector maps Codex app-server rate-limit buckets into sanitized `UsageSnapshot` records after explicit user opt-in.

Rate-limit windows use:

- `provider`: `openai`
- `product`: `codex`
- `surface`: `aggregate`
- `poolKey`: `openai_codex_<sanitized-limit-id>_<stable-hash>`
- `windowKey`: `primary_rolling_<minutes>m`, `secondary_rolling_<minutes>m`, or `<prefix>_window_unknown`
- `unit`: `utilization`
- `limit`: `100`
- `used`: `primary.usedPercent` or `secondary.usedPercent`
- `remaining`: `max(100 - used, 0)`
- `confidence`: `observed` until live validation proves the app-server bucket is authoritative aggregate provider usage
- `undercountRisk`: `possible` until live validation proves the bucket cannot miss Codex surfaces

When present, Codex display metadata uses:

- `display.poolLabel`: `limitName` from the app-server bucket, trimmed and ignored when empty. Aggregate `codex` buckets usually leave this unset.
- `display.windowLabel`: derived from `windowDurationMins`, currently `5 hour usage limit` for `300`, `Weekly usage limit` for `10080`, and generic hour/minute labels for other durations.

Credit balance snapshots use:

- `poolKey`: `openai_codex_credits`
- `windowKey`: `credits_remaining`
- `unit`: `credits`
- `used`: `null`
- `limit`: `null`
- `remaining`: numeric `credits.balance`
- `display.poolLabel`: `Codex`
- `display.windowLabel`: `Credits remaining`

If `credits.balance` is missing, non-numeric, negative, or `credits.unlimited == true`, the connector must not emit a Codex credits snapshot. This avoids presenting an unavailable balance as a quota-empty state.

The connector decodes only sanitized rate-limit fields from the app-server response: `limitId`, `limitName`, `planType`, `primary`, `secondary`, `credits`, and `rateLimitReachedType`. It does not store raw JSON-RPC envelopes.

## Contract Ownership

Changes to event or snapshot shape start in `packages/core/src/schemas.ts` with focused schema tests. Mac models, fixtures, architecture docs, and any future sync or extension payloads are downstream mirrors.

Any contract change that affects privacy boundaries also requires an ADR.
