# WhatTheToken Canonical Development Roadmap

Date: 2026-05-05

Status: canonical execution roadmap.

This document is the source of truth for step-by-step product development. Strategy, licensing, business model, and market assumptions live in `docs/roadmap/open-source-strategy-and-business-model.md`. Earlier planning documents are historical context unless they point back here.

## Product Direction

WhatTheToken is an open-source, local-first Mac menu bar app that helps developers avoid AI quota surprises across coding agents and assistants.

The first useful product is not a generic analytics dashboard. It is a trusted local status surface that answers:

1. Which AI coding tool can I use right now?
2. When will constrained quota reset?
3. How reliable is this number?

The product must be useful locally before it becomes public, and it must be useful publicly before it becomes a sync, team, or hosted product.

## Release Definitions

- Internal V0: end of Stage 4. The repo can remain private, but the app should be a working local Mac menu bar product for the maintainer and private testers. V0 includes Claude Code and Codex, connector consent, refresh, local cache, notifications, and trust-focused UI polish. V0 does not require a public DMG.
- Public V1: end of Stage 5. The repo can flip public only after the app has a signed/notarized free DMG, release checklist, public project docs, license, privacy/security docs, and a working menu bar app. Public V1 coverage is Claude Code and Codex unless a later explicit decision pulls provider expansion forward. Public V1 has no trial, no license key, no paid DMG, and no local-provider paywall.
- Post-V1: Stage 6 and later. Provider expansion, history, prediction, recommendations, sync, team, and agent integrations happen only after the local product is useful, trusted, and installable.

## Public-Launch Gate

Do not make the repository public at Stage 0.

Stage 0 creates public-readiness documents while the project can still be private. Publishing too early would create a weak first impression because there is no finished menu bar shell or installable build yet.

The repository should become public at the end of Stage 5, together with the first signed/notarized free DMG on GitHub Releases. Private testers can receive local or ad-hoc builds after Internal V0 if needed, but broad public launch waits for Public V1.

## Current State

Already in the repo:

- `packages/core` with usage snapshot schemas, confidence labels, staleness helpers, and tests.
- SwiftUI Mac app under `apps/mac`.
- Claude Code connector path with explicit opt-in, local Keychain read boundary, mapper, service, smoke command, and tests.
- Codex connector path with explicit opt-in, local app-server read boundary, mapper, service, smoke command, and tests.
- Menu bar SwiftUI shell with Claude Code and Codex sections, Settings, About, Quit, and DEBUG developer window.
- Root README, Apache-2.0 license, privacy/security/contributing docs, issue templates, and synthetic-test CI.
- Persisted settings for connector consent, pause state, refresh interval, notification preferences, and menu bar display preferences.
- Sanitized last-known-good snapshot cache with stale evaluation and provider backoff metadata.
- Manual refresh, popover-open foreground refresh, and opt-in app-running background refresh.
- Local notification settings, sanitized notification dedupe state, warning/critical evaluator, local notification delivery boundary, and modest menu bar critical state.
- Privacy boundaries, data contract, ADRs, provider research notes, and implementation plans.

Not yet in the repo:

- Proper `.app` bundle path.
- App icon and asset catalog.
- Entitlements and release signing configuration.
- Signed/notarized DMG.
- Sparkle update infrastructure.

## Non-Negotiables

- Provider credentials stay on the user's device.
- Do not copy provider tokens into WhatTheToken storage.
- Do not collect, log, fixture, sync, or expose prompts, responses, conversation content, cookies, bearer tokens, auth headers, provider session tokens, raw provider payloads, or raw local databases that can contain forbidden data.
- Every number shown to users must carry confidence: `verified`, `observed`, `estimated`, or `stale`.
- Every connector must expose source state and parser/source version.
- Local-only mode must remain useful.
- Open-source code and official signed builds must tell the same privacy story.
- Live provider checks stay manual and opt-in. CI uses synthetic fixtures only.

## Canonical Documents

