# Task 7 Privacy And Contract Documentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the thin Task 7 architecture notes with operational privacy and data-contract documentation that future ingestion work can follow and verify.

**Architecture:** `packages/core/src/schemas.ts` remains the Phase 1 runtime source of truth for usage events and snapshots. The architecture docs explain that contract, define privacy allow/deny lists, and link those docs from the broader engineering rules so future agents review them before ingestion, sync, extension, or UI changes.

**Tech Stack:** Markdown documentation, pnpm workspace checks, Swift Package Manager checks where contract-facing Mac files are affected, ripgrep for privacy review.

---

## Constraints

- Keep this task documentation-only unless a real mismatch is found between docs and existing code.
- Do not add provider ingestion, backend sync, browser extension, legal policy pages, analytics, or UI changes.
- Do not introduce examples that contain prompts, completions, conversation text, cookies, auth headers, bearer tokens, provider session tokens, provider credentials, API keys, access tokens, authorization values, secrets, raw browser storage, or browser request bodies.
- Treat `packages/core/src/schemas.ts` as the source of truth for Phase 1 event and snapshot shape.
- Require an ADR for future changes that weaken privacy boundaries or add sensitive data categories.

## File Structure

- Modify: `docs/architecture/data-contract.md` - expand the Phase 1 event and snapshot contract, allowed enum values, invariants, and source-of-truth rules.
- Modify: `docs/architecture/privacy-boundaries.md` - expand forbidden sensitive data, allowed sanitized usage data, local connector credential rules, diagnostics redaction, examples of acceptable identifiers, and ADR requirements.
- Modify: `docs/architecture/tech-stack-and-development-approach.md` - link Task 7 docs from architecture and development rules.
- Modify: `docs/agent/operating-rules.md` - ensure future agents check privacy boundaries and data contract before work that touches ingestion, schemas, fixtures, sync, or UI quota display.

## Task 1: Expand Data Contract Documentation

**Files:**
- Modify: `docs/architecture/data-contract.md`
- Reference: `packages/core/src/schemas.ts`
- Reference: `packages/core/README.md`
- Reference: `apps/mac/Sources/WhatTheTokenMac/Models/UsageSnapshot.swift`

- [ ] **Step 1: Read the current runtime schema**

Run:

```bash
sed -n '1,260p' packages/core/src/schemas.ts
sed -n '1,220p' apps/mac/Sources/WhatTheTokenMac/Models/UsageSnapshot.swift
```

Expected: `usageEventSchema` and `usageSnapshotSchema` define the Phase 1 fields; the Swift `UsageSnapshot` mirrors the snapshot fields used by the fixture-backed Mac app.

- [ ] **Step 2: Replace `docs/architecture/data-contract.md`**

Write this complete file:

```md
# Data Contract

Date: 2026-05-04

`packages/core/src/schemas.ts` is the Phase 1 source of truth for usage event and usage snapshot shape. `packages/core/README.md` explains the package boundary and validation rules for developers consuming the shared contract. Swift models, fixtures, provider ingestors, sync payloads, and UI state must mirror this contract instead of defining provider-specific shapes.

## Taxonomy

Provider, product, and surface are separate fields. Do not collapse them into labels such as "OpenAI usage" because a provider can expose multiple products and a product can appear on multiple surfaces.

| Field | Allowed values |
|---|---|
| `provider` | `openai`, `anthropic`, `google`, `cursor`, `github` |
| `product` | `codex`, `chatgpt`, `claude_code`, `claude`, `gemini`, `cursor`, `github_copilot` |
| `surface` | `cli`, `web`, `browser_extension`, `desktop_app`, `ide`, `cloud_agent`, `mobile` |
| Snapshot aggregate surface | `aggregate` |

## Confidence

Every event and snapshot must include one confidence value.

| Value | Meaning |
|---|---|
| `verified` | Derived from authoritative provider or local quota data. |
| `observed` | Counted directly from a local client action. |
| `estimated` | Inferred from observed activity and public or user-supplied limits. |
| `stale` | Last signal is too old to trust. |

When confidence is `stale`, `staleReason` is required. When confidence is not `stale`, `staleReason` must be `null`.

## Units And Risk

Allowed usage units:

- `messages`
- `requests`
- `tokens`
- `credits`
- `utilization`

Allowed undercount risk values:

- `none`
- `possible`
- `likely`

Use `possible` or `likely` when local observation can miss other devices, browsers, IDEs, cloud agents, or mobile activity.

## Usage Event

A usage event is a sanitized observation or quota poll. It must not contain prompt text, response text, conversation identifiers that reveal content, cookies, auth headers, bearer tokens, provider session tokens, or browser request bodies.

Event payloads are strict. Unknown fields are rejected so sensitive data cannot quietly enter the domain model by accident.

Required fields:

| Field | Type and constraints |
|---|---|
| `id` | Non-empty string |
| `userAccountId` | Non-empty string |
| `deviceId` | Non-empty string |
| `providerAccountId` | Non-empty string or `null` |
| `provider` | Allowed provider value |
| `product` | Allowed product value |
| `surface` | Allowed surface value |
| `eventType` | Allowed event type |
| `modelKey` | Non-empty string or `null` |
| `count` | Non-negative integer |
| `observedAt` | ISO datetime string |
| `confidence` | Allowed confidence value |
| `sourceVersion` | Non-empty string |
| `attribution` | Strict attribution object |

Allowed `eventType` values:

- `message_sent`
- `agent_run_started`
- `agent_run_finished`
- `quota_polled`

Attribution fields:

| Field | Type and constraints |
|---|---|
| `canMissOtherDevices` | Required boolean |
| `deviceName` | Optional non-empty string |
| `os` | Optional value: `macos`, `windows`, `linux`, `ios`, `android`, `unknown` |
| `browser` | Optional value: `chrome`, `edge`, `brave`, `firefox`, `safari`, `unknown` |

## Usage Snapshot

A usage snapshot is the display-ready state for a quota pool and window.

Required fields:

| Field | Type and constraints |
|---|---|
| `id` | Non-empty string |
| `userAccountId` | Non-empty string |
| `provider` | Allowed provider value |
| `product` | Allowed product value |
| `surface` | Allowed surface value or `aggregate` |
| `poolKey` | Non-empty string |
| `windowKey` | Non-empty string |
| `unit` | Allowed usage unit |
| `used` | Non-negative number or `null` |
| `limit` | Positive number or `null` |
| `remaining` | Non-negative number or `null` |
| `utilization` | Number greater than or equal to `0`, or `null` |
| `resetAt` | ISO datetime string or `null` |
| `lastUpdatedAt` | ISO datetime string |
| `confidence` | Allowed confidence value |
| `undercountRisk` | Allowed undercount risk value |
| `staleReason` | Non-empty string or `null` |

Snapshot math rules:

- When `used` and `limit` are known, `remaining` must equal `max(limit - used, 0)`.
- When `used` and `limit` are known, `utilization` must equal `used / limit`.
- When `used` or `limit` is unknown, `remaining` must be `null`.
- When `used` or `limit` is unknown, `utilization` must be `null`.
- `limit` must be positive when known.
- `used` and `remaining` must never be negative.
- Fractional usage measurements belong in snapshot fields such as `used`, not in event `count`.

## Contract Ownership

Changes to event or snapshot shape start in `packages/core/src/schemas.ts` with focused schema tests. Mac models, fixtures, architecture docs, and any future sync or extension payloads are downstream mirrors.

Any contract change that affects privacy boundaries also requires an ADR.
```

- [ ] **Step 3: Review data-contract diff**

Run:

```bash
git diff -- docs/architecture/data-contract.md
```

Expected: the diff expands contract details without adding speculative provider values or sensitive example data.

## Task 2: Expand Privacy Boundary Documentation

**Files:**
- Modify: `docs/architecture/privacy-boundaries.md`
- Reference: `docs/adr/0001-local-first-minimal-data-ingestion.md`
- Reference: `docs/adr/0002-confidence-labels-and-provenance.md`

- [ ] **Step 1: Replace `docs/architecture/privacy-boundaries.md`**

Write this complete file:

```md
# Privacy Boundaries

Date: 2026-05-04

WhatTheToken is local-first and minimal-data by default. Local ingestors may observe usage signals, but they must emit only sanitized usage events and snapshots that match `docs/architecture/data-contract.md`.

Product promise:

> Provider credentials stay on the user's device. WhatTheToken syncs only usage status.

## Must Never Collect

WhatTheToken must never collect, persist, sync, log, or fixture:

- prompts
- completions
- model responses
- conversation content
- conversation URLs
- cookies
- auth headers
- bearer tokens
- provider session tokens
- browser request bodies
- provider credentials
- API keys
- access tokens
- authorization values
- secrets
- raw local database rows that include any forbidden field above
- raw browser storage dumps

This deny list applies to production code, tests, fixtures, logs, debug output, analytics, support bundles, and documentation examples.

## Allowed Sanitized Usage Data

The product may collect sanitized usage metadata required to derive quota status:

- provider
- product
- surface
- model key when detectable without reading conversation content
- event type
- usage count, utilization, request amount, token amount, or credit amount
- observed timestamp
- quota reset timestamp
- non-secret user, device, provider-account, pool, and window identifiers
- confidence level
- freshness and stale reason
- undercount risk
- source or parser version
- sync or parser error status
- limited attribution such as operating system or browser family

Identifiers must be stable enough for deduplication and display, but they must not be copied from provider secrets or session tokens.

## Local Connector Credential Rules

Local connectors may read provider state only after explicit user opt-in.

When a connector needs a local provider credential or token to retrieve usage status:

- use the credential or token only in memory
- discard the credential or token after the request
- do not log the credential or token
- do not persist the credential or token in WhatTheToken storage
- do not upload the credential or token to any backend
- do not expose the credential or token to the browser extension
- sync or expose only sanitized usage snapshots and source states

Diagnostics must redact provider credentials, tokens, sensitive local paths, and raw provider payloads.

## Local Ingestor Rules

- Prefer parsing local quota/status files or direct local client signals over inspecting authenticated browser traffic.
- If a source can contain forbidden data, parse only the minimal fields needed and discard the raw source immediately.
- Do not log raw provider responses or local file contents.
- Treat parser failures as health states with confidence/freshness impact, not as a reason to collect broader data.
- Label numbers with confidence, freshness, and undercount risk close to where users see the number.

## Source States

Connectors should report structured source states instead of raw provider or OS errors:

- `not_connected`
- `missing_credentials`
- `permission_denied`
- `token_invalid`
- `rate_limited`
- `network_error`
- `schema_changed`
- `stale`

Surfaces should translate these states into product language without exposing raw provider responses, local paths, credentials, or tokens.

## Change Control

Any future change that weakens the deny list, allows a new sensitive data category, or requires broader local/browser permissions requires an ADR before implementation.

Any future legal privacy policy must be consistent with this engineering boundary, but this document is not a substitute for legal review.
```

