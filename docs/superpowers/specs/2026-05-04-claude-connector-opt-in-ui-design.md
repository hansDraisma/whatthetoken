# Claude Connector Opt-In UI Design

Date: 2026-05-04
Status: Implemented and verified

## Source To-Do Item

The next roadmap item is `Wire the Claude connector service into an explicit opt-in UI path` from `docs/roadmap/v1-developer-first-plan.md`.

This follows the completed Claude connector service, sanitized smoke harness, and live smoke validation. The Mac app now starts with an explicit Claude Code opt-in path instead of fixture-only data.

## Problem

WhatTheToken can now read Claude Code quota signals locally, but the product surface does not expose a deliberate connect action. The next increment must turn the connector from a developer smoke path into an explicit user-initiated Mac app path while preserving the privacy boundary:

- No Keychain read on app launch.
- No hidden provider request before the user chooses to connect.
- No token, authorization header, raw provider JSON, prompt, or conversation data in UI, logs, tests, or docs examples.
- Usage snapshots remain the only data shape shown by the app.

## User Outcome

A Mac user opens WhatTheToken, sees Claude Code as disconnected, chooses `Connect Claude Code`, and then sees either verified Claude usage snapshots or a clear local status message explaining why the connector could not refresh.

## Goals

- Add an explicit `Connect Claude Code` UI action to the Mac app.
- Keep Claude credential access behind that user action.
- Reuse the existing `ClaudeConnectorService` for real refresh behavior.
- Reuse the existing status card surface for successful snapshots.
- Show connector status for `not_connected`, `missing_credentials`, `token_invalid`, `rate_limited`, `network_error`, `schema_changed`, and `connected`.
- Keep all product copy sanitized and local-boundary focused.
- Cover the state transitions with Swift tests before implementation.

## Non-Goals

- No background refresh.
- No refresh on launch.
- No persisted setting for enabled connectors.
- No Supabase sync behavior.
- No Chrome extension onboarding.
- No Codex connector.
- No production analytics.
- No live Claude endpoint call in automated tests.
- No installer or auto-update flow.

## Product Behavior

Initial state:

- The app opens with zero Claude snapshots.
- The Claude connector state is `not_connected`.
- The primary action is `Connect Claude Code`.
- The UI says that WhatTheToken reads Claude Code credentials locally only after the user connects.

Connect action:

- Pressing `Connect Claude Code` moves the connector state to `checking`.
- The app calls the injected Claude connector refresher once.
- The button is disabled while the refresh is running.
- Additional connect attempts while `checking` are ignored.
- A successful connected result replaces snapshots with the connector snapshots.
- A non-connected result keeps snapshots empty unless the service returns safe snapshots.
- A thrown refresh error maps to a sanitized `network_error` UI state.

Connected state:

- The app shows status cards for returned snapshots.
- Snapshot cards keep existing provenance copy such as verified source and undercount risk.
- The connector status line shows the sanitized message from `ConnectorStatus.message`.

Error and unavailable states:

| Connector source state | UI title | UI detail |
| --- | --- | --- |
| `not_connected` | Claude Code is not connected | Connect Claude Code to show local quota signals in WhatTheToken. |
| `missing_credentials` | Claude Code credentials were not found | Sign in to Claude Code locally, then retry. |
| `token_invalid` | Claude Code credentials are invalid | Sign in to Claude Code again, then retry. |
| `rate_limited` | Claude usage is rate limited | Try again after Claude Code allows more usage requests. |
| `network_error` | Claude Code usage could not be refreshed | Check the local network connection, then retry. |
| `schema_changed` | Claude usage response changed | WhatTheToken needs a parser update before this signal can be trusted. |
| `connected` | Claude Code connected | Verified usage signals are shown below. |

The UI may use `ConnectorStatus.message` as the short status line, but must not display raw error descriptions from thrown errors.

## Architecture

- Move `ClaudeConnectorRefreshing` out of `ClaudeConnectorSmokeCommand.swift` into `apps/mac/Sources/WhatTheTokenMac/Connectors/ClaudeConnectorRefreshing.swift`.
- Keep `ClaudeConnectorSmokeCommand` dependent on the shared protocol.
- Extend `StatusViewModel` so it owns connector setup state, connector status copy, and an async `connectClaudeCode()` method.
- Inject `ClaudeConnectorRefreshing` into `StatusViewModel` so tests can use stubs and the app can use the live `ClaudeConnectorService`.
- Add a local Claude version provider that reads `claude --version` only during the user-initiated refresh path.
- Resolve the Claude executable from `PATH` plus common local install paths for Finder-launched app sessions.
- Keep connector setup titles and trust copy in a tested helper.
- Update `ContentView` to render the connector setup state above the existing snapshot cards.
- Update `WhatTheTokenApp` to create a live `StatusViewModel` without triggering a refresh on launch.

## Testing Requirements

Tests must prove:

- Initializing the live view model does not call the Claude refresher.
- Calling `connectClaudeCode()` calls the refresher exactly once.
- A connected result updates snapshots and connector state.
- Missing credentials displays the sanitized missing-credentials state and leaves snapshots empty.
- A thrown error becomes a sanitized network-error state.
- The smoke harness still passes after the shared protocol extraction.
- The local Claude version provider parses `claude --version` output and falls back safely when the command is unavailable.
- The executable resolver finds `~/.local/bin/claude` when `PATH` is restricted.
- Product setup copy is covered for every connector setup state.
- Duplicate connect attempts while checking start only one refresh.

Automated tests must use stubs only. Live smoke remains a manual developer command:

```bash
CLAUDE_CODE_VERSION="$(claude --version | awk '{print $1}')" swift run WhatTheTokenMac --claude-connector-smoke
```

## Acceptance Criteria

- The app starts with the connector disconnected and does not read Claude credentials on launch.
- The user must click `Connect Claude Code` before any Claude connector refresh occurs.
- The app does not run the Claude version command on launch.
- Successful connector refresh shows returned snapshots in existing cards.
- Failed connector refresh shows sanitized connector status copy.
- Swift tests cover the opt-in flow and pass.
- Existing smoke command tests still pass.
- Documentation remains clear that automated tests never call live Claude endpoints.

## Implementation Verification

Verified on 2026-05-05:

- `swift test --filter StatusViewModelClaudeConnectorTests` passed with opt-in, duplicate-connect, and setup-copy coverage.
- `swift test --filter ClaudeVersionProviderTests` passed with restricted-path executable resolution coverage.
- `swift test --filter ClaudeConnectorSmokeCommandTests` passed.
- `cd apps/mac && swift test` passed with 43 Swift tests.
- `cd apps/mac && swift build` passed.
- `pnpm check` passed with 16 TypeScript core tests.
- `swift run WhatTheTokenMac` launched and stayed alive for five seconds in a bounded local GUI smoke.

## Review Passes

Pass 1 - roadmap alignment:

- The spec directly implements the roadmap item for an explicit Claude opt-in UI path.
- Installer, Chrome onboarding, Codex, and sync remain separate roadmap items.

Pass 2 - privacy and safety:

- The spec preserves the no-launch-read rule and requires user action before credential access.
- The spec forbids raw provider data and raw thrown error descriptions in product output.

Pass 3 - implementation readiness:

- The spec names the current Swift files that need changes.
- The spec defines testable state transitions and concrete connector-state copy.
