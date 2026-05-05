# WhatTheToken Open-Source Strategy And Business Model

Date: 2026-05-05

Status: strategy companion to `docs/roadmap/development-roadmap.md`.

This document explains why WhatTheToken should be open source, how it can differentiate, and where a business model could exist later. It does not define execution phases. The canonical step-by-step roadmap lives in `docs/roadmap/development-roadmap.md`.

## Decisions

- The local app is open source.
- Use Apache-2.0 for the public repo.
- Internal V0 is the private working Mac app at the end of Stage 4 in `docs/roadmap/development-roadmap.md`.
- Public V1 is the public repo plus free signed/notarized DMG at the end of Stage 5 in `docs/roadmap/development-roadmap.md`.
- Public V1 provider coverage is Claude Code and Codex unless a later explicit roadmap decision pulls provider expansion forward.
- Do not make the repo public before Public V1.
- Publish under a clean public repo name before the visibility flip; avoid leaking workspace names such as `zurich-v1` into the public project identity.
- The official signed/notarized DMG is free for Public V1.
- Do not build trial, license-key, or paid-DMG infrastructure for Public V1.
- Use GitHub Sponsors or donations first.
- Treat hosted sync, team visibility, managed reliability, and support as the credible future business model.
- Keep local-only mode useful even if hosted features are added later.
- Keep the product name WhatTheToken for now, with a serious trust-oriented tagline. Revisit the name before public launch only if early users say it reduces trust.

## Positioning

WhatTheToken is:

> The open, local-first AI quota cockpit for developers using multiple coding agents.

The product should help a developer answer:

1. Which tool can I use right now?
2. When will my constrained quota reset?
3. How reliable is this number?

The product should not position itself as another single-provider usage bar. The useful wedge is cross-tool capacity planning with explicit trust labels.

## Target Users

Primary users for Public V1:

- Developers who use two or more AI coding tools weekly.
- Developers who have been interrupted by Claude Code or Codex limits.
- Developers who care whether usage data is verified, observed, estimated, or stale.
- Developers comfortable installing a local Mac utility from GitHub Releases.

Secondary users after provider expansion:

- Maintainers who want an auditable open-source tool.
- Teams experimenting with multiple AI coding subscriptions.
- Developers who have been interrupted by Cursor, Copilot, Gemini, or ChatGPT developer-workflow limits.
- Tooling-focused engineers who may contribute provider connectors.

## Anti-Personas

WhatTheToken is not for:

- Solo users who rely on one AI tool and do not experience quota anxiety.
- Casual ChatGPT users who only want general chat history or cost tracking.
- Teams that require SSO, audit logs, SOC 2, procurement, and formal compliance before installing any local tool.
- Users who want the app to collect prompts, responses, conversation URLs, or detailed productivity analytics.
- Users who want a closed-source vendor to take over all provider account handling.

Stating these non-targets keeps the product narrow enough to ship.

## Why Open Source

Open source is a product feature here, not only a licensing choice.

The app touches auth-adjacent local state. Users need to trust that WhatTheToken does not copy provider tokens, read prompts, upload raw provider payloads, or hide analytics. A public codebase makes the privacy promise inspectable.

Open source also helps with provider rot. Local app-server responses, undocumented endpoints, browser surfaces, and local file formats can change. A public connector architecture gives users and contributors a path to inspect and fix breakage.

The tradeoff is real: users and competitors can build from source or fork the app. That is acceptable because the moat is not secrecy. The moat is the official trusted build, careful provider boundaries, clear provenance, and sustained maintenance.

## License

Use Apache-2.0.

Reasoning:

- It is a permissive open-source license.
- It includes an explicit patent grant.
- It is familiar to companies and contributors.
- It leaves room for hosted commercial features later.
- It avoids ambiguity before public launch.

## Differentiation

### Trust/provenance-first tracker

Every number must say whether it is `verified`, `observed`, `estimated`, or `stale`.

Competitors often blur this distinction, but it matters. Some providers require unofficial APIs, local app-server probes, local files, DOM observation, or browser extension logic. Users need to know whether a value is authoritative, directly observed, inferred, or too old to trust.

This must stay in the primary UI and documentation. It should not be buried in tooltips or diagnostics.

### Best tool right now

The app should move beyond:

> Claude is 82% used.

The stronger workflow is:

> Use Codex for heavy work now. Claude resets in 42 minutes. Gemini is fresh.

This is a hard product problem because provider pools are not fungible. Claude Code rolling-window limits, Codex app-server buckets, Cursor request pools, Copilot plan rules, Gemini limits, and ChatGPT web limits cannot always be compared directly.

The correct strategy is task-specific recommendation, not a universal capacity score. The app should recommend only when the inputs justify it and should otherwise explain the constraints.

### Pace and burn-rate prediction

Current usage is useful. Predicted exhaustion is better:

> Observed: at this pace, you may hit the Claude 5h limit in 38 minutes.

Prediction must be conservative and clearly labeled. Claude Code uses rolling windows, so a fixed-bucket approximation can mislead users. If the app lacks enough event-level data to model a provider accurately, it should show limited prediction copy or omit the prediction.

