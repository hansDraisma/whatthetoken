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

Allowed units:

- messages
- requests
- tokens
- credits
- utilization

The shared TypeScript schemas in `packages/core/src/schemas.ts` are the source of truth for event and snapshot shape during Phase 1.
