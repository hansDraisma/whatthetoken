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

The Mac app stores this data locally in its Application Support directory:

- `settings.json` for connector consent, refresh preferences, notification preferences, and menu bar display preferences
- `snapshot-cache.json` for sanitized usage snapshots, last successful refresh timestamps, and sanitized provider error/backoff state

These files must not contain provider credentials, copied tokens, raw provider payloads, prompts, responses, cookies, auth headers, provider session tokens, raw local database rows, or sensitive local paths.

## Connector Consent And Disconnect

Connectors are disabled by default. A connector may read local provider state only after the user chooses `Connect Claude Code` or `Connect Codex`.

Disconnecting a provider disables future reads and removes that provider's cached usage snapshots from WhatTheToken storage. The app must not show the provider as disconnected unless disabled consent and cache removal are both persisted. If either write fails, the UI remains connected so it does not claim cached data was removed.

Opening the popover may refresh enabled connectors, but provider backoff still applies. Timer-based auto-refresh is optional, off by default, and runs only while the popover is open.

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