### Cross-provider planning

Developers increasingly hold a portfolio of AI capacity:

- Claude Code
- Codex
- Cursor
- GitHub Copilot
- Gemini
- ChatGPT developer workflows
- provider API credits where useful later

WhatTheToken should help preserve scarce pools and route work:

- heavy agentic work
- short questions
- code review
- browser chat
- model-specific tasks
- work that can wait for reset

This is the path that makes the product more valuable than a list of provider cards.

### Privacy and auditability

The public trust promise is:

> Provider credentials stay on the user's device. WhatTheToken syncs only sanitized usage status.

Operationally this means:

- no copied provider tokens in WhatTheToken storage
- no backend storage of provider credentials
- no prompt or response collection
- no raw provider payload diagnostics
- synthetic fixtures only
- redacted support exports
- signed official builds
- open-source connector boundaries

### Team or multi-device sync later

This is the most plausible recurring-revenue path.

Individual developers may pay once for a polished utility, but the local app market is crowded and price-sensitive. Teams have a stronger business need if they want to know who is blocked, which AI seats are underused, and whether work should shift between providers.

This should not define Public V1. It should be validated only after the local app earns trust.

### Developer-agent integrations

The app can become more useful by warning before quota-heavy work starts:

> This may exhaust your Claude 5h pool. Use Codex instead?

This should be read-only, local, and sanitized. It depends on the trusted local app, recommendation model, and status API.

## Competitor Matrix

Last checked: 2026-05-05. Re-check this matrix before public launch because the category is moving quickly.

| Product | Public positioning | Notable claimed features | Strategic implication |
|---|---|---|---|
| SessionWatcher | Paid native macOS tracker for Claude Code and Codex | Menu bar, rolling window countdown, notifications, cost tracking, one-time pricing | Paid demand exists, but basic Claude/Codex tracking is not differentiated |
| ClaudeUsageBar | Free open-source Claude and Claude Code menu bar tracker | Menu bar, notifications, reset countdown, privacy-first copy | Open-source plus free is already table stakes for Claude-only tracking |
| ClaudeBar | macOS monitor for multiple AI coding assistants | Claude, Codex, Gemini, GitHub Copilot, Antigravity, menu bar positioning | Multi-provider breadth is already being attempted |
| CodexBar | Codex-focused macOS tracker | Codex menu bar status | Codex alone is not enough as a long-term wedge |
| AI Usage Bar | Open-source multi-provider menu bar app | Claude, Codex, Z.ai, real-time updates, notifications, privacy copy | Trust and multi-provider claims need concrete provenance labels to stand out |
| OpenUsage | Free open-source AI limits tracker | Cursor, Claude Code, Codex, macOS menu bar | Provider breadth is crowded; WhatTheToken needs clearer trust and workflow differentiation |
| Tally / AI Tally | Multi-provider usage tracker | Claude, OpenAI/Codex, Gemini, local history claims | History and backfill matter, but file-reading privacy boundaries are a key differentiation point |
| CC Usage Viewer / similar Claude tools | Claude-focused usage tracking | Desktop app, notifications, sometimes sign-in flow | Claude-only tooling is saturated |

WhatTheToken should avoid competing on "we have a menu bar too." The clearer wedge is:

- provenance labels on every number
- local-first privacy boundary
- best-tool-right-now recommendations
- careful provider connector docs
- public threat model
- signed official open-source builds

Sources used for this matrix:

- https://www.sessionwatcher.com/
- https://www.sessionwatcher.com/guides/best-claude-code-usage-trackers
- https://www.claudeusagebar.com/
- https://tddworks.github.io/ClaudeBar/
- https://codexbar.app/
- https://envie.studio/aiusagebar/
- https://www.openusage.ai/
- https://ai-tally.app/
- https://cc-usage-widget.com/

## Monetization

### Public V1

Public V1 should not monetize access.

Ship:

- free source
- free official signed/notarized DMG
- optional GitHub Sponsors or donation link
- no trial
- no license key
- no paid DMG
- no paywalled local providers

Reasoning:

- A paid local-only app competes directly with cheap/free trackers.
- Open-source users can build from source.
- License checks weaken the privacy story and add maintenance.
- Trust and adoption matter more than early low-dollar revenue.

### Later Revenue Paths

Potential revenue should require real usage evidence.

| Model | When to consider | Why it could work |
|---|---|---|
| GitHub Sponsors / donations | Immediately after public release | Fits open-source trust and has low complexity |
| Hosted sync | After users ask for multi-device state | Provides recurring value without paywalling local tracking |
| Team dashboard | After team interviews confirm demand | Strongest recurring-revenue path |
| Managed connector reliability | After companies depend on the tool | Teams may pay for maintained parsers and support |
| Priority support | After public adoption | Low product complexity, useful for teams |

Do not add pricing infrastructure until one of these signals appears:

- repeated sponsor requests for a funded roadmap
- users asking for cross-device sync
- teams asking for organization visibility
- maintainers spending significant time on provider breakage for companies

## Privacy-First Measurement

Default telemetry should be off in Public V1.

Use these signals first:

