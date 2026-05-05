# Stage 0 Pre-Public Foundation Design

Date: 2026-05-05

Status: refined stage spec for `docs/roadmap/development-roadmap.md` Stage 0.

## Purpose

Stage 0 makes WhatTheToken safe and understandable to publish later without actually publishing it yet.

The project already has working Claude Code and Codex connector paths, tests, architecture docs, and a basic SwiftUI app. The next immediate risk is not more provider ingestion. The next risk is trust: a future public repo must explain what the app does, what it never reads, how contributors should avoid leaking sensitive data, and how CI verifies the local-only contract.

## Stage Boundary

Stage 0 is a pre-public documentation and governance slice.

It produces:

- root project documentation
- license choice in the repository
- privacy and security docs suitable for a public repo
- contributor rules for provider connectors and fixtures
- issue templates that discourage users from posting secrets
- CI that runs synthetic Swift and TypeScript tests
- roadmap links that keep public-readiness docs aligned with the canonical roadmap

It does not produce:

- a public repo visibility flip
- a signed or notarized DMG
- app bundle or menu bar work
- monetization infrastructure
- provider expansion
- hosted sync
- telemetry

The repository remains private after Stage 0 unless the Public V1 exit criteria in `docs/roadmap/development-roadmap.md` are met.

## Current Inputs

Stage 0 should build on these existing sources:

- `docs/roadmap/development-roadmap.md`
- `docs/roadmap/open-source-strategy-and-business-model.md`
- `docs/architecture/privacy-boundaries.md`
- `docs/architecture/data-contract.md`
- `docs/architecture/tech-stack-and-development-approach.md`
- `docs/adr/0001-local-first-minimal-data-ingestion.md`
- `docs/adr/0002-confidence-labels-and-provenance.md`
- `packages/core/README.md`
- `apps/mac/Package.swift`
- existing connector tests under `apps/mac/Tests/WhatTheTokenMacTests/`
- existing core tests under `packages/core/src/__tests__/`

## Approach Decision

Three approaches were considered.

### Option A: Minimal Public Files

Add only `README.md`, `LICENSE`, and a simple CI workflow.

This is fastest, but it leaves the most important trust surfaces underspecified. For a local app that touches auth-adjacent provider state, a thin README is not enough.

### Option B: Trust-Foundation Bundle

Add root docs, privacy/security/contributing rules, issue templates, and CI in one focused stage. Keep the repo private until later stages deliver the app shell and signed build.

This is the recommended approach. It gives future contributors and private testers clear boundaries before more UI and distribution work begins, while avoiding a weak public launch.

### Option C: Full Public Launch Kit

Add all public docs, release packaging, signing, GitHub Release automation, and app distribution in one larger stage.

This is too broad. It would mix editorial trust work with app packaging and signing decisions that belong in Stage 5.

Stage 0 should use Option B.

## Document Design

### `README.md`

The root README is the public entrypoint, even while the repo remains private. It should be honest about status and should not pretend the app is ready for broad public use.

Required sections:

- product name and one-sentence positioning
- current status: pre-public, not Public V1
- what the app answers: best usable tool, reset timing, reliability of each number
- current support matrix: Claude Code and Codex only
- privacy promise: provider credentials stay local; WhatTheToken stores only sanitized usage status
- trust labels: `verified`, `observed`, `estimated`, `stale`
- install/run status: source/development only until Public V1
- local development prerequisites
- verification commands
- license summary
- connector safety summary
- roadmap links
- contribution and security links

The README should not advertise a public DMG, paid trial, app store listing, or hosted service.

### `LICENSE`

Use Apache-2.0.

The license must match the strategy decision in `docs/roadmap/open-source-strategy-and-business-model.md`. Do not use MIT in Stage 0.

### `PRIVACY.md`

The root privacy document is user-facing and contributor-facing. It should be consistent with `docs/architecture/privacy-boundaries.md`, but it should not require a reader to understand every architecture detail.

Required sections:

- short privacy promise
- local-first model
- what WhatTheToken may read after explicit connector consent
- what WhatTheToken never collects
- what sanitized data may be stored locally
- connector-specific boundaries for Claude Code and Codex
- diagnostics and support export rules
- default telemetry position
- threat model summary, including accidental logging and malicious contributor risk
- incident response expectations
- links to architecture privacy boundary and ADRs

The privacy doc must not include provider tokens, raw provider payload examples, local credential extraction tutorials beyond the already documented boundary, or screenshots of private provider state.

### `SECURITY.md`

Security reporting should protect users from pasting secrets into public issues.

Required sections:

- supported versions: pre-public development branch only until Public V1
- vulnerability reporting path
- explicit instruction not to paste secrets, provider payloads, prompts, logs, cookies, auth headers, tokens, or local database rows into issues
- what to include in a report: app version, connector, sanitized state, reproduction steps, expected behavior, actual behavior
- local security model summary
- out-of-scope items, such as unsupported forks or claims requiring collection of forbidden data