- Strategy and business model: `docs/roadmap/open-source-strategy-and-business-model.md`
- Execution roadmap: `docs/roadmap/development-roadmap.md`
- Privacy boundary: `docs/architecture/privacy-boundaries.md`
- Data contract: `docs/architecture/data-contract.md`
- Technical approach: `docs/architecture/tech-stack-and-development-approach.md`
- Local-first ADR: `docs/adr/0001-local-first-minimal-data-ingestion.md`
- Confidence/provenance ADR: `docs/adr/0002-confidence-labels-and-provenance.md`

Each stage is an individual development slice. Before implementation starts for a stage, write a focused design in `docs/superpowers/specs/` and an implementation plan in `docs/superpowers/plans/` unless the stage is purely editorial. If a stage proves too large for one plan, split it into smaller stage-scoped plans without changing the canonical stage order.

## Architecture Direction

### Shared Core

`packages/core` owns portable domain rules:

- provider/product/surface taxonomy
- usage event and snapshot schema
- confidence labels
- staleness logic
- future notification threshold math
- future burn-rate and recommendation scoring

The Swift app may duplicate display-only formatting in Swift, but domain semantics should stay aligned with core schemas and docs.

### Mac App

`apps/mac` owns local UX and provider connector orchestration:

- SwiftUI menu bar app shell
- connector consent and settings
- local refresh scheduling
- local sanitized cache
- notification permission and delivery
- local diagnostics export
- app bundle and distribution configuration

Views render state. Connector services fetch and map provider status. View models coordinate refresh and cache state. Privacy-sensitive operations stay behind narrow protocols so tests use stubs.

### Provider Connectors

Each provider/product/surface connector must be isolated:

- one source boundary
- one parser/mapper
- one service
- one source-state enum mapping
- one test fixture family
- one manual smoke path if live validation is needed

Connectors must discard raw provider responses after parsing and must never log forbidden fields.

### Future Hosted Layer

Hosted sync, team dashboards, and managed reliability are later tracks. They may sync only sanitized snapshots, settings, device attribution, and health state. They must not receive provider credentials or raw provider payloads.

## Development Roadmap

### Stage 0: Pre-Public Foundation

Stage spec: `docs/superpowers/specs/2026-05-05-stage-0-pre-public-foundation-design.md`

Implementation plan: `docs/superpowers/plans/2026-05-05-stage-0-pre-public-foundation.md`

Goal: make the project safe to publish later and understandable to contributors before wider distribution.

Why now: the connectors already exist. The next risk is trust, not ingestion.

Tasks:

- Add root `README.md` with product positioning, current support matrix, privacy promise, local development setup, verification commands, and a clear note that the repo is not public-launch ready until Public V1.
- Add `LICENSE` using Apache-2.0.
- Add `PRIVACY.md` with deny list, allowed sanitized data, connector rules, threat model, diagnostics rules, and incident response.
- Add `SECURITY.md` with vulnerability reporting and instructions not to paste secrets, prompts, provider payloads, or raw logs.
- Add `CONTRIBUTING.md` with test commands, fixture rules, provider connector rules, and review requirements.
- Add `.github/ISSUE_TEMPLATE/` with bug report and provider breakage templates that warn against sensitive data.
- Add `.github/workflows/test.yml` for Swift tests and TypeScript core tests.
- Update docs that mention monetization or roadmap state so they point to this canonical roadmap and strategy doc.

Exit criteria:

- An authorized developer can clone the private repo, understand what the app does, run tests, and understand the privacy boundary.
- Issue templates are ready to discourage leaking sensitive data once the repo becomes public.
- CI runs on pull requests, pushes to `main`, and manual dispatch without live provider, Keychain, Codex app-server, or network dependencies.
- Repo remains private unless Public V1 exit criteria are met.

Verification:

- `swift test` from `apps/mac`.
- `pnpm --filter @whatthetoken/core test`.
- GitHub Actions workflow passes on synthetic tests.

### Stage 1: App Bundle And Menu Bar Foundation

Goal: turn the current SwiftPM window app into a real Mac menu bar product shell.

Why now: the eventual public DMG and the private V0 app both require an `.app` bundle, app metadata, and menu bar UX.

Tasks:

