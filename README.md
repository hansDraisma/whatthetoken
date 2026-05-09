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

## Local Persistence And Refresh

The Mac app persists connector consent, refresh preferences, notification preferences, a sanitized snapshot cache, and sanitized notification dedupe state in Application Support (`settings.json`, `snapshot-cache.json`, `notification-state.json`). It does not persist provider credentials, raw provider payloads, prompts, responses, cookies, auth headers, or provider session tokens.

Connectors start disconnected by default. `Connect Claude Code` and `Connect Codex` are explicit opt-in actions. `Pause` stops refresh for a connector while keeping sanitized cached values visible. `Disconnect ...` stops future reads for that provider and removes that provider's cached usage snapshots and notification dedupe state from WhatTheToken storage. The app must not present a provider as disconnected unless disabled consent, cache removal, and notification-state removal are all persisted; if any write fails the provider stays connected.

Manual refresh remains available for connected, unpaused providers. Opening the popover may refresh enabled connectors subject to provider backoff, and skips a per-provider refresh that ran in the last 60 seconds via background auto-refresh. Timer-based auto-refresh is optional, off by default, and runs while the app process is running only after explicit user opt-in. During refresh, existing values remain visible with a small updating indicator; the last-updated timestamp appears in the footer only.

## Notifications

Local notifications warn before quota runs out. The master toggle is off by default; enabling it requests macOS notification permission. Per-provider toggles default to enabled. Default thresholds are 20% (warning) and 10% (critical). Notifications respect connector pause state, never fire on stale snapshots, and dedupe per provider/pool/window with recovery and rolling-window cooldown so flapping pools do not spam. The menu bar surfaces a critical state when any enabled, unpaused provider has an exhausted-or-critical included quota pool.

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

## CI

GitHub Actions runs the synthetic test workflow on pull requests, pushes to `main`, and manual dispatch from the Actions tab. The workflow does not require live provider credentials, Keychain access, Codex app-server access, cookies, browser state, or provider network calls.

## Connector Safety

Live provider checks are manual and opt-in. CI uses synthetic fixtures only.

Claude Code and Codex connectors must discard raw provider responses after parsing and must never persist copied provider credentials in WhatTheToken storage.

## Install And Updates

Public V1 will ship as a signed and notarized DMG attached to GitHub Releases. Install by opening the DMG and moving `WhatTheToken.app` to `/Applications`.

For Public V1, updates are manual-first. GitHub Releases remains the fallback path for downloading the newest signed and notarized DMG. Sparkle is wired for an explicit `Check for Updates` action once the public appcast, EdDSA public key, and signed old-build to new-build smoke test are complete. Automatic background checks and silent installs remain disabled.

Official release steps are documented in `docs/release/public-v1-checklist.md`.

## Roadmap

- Canonical roadmap: `docs/roadmap/development-roadmap.md`
- Open-source strategy and business model: `docs/roadmap/open-source-strategy-and-business-model.md`
- Privacy boundary: `docs/architecture/privacy-boundaries.md`
- Data contract: `docs/architecture/data-contract.md`

## Contributing And Security

Read `CONTRIBUTING.md`, `PRIVACY.md`, and `SECURITY.md` before opening connector, diagnostics, fixture, sync, or UI quota-display changes.
