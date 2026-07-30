# Contributing

Thanks for looking. This document covers setup, the invariants that are not negotiable,
and an honest walkthrough of adding a provider connector.

## Development Setup

```bash
pnpm install --frozen-lockfile

# TypeScript core (includes the Swift fixture contract test)
pnpm --filter @whatthetoken/core test

# Mac app
cd apps/mac && swift test

# build a runnable .app for manual checking
apps/mac/Scripts/package-app.sh
```

Prerequisites: macOS 14+, Swift 6 toolchain, Node, pnpm 10.

Both build systems compile the same `apps/mac/Sources` tree. SwiftPM (`swift build`)
produces a bare executable; the Xcode project produces the actual `.app` with the widget,
Sparkle, and `LSUIElement`. Use `package-app.sh` when you need something launchable.

## The Invariants

These are the rules that matter more than style. A change that breaks one of these will
not be merged, however good the rest of it is.

**Never collect forbidden data.** Prompts, completions, conversation content, cookies,
auth headers, bearer tokens, session tokens, API keys, credentials, or raw provider
payloads must never be collected, persisted, synced, logged, *or written into a test
fixture*. That last clause is the one people trip over. The full deny list is
[`docs/architecture/privacy-boundaries.md`](docs/architecture/privacy-boundaries.md).

**Never take ownership of a provider credential.** Read-only, in memory, discarded after
use. Never redeem a refresh token, never mint a credential, never write a provider-owned
Keychain item — see [ADR 0003](docs/adr/0003-never-refresh-provider-tokens.md) for why
this is stricter than it first appears.

**Every number carries provenance.** Confidence, freshness, and undercount risk travel
with the value and are rendered near it. Never widen a confidence label to make a number
look better than it is. See [ADR 0002](docs/adr/0002-confidence-labels-and-provenance.md).

**Emit sanitized source states, not raw errors.** Map provider and OS failures onto
`ConnectorSourceState` (`Models/ConnectorSourceState.swift`). Raw provider responses and
local paths must not reach the UI, the logs, or an issue report.

**Fixtures and CI stay synthetic.** No live credentials, no Keychain access, no Codex
app-server, no provider network calls in CI. If a test needs provider data, hand-write it.

**Prefer emitting nothing over inventing something.** If a limit is unknown, do not
synthesise one. A missing row is honest; a guessed row is not.

Anything that weakens the deny list, adds a sensitive data category, or changes confidence
semantics needs an ADR before implementation.

## Package Boundaries

`packages/core` owns portable schemas, confidence labels, snapshot helpers, and staleness
logic. `apps/mac` owns SwiftUI views, connector orchestration, credential access
boundaries, smoke commands, and macOS behaviour.

## Adding a Provider Connector

Read this section before starting, because the honest answer is that this is a bigger job
than it looks.

**There is currently no generic connector abstraction.** Claude Code and Codex are two
parallel, hand-written stacks. Each has its own one-method refresh protocol, its own
result type, its own copy tables, its own `StatusViewModel` refresh path, and its own
settings field. Adding a third provider is mechanical duplication across roughly
twenty-five files, not implementing one interface.

Worse, several places assume there are *exactly two* providers:

| Location | Assumption |
|---|---|
| `ViewModels/BannerState.swift` | `otherTab` is computed as a binary either/or |
| `ViewModels/BannerState.swift` | "both disconnected" copy is two-provider |
| `ViewModels/PopoverChromeState.swift` | tab indicators are two hand-written calls, not `ProviderTab.allCases` |
| `ViewModels/PopoverChromeState.swift` | the critical menu-bar state ORs exactly two providers |
| `ViewModels/StatusViewModel.swift` | `lastUpdatedAt`, `isAnyRefreshing`, and `refreshAll` are hardcoded pairs |
| `Storage/AppSettings.swift` | connector and alert consent are named struct fields, not a keyed collection |

**Generalising those over `ProviderTab.allCases` is the most useful contribution someone
could make right now**, and it is a good first issue precisely because it is well-bounded
and fully covered by existing tests. Doing it before adding a third provider is strongly
preferred over adding a provider that quietly gets degraded banner and menu-bar behaviour.

### The contract a connector must satisfy

A connector is a `Sendable` type with one method:

```swift
protocol ClaudeConnectorRefreshing: Sendable {
    func refresh() async throws -> ClaudeConnectorResult
}
```

