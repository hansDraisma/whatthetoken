# Data Contract

The product uses provider/product/surface as separate fields. The shared TypeScript schemas in `packages/core/src/schemas.ts` are the source of truth for event and snapshot shape during Phase 1.

## Usage Events

Every usage event must include:

- id
- userAccountId
- deviceId
- providerAccountId
- provider
- product
- surface
- eventType
- modelKey
- count
- observedAt
- confidence
- sourceVersion
- attribution

`count` is an event cardinality, not a fractional measurement. It must be a non-negative integer.

Event payloads are strict. Unknown fields are rejected so prompts, completions, conversation metadata, cookies, auth headers, bearer tokens, and provider session tokens cannot quietly enter the domain model.

## Usage Snapshots

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

Allowed units:

- messages
- requests
- tokens
- credits
- utilization

When `used` and `limit` are known, `remaining` must equal `max(limit - used, 0)` and `utilization` must equal `used / limit`. When either `used` or `limit` is unknown, `remaining` and `utilization` must be `null`.

Snapshots use `confidence` and `undercountRisk` to keep provenance visible. Stale snapshots must include a stale reason; non-stale snapshots must not.