- GitHub stars.
- GitHub issues and discussions.
- GitHub Release download counts as a directional signal only; downloads can be inflated by retries, mirrors, caches, scripts, and automated crawlers.
- Sponsor and donation events.
- Manual user interviews.
- Voluntary diagnostic exports initiated by users.
- Optional survey links.

If product analytics are proposed later:

- make them opt-in
- document exact events before implementation
- avoid identifiers that can be tied to provider accounts
- avoid prompt, response, conversation, path, token, or raw payload data
- require a privacy design review before code changes

## Threat Model

Trust must be operational, not marketing.

### Assets To Protect

- provider access tokens and credentials
- provider session state
- prompts and responses
- conversation metadata
- local project paths
- raw provider payloads
- diagnostic exports
- signing keys and update keys
- user trust in official releases

### Attacker Scenarios

| Scenario | Risk | Mitigation |
|---|---|---|
| Connector regression logs raw provider payload | Secrets or private usage data leak into logs/issues | Redaction tests, no raw logging, diagnostics preview, security review for connector changes |
| Rogue or compromised contributor PR adds exfiltration | Official app could ship code that uploads local provider state or secrets | Small trusted maintainer set, required review for connector/network changes, redaction tests in CI, dependency review, no broad auto-merge |
| Dependency compromise | Malicious package exfiltrates local data | Keep dependency surface small, pin lockfiles, review dependency changes, avoid runtime network dependencies in local connector path |
| Malicious fork | Fork claims to be official and exfiltrates data | Signed official releases, clear download links, public release checksums, security docs |
| Signing key compromise | Attacker ships trusted update | Store signing/update keys outside repo, restrict access, rotate and revoke on incident |
| User posts sensitive logs in GitHub issue | Tokens or prompt content become public | Issue templates, SECURITY.md warnings, redacted diagnostics, maintainer cleanup process |
| Provider changes response shape | Parser misreads usage or leaks raw payload during debugging | Source health states, fixture tests, no raw payload diagnostics, manual smoke process |
| Browser extension over-collects | Web prompts/cookies/session data are exposed | Minimal permissions, open-source extension, separate ADR for browser surfaces |
| Hosted sync breach later | Sanitized usage history exposed | Minimize synced data, consider end-to-end encryption, no provider credentials in backend |

### Incident Response

If a privacy or credential handling issue is suspected:

1. Stop distributing the affected build or connector.
2. Publish a security advisory with affected versions and data categories.
3. Remove or redact public issue content if users pasted secrets.
4. Rotate signing/update keys if release integrity is affected.
5. Add regression tests before re-enabling the connector.
6. Document the fix in the changelog.

## Risk Register

| Risk | Impact | Mitigation | Trigger |
|---|---|---|---|
| Anthropic locks down local credential/usage path | Claude connector loses verified signal | Degrade to source health state, document confidence change, research safer alternatives | Claude refresh starts failing broadly |
| OpenAI changes Codex app-server method | Codex connector breaks | Isolated parser/service, schema-change state, manual smoke, fixture updates | Codex smoke fails or schema test fails |
| Official provider trackers launch | Category becomes less valuable | Differentiate on cross-provider planning, open-source trust, and recommendations | Provider ships persistent quota UI |
| Competitors copy features | Feature moat weakens | Maintain trust/docs/release quality and provider breadth with provenance | Similar features appear in competing apps |
| Connector leaks sensitive data | Trust loss | Strict deny list, tests, redacted diagnostics, code review, incident response | Any log/issue contains forbidden data |
| Maintainer stops updating parsers | App decays | Open-source contribution guide, modular connectors, public health states | Provider breakage issues remain unresolved |
| Maintainer burnout | Solo-maintained OSS project stalls, releases stop, and provider rot accumulates | Keep scope narrow, document maintainer boundaries, design modular connectors, recruit trusted maintainers only after trust is established | Issues and release work exceed available maintainer time |
| Apple distribution rules change | DMG release breaks | Keep signing docs current, use standard Developer ID flow, test release process | Notarization/signing failure |
| Telemetry pressure weakens privacy | Trust story becomes incoherent | Default no telemetry, opt-in only after design review | Proposal to add analytics |
| Team product weakens user trust | Individual users reject app | Keep local-only mode, explicit admin visibility, separate privacy ADR | Team dashboard work begins |

## Brand

Keep WhatTheToken as the product name for now.

Reasoning:

- It is memorable and developer-friendly.
- The tagline can carry the serious trust posture.
- Renaming now would slow the roadmap without evidence that the name hurts trust.

Before the repo becomes public, publish under a clean repo name such as `whatthetoken` or `WhatTheToken`. Do not expose internal workspace names like `zurich-v1` as the public repository identity. Revisit the product name before public launch only if early users say it feels too unserious for a privacy-sensitive tool.

## Strategic Gates

- Do not make the repo public before Public V1.
- Do not expand beyond Claude/Codex polish until five developer interviews are complete.
- Do not add browser extension work until local and official sources are exhausted for the target provider.
- Do not add paid infrastructure until users show demand for sync, teams, managed reliability, or support.
- Do not add default telemetry for Public V1.
- Do not build team features without a new privacy model.
