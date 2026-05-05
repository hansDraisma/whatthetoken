# WhatTheToken V1 Developer-First Plan

Date: 2026-05-04

Status: historical context.

The current canonical execution roadmap is `docs/roadmap/development-roadmap.md`.
The current open-source strategy and business model is `docs/roadmap/open-source-strategy-and-business-model.md`.

Use this document for original V1 framing only. Do not use its older phase assumptions as the current implementation order.

This document predates the completed Claude Code and Codex connector work. Where it conflicts with `docs/roadmap/development-roadmap.md`, the canonical roadmap wins.

## Positioning

WhatTheToken helps developers avoid AI quota surprises across the coding agents and assistants they actively use.

The v1 wedge is not "all AI subscriptions." The v1 wedge is:

> Know when your coding agents are close to throttling before they interrupt your work.

This makes Codex, Claude Code, Cursor, and GitHub Copilot more important than generic ChatGPT usage. ChatGPT and Gemini still matter, but they should not define the first product shape.

## Current Decision

V1 is developer-first and ingestion-first:

1. Claude Code is the first implementation target because it has the clearest local verified usage path.
2. Codex remains a high-priority developer product, but moves to a later adapter phase after a dedicated local metadata schema and redaction review.
3. ChatGPT and Gemini web tracking are useful follow-ons, not the first validation loop.
4. The first product surface should be a Mac-first developer quota monitor.
5. The first visible product should render a quota/status signal quickly, even if it is initially local-only and limited.
6. The implementation plan should start with the Claude Code local connector.

## Adopted Principles

- Local-first ingestion: collect usage signals on the user's device where the authenticated session or local client state already exists.
- Minimal cloud: sync sanitized events and derived snapshots, not prompts, conversations, cookies, auth headers, or provider session tokens.
- Local credential boundary: provider credentials may be used by a local connector with consent, but they must not be uploaded to the backend, exposed to the browser extension, or copied into diagnostics.
- Provenance is mandatory: every number must be labeled as `verified`, `observed`, `estimated`, or `stale`.
- Data contract before UI: shared event and snapshot types come before dashboards.
- Pure core logic: quota windows, deduplication, stale detection, and snapshot derivation live in a shared `packages/core` package.
- Open-source trust posture: the local app, shared core, and connector boundaries should be auditable; official builds should be signed and notarized.
- Extension trust posture: open-source the browser extension; backend can remain closed.
- Lean process: one operating rules document and a small number of ADRs before implementation.
- Budget-aware model: track quota pools, credit balances, model multipliers, reset windows, and paid-overage state where available.

## Non-Negotiable Privacy Rules

The product must never collect:

- prompts
- model responses
- conversation contents
- conversation URLs unless explicitly justified by a future ADR
- cookies
- bearer tokens
- provider session tokens
- browser request bodies

Allowed telemetry for usage tracking:

- provider
- product
- surface
- model key when detectable
- event type
- count or utilization
- observed timestamp
- device identifier
- confidence level
- parser/source version
- sync/error status

## Product Taxonomy

Provider, product, and surface must be separate concepts.

Examples:

| Provider | Product | Surface | Confidence |
|---|---|---|---|
| OpenAI | Codex | CLI | observed or verified |
| OpenAI | Codex | Cloud agent | unknown initially |
| OpenAI | ChatGPT | Web | estimated |
| Anthropic | Claude Code | CLI | verified or observed |
| Anthropic | Claude | Web | verified or estimated |
| Google | Gemini | Web | estimated |
| Cursor | Cursor | IDE / CLI / cloud agent | observed initially |
| GitHub | Copilot | IDE / CLI / GitHub | observed initially |

This prevents vague UI like "OpenAI usage" when the user actually needs to know whether Codex, ChatGPT, or API usage is being counted.

## Confidence Labels

| Label | Meaning | Example |
|---|---|---|
| `verified` | Derived from provider/local authoritative quota data | Claude usage endpoint, official local quota file if available |
| `observed` | Counted directly from a local client action | Codex CLI invocation, browser send button |
| `estimated` | Inferred from observed activity and public limits | ChatGPT messages remaining |
| `stale` | Last signal is older than the freshness threshold | laptop offline, extension not seen recently |

The UI must show freshness and undercount risk near the number, not hidden in help text.

## Initial Data Contract

```ts
export type Provider =
  | "openai"
  | "anthropic"
  | "google"
  | "cursor"
  | "github";

export type Product =
  | "codex"
  | "chatgpt"
  | "claude_code"
  | "claude"
  | "gemini"
  | "cursor"
  | "github_copilot";

export type Surface =
  | "cli"
  | "web"
  | "browser_extension"
  | "desktop_app"
  | "ide"
  | "cloud_agent"
  | "mobile";

export type UsageConfidence =
  | "verified"
  | "observed"
  | "estimated"
  | "stale";

export type UsageEvent = {
  id: string;
  userAccountId: string;
  deviceId: string;
  providerAccountId: string | null;
  provider: Provider;
  product: Product;
  surface: Surface;
  eventType: "message_sent" | "agent_run_started" | "agent_run_finished" | "quota_polled";
  modelKey: string | null;
  count: number;
  observedAt: string;
  confidence: UsageConfidence;
  sourceVersion: string;
  attribution: {
    deviceName?: string;
    os?: "macos" | "windows" | "linux" | "ios" | "android" | "unknown";
    browser?: "chrome" | "edge" | "brave" | "firefox" | "safari" | "unknown";
    canMissOtherDevices: boolean;
  };
};

export type UsageSnapshot = {
  id: string;
  userAccountId: string;
  provider: Provider;
  product: Product;
  surface: Surface | "aggregate";
  windowKey: string;
  used: number | null;
  limit: number | null;
  remaining: number | null;
  utilization: number | null;
  resetAt: string | null;
  lastUpdatedAt: string;
  confidence: UsageConfidence;
  undercountRisk: "none" | "possible" | "likely";
  staleReason: string | null;
};
```

