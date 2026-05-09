# App Sandbox Compatibility Matrix

Public V1 ships outside the Mac App Store through Developer ID distribution. App Sandbox is not required for that channel, so the release decision is based on connector compatibility rather than store policy.

## Public V1 Decision

Keep `com.apple.security.app-sandbox` disabled for Public V1 unless every row in this matrix passes on a signed, notarized release candidate.

Rationale:

- WhatTheToken is a local developer utility.
- Claude Code and Codex connector paths depend on local command/process behavior and user-owned local state.
- A broken sandboxed release would look safer in metadata while weakening the actual product promise.
- Hardened runtime, notarization, explicit connector consent, sanitized persistence, and public source review carry the Public V1 trust posture.

## Matrix

| Area | Test | Expected Result | Public V1 Status |
| --- | --- | --- | --- |
| Finder launch | Install from notarized DMG into `/Applications` and launch from Finder | App opens as a menu bar utility without Gatekeeper friction | Not run |
| Menu bar app mode | Launch production app | No Dock icon; menu bar item appears | Covered by `LSUIElement`, needs signed smoke |
| Settings persistence | Toggle settings, quit, relaunch | Settings persist in Application Support | Not run |
| Launch at login | Toggle launch at login on and off | `SMAppService.mainApp` registers and unregisters without entitlement failures | Not run |
| Claude consent | Connect Claude Code from a clean account | No credential copying; status is parsed only after opt-in | Not run |
| Claude disconnect | Disconnect Claude Code | Consent, cached snapshots, and notification state are removed | Not run |
| Codex consent | Connect Codex from a clean account | Local app-server status can be read only after opt-in | Not run |
| Codex disconnect | Disconnect Codex | Consent, cached snapshots, and notification state are removed | Not run |
| Background refresh | Enable optional auto-refresh | Runs only for opted-in connectors and respects provider backoff | Not run |
| Notifications | Enable notifications and cross a synthetic threshold | Local notification fires without stale snapshots or repeated spam | Not run |
| Sparkle manual check | Choose `Check for Updates` after appcast is configured | Only explicit action reaches the appcast URL | Not run |
| First launch network silence | Observe process sockets for 60 seconds after first launch | No network connection before explicit user action | Not run |
| DMG copy-out | Mount final DMG, copy app out, run Gatekeeper assessment | Copied app remains signed, timestamped, and accepted | Covered by release script, needs signed artifact |

## Reconsidering Sandbox

Only reconsider sandboxing after Public V1 if:

- every connector has a documented sandbox-compatible source,
- the app does not require broad user-selected file access for routine operation,
- Sparkle update checks still work from the sandboxed candidate,
- launch-at-login behavior remains stable,
- fresh-account install smoke passes from the notarized DMG.

If sandboxing is enabled later, add only the narrow entitlements proven by this matrix and update `docs/superpowers/specs/2026-05-09-distribution-hardening-design.md`.
