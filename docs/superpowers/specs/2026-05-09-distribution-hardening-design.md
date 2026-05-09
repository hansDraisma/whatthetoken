# Distribution Hardening And Sparkle Design

Date: 2026-05-09

Status: Stage 5 release-readiness spec. Repo-side foundation is implemented; credentialed release rehearsal and public launch are still pending.

## Purpose

Stage 5 turns WhatTheToken from a developer-run SwiftPM app into a trusted public Mac download.

This spec defines release readiness, not just repository configuration. Passing unit tests and release-script dry-runs is necessary but not enough to claim Public V1 is ready. Public readiness requires a real Developer ID archive/export, notarized DMG, Gatekeeper verification, fresh-machine smoke test, and explicit release artifact review.

The public release must be a signed and notarized direct-distribution build that a non-developer can install without Gatekeeper friction. The release path must preserve the product's local-first trust story: no copied provider credentials, no raw provider payload persistence, no default telemetry, and no hidden update or network behavior that weakens the privacy promise.

Sparkle is part of the Stage 5 architecture. Public V1 should be Sparkle-ready and may expose a manual `Check for Updates` path after update verification passes. Background automatic update checks and silent automatic installs must remain disabled until at least one signed/notarized release and one signed update path have been proven.

## Product Decision

Use direct distribution through GitHub Releases for Public V1:

- Developer ID signed `.app`
- notarized and stapled DMG with an `/Applications` symlink
- public release notes and checksums
- documented manual update instructions
- Sparkle-capable release target, with any user-visible update check gated on appcast signing and old-build to new-build update smoke tests
- Sparkle automatic checks disabled by default for Public V1
- no Mac App Store submission for Public V1
- no paid DMG, trial, license key, or local-provider paywall

This keeps the first public launch aligned with the open-source trust strategy while preparing the app for fast connector-fix delivery after launch.

## Current State

Implemented repo-side foundation:

- SwiftPM executable product remains the local development and unit-test path: `apps/mac/Package.swift`
- Xcode release app target exists: `apps/mac/WhatTheToken.xcodeproj`
- release metadata, entitlements, Developer ID export options, and xcconfigs exist under `apps/mac/Packaging`
- release scripts exist under `apps/mac/Scripts`
- launch-at-login setting uses `SMAppService.mainApp`
- Sparkle is wired into the Xcode target and bridged behind a manual-check controller
- public release checklist exists at `docs/release/public-v1-checklist.md`
- menu bar utility behavior remains enforced through `LSUIElement = true` and runtime `.accessory` activation policy

Remaining before Public V1:

- app icon and asset catalog for public packaging
- initialized local Xcode installation capable of `xcodebuild archive`
- real Developer ID archive/export with maintainer certificate access
- notarization submission, stapling, and Gatekeeper acceptance on the real DMG
- sandbox compatibility matrix, if sandboxing is reconsidered
- Sparkle EdDSA public key and stable appcast URL decision
- signed old-build to new-build Sparkle update smoke before exposing `Check for Updates`
- fresh-machine install and launch smoke from the notarized DMG
- repository public-visibility scan for internal workspace names and release secrets

## Source Facts

Apple's direct-distribution path uses Developer ID signing and notarization so Gatekeeper can verify the app is from an identified developer and has been checked by Apple. Apple requires hardened runtime for notarized apps distributed outside the Mac App Store.

Apple's App Sandbox is required for Mac App Store distribution, but direct-distribution Developer ID apps can decide whether to enable sandboxing. WhatTheToken must test sandbox compatibility because the current connector architecture uses `/usr/bin/security`, local process launching for Codex app-server, Application Support storage, and provider network requests.

Apple's modern launch-at-login API is `SMAppService` on macOS 13 and later. WhatTheToken targets macOS 14, so it should use `SMAppService.mainApp` rather than legacy login item APIs.

Sparkle is the standard updater framework for direct-distributed macOS apps. It uses an appcast feed, `SUFeedURL`, `SUPublicEDKey`, EdDSA update signatures, Apple code signing, and Sparkle helper tools that must be packaged and signed correctly. Sparkle's own docs recommend Developer ID signed and notarized distribution and careful signing key custody.

Primary references:

- Apple Developer ID: https://developer.apple.com/developer-id/
- Apple Xcode direct distribution: https://help.apple.com/xcode/mac/current/en.lproj/dev033e997ca.html
- Apple App Sandbox: https://developer.apple.com/documentation/security/app-sandbox
- Apple `SMAppService`: https://developer.apple.com/documentation/servicemanagement/smappservice
- Sparkle documentation: https://sparkle-project.org/documentation/

