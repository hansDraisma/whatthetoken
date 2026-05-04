# Data Contract

The product uses provider/product/surface as separate fields.

Every usage snapshot must include:

- provider
- product
- surface
- poolKey
- windowKey
- unit
- confidence
- freshness
- undercount risk
- source metadata

Allowed units:

- messages
- requests
- tokens
- credits
- utilization

The shared TypeScript schemas in `packages/core/src/schemas.ts` are the source of truth for event and snapshot shape during Phase 1.

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

Supported window keys:

- `five_hour`
- `seven_day`
- `seven_day_opus`
- `seven_day_sonnet`

Enabled extra usage credits use:

- `poolKey`: `anthropic_claude_extra_usage`
- `windowKey`: `monthly_extra_usage`
- `unit`: `credits`
- `used`: `extra_usage.used_credits`
- `limit`: `extra_usage.monthly_limit`
- `remaining`: `max(limit - used, 0)`

The connector must ignore disabled or incomplete extra-usage credit records rather than inventing a limit.

## Snapshot Source Metadata

Every `UsageSnapshot` includes sanitized source metadata:

- `connector`: `mac_connector`, `chrome_extension`, `web_dashboard`, or `manual_fixture`
- `state`: connector state such as `connected`, `missing_credentials`, `token_invalid`, `schema_changed`, or `stale`
- `label`: user-facing source label
- `parserVersion`: source/parser version used to produce the snapshot
- `deviceId`: local device identifier

Source metadata must never contain credentials, OAuth tokens, cookies, prompts, responses, or browser request bodies.
