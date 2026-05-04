# Task 7 Privacy And Contract Documentation Design

Date: 2026-05-04

## Purpose

Task 7 makes the WhatTheToken trust and data boundaries explicit enough for future agents to implement ingestion without collecting sensitive provider or user content. It documents the canonical event and snapshot contract, the privacy allow/deny lists, and the review checks required before future work changes those boundaries.

## Background

The Phase 1 plan already defines WhatTheToken as a local-first Mac developer quota monitor. The shared TypeScript package owns the runtime event and snapshot schemas, while the SwiftUI app mirrors the snapshot contract for fixture-backed rendering. The existing architecture docs are intentionally small; Task 7 should turn them into practical references that later provider-ingestion, sync, extension, and UI work can use without re-reading the full roadmap.

## Goals

- Document `packages/core/src/schemas.ts` as the Phase 1 source of truth for `UsageEvent` and `UsageSnapshot`.
- Define provider, product, surface, confidence, unit, and undercount-risk values in one architecture contract document.
- Explain required snapshot math invariants: `remaining = max(limit - used, 0)`, `utilization = used / limit`, and null derived values when `used` or `limit` is unknown.
- Document stale-state requirements: `staleReason` is required only when confidence is `stale`.
- Define exactly which usage data may be collected.
- Define exactly which sensitive data must never be collected.
- Require an ADR for any future expansion of sensitive data boundaries.
- Add a repeatable privacy grep that future agents can run before accepting Task 7 or later ingestion work.
- Document the local connector trust boundary: provider credentials stay local, WhatTheToken syncs only usage status, and connector tokens may be used only in memory with explicit user opt-in.

## Non-Goals

- Do not change TypeScript schemas or Swift models in Task 7 unless documentation uncovers an existing mismatch.
- Do not add backend, sync, browser extension, analytics, or provider ingestion code.
- Do not write a public legal privacy policy; this is engineering contract documentation, not legal terms.
- Do not document speculative providers beyond the provider/product/surface values already accepted by the shared schema.

## Documentation Design

### Data Contract

`docs/architecture/data-contract.md` should describe the canonical runtime contract in prose and compact tables. It should point readers to `packages/core/src/schemas.ts` as source of truth and explain that Swift models and fixture JSON must mirror the shared schema.

The document should cover:

- Allowed provider values: `openai`, `anthropic`, `google`, `cursor`, `github`.
- Allowed product values: `codex`, `chatgpt`, `claude_code`, `claude`, `gemini`, `cursor`, `github_copilot`.
- Allowed surface values plus snapshot-only `aggregate`.
- Allowed confidence values and their meanings.
- Allowed usage units.
- Required event fields.
- Required snapshot fields.
- Field nullability, optional attribution fields, and attribution enum values.
- Strict payload behavior and the event `count` rule: event counts are non-negative integers, while fractional measurements belong in snapshot values such as `used`.
- Snapshot derivation invariants.
- Staleness and undercount-risk expectations.

### Privacy Boundaries

`docs/architecture/privacy-boundaries.md` should be direct and operational. It should separate data that must never be collected from sanitized usage data that may be collected. The sensitive-data deny list must include prompts, completions, conversation content, conversation URLs, cookies, auth headers, bearer tokens, provider session tokens, browser request bodies, provider credentials, API keys, access tokens, authorization values, secrets, and raw browser storage dumps.

The allowed-data list should stay aligned with `UsageEvent`, `UsageSnapshot`, and the roadmap: provider/product/surface, model key when detectable, event type, count or quota amount, timestamps, non-secret device identifiers, confidence, source/parser version, freshness, stale/error state, and undercount risk.

Any future change that allows new sensitive categories or weakens the deny list requires an ADR.

Local connector rules should be explicit without documenting provider-specific credential extraction flows. The privacy document should say that a connector may read local provider state only after opt-in, use provider credentials or tokens only in memory, never log/persist/upload them, never expose them to a browser extension, redact credentials and sensitive local paths from diagnostics, and emit structured source states instead of raw provider errors.

### Tech Stack And Operating Rule Links

`docs/architecture/tech-stack-and-development-approach.md` should reference the Task 7 docs from the architecture rules so future work does not treat privacy review as optional. `docs/agent/operating-rules.md` may be updated if the existing checklist does not clearly require privacy and contract review.

## Verification Design

Task 7 is documentation-only, so verification is mostly drift and sensitive-data checks:

- Run a grep over `docs`, `packages`, and `apps` for sensitive terms. The grep must include common credential spellings such as `authorization`, `access_token`, `api_key`, `secret`, `credential`, `localStorage`, and `browser storage`, not only the exact deny-list wording.
- Review each match and confirm it is either a deny-list rule, a test that rejects sensitive fields, or source text that does not contain real user/provider secrets.
- Run `pnpm check` if package scripts are available and working in the current workspace.
- Run `swift test` for `apps/mac` if Swift is available and the task changes contract references consumed by the app.

## Acceptance Criteria

- `docs/architecture/data-contract.md` is detailed enough for an agent to create a schema-valid event or snapshot without reading the roadmap.
- `docs/architecture/privacy-boundaries.md` clearly separates forbidden sensitive data from allowed sanitized usage data.
- Architecture or operating docs link to both contract documents.
- The documentation names `packages/core/src/schemas.ts` as the source of truth during Phase 1.
- The privacy documentation states the product promise: provider credentials stay on the user's device and WhatTheToken syncs only usage status.
- The privacy documentation includes local connector credential, token, diagnostics, and source-state rules without adding provider-specific endpoint or credential extraction details.
- The privacy grep has been run and reviewed.
- No fixture, app resource, source file, or doc example contains real prompt, response, cookie, auth header, bearer token, provider session token, or browser request body content.

## Open Decisions

None. The current Phase 1 roadmap, ADR 0001, ADR 0002, and shared schemas provide enough scope for Task 7.