## Approaches Considered

### Option A: Manual DMG Only

Ship only a signed/notarized DMG and GitHub Releases manual update instructions.

Advantages:

- lowest first-release complexity
- no updater dependency
- no appcast hosting, EdDSA key custody, or nested Sparkle signing
- easiest to reason about for Public V1

Disadvantages:

- provider connector breakage fixes depend on users manually checking GitHub
- no in-app path for urgent update awareness
- weak long-term product experience for a tool that depends on provider behavior staying current

This is acceptable as a fallback but insufficient as the Stage 5 architecture.

### Option B: Sparkle-Ready Manual-First

Build the release pipeline so Sparkle can be included safely, but keep automatic checks disabled by default for Public V1. Manual update instructions remain the primary Public V1 update path. A manual Sparkle `Check for Updates` affordance can ship only if update smoke tests pass against signed/notarized old and new builds.

Advantages:

- prepares the right long-term updater architecture
- avoids blocking Public V1 on background updater behavior
- lets release signing, notarization, DMG, appcast, and Sparkle verification be tested deliberately
- supports fast connector fixes after the first release path is proven

Disadvantages:

- more Stage 5 implementation work than manual-only
- requires careful packaging and nested code signing
- requires private EdDSA key custody before public launch

This is the recommended approach.

### Option C: Sparkle Fully Enabled At Public V1

Ship Sparkle with automatic background update checks and visible update settings from the first public DMG.

Advantages:

- best end-user update experience immediately
- fastest route for connector fixes

Disadvantages:

- increases first-launch trust and QA surface
- adds updater prompts before the product has earned trust
- makes Public V1 depend on appcast hosting and update-channel reliability
- failure modes are harder to debug before any public install base exists

Do not choose this for Public V1.

## Stage Boundary

In scope:

- direct-distribution release architecture
- app bundle metadata cleanup
- app icon and asset catalog required for public launch
- entitlements file with hardened runtime-compatible signing
- Developer ID signing
- notarization and stapling
- DMG creation
- Gatekeeper verification
- checksum generation
- release checklist
- Sparkle key/appcast/update strategy
- Sparkle packaging if tests prove it can be signed and notarized reliably
- launch-at-login setting using `SMAppService`
- documentation updates for install, update, and trust

Out of scope:

- Mac App Store submission
- App Store sandbox compliance as a release requirement
- paid distribution, trials, license keys, or purchase flow
- hosted account sync
- default telemetry
- crash reporting service
- browser extension distribution
- team/admin deployment
- automatic background Sparkle checks before one public release path is proven
- silent automatic update installs

## Completion Model

Stage 5 must be tracked in three gates so the project does not confuse repository readiness with public release readiness.

### Stage 5A: Repo Foundation

Complete when the repository contains the release target, metadata, entitlements, launch-at-login setting, Sparkle-ready wiring, release scripts, tests, and release checklist. This gate can pass without maintainer signing credentials. It does not produce an official public build.

### Stage 5B: Credentialed Release Rehearsal

Complete when the maintainer runs the release flow with real credentials on a clean checkout:

- Xcode archive/export succeeds for explicit version and build values
- exported app is Developer ID signed with hardened runtime
- DMG is created, notarized, stapled, and accepted by Gatekeeper
- checksums are generated from final artifacts
- launch, quit, settings, connector opt-in, disconnect, relaunch, and launch-at-login smoke tests pass on a fresh macOS account
- Sparkle remains hidden unless signed update smoke passes

### Stage 5C: Public Launch

Complete when the notarized DMG and checksum are published on GitHub Releases, public docs point to the official artifacts, support/security boundaries are accurate, and the repository can be made public without exposing internal paths, diagnostics, or secret material.

## Release Architecture

The release pipeline should produce these artifacts from a clean checkout:

1. `WhatTheToken.app`
2. `WhatTheToken-<version>.dmg`
3. `WhatTheToken-<version>.dmg.sha256`
4. `WhatTheToken-<version>.app.sha256` or an equivalent app archive checksum if an app zip is also published
5. release notes
6. optional Sparkle `appcast.xml` entry after Sparkle update verification passes

The public release channel is GitHub Releases. The appcast can be hosted from a stable HTTPS URL controlled by the project. If GitHub Pages is used for the first appcast, the appcast path must not expose internal workspace names and must be documented as public release infrastructure.