Because the repository is not public yet, the reporting path should be practical: use private maintainer channels before Public V1, and enable GitHub private vulnerability reporting before the repository visibility flip.

### `CONTRIBUTING.md`

The contributor doc should make privacy review operational.

Required sections:

- development setup
- test commands
- Swift and TypeScript package boundaries
- provider connector rules
- fixture rules
- redaction requirements
- CI expectations
- review checklist
- commit and PR expectations
- documentation update expectations

Contributor guidance must make clear that live provider checks stay manual and opt-in, while CI uses synthetic fixtures only.

### `.github/ISSUE_TEMPLATE/`

Issue templates should be ready before public launch, but they can exist while the repo remains private.

Required templates:

- bug report
- provider breakage report

Both templates must warn users not to paste secrets, provider tokens, cookies, auth headers, prompts, responses, raw provider JSON, raw local database rows, or sensitive local paths.

Provider breakage reports should request sanitized connector state, provider/product/surface, app version, provider app/CLI version when relevant, and whether the user has rerun a manual refresh.

Blank public issues should be disabled once the repo is public unless there is a deliberate decision to allow them.

### `.github/workflows/test.yml`

CI should prove that the repository works without live provider access.

Required behavior:

- run on pull requests, pushes to `main`, and manual dispatch
- install pnpm
- install dependencies with `pnpm install --frozen-lockfile`
- run `pnpm --filter @whatthetoken/core test`
- run `swift test` from `apps/mac`
- avoid live provider, Keychain, Codex app-server, cookie, browser, or network dependencies

CI may run on `macos-latest` for the combined Swift and TypeScript jobs to keep Stage 0 simple. A later optimization can split jobs by platform if runtime or cost becomes a problem.

## Threat Model Additions

Stage 0 public docs should summarize these risks:

- accidental logging of tokens or raw provider payloads
- issue reports that include secrets
- fixture files copied from real provider responses
- connector parser regressions that expose raw fields
- rogue or compromised contributor pull requests that add exfiltration
- users misunderstanding confidence labels
- maintainers burning out under provider breakage reports

Stage 0 mitigations:

- sensitive-data deny lists in root docs and issue templates
- fixture rules requiring synthetic data
- CI tests that do not require live provider access
- contributor review checklist for connector and diagnostics changes
- redaction tests and grep checks
- small trusted maintainer set before public launch
- clear scope boundaries so the project does not promise unsupported providers too early

## Acceptance Criteria

- `README.md` explains what WhatTheToken does, what it supports now, what Public V1 means, and how to run tests.
- `LICENSE` is Apache-2.0.
- `PRIVACY.md` clearly separates forbidden sensitive data from allowed sanitized usage status.
- `SECURITY.md` gives a safe vulnerability reporting path and warns against sharing secrets in issues.
- `CONTRIBUTING.md` gives concrete connector, fixture, redaction, test, and review rules.
- Bug and provider breakage issue templates exist and include sensitive-data warnings.
- CI runs TypeScript core tests and Swift Mac tests on pull requests, pushes to `main`, and manual dispatch without live provider access.
- Roadmap docs point to this Stage 0 spec and plan.
- No Stage 0 document claims the repo is public-launch ready.
- No Stage 0 work starts Stage 1 app bundle or menu bar implementation.

## Verification

Run these checks before accepting Stage 0:

```bash
pnpm --filter @whatthetoken/core test
(cd apps/mac && swift test)
git diff --check
LC_ALL=C rg -n '[^\x00-\x7F]|TO''DO|TB''D|mandatory paid D''MG|paid official conven''ience|MI''T would|MI''T if|Chat''GPT web or desktop|official signed/notarized D''MG is free for V''1|free D''MG for V''1' README.md PRIVACY.md SECURITY.md CONTRIBUTING.md LICENSE .github docs/roadmap docs/superpowers/specs/2026-05-05-stage-0-pre-public-foundation-design.md docs/superpowers/plans/2026-05-05-stage-0-pre-public-foundation.md
LC_ALL=C rg -in '(access''[_-]?token|api''[_-]?key|authorization''[[:space:]]*:|bearer ''[A-Za-z0-9._-]{12,}|coo''kie[[:space:]]*:|set-''coo''kie[[:space:]]*:|sk-''[A-Za-z0-9_-]{10,}|xo''x[baprs]-|gh''p_[A-Za-z0-9]|github_''pat_)' README.md PRIVACY.md SECURITY.md CONTRIBUTING.md .github docs apps packages
```

Expected results:

- TypeScript and Swift tests pass.
- `git diff --check` reports no whitespace errors.
- The docs consistency scan has no matches.
- Sensitive-pattern matches are manually reviewed and limited to deny-list text, redaction rules, intentional in-memory credential boundary code, or synthetic tests; no real secrets or raw provider payloads are present.

## Open Decisions

None for Stage 0.

The public repository name and security contact mechanics must be finalized before the Stage 5 public visibility flip, but Stage 0 can proceed with docs that avoid workspace names and instruct users to use private maintainer channels until Public V1.
