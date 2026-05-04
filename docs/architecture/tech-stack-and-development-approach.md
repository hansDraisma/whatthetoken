# Tech Stack And Development Approach

Date: 2026-05-04

## Product Direction

WhatTheToken is a Mac-first developer consumption monitor for AI coding tools.

V1 focuses on Codex CLI and Claude Code, then expands to browser assistants and other developer tools. The product should expose data to other touchpoints later, but those future surfaces must not force premature cross-platform desktop compromises.

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

For TypeScript package tasks:

1. Keep package entrypoints and emitted files aligned. If `package.json` points at `dist`, the package must expose a build script that writes `dist`.
2. Use explicit `exports` for package boundaries instead of relying only on `main`.
3. Use `.js` runtime specifiers in TypeScript source for ESM files that compile to Node-loadable JavaScript.
4. Verify package boundaries with both `pnpm --filter <package> build` and a direct Node import from the package directory when adding or changing entrypoints.

## Architecture Rules

- Keep quota math, confidence logic, stale detection, deduplication, and snapshot derivation in `packages/core`.
- Treat `packages/core/src/schemas.ts` as the runtime contract for sanitized usage events and snapshots.
- Treat `docs/architecture/data-contract.md` as the human-readable companion to `packages/core/src/schemas.ts`.
- Review `docs/architecture/privacy-boundaries.md` before changing ingestion, sync, fixtures, logs, analytics, or quota UI.
- Keep provider-specific ingestion code isolated under the app or provider package that owns it.
- Keep SwiftUI views thin. Views render state; domain decisions belong in model/controller code or shared schemas.
- Use provider/product/surface taxonomy everywhere.
- Model budgets and pools, not just message counts.
- Never collect prompts, responses, conversation content, cookies, bearer tokens, auth headers, or provider session tokens.

## Phase 1 Stack Boundary

Phase 1 should create:

- `packages/core`: TypeScript schemas and quota logic.
- `apps/mac`: SwiftUI status app shell with a fixture-backed first quota card.
- `docs`: implementation notes, ADRs, and operating rules.

Phase 1 should not create:

- Supabase backend.
- Next.js dashboard.
- Chrome extension.
- iOS app.
- Payments.
- Production analytics.

Those are valuable, but they are not needed to prove the first Mac-visible developer quota/status signal.
