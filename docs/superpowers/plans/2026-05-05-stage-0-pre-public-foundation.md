# Stage 0 Pre-Public Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the root documentation, issue templates, and CI needed to make WhatTheToken safe to publish later while keeping the repo private until Public V1.

**Architecture:** Stage 0 is a documentation and governance slice. Root docs explain the product and trust boundary, issue templates prevent sensitive-data leakage, and CI verifies the existing synthetic Swift and TypeScript tests without live provider access.

**Tech Stack:** Markdown, GitHub issue forms, GitHub Actions, pnpm 10, Swift Package Manager on macOS 14.

---

## Scope

Implement only Stage 0 from `docs/roadmap/development-roadmap.md`.

In scope:

- root `README.md`
- Apache-2.0 `LICENSE`
- root `PRIVACY.md`
- root `SECURITY.md`
- root `CONTRIBUTING.md`
- `.github/ISSUE_TEMPLATE/bug_report.yml`
- `.github/ISSUE_TEMPLATE/provider_breakage.yml`
- `.github/ISSUE_TEMPLATE/config.yml`
- `.github/workflows/test.yml`
- roadmap links to this spec and plan

Out of scope:

- public repository visibility change
- app bundle generation
- menu bar implementation
- signed or notarized DMG
- Sparkle
- provider expansion
- hosted sync
- telemetry
- paid DMG, trial, or license-key infrastructure

## File Structure

- Create: `README.md` - product entrypoint, current status, supported connectors, local development, verification, trust promise.
- Create: `LICENSE` - Apache-2.0 license.
- Create: `PRIVACY.md` - user-facing and contributor-facing privacy policy aligned to architecture docs.
- Create: `SECURITY.md` - vulnerability reporting and secret-sharing rules.
- Create: `CONTRIBUTING.md` - development setup, connector rules, fixture rules, review checklist.
- Create: `.github/ISSUE_TEMPLATE/bug_report.yml` - safe bug report issue form.
- Create: `.github/ISSUE_TEMPLATE/provider_breakage.yml` - safe provider breakage issue form.
- Create: `.github/ISSUE_TEMPLATE/config.yml` - disable blank issues and route users to safe templates.
- Create: `.github/workflows/test.yml` - synthetic TypeScript and Swift test workflow.
- Modify: `docs/roadmap/development-roadmap.md` - link Stage 0 to this spec and plan.

## Task 1: Add Product README And License

**Files:**
- Create: `README.md`
- Create: `LICENSE`

- [ ] **Step 1: Confirm root docs are absent**

Run:

```bash
ls README.md LICENSE 2>/dev/null || true
```

Expected: no existing root README or LICENSE is printed. If one exists, preserve useful existing content while bringing it into this plan's structure.

- [ ] **Step 2: Create `README.md`**

Create `README.md` with these sections in this order:

````md
# WhatTheToken

Open, local-first AI quota status for developers using multiple coding agents.

## Status

WhatTheToken is pre-public. The repository should remain private until Public V1: the first signed and notarized free DMG with Claude Code and Codex support.

## What It Answers

- Which AI coding tool can I use right now?
- When will constrained quota reset?
- How reliable is this number?

## Current Support

| Provider | Product | Surface | Status | Confidence model |
|---|---|---|---|---|
| Anthropic | Claude Code | CLI | Implemented connector path | Verified when provider usage status is available |
| OpenAI | Codex | Local app-server | Implemented connector path | Observed until app-server quota semantics are fully validated |

Provider expansion is post-Public V1 unless the roadmap is explicitly changed.

## Privacy Promise

Provider credentials stay on your device. WhatTheToken stores and displays only sanitized usage status.

The app must not collect prompts, responses, conversation content, cookies, auth headers, bearer tokens, provider session tokens, raw provider payloads, or raw local databases that can contain forbidden data.

Every usage number must be labeled as `verified`, `observed`, `estimated`, or `stale`.

## License

WhatTheToken uses Apache-2.0. Copyright 2026 Hans Draisma unless otherwise noted.

## Local Development

Prerequisites:

- macOS 14 or newer for the Mac app target
- Swift 6 toolchain
- Node.js compatible with the workspace package manager
- pnpm 10

Install dependencies:

```bash
pnpm install --frozen-lockfile
```

