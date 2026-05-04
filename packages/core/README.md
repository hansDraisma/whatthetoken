# @whatthetoken/core

Shared TypeScript domain package for WhatTheToken usage contracts.

## Responsibilities

- Define provider, product, surface, confidence, unit, and undercount-risk types.
- Validate sanitized usage events and usage snapshots with Zod.
- Reject unknown payload fields so sensitive content cannot enter the domain model by accident.
- Provide pure helpers for staleness, snapshot derivation, and fixture generation.

This package must not contain provider credentials, prompts, completions, conversation content, cookies, bearer tokens, auth headers, or provider session tokens.

## Package Boundary

The package emits ESM into `dist`:

```bash
pnpm --filter @whatthetoken/core build
```

Consumers should import through the package boundary:

```ts
import { usageEventSchema, usageSnapshotSchema } from "@whatthetoken/core";
```

Source files use `.js` runtime specifiers in relative imports/exports so the emitted JavaScript remains importable by Node.

## Validation Rules

Usage event `count` is a non-negative integer. Fractional usage measurements belong in snapshot fields such as `used`, not event cardinality.

Usage snapshots keep arithmetic explicit:

- `remaining` equals `max(limit - used, 0)` when `used` and `limit` are known.
- `utilization` equals `used / limit` when `used` and `limit` are known.
- `remaining` and `utilization` are `null` when either `used` or `limit` is unknown.
- `staleReason` is present only when `confidence` is `stale`.

## Verification

Run the focused core checks:

```bash
pnpm --filter @whatthetoken/core typecheck
pnpm --filter @whatthetoken/core test
pnpm --filter @whatthetoken/core build
```

After building, verify the package boundary from `packages/core`:

```bash
node --input-type=module -e "import('@whatthetoken/core').then((core) => console.log(typeof core.usageEventSchema.parse))"
```
