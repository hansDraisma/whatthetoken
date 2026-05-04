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