- Decide the app packaging path: Xcode project, Swift package app bundle generation, or a minimal build script. Prefer the simplest path that can produce a signed `.app`.
- Add `Info.plist` with bundle identifier, display name, version/build fields, app category, and menu-bar behavior.
- Add `LSUIElement = YES` once the app has a complete menu bar shell and an accessible quit/settings path.
- Add asset catalog and placeholder app icon.
- Add entitlements file only for required capabilities. Treat App Sandbox as a deliberate later decision, not an automatic default, because local tool launching and `/usr/bin/security` access must be tested.
- Add `MenuBarExtra` as the primary app surface on macOS 14.
- Keep a developer window or debug launch path only if it helps testing.
- Add About, Settings, Refresh, Quit, and connector rows in the menu bar popover.
- Preserve smoke command behavior for `--claude-connector-smoke` and `--codex-connector-smoke`.

Exit criteria:

- App launches from Finder as a menu bar utility.
- Menu bar popover shows Claude Code and Codex sections.
- User can quit the app and open settings without a Dock icon.
- Smoke commands remain command-line-only and do not activate UI.

Verification:

- `swift test`.
- Manual app launch from built `.app`.
- Manual smoke command check with no UI activation.

### Stage 2: Consent, Persistence, And Refresh Engine

Goal: make connector consent explicit, make the app remember user choices, and refresh safely without reconnecting every time.

Why now: users should not have to reconnect on every launch, but memory must not mean storing copied provider tokens.

Tasks:

- Add persisted app settings for connector enabled state, thresholds, refresh interval, notification preferences, and menu bar display mode.
- Add sanitized last-known-good snapshot cache.
- Do not persist Claude access tokens, Codex auth state, provider cookies, provider session tokens, or raw provider responses.
- Add first-run consent for each connector.
- Add per-connector consent copy explaining what local state is accessed, what is never read, what is stored, and how to disconnect.
- Add manual refresh that refreshes enabled connectors without changing consent state.
- Add app-running background auto-refresh only after explicit user opt-in. Do not migrate older popover-only auto-refresh consent into enabled background refresh.
- Pause or defer refresh around sleep/wake and offline conditions.
- Add error backoff: 5 minutes, then 15 minutes, then 60 minutes until a successful refresh or manual refresh.
- Re-evaluate cached snapshots as `stale` when freshness expires.
- Show stale/error state without deleting last-known-good data unless the user disconnects.

Exit criteria:

- Relaunch preserves enabled connectors and last sanitized values.
- User can review, enable, disable, and disconnect each connector from settings.
- Auto-refresh is explicit, configurable, app-running, and disabled by default.
- No WhatTheToken storage contains copied provider credentials.
- Stale data is visibly stale.

Verification:

- Unit tests for settings persistence.
- Unit tests for cache staleness.
- Unit tests for refresh deduplication and backoff.
- Manual relaunch check.

### Stage 3: Notifications And Glance Value

Goal: alert users before quota interrupts work.

Why now: notifications are the core "know before you throttle" product promise.

This stage requires a focused design doc before implementation.

Design requirements:

- Provider-level settings with pool/window-level evaluator internals.
- Default warning and critical thresholds.
- Notify once per threshold crossing.
- Reset notification state after quota recovery, provider reset when a provider has a discrete reset, or cooldown.
- Handle rolling-window providers such as Claude Code without pretending they have a single reset event; use hysteresis, cooldown, and recovery thresholds.
- Handle flapping pools without repeated alerts.
- Rely on macOS notification and Focus settings for interruption behavior.
- Define cross-provider grouping: separate notifications by provider by default, optional summary later.
- Define notification copy for `verified`, `observed`, `estimated`, and `stale` values.
- Define behavior when data is stale or confidence is low.

Tasks:

- Add notification permission flow.
- Add threshold state model in core or shared Swift domain code.
- Add notification delivery service behind a protocol.
- Add tests for threshold crossing, reset, cooldown, and stale suppression.
- Add settings controls for notifications.
- Add menu bar critical indicator.
- Clear provider notification dedupe state on disconnect.
- Keep developer smoke launch from constructing the live app model so background refresh cannot start in smoke mode.