## V1 Scope

### Must Ship

- Shared TypeScript core package for usage events, snapshots, confidence labels, stale detection, and quota window math.
- Claude Code local connector that maps sanitized Anthropic usage responses into shared snapshots.
- Minimal SwiftUI Mac status surface that shows current provider/product/pool status.
- Trust/privacy README.
- One agent operating rules document.
- Two ADRs:
  - local-first minimal-data ingestion
  - confidence labels and provenance

### Should Ship If Validation Holds

- Codex local metadata/redaction spike.
- Codex local connector after the redaction spike identifies a safe source.
- Supabase sync for sanitized events and snapshots.
- Browser extension popover.
- ChatGPT web estimated counter.
- Gemini web estimated counter.
- Device attribution and undercount warning.

### Explicitly Out Of V1

- iOS app and WidgetKit.
- Apple Watch.
- API spend tracking.
- Fully polished Mac app beyond the minimal SwiftUI status surface.
- Firefox/Safari extension ports.
- Team/admin dashboards.

## Desktop Direction

Use SwiftUI for the Mac product direction.

Reasoning:

- The initial target user is a developer on macOS who wants a polished local quota monitor.
- SwiftUI is the strongest fit for Keychain access, menu bar presence, local notifications, login items, and eventual Apple-platform touchpoints.
- Non-Mac surfaces can be added later through separate clients or shared backend APIs.
- Cross-platform desktop support is not required to validate the v1 wedge.

Implication:

- V1 may still start with local CLI/core work before a full Mac UI, but the native Mac client is the preferred desktop destination.
- Windows/Linux are future touchpoints, not constraints on the v1 architecture.

## Validation Before Heavy Build

Before full implementation, talk to at least five target developers who actively use two or more AI coding tools.

Questions to validate:

1. Which tools do you pay for and use weekly: Claude Code, Codex, Cursor, Copilot, ChatGPT, Gemini?
2. Which quota has interrupted you in the last 30 days?
3. Where were you working when it happened: CLI, IDE, browser, mobile?
4. Would an estimated number be useful if clearly labeled?
5. Would you install an open-source browser extension for this?
6. Would you pay for multi-tool quota tracking? If yes, roughly how much?

Success signal:

- At least three of five have experienced quota pain recently.
- At least three would install a local/browser ingestor.
- At least two would pay for multi-tool support.

## DOM And Provider Rot Strategy

Provider UIs and local client formats will change. Treat parser rot as a product risk, not an edge case.

Required strategy:

- Parser code must be isolated by provider/product/surface.
- Each parser must expose a health check result.
- Extension must include a diagnostics screen showing last detected model, last observed event, and parser version.
- Add fixture-based parser tests from day one.
- Add live smoke tests only after the extension has a stable first parser.
- Publish contribution guidance for parser fixes if the extension is open-source.

Daily live smoke tests against provider websites are useful, but they should not run before there is a stable parser and test account strategy. Running authenticated live tests too early creates operational noise.

## Onboarding Recommendation

V1 onboarding should be extension/local-client first, web second.

Reasoning:

- The product value appears only after an ingestor is connected.
- Web-first signup creates drop-off before the user sees a number.
- Extension/local-first onboarding can show a local status immediately, then ask the user to create an account for sync/history.

Proposed flow:

1. User installs extension or local CLI helper.
2. Product detects supported tools/surfaces.
3. Product shows first local quota/status card.
4. User creates account only when they want sync, history, alerts, or multiple devices.

Security framing:

- The Chrome extension and Mac connector should feel like connectors for one product, not separate products.
- The Mac connector is the secure path for Claude Code because it can use local device state without sending provider credentials to WhatTheToken.
- Codex should use the same connector model later only after its local files or invocation metadata have a separate redaction review.
- The unified UI should show all providers together regardless of which connector produced the signal.
- Frontend copy should lead with the trust promise: provider credentials stay on the user's device; WhatTheToken syncs only usage status.

## Current Plan

The original V1 framing in this file remains useful:

- developer-first wedge
- local-first ingestion
- confidence labels
- provider/product/surface taxonomy
- non-negotiable privacy rules
- Mac-first direction
- validation questions
- provider rot strategy

The implementation order has changed because Claude Code and Codex connector work already exists. Current execution now continues from the repo state documented in `docs/roadmap/development-roadmap.md`.

Current strategic decisions:

- The local app is open source.
- The license is Apache-2.0.
- Internal V0 is the private working Mac app at the end of Stage 4 in `docs/roadmap/development-roadmap.md`.
- Public V1 is the public repo plus free signed/notarized DMG at the end of Stage 5 in `docs/roadmap/development-roadmap.md`.
- There is no Public V1 trial, license key, paid DMG, or local-provider paywall.
- Sponsorship is acceptable.
- Hosted sync, team visibility, managed reliability, and support are the future revenue candidates.

Current differentiators:

- Trust/provenance-first tracking.
- Best-tool-right-now recommendations after research validation.
- Pace and burn-rate prediction after rolling-window model validation.
- Cross-provider planning.
- Privacy and auditability.
- Team or multi-device sync later.
- Developer-agent integrations later.

See:

- `docs/roadmap/development-roadmap.md`
- `docs/roadmap/open-source-strategy-and-business-model.md`