Release artifacts must be created from committed source, not from untracked local files. A release tag must point at the exact commit used for the archive. If a release candidate fails notarization, Gatekeeper, Sparkle, or fresh-machine smoke, cut a new build number rather than reusing the failed public build number.

The current `package-app.sh` path is development-only. It may remain for unsigned local smoke tests, but the public release owner is the Xcode archive/export flow.

## Bundle And Metadata

The bundle identity should remain:

- display name: `WhatTheToken`
- executable: `WhatTheTokenMac`
- bundle identifier: `com.whatthetoken.mac`
- minimum macOS: `14.0`
- activation: menu bar utility with no Dock icon in production

Versioning rules:

- `CFBundleShortVersionString` is the human version, starting from the Public V1 version chosen before release.
- `CFBundleVersion` is a monotonically increasing integer build number.
- Every release script must accept explicit version and build values.
- Sparkle compares bundle versions, so `CFBundleVersion` must never go backward in public builds.
- Once a build number appears in a public artifact or appcast, do not reuse it for a different binary.

Public release builds must use a thin Xcode app target that references the existing Swift source tree and archives with `xcodebuild archive`. Release export must use `xcodebuild -exportArchive` with Developer ID export options.

SwiftPM remains the fast local development and unit-test path. Once the Xcode release flow is proven, either delete `package-app.sh` or rename/document it as development-only so it cannot be mistaken for a notarizable release path.

Sparkle's docs recommend Xcode archive/export because Sparkle helper tools and framework code must be embedded and signed correctly. The Xcode target should add Sparkle through Swift Package Manager and use Xcode's Embed & Sign behavior for `Sparkle.framework`. Hand-written release scripts should wrap `xcodebuild`, `notarytool`, `stapler`, `hdiutil`, `spctl`, checksum generation, and Sparkle appcast tooling; they should not reimplement Xcode's nested framework embedding.

## Signing And Hardened Runtime

Public builds must be signed with a Developer ID Application certificate. The signing process must:

- enable hardened runtime
- include secure timestamping
- sign nested code before the outer app; `--deep` may verify but must not be used to mask incorrect nested signing ownership
- verify the resulting app with `codesign --verify --deep --strict --verbose=2`
- reject ad hoc, Apple Development, Mac App Store distribution, or self-signed identities for public release artifacts
- use `xcrun notarytool` for notarization; do not add legacy `altool` flows
- staple the accepted ticket to the final DMG and validate the staple before publishing
- verify Gatekeeper acceptance for both the app and the DMG

Release scripts must never require signing secrets to be committed. Developer ID certificate private keys live in the developer's login Keychain or CI secret store if CI signing is added later. Notarization credentials live in Keychain profiles or CI secrets, not the repo.

Credential handling rules:

- scripts may read `DEVELOPER_ID_TEAM_ID` and `NOTARY_KEYCHAIN_PROFILE`
- scripts must not echo notary credentials, certificate private material, Sparkle private keys, provider tokens, or local provider state
- CI signing is out of scope until a separate CI secret model and maintainer approval exist
- the release checklist is the authority for who can run a public signing flow

## Entitlements

Add an entitlements file only for behavior the app actually needs.

Required initial posture:

- no broad entitlement just because it is available
- no App Sandbox entitlement in Public V1 until connector tests prove it works
- no `com.apple.security.get-task-allow` in release builds
- no network server entitlement unless a future connector requires inbound connections
- no file-system entitlement beyond what is proven necessary for the release target

Likely release needs:

- outbound network access if App Sandbox is later enabled
- file access only inside the app container/Application Support unless a future sandboxed connector design explicitly needs user-selected paths or helper tools

The entitlements file should be reviewed as a product trust artifact. It explains what the app is allowed to do at the OS level.

## App Sandbox Decision

Public V1 should be Developer ID signed and notarized. App Sandbox should not be enabled by default until a focused compatibility matrix proves these operations still work:

- app launch from Finder
- menu bar extra display
- settings persistence in Application Support
- sanitized snapshot cache persistence
- Claude Code connector after explicit opt-in
- `/usr/bin/security find-generic-password` boundary
- Claude usage network request
- Codex executable discovery
- Codex app-server process launch over stdio
- Codex rate-limit read
- Sparkle framework load
- Sparkle update check against a test feed
- launch-at-login registration through `SMAppService`

If sandboxing breaks the connector model, Public V1 should ship unsandboxed with hardened runtime and notarization, and the release docs should explain the reason: the app is a local developer utility that must interoperate with local developer tools after explicit opt-in. The privacy promise remains enforced by code boundaries, tests, open source review, and signed/notarized official builds.

## Sparkle Design