Exit criteria:

- Users receive useful alerts before low/critical states.
- Alerts do not spam during flapping conditions.
- Notification copy includes enough provenance to avoid overclaiming.

Verification:

- Unit tests for threshold state.
- Manual notification permission and delivery check.
- Manual low/critical fixture check.

### Stage 4: Visual Polish And Trust UX

Goal: make the app feel trustworthy, compact, and useful at a glance.

Why now: competitors already ship polished menu bar utilities. WhatTheToken must look intentional before public release.

Tasks:

- Define UI tokens for spacing, type, status colors, confidence labels, and provider rows.
- Add compact menu bar summary for healthiest/most constrained state.
- Add provider icons or stable text marks where licensing allows.
- Add clear empty states for never connected, disabled, missing credentials, auth invalid, network error, schema changed, stale, and connected.
- Add redacted diagnostics preview before export.
- Add basic app icon suitable for beta.
- Add accessibility labels for menu bar controls and status rows.

Exit criteria:

- A user can understand status within one click.
- Trust/provenance is visible without overwhelming the UI.
- Diagnostics are inspectable before sharing.

Verification:

- SwiftUI unit tests for display models.
- Manual light/dark mode check.
- Manual narrow/wide popover check.

### Stage 5: Distribution Hardening

Goal: ship a trusted official build for non-developer users.

Why now: public launch needs more than GitHub source; most users need a safe DMG.

Tasks:

- Write a distribution design covering entitlements, App Sandbox, signing, notarization, Sparkle, release secrets, and install/update UX.
- Configure Developer ID signing.
- Enable hardened runtime.
- Decide App Sandbox before final signing mechanics after testing connector behavior. If sandboxing breaks local connector needs, document why it is not enabled for direct distribution.
- Generate Sparkle EdDSA keypair before the first public signed release if Sparkle is planned.
- Store Sparkle private key outside the repo.
- Add public Sparkle key to the app bundle even if auto-updates are enabled in a later release.
- Add notarization script using `xcrun notarytool`.
- Add DMG packaging script.
- Add release checklist.
- Publish signed/notarized free DMG through GitHub Releases.
- Host the Public V1 Sparkle appcast on GitHub Pages from the repository `/docs` folder.
- Add a manual Sparkle `Check for Updates` action for Public V1; keep automatic background checks and silent installs disabled.
- Add Sparkle auto-update only after at least one stable signed release flow and manual signed update path are proven.
- Add a long-term Stage 5D distribution item for an owned site/custom domain such as `whatthetoken.app`; do not move `SUFeedURL` away from GitHub Pages until a redirect and migration design exists for already-installed apps.
- Extend the existing About panel in V1.x with build commit, Sparkle version, and license attribution.
- Add launch-at-login with `SMAppService`.

Stage 5A repo foundation is complete when release metadata, Xcode target, Sparkle-ready wiring, launch-at-login, scripts, release checklist, app icon, sandbox matrix, rollback rules, and tests are committed.

Stage 5B credentialed rehearsal remains gated on maintainer Xcode setup, Developer ID certificate access, notarization profile, real archive/export, notarized DMG, Gatekeeper verification, and fresh-account smoke.

Stage 5C public launch remains gated on GitHub Release publication, checksum publication, public docs, repository visibility scan, and Sparkle appcast publication only after signed update smoke passes.

Stage 5D owned distribution remains a later refinement: evaluate a product site, custom domain, analytics-free download page, redirect policy, and appcast migration after Public V1 is stable on GitHub-hosted infrastructure.

Exit criteria:

- A user can install the app without Gatekeeper friction.
- Release process is documented and repeatable.
- Signing secrets are not in the repo.
- Repository visibility can flip to public after this stage exits.

Verification:

- Local signed build verification.
- `spctl` assessment on the `.app` and DMG.
- Notarization ticket stapled.
- Fresh-machine install smoke.

### Stage 6: Provider Expansion

Goal: expand beyond Claude Code and Codex without weakening trust.

