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

## Snapshot Source Metadata

Every `UsageSnapshot` includes sanitized source metadata:

- `connector`: `mac_connector`, `chrome_extension`, `web_dashboard`, or `manual_fixture`
- `state`: connector state such as `connected`, `missing_credentials`, `token_invalid`, `schema_changed`, or `stale`
- `label`: user-facing source label
- `parserVersion`: source/parser version used to produce the snapshot
- `deviceId`: local device identifier

Source metadata must never contain credentials, OAuth tokens, cookies, prompts, responses, or browser request bodies.
