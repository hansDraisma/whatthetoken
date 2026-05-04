# Tech Stack And Development Approach

Date: 2026-05-04

## Product Direction

WhatTheToken is a Mac-first developer consumption monitor for AI coding tools.

V1 starts with Claude Code because it has the clearest verified local usage path. Codex remains a high-priority developer product, but its connector comes after a dedicated local metadata and redaction review. Browser assistants and other developer tools expand the same shared status model later.

## Tech Stack

| Area | Choice | Reason |
|---|---|---|
| Mac app | SwiftUI | Best fit for a native menu bar/status app, Keychain, notifications, login items, and future Apple-platform touchpoints |
| Shared domain core | TypeScript package | Fast TDD loop for quota math, schemas, confidence labels, stale detection, and future web/extension reuse |
| Package manager | pnpm workspaces pinned with `packageManager: pnpm@10.0.0` | Simple monorepo management for TypeScript packages and future web/extension apps, with deterministic lockfile behavior across parallel worktrees |
| TypeScript tests | Vitest | Fast unit tests for pure domain logic |
| Type validation | Zod | Runtime validation for events, snapshots, and ingestor payloads |
| Web dashboard later | Next.js | Good default for auth/dashboard when sync becomes active scope |
| Backend later | Supabase Postgres/Auth/Realtime | Fastest path to multi-device sync with relational data and RLS |
| Browser extension later | WXT | Modern TypeScript-first Chrome extension framework |
| Payments later | Stripe | Standard SaaS billing |
| Error reporting later | Sentry | Useful once beta users exist, with strict sensitive-data filtering |

## Development Approach

Use TDD for behavior changes:

1. Write a failing test.
2. Run the focused test and confirm the expected failure.
3. Implement the minimum code.
4. Run the focused test and confirm it passes.
5. Run package-level checks.
6. Commit a small coherent change.

For workspace-foundation tasks:

1. Verify the package manager before installing dependencies. `pnpm --version` must match the root `packageManager` declaration exactly.
2. Use Corepack to activate the pinned pnpm version when the local version differs.
3. Treat `pnpm-lock.yaml` as a reviewed source artifact. Inspect lockfile changes before committing.
4. Treat root workspace scaffolding as a dependency barrier for parallel Conductor work. Core, Mac, documentation, and provider-spike worktrees should branch from a base that already includes the workspace scaffold.

## Architecture Rules

- Keep quota math, confidence logic, stale detection, deduplication, and snapshot derivation in `packages/core`.
- Keep provider-specific ingestion code isolated under the app or provider package that owns it.
- Keep SwiftUI views thin. Views render state; domain decisions belong in model/controller code or shared schemas.
- Use provider/product/surface taxonomy everywhere.
- Model budgets and pools, not just message counts.
- Never collect prompts, responses, conversation content, cookies, bearer tokens, auth headers, or provider session tokens.

## Frontend Trust Messaging

When frontend work starts, make secure local collection part of the primary product language rather than buried help text.

Use copy in this direction:

- "Provider credentials stay on your device."
- "WhatTheToken syncs only usage status."
- "Claude Code and Codex can be connected through the Mac connector for higher-confidence local tracking."
- "Estimated browser counters are labeled separately from verified local signals."

Avoid claims that are too broad:

- Do not say "we never access credentials"; the local connector may access them in memory.
- Do not say "fully private" without explaining what is and is not synced.
- Do not hide confidence labels behind tooltips or settings screens.

## Phase 1 Stack Boundary

Phase 1 should create:

- `packages/core`: TypeScript schemas and quota logic.
- `apps/mac`: SwiftUI status app shell plus the first Claude Code local connector boundary.
- `docs`: implementation notes, ADRs, and operating rules.

Phase 1 should not create:

- Supabase backend.
- Next.js dashboard.
- Chrome extension.
- iOS app.
- Payments.
- Production analytics.

Those are valuable, but they are not needed to prove the first Mac-visible developer quota/status signal.

## Current Claude Connector Boundary

The Mac app owns Claude-specific ingestion code under `apps/mac/Sources/WhatTheTokenMac/Claude`.

The connector is responsible for:

- reading the Claude Code Keychain credential locally only after opt-in
- using the OAuth token in memory to request Anthropic usage
- passing a detected or injected Claude Code version into the usage request
- mapping `five_hour`, `seven_day`, `seven_day_opus`, `seven_day_sonnet`, and enabled `extra_usage` credit data into sanitized snapshots
- returning structured connector states for missing credentials, invalid tokens, rate limits, network errors, and schema changes

Codex should follow the same connector/source model later, but no Codex files, auth state, prompts, responses, command history, shell snapshots, or session contents should be parsed before the Codex redaction review is complete.