Why now: after Public V1, additional provider coverage is more valuable than advanced recommendation logic. Cross-provider value depends on breadth, but each new connector can introduce privacy and parser-rot risk.

Priority order:

1. Cursor.
2. GitHub Copilot.
3. Gemini.
4. ChatGPT for developer workflows, not casual ChatGPT usage.
5. Other tools only after validation.

Rules:

- Prefer official/local quota or status sources.
- Avoid browser scraping unless no safer source exists and users explicitly opt in.
- Do not parse files that can contain prompts, responses, shell snapshots, task titles, or raw conversations unless a redaction ADR approves a narrow safe subset.
- Each provider needs a research note before implementation.
- Interview at least five target developers before starting provider expansion beyond Claude/Codex polish.

Tasks for each provider:

- Write source research note.
- Document allowed and denied data.
- Define confidence level.
- Build parser with synthetic fixtures.
- Add source health state.
- Add UI row.
- Add manual smoke path only if needed.

Exit criteria:

- Each provider has documented provenance and tests.
- UI remains clear rather than crowded.
- Provider breakage degrades to health state, not broad data collection.

Verification:

- Provider-specific unit tests.
- No live provider dependency in CI.
- Manual smoke where explicitly safe.
- Interview notes confirm the provider matters to target developers.

### Stage 7: History And Burn-Rate Research

Goal: model exhaustion risk honestly before showing prediction-heavy UI.

Why now: "at this pace you will hit the limit" is valuable only if it handles rolling windows and incomplete data.

This stage is research-first and requires a focused design doc.

Rules:

- Do not show precise time-to-empty for a rolling window until the model is validated.
- Claude Code prediction must account for rolling 5-hour behavior. A fixed bucket approximation is not acceptable for user-facing copy.
- If only snapshots are available, predictions must be labeled limited or omitted.
- If data is `observed`, `estimated`, or `stale`, prediction confidence must degrade.

Tasks:

- Define which providers expose enough data for burn-rate.
- Define a rolling-window model for Claude where event-level data is available.
- Define snapshot-only fallback copy.
- Design the migration from Stage 2 last-known-good cache to local sanitized history store.
- Add local history store for sanitized snapshots and, where safe, sanitized usage events.
- Add migration tests so existing cached users keep their last-known-good values.
- Add tests for rolling-window edge cases.
- Add UI copy for exact, approximate, unavailable, and stale predictions.

Exit criteria:

- App can explain why a prediction is exact, approximate, or unavailable.
- Claude rolling-window examples pass fixture tests.
- No prediction overclaims confidence.

Verification:

- Core tests for rolling-window math.
- Fixture tests for snapshot-only fallback.
- Migration tests from cache to history store.
- Manual comparison against known local cases.

### Stage 8: Cross-Provider Planning Research

Goal: turn multi-provider status into useful routing advice without pretending all quotas are fungible.

Why later: this is a key differentiator, but it should wait until the app has more provider breadth and at least a basic history/prediction model. It is intentionally research-heavy and should not block the basic working product.

This stage requires a focused design doc.

Rules:

- Do not create a single universal "messages-equivalent" score unless validation proves it is useful.
- Treat provider capacity as task-specific: heavy agentic work, short question, code review, browser chat, and work that can wait.
- Prefer recommendations that explain constraints over false precision.
- If pools cannot be compared, show a ranked status summary rather than a directive.

Tasks:

- Define task classes.
- Define provider suitability per task class.
- Define recommendation inputs: remaining capacity, reset time, confidence, stale state, undercount risk, user preference, and provider availability.
- Define recommendation outputs:
  - direct recommendation
  - caution
  - wait for reset
  - insufficient data
- Add recommendation tests using synthetic provider portfolios.
- Add UI for recommendation rationale only after text prototypes validate with users.

Exit criteria:

- App can say "use X" only when inputs justify it.
- App can say "insufficient comparable data" when pools are not safely comparable.
- Recommendation copy includes rationale and confidence.

Verification:

- Core tests for recommendation scoring.
- Swift display tests for recommendation states.
- User interview validation with at least five developers.

### Stage 9: Multi-Device Sync

