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