- [ ] **Step 2: Review privacy-boundaries diff**

Run:

```bash
git diff -- docs/architecture/privacy-boundaries.md
```

Expected: the diff tightens the deny list, keeps allowed data aligned with schemas, and does not include realistic secret strings or user content examples.

## Task 3: Link Contract Docs From Architecture And Agent Rules

**Files:**
- Modify: `docs/architecture/tech-stack-and-development-approach.md`
- Modify: `docs/agent/operating-rules.md`

- [ ] **Step 1: Update architecture rules**

In `docs/architecture/tech-stack-and-development-approach.md`, add these bullets under `## Architecture Rules`:

```md
- Treat `docs/architecture/data-contract.md` as the human-readable companion to `packages/core/src/schemas.ts`.
- Review `docs/architecture/privacy-boundaries.md` before changing ingestion, sync, fixtures, logs, analytics, or quota UI.
```

Expected: the architecture document points future workers to both Task 7 docs.

- [ ] **Step 2: Update agent review checklist**

In `docs/agent/operating-rules.md`, add these bullets under `## Review Checklist`:

```md
- Does the change still match `docs/architecture/data-contract.md`?
- Has `docs/architecture/privacy-boundaries.md` been reviewed for any ingestion, sync, fixture, logging, analytics, or quota UI change?
```

Expected: agent reviews explicitly include Task 7 documentation.

- [ ] **Step 3: Review linking diffs**

Run:

```bash
git diff -- docs/architecture/tech-stack-and-development-approach.md docs/agent/operating-rules.md
```

Expected: only the intended checklist/link bullets changed.

## Task 4: Verify Privacy And Documentation Drift

**Files:**
- Review: `docs`
- Review: `packages`
- Review: `apps`

- [ ] **Step 1: Run privacy grep**

Run:

```bash
rg -n "prompt|completion|model response|conversation|cookie|bearer|auth header|session token|provider credential|request bod" docs packages apps
```

Expected: matches are limited to privacy deny-list rules, ADR discussions, roadmap rules, or tests that intentionally reject sensitive fields. No fixture or app resource may contain real prompt, response, cookie, auth header, bearer token, provider session token, provider credential, or browser request body content.

Run the broader secret-spelling grep:

```bash
rg -n "authorization|auth[_ -]?header|access[_ -]?token|api[_ -]?key|secret|credential|localStorage|browser storage|request bod" docs packages apps
```

Expected: matches are limited to privacy deny-list rules, ADR discussions, roadmap/research warnings, or tests that intentionally reject sensitive fields. No fixture or app resource may contain real authorization values, access tokens, API keys, secrets, credentials, browser storage dumps, or browser request body content.

- [ ] **Step 2: Run workspace checks**

Run:

```bash
pnpm check
```

Expected: PASS.

If `pnpm --version` does not match `packageManager` in `package.json`, run:

```bash
corepack enable
corepack prepare pnpm@10.0.0 --activate
pnpm --version
pnpm check
```

Expected: `pnpm --version` prints `10.0.0`, then `pnpm check` passes.

- [ ] **Step 3: Run Mac checks if contract-facing Swift files changed**

Skip this step if only Markdown files changed.

Run:

```bash
cd apps/mac
swift test
swift build
```

Expected: both commands PASS.

- [ ] **Step 4: Final diff review**

Run:

```bash
git diff -- docs/architecture/data-contract.md docs/architecture/privacy-boundaries.md docs/architecture/tech-stack-and-development-approach.md docs/agent/operating-rules.md
git status --short
```

Expected: only Task 7 documentation files are modified. There are no schema, fixture, app, lockfile, or generated build-output changes.

- [ ] **Step 5: Commit**

Run:

```bash
git add docs/architecture/data-contract.md docs/architecture/privacy-boundaries.md docs/architecture/tech-stack-and-development-approach.md docs/agent/operating-rules.md
git commit -m "docs: clarify privacy and data contract"
```

Expected: commit succeeds with only Task 7 documentation changes.