Run TypeScript core tests:

```bash
pnpm --filter @whatthetoken/core test
```

Run Mac tests:

```bash
cd apps/mac
swift test
```

## Connector Safety

Live provider checks are manual and opt-in. CI uses synthetic fixtures only.

Claude Code and Codex connectors must discard raw provider responses after parsing and must never persist copied provider credentials in WhatTheToken storage.

## Roadmap

- Canonical roadmap: `docs/roadmap/development-roadmap.md`
- Open-source strategy and business model: `docs/roadmap/open-source-strategy-and-business-model.md`
- Privacy boundary: `docs/architecture/privacy-boundaries.md`
- Data contract: `docs/architecture/data-contract.md`

## Contributing And Security

Read `CONTRIBUTING.md`, `PRIVACY.md`, and `SECURITY.md` before opening connector, diagnostics, fixture, sync, or UI quota-display changes.
````

- [ ] **Step 3: Create `LICENSE`**

Create `LICENSE` using the standard Apache License 2.0 text exactly as published by the Apache Software Foundation. Do not add a project-specific copyright line to `LICENSE`; the README license section carries the project copyright summary.

The license text must be Apache-2.0, matching `docs/roadmap/open-source-strategy-and-business-model.md`.

- [ ] **Step 4: Review README and license diff**

Run:

```bash
git diff -- README.md LICENSE
```

Expected: README describes a pre-public project and Apache-2.0 is the only license introduced.

- [ ] **Step 5: Commit README and license**

Run:

```bash
git add README.md LICENSE
git commit -m "docs: add project readme and license"
```

Expected: one docs commit is created.

## Task 2: Add Root Privacy Document

**Files:**
- Create: `PRIVACY.md`
- Reference: `docs/architecture/privacy-boundaries.md`
- Reference: `docs/adr/0001-local-first-minimal-data-ingestion.md`
- Reference: `docs/adr/0002-confidence-labels-and-provenance.md`

- [ ] **Step 1: Read architecture privacy boundary**

Run:

```bash
sed -n '1,220p' docs/architecture/privacy-boundaries.md
sed -n '1,180p' docs/adr/0001-local-first-minimal-data-ingestion.md
sed -n '1,180p' docs/adr/0002-confidence-labels-and-provenance.md
```

Expected: local-first, minimal-data, and confidence-label rules are already documented.

- [ ] **Step 2: Create `PRIVACY.md`**

Create `PRIVACY.md` with these sections:

```md
# Privacy

WhatTheToken is local-first. Provider credentials stay on your device. The app stores and displays only sanitized usage status.

## What The App May Read

After explicit connector consent, a connector may read only the local provider state needed to request or observe usage status.

Claude Code may use the local Claude Code credential in memory after opt-in. Codex may connect to the local Codex app-server after opt-in. WhatTheToken must not copy provider credentials into its own storage.

## What The App Must Never Collect

WhatTheToken must never collect, persist, sync, log, fixture, or ask users to paste:

- prompts
- responses
- conversation content
- conversation URLs
- cookies
- auth headers
- bearer tokens
- provider session tokens
- provider credentials
- API keys
- access tokens
- authorization values
- raw provider payloads
- raw local database rows
- raw browser storage dumps
- sensitive local paths

## What The App May Store Locally

WhatTheToken may store sanitized status data:

- provider, product, and surface
- quota pool and window identifiers
- used, limit, remaining, utilization, or credit balance
- reset timestamp when available
- last updated timestamp
- confidence label
- undercount risk
- stale reason
- sanitized source state
- parser/source version
- connector enabled state and app preferences

## Confidence Labels

Every usage number must show whether it is `verified`, `observed`, `estimated`, or `stale`.

## Diagnostics

Diagnostics must be redacted and inspectable by the user before sharing. Diagnostics must not include credentials, tokens, prompts, responses, raw provider payloads, or sensitive local paths.

## Telemetry

Product telemetry is off by default for Public V1. Any future telemetry must be opt-in and must not include forbidden sensitive data.

## Threat Model Summary

Important risks include accidental logging, users pasting secrets into issue reports, fixtures copied from real provider responses, parser regressions that expose raw fields, and rogue or compromised contributor changes that attempt exfiltration.

Mitigations include explicit connector consent, synthetic fixtures, redaction checks, issue-template warnings, small trusted maintainer review before public launch, and CI tests that do not require live provider access.

## Incident Response

If sensitive data is reported or found in the repository, remove the exposure, rotate affected credentials when applicable, audit nearby code paths, and document the fix without repeating the sensitive data.

## Architecture References

- `docs/architecture/privacy-boundaries.md`
- `docs/architecture/data-contract.md`
- `docs/adr/0001-local-first-minimal-data-ingestion.md`
- `docs/adr/0002-confidence-labels-and-provenance.md`
```

