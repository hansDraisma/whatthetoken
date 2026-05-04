# WhatTheToken V1 Developer-First Plan

Date: 2026-05-04

## Positioning

WhatTheToken helps developers avoid AI quota surprises across the coding agents and assistants they actively use.

The v1 wedge is not "all AI subscriptions." The v1 wedge is:

> Know when your coding agents are close to throttling before they interrupt your work.

This makes Codex, Claude Code, Cursor, and GitHub Copilot more important than generic ChatGPT usage. ChatGPT and Gemini still matter, but they should not define the first product shape.

## Current Decision

V1 is developer-first and ingestion-first:

1. Codex and Claude Code are the priority products.
2. ChatGPT and Gemini web tracking are useful follow-ons, not the first validation loop.
3. The first product surface should be a Mac-first developer quota monitor.
4. The first visible product should render a quota/status signal quickly, even if it is initially local-only and limited.
5. The implementation plan should wait until this design is accepted.

## Adopted Principles

- Local-first ingestion: collect usage signals on the user's device where the authenticated session or local client state already exists.
- Minimal cloud: sync sanitized events and derived snapshots, not prompts, conversations, cookies, auth headers, or provider session tokens.
- Provenance is mandatory: every number must be labeled as `verified`, `observed`, `estimated`, or `stale`.
- Data contract before UI: shared event and snapshot types come before dashboards.
- Pure core logic: quota windows, deduplication, stale detection, and snapshot derivation live in a shared `packages/core` package.
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
- Codex local ingestion spike.
- Claude Code local ingestion spike.
- Minimal SwiftUI Mac status surface that shows current provider/product/pool status.
- Trust/privacy README.
- One agent operating rules document.
- Two ADRs:
  - local-first minimal-data ingestion
  - confidence labels and provenance

### Should Ship If Validation Holds

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

## Monetization Assumption

Do not optimize v1 around pricing, but keep the shape compatible with freemium.

Likely model:

- Free: one or two local providers, local-only status.
- Paid: multi-provider sync, history, alerts, widgets/mobile later, and advanced diagnostics.

Pricing should not be finalized until validation interviews and beta usage reveal frequency of pain.

## Roadmap

### Phase 0: Design And Validation

Goal: settle scope before implementation.

- Write this developer-first v1 plan.
- Write `docs/agent/operating-rules.md`.
- Write ADR 0001 for local-first minimal-data ingestion.
- Write ADR 0002 for confidence labels.
- Interview five target developers.
- Decide first two ingestors based on validation.

Exit criteria:

- V1 scope accepted.
- First provider/product/surface pair selected.
- Trust model accepted.

### Phase 1: Core And First Visible Counter

Goal: render one useful developer quota/status signal by the end of week 2.

- Scaffold monorepo.
- Create `packages/core`.
- Implement data contract.
- Implement confidence/stale helpers.
- Implement first ingestion spike for Codex or Claude Code.
- Render a minimal local, SwiftUI, or extension UI card.
- Add focused tests for core logic.

Exit criteria:

- One provider/product/surface shows a real or observed status.
- Tests cover the core data transformation path.
- No sensitive data is collected.

### Phase 2: Second Developer Ingestor

Goal: prove multi-tool developer value.

- Add the second high-priority ingestor, likely Claude Code if Codex is first, or Codex if Claude Code is first.
- Normalize both into the same `UsageEvent` and `UsageSnapshot` model.
- Add undercount/stale states.
- Add basic diagnostics.

Exit criteria:

- The UI shows at least two developer tools with distinct provenance labels.
- Parser/ingestor failures are visible to the user.

### Phase 3: Sync And Account Layer

Goal: make it a real product without compromising trust.

- Add Supabase Auth.
- Add device registration.
- Add sanitized event/snapshot sync.
- Add web dashboard for account, devices, and provider status.
- Add RLS policies and migration tests.

Exit criteria:

- User can connect a device and see synced status in web.
- Backend stores no prompts, conversations, cookies, or tokens.

### Phase 4: Browser Extension Counters

Goal: expand from coding agents to browser assistants.

- Add ChatGPT web estimated counter.
- Add Gemini web estimated counter.
- Add model detection and send detection.
- Add clear undercount warnings.
- Add fixture tests for DOM parsers.

Exit criteria:

- ChatGPT and Gemini show estimated status with clear caveats.
- Extension remains minimal-permission and open-source.

### Phase 5: Beta Hardening

Goal: make the product reliable enough for paid beta.

- Add error reporting without sensitive data.
- Add parser health checks.
- Add provider rot smoke checks.
- Add support diagnostics export.
- Add onboarding polish.
- Add pricing experiment.

Exit criteria:

- Beta users can self-diagnose stale/broken tracking.
- The team can detect parser breakage quickly.
- Payment scope is defined.

## Immediate Next Step

Do not write a full implementation plan yet.

Next steps:

1. Review and accept or edit this design.
2. Write the one-page agent operating rules.
3. Write the two initial ADRs.
4. Run validation interviews.
5. Then write the first implementation plan for Phase 1.