It must gate on explicit consent before reading anything, map every failure to a
`ConnectorSourceState`, and return `[UsageSnapshot]` plus a `ConnectorStatus`. Mappers are
pure `static` functions on a caseless `enum`:

```swift
static func map(
    _ response: ProviderResponse,
    userAccountId: String,
    deviceId: String,
    observedAt: String,
    source: ConnectorSource
) -> [UsageSnapshot]
```

Use `Claude/ClaudeConnectorService.swift` and `Codex/CodexConnectorService.swift` as the
two reference templates — Claude for the credential-reading shape, Codex for the
local-subprocess shape.

### Suggested order

Working in this order means each step is verifiable before the next one depends on it.

1. **Schema first.** Add the provider and product to `packages/core/src/schemas.ts` *and*
   the hand-maintained mirror unions in `packages/core/src/types.ts` — they are not
   derived from each other, so forgetting one compiles fine and silently drifts. Add
   accept/reject cases to `schemas.test.ts`.
2. **Fixture and contract test.** Add a synthetic
   `Resources/usage-<provider>-snapshot.fixture.json` matching exactly what your mapper
   will emit, and add a new assertion block to
   `packages/core/src/__tests__/mac-fixture-contract.test.ts`. That test is currently
   hardcoded to the single Claude fixture, so **a new fixture with no new assertion is
   completely unvalidated.** Run `pnpm --filter @whatthetoken/core test`.
3. **DTO and client.** A response type plus a fetching protocol seam so tests can inject,
   and a sanitized error enum. Tests first.
4. **Mapper.** Assert every field against the fixture.
5. **Credential access, if any.** Redacting `description`, never persisted. Re-read
   ADR 0003 before writing this.
6. **Connector service** and its refresh protocol, result, and settings types.
7. **Identity enums:** `CachedProviderID`, `ProviderTab`, and `WidgetProvider`. Adding a
   case here produces compiler errors at every exhaustive switch — that is your free
   checklist, so work through them.
8. **The silent list.** These match on provider and product *strings*, so the compiler
   will not help and a miss shows up as data mysteriously vanishing:
   - `StatusViewModel.applyCachedSnapshots` — unrecognised snapshots are silently dropped
     on every launch and settings change. This is the most likely cause of a connector
     that "works once then disappears".
   - `StatusViewModel.applyCachedRefreshTimestamps`
   - `SnapshotCache.CachedProviderID.snapshotPredicate`
   - `ProviderAvailability.from(snapshot:)` and the lane predicates
   - `NotificationEvaluator.provider(for:)`, `normalizedPoolKey`, `normalizedWindowKey`
   - `StatusSectionDisplayModel.compareLink`
   - `isFallbackCredits` — **duplicated** in `StatusRowDisplayModel` and `StatusRowCopy`
   - `SnapshotEntryBuilder.isIncludedQuota`
9. **Settings.** Add consent and alert fields, default to disabled, and **bump
   `AppSettings.currentSchemaVersion` with a new migration** — otherwise settings files
   written by older builds fail to decode. Never migrate an existing user into new consent.
10. **`StatusViewModel` wiring**, then **UI**, then a `--<provider>-connector-smoke`
    command with an env opt-in if it spawns a subprocess.
11. **`project.pbxproj`.** Every new Swift file must be added to the Xcode target;
    `MacXcodeProjectTests` asserts the project and the source tree agree. Note the widget
    target has its own small source list, so anything reachable from `SnapshotCache.swift`
    or `WidgetEntry.swift` must be in it or `#if`-guarded.
12. **Docs.** Update `data-contract.md`, `privacy-boundaries.md` if boundaries moved, and
    add an ADR if semantics changed.

## Review Checklist

Before submitting connector, diagnostics, fixture, notification, or quota-display changes:

- [ ] privacy deny list is not weakened
- [ ] every number has a confidence label
- [ ] stale state remains visible
- [ ] raw provider payloads are not logged or persisted
- [ ] no credential is written, minted, or refreshed
- [ ] tests use synthetic data only
- [ ] `pnpm --filter @whatthetoken/core test` passes
- [ ] `swift test` passes from `apps/mac`
- [ ] docs or an ADR updated if boundaries, schema, or confidence semantics changed

## Reporting Issues

Bugs go to [GitHub Issues](https://github.com/hansDraisma/whatthetoken/issues); security
reports follow [SECURITY.md](SECURITY.md).

**Never paste provider credentials, cookies, authorization headers, tokens, prompts,
responses, or raw provider payloads into an issue.** If you are attaching output, read it
first.