- [ ] **Step 3: Scan privacy doc for accidental forbidden examples**

Run:

```bash
LC_ALL=C rg -in '(access''[_-]?token|api''[_-]?key|authorization''[[:space:]]*:|bearer ''[A-Za-z0-9._-]{12,}|coo''kie[[:space:]]*:|set-''coo''kie[[:space:]]*:|sk-''[A-Za-z0-9_-]{10,}|xo''x[baprs]-|gh''p_[A-Za-z0-9]|github_''pat_)' PRIVACY.md || true
```

Expected: no matches.

- [ ] **Step 4: Commit privacy doc**

Run:

```bash
git add PRIVACY.md
git commit -m "docs: add root privacy policy"
```

Expected: one docs commit is created.

## Task 3: Add Security And Contributing Docs

**Files:**
- Create: `SECURITY.md`
- Create: `CONTRIBUTING.md`

- [ ] **Step 1: Create `SECURITY.md`**

Create `SECURITY.md` with these sections:

```md
# Security

## Supported Versions

Before Public V1, only the current private development branch is supported. Public V1 support begins after the first signed and notarized free DMG is published.

## Reporting A Vulnerability

Before Public V1, report vulnerabilities through an existing private maintainer channel. After the repository becomes public, use GitHub private vulnerability reporting if it is enabled.

Do not paste secrets, provider tokens, cookies, auth headers, prompts, responses, raw provider payloads, raw local database rows, or sensitive local paths into issues, discussions, pull requests, or logs.

## Useful Report Content

Include only sanitized details:

- WhatTheToken version or commit
- macOS version
- connector name
- sanitized connector state
- reproduction steps
- expected behavior
- actual behavior
- whether the issue reproduces with synthetic fixtures

## Local Security Model

Provider credentials stay local. Connectors may use local provider credentials or app-server state in memory only after explicit user consent. WhatTheToken stores sanitized usage status, connector settings, and preferences, not copied provider credentials.

## Out Of Scope

Reports that require collecting forbidden sensitive data are out of scope until a privacy-preserving reproduction exists. Unsupported forks and modified builds are outside the official support boundary.
```

- [ ] **Step 2: Create `CONTRIBUTING.md`**

Create `CONTRIBUTING.md` with these sections:

````md
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
````

- [ ] **Step 3: Review security and contributing docs**

Run:

```bash
git diff -- SECURITY.md CONTRIBUTING.md
```

Expected: docs give concrete safety and contributor rules without introducing live secrets or public-launch claims.

- [ ] **Step 4: Commit security and contributing docs**

Run:

```bash
git add SECURITY.md CONTRIBUTING.md
git commit -m "docs: add security and contribution rules"
```

Expected: one docs commit is created.

## Task 4: Add Safe Issue Templates

**Files:**
- Create: `.github/ISSUE_TEMPLATE/bug_report.yml`
- Create: `.github/ISSUE_TEMPLATE/provider_breakage.yml`
- Create: `.github/ISSUE_TEMPLATE/config.yml`

- [ ] **Step 1: Create issue template directory**

Run:

```bash
mkdir -p .github/ISSUE_TEMPLATE
```

Expected: `.github/ISSUE_TEMPLATE` exists.

- [ ] **Step 2: Create bug report template**

Create `.github/ISSUE_TEMPLATE/bug_report.yml`:

```yaml
name: Bug report
description: Report a WhatTheToken bug without sharing sensitive data.
title: "[Bug]: "
labels: ["bug"]
body:
  - type: markdown
    attributes:
      value: |
        Do not paste prompts, responses, cookies, auth headers, bearer tokens, provider session tokens, API keys, raw provider payloads, raw local database rows, or sensitive local paths.
  - type: input
    id: version
    attributes:
      label: WhatTheToken version or commit
      description: Use the app version or commit hash.
    validations:
      required: true
  - type: input
    id: macos
    attributes:
      label: macOS version
    validations:
      required: false
  - type: textarea
    id: summary
    attributes:
      label: Summary
      description: Describe the bug without sensitive provider data.
    validations:
      required: true
  - type: textarea
    id: steps
    attributes:
      label: Reproduction steps
      description: Use sanitized steps only.
    validations:
      required: true
  - type: textarea
    id: expected
    attributes:
      label: Expected behavior
    validations:
      required: true
  - type: textarea
    id: actual
    attributes:
      label: Actual behavior
    validations:
      required: true
  - type: textarea
    id: safe_diagnostics
    attributes:
      label: Sanitized diagnostics
      description: Include only redacted diagnostics you have inspected.
    validations:
      required: false
```

- [ ] **Step 3: Create provider breakage template**

Create `.github/ISSUE_TEMPLATE/provider_breakage.yml`:

```yaml
name: Provider breakage
description: Report a connector or provider parser problem without sharing sensitive data.
title: "[Provider]: "
labels: ["provider-breakage"]
body:
  - type: markdown
    attributes:
      value: |
        Do not paste provider tokens, cookies, auth headers, prompts, responses, raw JSON-RPC envelopes, raw provider payloads, app-server logs, raw local database rows, or sensitive local paths.
  - type: dropdown
    id: connector
    attributes:
      label: Connector
      options:
        - Claude Code
        - Codex
        - Other
    validations:
      required: true
  - type: input
    id: product_version
    attributes:
      label: Provider app or CLI version
      description: Use a version string only. Do not paste logs or paths.
    validations:
      required: false
  - type: input
    id: app_version
    attributes:
      label: WhatTheToken version or commit
    validations:
      required: true
  - type: dropdown
    id: source_state
    attributes:
      label: Sanitized source state
      options:
        - not_connected
        - missing_credentials
        - permission_denied
        - token_invalid
        - rate_limited
        - network_error
        - schema_changed
        - stale
        - connected
        - unknown
    validations:
      required: true
  - type: textarea
    id: behavior
    attributes:
      label: What changed
      description: Describe the breakage without raw provider data.
    validations:
      required: true
  - type: checkboxes
    id: checks
    attributes:
      label: Checks
      options:
        - label: I manually refreshed the connector.
          required: false
        - label: I inspected diagnostics and removed sensitive data.
          required: true
        - label: I did not paste prompts, responses, credentials, raw provider payloads, or sensitive local paths.
          required: true
```

- [ ] **Step 4: Disable blank issues**

Create `.github/ISSUE_TEMPLATE/config.yml`:

```yaml
blank_issues_enabled: false
# Stage 5 should add a security contact link after the public repo name and
# GitHub private vulnerability reporting are finalized.
```

- [ ] **Step 5: Commit issue templates**

Run:

```bash
git add .github/ISSUE_TEMPLATE
git commit -m "docs: add safe issue templates"
```

Expected: one docs commit is created.

## Task 5: Add Synthetic Test CI

**Files:**
- Create: `.github/workflows/test.yml`

- [ ] **Step 1: Create workflows directory**

Run:

```bash
mkdir -p .github/workflows
```

Expected: `.github/workflows` exists.

- [ ] **Step 2: Create GitHub Actions test workflow**

Create `.github/workflows/test.yml`:

```yaml
name: Test

on:
  push:
    branches:
      - main
  pull_request:

jobs:
  test:
    name: Swift and TypeScript tests
    runs-on: macos-latest
    steps:
      - name: Check out repository
        uses: actions/checkout@v4

      - name: Set up pnpm
        uses: pnpm/action-setup@v4
        with:
          version: 10.0.0

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: pnpm

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Run core tests
        run: pnpm --filter @whatthetoken/core test

      - name: Run Mac tests
        working-directory: apps/mac
        run: swift test
```

This workflow must not require Claude credentials, Codex app-server access, Keychain access, cookies, browser state, or live provider network calls.

- [ ] **Step 3: Commit CI workflow**

Run:

```bash
git add .github/workflows/test.yml
git commit -m "ci: add synthetic test workflow"
```

Expected: one CI commit is created.