Goal: test the first credible recurring-revenue feature while preserving local trust.

Why later: sync adds accounts, backend storage, security obligations, and pricing complexity. It should wait until local usage proves demand.

Rules:

- Local-only mode remains first-class.
- Sync sanitized snapshots, settings, device attribution, and health state only.
- Do not sync provider credentials, raw provider payloads, prompts, responses, cookies, or auth material.
- Evaluate end-to-end encryption before syncing personal usage history.

Tasks:

- Validate user demand through interviews and issue/sponsor signals.
- Write sync privacy ADR.
- Add account layer.
- Add device registration.
- Add sanitized snapshot sync.
- Add stale-device warnings.
- Add optional cloud alerts.
- Add delete/export controls.

Exit criteria:

- Users understand what sync stores and why.
- Multi-device status works without provider secrets leaving devices.
- Local-only mode remains useful.

Verification:

- Backend RLS tests if using Supabase.
- Sync contract tests.
- Privacy review before beta.

### Stage 10: Team Product Exploration

Goal: validate whether WhatTheToken can become a business.

Why later: team visibility is monetizable but materially changes privacy, trust, and product scope.

Rules:

- Do not build team admin features before interviewing team leads.
- Team analytics must be aggregate and privacy-preserving by default.
- Admin visibility must be explicit to team members.

Tasks:

- Interview at least five team leads or engineering managers.
- Validate quota blocking, seat waste, provider mix, and tool-routing pain.
- Define team privacy model.
- Prototype dashboard from sanitized aggregate data.
- Price only after teams confirm willingness to pay.

Exit criteria:

- At least three teams independently describe a quota/tool-utilization problem they would pay to solve.
- Team plan does not weaken the local app promise.

Verification:

- Interview notes.
- Prototype review with target users.
- Security/privacy review.

### Stage 11: Developer-Agent Integrations

Goal: warn before quota-heavy work starts.

Why later: this can be more useful than passive charts, but it depends on trusted local status, recommendation logic, and agent integration points.

Tasks:

- Add local read-only status API or CLI command.
- Add preflight output for Claude Code and Codex workflows.
- Add recommendation output suitable for agents.
- Add integration docs.
- Keep status API sanitized and local-only by default.

Exit criteria:

- A local agent can ask which tool is safest for a task without exposing prompts or provider secrets.
- Output is useful to humans and machines.

Verification:

- CLI/API tests.
- Manual integration smoke with local agents.

## Sub-Designs Required Before Implementation

Write focused design docs before these slices:

- App bundle and menu bar architecture.
- Connector consent UX.
- Persistence and refresh engine.
- Notification thresholds and deduplication.
- Privacy threat model and diagnostics.
- Distribution, signing, notarization, and Sparkle.
- Provider expansion research for each new provider.
- Burn-rate prediction.
- Cross-provider planning recommendations.
- Multi-device sync.
- Team dashboard.
- Developer-agent integrations.

## Validation Gates

Validation has not blocked the current Claude/Codex connector work. Going forward it gates specific stages:

- Before Stage 6 provider expansion: interview at least five target developers and confirm which provider should come next.
- Before burn-rate UI: validate the model against known rolling-window cases.
- Before cross-provider planning UI: validate recommendation copy with at least five developers.
- Before sync: confirm at least five users want multi-device state.
- Before team product: confirm at least three teams would pay for team-level visibility.

## Measurement Without Default Telemetry

Default product telemetry should be off for Public V1.

Use these signals first:

- GitHub stars.
- GitHub issues and discussions.
- GitHub Release download counts as a directional signal only; downloads can be inflated by retries, mirrors, caches, scripts, and automated crawlers.
- Sponsor/donation events.
- Manual user interviews.
- Voluntary diagnostic exports initiated by users.
- Optional explicit survey links.

If anonymous telemetry is ever proposed, it requires a separate privacy design and must be opt-in, narrowly scoped, and documented before implementation.

## Execution Rule

Follow stages in order. Stage 0 through Stage 4 produce Internal V0. Stage 5 produces Public V1. Stages 6 and later should not start until the local product is useful, trusted, installable, and public.
