# Contributing

## Development Setup

Install dependencies from the repository root:

```bash
pnpm install --frozen-lockfile
```

Run core tests:

```bash
pnpm --filter @whatthetoken/core test
```

Run Mac tests:

```bash
cd apps/mac
swift test
```

## CI

The GitHub Actions test workflow runs on pull requests, pushes to `main`, and manual dispatch from the Actions tab. CI must remain synthetic: do not add live provider credentials, Keychain access, Codex app-server access, cookies, browser state, or provider network calls to the workflow.

## Package Boundaries

`packages/core` owns portable schemas, confidence labels, snapshot helpers, and staleness logic.

`apps/mac` owns SwiftUI views, local connector orchestration, local credential access boundaries, smoke commands, and macOS-specific behavior.

## Provider Connector Rules

- Require explicit user opt-in before reading local provider state.
- Use provider credentials only in memory.
- Do not persist copied provider credentials in WhatTheToken storage.
- Discard raw provider responses after parsing.
- Emit sanitized source states instead of raw provider errors.
- Add parser/source version metadata.
- Add synthetic fixture coverage for parser changes.

## Fixture Rules

Fixtures must be synthetic. Do not copy real provider payloads, prompts, responses, cookies, auth headers, tokens, local database rows, browser storage, or sensitive local paths into tests.

## Review Checklist

Before submitting connector, diagnostics, fixture, sync, or UI quota-display changes, verify:

- privacy deny list is not weakened
- every number has a confidence label
- stale state remains visible
- raw provider payloads are not logged or persisted
- tests use synthetic data
- `pnpm --filter @whatthetoken/core test` passes
- `swift test` passes from `apps/mac`

## Documentation

Update `docs/architecture/privacy-boundaries.md`, `docs/architecture/data-contract.md`, or an ADR when changing privacy boundaries, schema shape, confidence semantics, or connector source boundaries.