## Task 6: Link Stage 0 Docs And Verify

**Files:**
- Modify: `docs/roadmap/development-roadmap.md`
- Reference: `docs/superpowers/specs/2026-05-05-stage-0-pre-public-foundation-design.md`
- Reference: `docs/superpowers/plans/2026-05-05-stage-0-pre-public-foundation.md`

- [ ] **Step 1: Add Stage 0 refinement links**

In `docs/roadmap/development-roadmap.md`, directly under `### Stage 0: Pre-Public Foundation`, add:

```md
Stage spec: `docs/superpowers/specs/2026-05-05-stage-0-pre-public-foundation-design.md`

Implementation plan: `docs/superpowers/plans/2026-05-05-stage-0-pre-public-foundation.md`
```

- [ ] **Step 2: Run TypeScript tests**

Run:

```bash
pnpm --filter @whatthetoken/core test
```

Expected: all core Vitest tests pass.

- [ ] **Step 3: Run Swift tests**

Run:

```bash
cd apps/mac
swift test
```

Expected: all Swift tests pass.

- [ ] **Step 4: Run whitespace check**

Run:

```bash
git diff --check
```

Expected: no output.

- [ ] **Step 5: Run docs consistency scan**

Run:

```bash
LC_ALL=C rg -n '[^\x00-\x7F]|TO''DO|TB''D|mandatory paid D''MG|paid official conven''ience|MI''T would|MI''T if|Chat''GPT web or desktop|official signed/notarized D''MG is free for V''1|free D''MG for V''1' README.md PRIVACY.md SECURITY.md CONTRIBUTING.md LICENSE .github docs/roadmap docs/superpowers/specs/2026-05-05-stage-0-pre-public-foundation-design.md docs/superpowers/plans/2026-05-05-stage-0-pre-public-foundation.md || true
```

Expected: no matches.

- [ ] **Step 6: Run sensitive-data pattern scan**

Run:

```bash
LC_ALL=C rg -in '(access''[_-]?token|api''[_-]?key|authorization''[[:space:]]*:|bearer ''[A-Za-z0-9._-]{12,}|coo''kie[[:space:]]*:|set-''coo''kie[[:space:]]*:|sk-''[A-Za-z0-9_-]{10,}|xo''x[baprs]-|gh''p_[A-Za-z0-9]|github_''pat_)' README.md PRIVACY.md SECURITY.md CONTRIBUTING.md .github docs apps packages || true
```

Expected: manually review any matches. Matches are acceptable only when they are deny-list rules, redaction rules, intentional in-memory credential boundary code, or synthetic tests. No real secrets, raw provider payloads, or raw local provider data are present. This grep is a lightweight guardrail, not a substitute for manual privacy review.

- [ ] **Step 7: Review final diff**

Run:

```bash
git diff --stat
git diff -- README.md LICENSE PRIVACY.md SECURITY.md CONTRIBUTING.md .github docs/roadmap/development-roadmap.md docs/superpowers/specs/2026-05-05-stage-0-pre-public-foundation-design.md docs/superpowers/plans/2026-05-05-stage-0-pre-public-foundation.md
```

Expected: changes are limited to Stage 0 public-readiness docs, safe issue templates, CI, and roadmap links.

- [ ] **Step 8: Commit roadmap link and any final fixes**

Run:

```bash
git add docs/roadmap/development-roadmap.md docs/superpowers/specs/2026-05-05-stage-0-pre-public-foundation-design.md docs/superpowers/plans/2026-05-05-stage-0-pre-public-foundation.md README.md LICENSE PRIVACY.md SECURITY.md CONTRIBUTING.md .github
git commit -m "docs: finalize pre-public foundation"
```

Expected: any final Stage 0 refinements are committed, including the Stage 0 spec and plan files that the roadmap links to. If there are no remaining changes after previous task commits, skip this commit.

## Completion Criteria

Stage 0 is complete when:

- root README, license, privacy, security, and contributing docs exist
- safe issue templates exist
- CI workflow exists
- roadmap links point to the Stage 0 spec and plan
- Stage 0 spec and plan are committed with the roadmap links
- TypeScript core tests pass
- Swift Mac tests pass
- docs consistency scan is clean
- sensitive-data grep plus manual review finds no real secrets or raw provider data
- repository remains private
