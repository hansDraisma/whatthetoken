# Agent Operating Rules

Date: 2026-05-04

These rules apply to Codex, Claude, and any future Conductor-managed agents working on WhatTheToken.

## Core Product Rules

- Build for developers first.
- Prefer local-first ingestion and minimal cloud sync.
- Never collect prompts, completions, conversation contents, cookies, auth headers, bearer tokens, or provider session tokens.
- Every usage number must include confidence: `verified`, `observed`, `estimated`, or `stale`.
- Every usage number must include freshness.
- Surface undercount risk when activity from other devices or surfaces may be missing.

## Engineering Rules

- Use TDD for behavior changes.
- Write the failing test first.
- Run the failing test and confirm the failure.
- Implement the minimum code needed.
- Run the focused test.
- Run the relevant package checks.
- Commit small, coherent changes.
- Respect foundation-task barriers before parallel work. For Phase 1, the root workspace scaffold must be available as the base before starting core, Mac, documentation, or research worktrees.
- Use the pinned package manager. If `package.json` declares `packageManager: pnpm@10.0.0`, `pnpm --version` must print exactly `10.0.0` before running `pnpm install`; use Corepack to resolve mismatches.
- Review lockfile changes deliberately. `pnpm-lock.yaml` is an owned artifact, not incidental install noise.

## Architecture Rules

- Keep quota math and snapshot derivation in `packages/core`.
- Keep provider/product/surface parser code isolated.
- Do not bury provider-specific logic in UI components.
- Prefer pure functions for core logic.
- Add dependencies only when they remove meaningful complexity.
- Use SwiftUI for the Mac product direction.
- Keep future non-Mac touchpoints possible through shared schemas, documented contracts, and backend APIs.

## Security Rules

- No sensitive provider credentials in logs.
- No prompt or response text in analytics.
- No remote code loading in browser extension code.
- Use minimal browser permissions.
- Treat parser failures as user-visible health states, not silent errors.

## Definition Of Done

A task is done only when:

- Tests are added or updated, or the task explicitly does not need tests.
- Focused tests pass.
- Typecheck passes where applicable.
- Lint passes where applicable.
- Package-manager version and lockfile changes are verified where applicable.
- Privacy impact is considered.
- Confidence and freshness behavior is handled.
- Docs or ADRs are updated if the task changes architecture or product scope.

## Review Checklist

Before merging or accepting agent work, check:

- Does this collect only allowed data?
- Does the change still match `docs/architecture/data-contract.md`?
- Has `docs/architecture/privacy-boundaries.md` been reviewed for any ingestion, sync, fixture, logging, analytics, or quota UI change?
- Is confidence labeling correct?
- Is stale/undercount behavior explicit?
- Are provider-specific assumptions isolated?
- Are tests meaningful and focused?
- Are package-manager and lockfile changes intentional?
- Is the change smaller than it could reasonably be?