Sparkle is the chosen updater framework. Stage 5 should make the app Sparkle-capable while avoiding background update behavior as a Public V1 launch risk.

Sparkle integration has two separate decisions:

- packaging Sparkle safely in the Xcode app target
- exposing an update-checking user experience

The app target may link and embed Sparkle before Public V1 if signing and notarization still pass. User-visible update checks must remain hidden until the app has a stable feed URL, public EdDSA key, signed update archive, and passing old-build to new-build smoke test.

Required Sparkle setup:

- choose Sparkle 2.x
- add Sparkle to the Xcode app target through Swift Package Manager
- embed `Sparkle.framework` with Xcode's Embed & Sign behavior
- verify Sparkle framework and helper tools are signed inside the archived app
- add `SUPublicEDKey` to `Info.plist` once the EdDSA key is generated
- add `SUFeedURL` only after the public appcast URL is chosen
- set `SUEnableAutomaticChecks` to `false` for Public V1 builds
- set `SUAutomaticallyUpdate` to `false` for Public V1 builds
- keep the Sparkle private EdDSA key outside the repo
- document key backup and custody

Public V1 behavior:

- manual update instructions are always present
- no silent updates
- no automatic background checks
- no first-launch updater prompt
- no user-visible `Check for Updates` UI unless a signed old-build to signed new-build update smoke passes
- no Sparkle network request unless the user explicitly invokes an approved manual update check

Post-Public V1 behavior:

- enable manual `Check for Updates` first if it did not ship in Public V1
- enable opt-in automatic checks only after at least one public manual update path succeeds
- enable automatic download/install only after separate user-experience and trust review

Appcast rules:

- hosted over HTTPS
- public URL controlled by the project
- generated by Sparkle tooling where possible
- includes release notes that do not expose sensitive diagnostics or internal workspace names
- update archives are EdDSA signed
- appcast changes are part of the release checklist
- appcast is published only after the referenced artifact and checksum are already available
- appcast rollback means publishing a corrected feed entry, not reusing a lower build number

## DMG Design

Public V1 should distribute a DMG rather than only a zip archive.

DMG requirements:

- contains a Developer ID signed app
- notarized and stapled
- includes `WhatTheToken.app`
- includes `/Applications` symlink
- uses a simple, non-marketing layout
- does not include logs, diagnostics, internal docs, or local build artifacts
- filename includes version: `WhatTheToken-<version>.dmg`

The release script should build the DMG deterministically enough that checksums are meaningful. If visual DMG layout tooling adds unnecessary fragility, use a plain DMG first.

## Launch At Login

Launch at login belongs in Stage 5 because it affects install/update UX.

Design:

- add a settings toggle: `Launch at Login`
- use `SMAppService.mainApp` because the app targets macOS 14
- persist the user's preference in `AppSettings`
- registering/unregistering should update the OS service and then persist state only if the OS call succeeds
- failure should show sanitized settings error copy, not raw OS errors
- launch-at-login must not connect providers or refresh before existing consent rules allow it

This is user-controlled. It must be off by default.

## Release Scripts

Stage 5 should introduce scripts that can be run locally by the maintainer:

- build app bundle
- archive the Xcode app target
- export the archive with Developer ID export options
- sign app
- verify app signature
- create DMG
- notarize DMG with `xcrun notarytool`
- staple notarization ticket
- verify Gatekeeper acceptance with `spctl`
- generate checksums
- optionally generate/update Sparkle appcast
- run release checklist

The scripts should fail fast when required environment variables, signing identities, Keychain profiles, version values, or artifact paths are missing. They should print actionable sanitized errors and must not print notary credentials, private keys, or local credential material.

Required script posture:

- support dry-runs for command review without credentials
- require explicit version and build values for archives
- never create public artifacts from uncommitted source
- write artifacts under ignored build output directories
- make final artifact paths clear enough for the release checklist
- leave real signing, notarization, and appcast signing credential-gated

CI should continue running synthetic tests. Public signing and notarization may remain local/manual until secret handling is designed explicitly for CI.

## Documentation

Update public docs before the repository visibility flip:

- README install section
- README update section
- README official download link placeholder or final GitHub Releases link
- SECURITY official-build trust boundary
- release checklist
- maintainer-only signing/notarization notes
- Sparkle key custody notes
- manual update instructions
- no-telemetry statement remains accurate

Documentation must distinguish:

- source builds
- unsigned local development builds
- signed/notarized official builds
- future Sparkle-updated builds

## Verification

Automated verification:

- `swift test` from `apps/mac`
- `pnpm --filter @whatthetoken/core test`
- `plutil -lint` for release plists and Xcode project syntax where applicable
- scheme XML validation for shared Xcode schemes
- Xcode project configuration tests verify release metadata, entitlements, and Sparkle settings
- Xcode Debug build with signing disabled on a machine whose Xcode first-launch packages are installed
- development app bundle script is clearly labeled as non-release if it remains
- release script dry-run validates required inputs
- entitlements test verifies release builds do not contain `get-task-allow`
- bundle metadata test verifies version/build values are present and valid
- launch-at-login view-model or service wrapper tests use stubs

Manual verification:

- build release app from clean checkout
- confirm the release commit is clean and tagged
- sign with Developer ID Application
- verify signature
- create DMG
- notarize DMG
- staple DMG
- verify app and DMG with `spctl`
- install by dragging from DMG to `/Applications`
- launch from Finder on a Gatekeeper-enabled Mac
- confirm no Dock icon in production
- confirm Settings and Quit are reachable
- confirm app does not refresh providers before consent
- connect Claude Code manually and verify sanitized status
- connect Codex manually and verify sanitized status
- relaunch and verify persisted settings/cache behavior
- verify launch-at-login off by default
- toggle launch-at-login and verify expected login item behavior
- if Sparkle UI ships, test update from an older signed/notarized build to a newer signed/notarized build using a test appcast
- inspect final DMG contents for logs, diagnostics, local paths, or untracked files

## Acceptance Criteria

Stage 5A repo foundation is complete when:

- release target, metadata, entitlements, scripts, launch-at-login setting, Sparkle-ready wiring, tests, and release checklist are committed
- TypeScript and Swift test suites pass
- release script dry-runs pass
- Xcode project and scheme files parse cleanly
- outstanding credentialed release tasks are documented explicitly

Public V1 distribution is complete when:

- a non-developer user can install the official DMG without Gatekeeper friction
- `WhatTheToken.app` is Developer ID signed
- hardened runtime is enabled
- the distributed artifact is notarized and stapled
- `spctl` accepts both the app and DMG according to the release checklist
- release scripts and docs are repeatable by the maintainer
- signing/notarization/Sparkle private material is not in the repo
- Public V1 docs explain official builds, manual updates, and the future Sparkle update path
- Sparkle is either exposed in manual-check-only mode with passing update smoke tests, or explicitly hidden with keys/appcast decisions documented and no background update behavior enabled
- launch at login is implemented as an explicit opt-in setting
- repository visibility can flip public without exposing internal workspace names or release secrets

## Risks And Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Sparkle framework or helper tools are copied incorrectly | release fails to launch or notarize | use Xcode archive/export and Embed & Sign; verify nested code signing |
| Sparkle private EdDSA key is lost | future updates cannot be signed normally | store key in Keychain plus documented secure backup outside repo |
| Sparkle private key leaks | attacker may sign malicious update archives if appcast/download hosting is compromised | keep private key off hosting machines and out of CI until secret model exists |
| App Sandbox breaks connectors | Claude/Codex stop working in public builds | test sandbox matrix before enabling; document unsandboxed direct-distribution rationale if needed |
| Notarization fails late | public launch blocked | add local verification and notary dry-run checklist before release day |
| Xcode installation is not initialized | archive/export cannot start | run Xcode first-launch setup before release rehearsal; do not treat dry-run success as archive proof |
| Missing public app icon | public build looks unfinished or fails app review expectations | add asset catalog before release rehearsal and include icon smoke in the checklist |
| Update feed URL changes after public launch | installed apps cannot find updates | choose stable appcast URL before embedding `SUFeedURL` |
| Appcast says update exists before artifact is ready | users see broken update flow | release checklist publishes artifacts before appcast update |
| Build number is reused | Sparkle or user support cannot distinguish binaries | require monotonic `CFBundleVersion`; cut a new build after every failed public candidate |
| Launch-at-login starts refresh before consent | privacy regression | reuse existing consent gates; test launch path with disconnected settings |

## Self-Review

- No default telemetry is introduced.
- Public V1 remains free.
- Mac App Store work is explicitly out of scope.
- Sparkle is included in the architecture without requiring automatic background update checks at first launch.
- User-visible Sparkle checks are separated from Sparkle packaging.
- The App Sandbox decision is evidence-based, not assumed.
- Stage 5A repo readiness is separated from credentialed Public V1 distribution readiness.
- Signing secrets, notary credentials, and Sparkle private keys stay outside the repo.
- The spec has no placeholder requirements.
