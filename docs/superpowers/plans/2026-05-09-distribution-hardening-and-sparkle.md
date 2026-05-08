# Distribution Hardening And Sparkle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the repo-side Public V1 distribution foundation: Xcode-owned release archives, Sparkle-ready metadata, release scripts, launch-at-login settings, and maintainer documentation.

**Architecture:** SwiftPM remains the unit-test and local development path. A thin Xcode app target owns public app archives, asset catalog compilation, entitlements, Sparkle embedding, and Developer ID export. Release scripts wrap Xcode, `hdiutil`, `codesign`, `notarytool`, `stapler`, `spctl`, checksum generation, and Sparkle appcast tooling without storing secrets in the repo.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, Xcode 26, SwiftPM, Sparkle 2.x, `SMAppService`, bash release scripts, Apple Developer ID notarization tooling.

---

## File Structure

- Modify: `docs/superpowers/specs/2026-05-09-distribution-hardening-design.md` - lock Xcode as the Public V1 release owner.
- Create: `docs/release/public-v1-checklist.md` - maintainer release checklist.
- Create: `apps/mac/Packaging/WhatTheToken.entitlements` - minimal release entitlements.
- Modify: `apps/mac/Packaging/Info.plist` - version interpolation, Sparkle-ready keys, app category, icon metadata.
- Create: `apps/mac/Packaging/ExportOptions.DeveloperID.plist` - Developer ID export options.
- Create: `apps/mac/Packaging/WhatTheToken.xcconfig` - shared app build settings.
- Create: `apps/mac/Packaging/WhatTheToken-Debug.xcconfig` - debug build settings.
- Create: `apps/mac/Packaging/WhatTheToken-Release.xcconfig` - release build settings.
- Create: `apps/mac/WhatTheToken.xcodeproj/project.pbxproj` - Xcode app target using existing source files.
- Modify: `apps/mac/Package.swift` - add Sparkle dependency only if SwiftPM build needs Sparkle compilation.
- Create: `apps/mac/Sources/WhatTheTokenMac/Updates/SparkleUpdateController.swift` - Sparkle bridge, manual-check-first.
- Create: `apps/mac/Sources/WhatTheTokenMac/Settings/LaunchAtLoginService.swift` - `SMAppService.mainApp` wrapper.
- Modify: `apps/mac/Sources/WhatTheTokenMac/Storage/AppSettings.swift` - persist launch-at-login preference.
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift` - save launch-at-login preference through a testable service.
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/Settings/ConnectorsView.swift` - add Launch at Login toggle.
- Create: `apps/mac/Tests/WhatTheTokenMacTests/LaunchAtLoginServiceTests.swift` - launch-at-login behavior tests.
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/Storage/AppSettingsTests.swift` - setting persistence tests.
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/MacBundleInfoTests.swift` - release metadata and script tests.
- Create: `apps/mac/Scripts/archive-release.sh` - Xcode archive/export wrapper.
- Create: `apps/mac/Scripts/create-dmg.sh` - plain DMG creation.
- Create: `apps/mac/Scripts/notarize-dmg.sh` - `notarytool` and `stapler` wrapper.
- Create: `apps/mac/Scripts/verify-release-artifacts.sh` - signature, Gatekeeper, and checksum checks.
- Create: `apps/mac/Scripts/generate-appcast.sh` - Sparkle appcast helper.
- Modify: `README.md` - install/update section.
- Modify: `SECURITY.md` - official build trust boundary.

## Task 1: Lock The Spec To Xcode Release Builds

**Files:**
- Modify: `docs/superpowers/specs/2026-05-09-distribution-hardening-design.md`

- [ ] **Step 1: Replace build-system ambiguity**

Edit the spec so `Bundle And Metadata` says Public V1 release builds use a thin Xcode app target and `xcodebuild archive` / `xcodebuild -exportArchive`.

- [ ] **Step 2: Re-scan the spec**

Run:

```bash
rg -n "implementation plan should decide|preserve framework symlinks|package-app.sh.*release" docs/superpowers/specs/2026-05-09-distribution-hardening-design.md
```

Expected: no matches for deferred release-owner decisions.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-05-09-distribution-hardening-design.md
git commit -m "docs: lock distribution design to Xcode release builds"
```

## Task 2: Add Release Metadata, Entitlements, And Config Tests

**Files:**
- Create: `apps/mac/Packaging/WhatTheToken.entitlements`
- Create: `apps/mac/Packaging/ExportOptions.DeveloperID.plist`
- Create: `apps/mac/Packaging/WhatTheToken.xcconfig`
- Create: `apps/mac/Packaging/WhatTheToken-Debug.xcconfig`
- Create: `apps/mac/Packaging/WhatTheToken-Release.xcconfig`
- Modify: `apps/mac/Packaging/Info.plist`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/MacBundleInfoTests.swift`

- [ ] **Step 1: Write failing metadata tests**

Add tests that verify:

- `Info.plist` has `CFBundleShortVersionString = $(MARKETING_VERSION)`
- `Info.plist` has `CFBundleVersion = $(CURRENT_PROJECT_VERSION)`
- release entitlements do not contain `com.apple.security.get-task-allow`
- Developer ID export options use `method = developer-id`
- release xcconfig enables hardened runtime and points to the entitlements file
- debug xcconfig keeps signing local-development-friendly

- [ ] **Step 2: Run failing tests**

Run:

```bash
swift test --filter MacBundleInfoTests
```

Expected: FAIL because the new files and interpolated keys do not exist yet.

- [ ] **Step 3: Add metadata files**

Create the entitlements, export options, and xcconfig files. Update `Info.plist` version/build values to Xcode build-setting interpolation.

- [ ] **Step 4: Run metadata tests**

Run:

```bash
swift test --filter MacBundleInfoTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/mac/Packaging apps/mac/Tests/WhatTheTokenMacTests/MacBundleInfoTests.swift
git commit -m "build(mac): add release metadata and entitlements"
```

## Task 3: Add Launch At Login Setting

**Files:**
- Create: `apps/mac/Sources/WhatTheTokenMac/Settings/LaunchAtLoginService.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/Storage/AppSettings.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/ViewModels/StatusViewModel.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/Settings/ConnectorsView.swift`
- Create: `apps/mac/Tests/WhatTheTokenMacTests/LaunchAtLoginServiceTests.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/Storage/AppSettingsTests.swift`

- [ ] **Step 1: Write failing settings tests**

Add tests for default `launchAtLogin.isEnabled == false`, JSON round-trip, and save behavior through a fake service.

- [ ] **Step 2: Run failing tests**

Run:

```bash
swift test --filter AppSettingsTests
swift test --filter LaunchAtLoginServiceTests
```

Expected: FAIL because launch-at-login settings and service do not exist.

- [ ] **Step 3: Implement setting and service**

Add `LaunchAtLoginSettings`, a `LaunchAtLoginServicing` protocol, `SystemLaunchAtLoginService` using `SMAppService.mainApp`, and a `StatusViewModel.setLaunchAtLoginEnabled(_:)` method that updates the OS service first and persists only after success.

- [ ] **Step 4: Add Settings toggle**

Add a `Launch` section to settings with a `Launch at Login` toggle bound through `StatusViewModel.setLaunchAtLoginEnabled(_:)`.

- [ ] **Step 5: Run focused tests**

Run:

```bash
swift test --filter AppSettingsTests
swift test --filter LaunchAtLoginServiceTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/mac/Sources/WhatTheTokenMac apps/mac/Tests/WhatTheTokenMacTests
git commit -m "feat(mac): add launch at login setting"
```

## Task 4: Add Xcode Release Project And Sparkle-Ready App Target

**Files:**
- Create: `apps/mac/WhatTheToken.xcodeproj/project.pbxproj`
- Create: `apps/mac/Sources/WhatTheTokenMac/Updates/SparkleUpdateController.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/MacBundleInfoTests.swift`

- [ ] **Step 1: Write failing project tests**

Add tests that read `WhatTheToken.xcodeproj/project.pbxproj` and verify:

- target name `WhatTheToken`
- source file references include `WhatTheTokenApp.swift`
- package reference URL is `https://github.com/sparkle-project/Sparkle`
- product dependency includes `Sparkle`
- build settings reference `Packaging/WhatTheToken-Release.xcconfig`
- build settings reference `Packaging/WhatTheToken-Debug.xcconfig`

- [ ] **Step 2: Run failing tests**

Run:

```bash
swift test --filter MacBundleInfoTests
```

Expected: FAIL because the Xcode project does not exist.

- [ ] **Step 3: Add Xcode project**

Create a minimal Xcode app target that compiles the existing `apps/mac/Sources/WhatTheTokenMac` Swift files, processes `Resources/usage-snapshot.fixture.json`, processes the future asset catalog, uses `Packaging/Info.plist`, uses the xcconfig files, and links Sparkle through Swift Package Manager.

- [ ] **Step 4: Add Sparkle bridge**

Add a small update controller that can be wired to UI later and keeps automatic checks disabled by Info.plist for Public V1.

- [ ] **Step 5: Verify package resolution and build**

Run:

```bash
xcodebuild -project apps/mac/WhatTheToken.xcodeproj -scheme WhatTheToken -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/mac/WhatTheToken.xcodeproj apps/mac/Sources/WhatTheTokenMac/Updates apps/mac/Tests/WhatTheTokenMacTests/MacBundleInfoTests.swift
git commit -m "build(mac): add Xcode release app target"
```

## Task 5: Add Release Scripts

**Files:**
- Create: `apps/mac/Scripts/archive-release.sh`
- Create: `apps/mac/Scripts/create-dmg.sh`
- Create: `apps/mac/Scripts/notarize-dmg.sh`
- Create: `apps/mac/Scripts/verify-release-artifacts.sh`
- Create: `apps/mac/Scripts/generate-appcast.sh`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/MacBundleInfoTests.swift`

- [ ] **Step 1: Write failing script tests**

Add tests that verify each script exists, uses `set -euo pipefail`, does not print secret variables, and contains the required tool invocations.

- [ ] **Step 2: Run failing tests**

Run:

```bash
swift test --filter MacBundleInfoTests
```

Expected: FAIL because release scripts do not exist.

- [ ] **Step 3: Add scripts**

Implement scripts with `--dry-run` where practical. Scripts must fail fast when required inputs are missing and must not echo notary credentials, private keys, or provider credentials.

- [ ] **Step 4: Run dry-run checks**

Run:

```bash
apps/mac/Scripts/archive-release.sh --dry-run --version 0.1.0 --build 1
apps/mac/Scripts/create-dmg.sh --dry-run --version 0.1.0
apps/mac/Scripts/notarize-dmg.sh --dry-run --dmg /tmp/WhatTheToken-0.1.0.dmg
apps/mac/Scripts/verify-release-artifacts.sh --dry-run --dmg /tmp/WhatTheToken-0.1.0.dmg
apps/mac/Scripts/generate-appcast.sh --dry-run --updates-dir /tmp/whatthetoken-updates
```

Expected: all dry-runs exit 0 and print sanitized planned actions.

- [ ] **Step 5: Commit**

```bash
git add apps/mac/Scripts apps/mac/Tests/WhatTheTokenMacTests/MacBundleInfoTests.swift
git commit -m "build(mac): add release automation scripts"
```

## Task 6: Add Public Release Documentation

**Files:**
- Create: `docs/release/public-v1-checklist.md`
- Modify: `README.md`
- Modify: `SECURITY.md`

- [ ] **Step 1: Add release checklist**

Document the exact maintainer flow for clean checkout, tests, archive, export, DMG, notarization, stapling, verification, checksums, GitHub Release upload, optional appcast generation, and fresh-machine smoke.

- [ ] **Step 2: Update public docs**

Add README install/update sections and SECURITY official-build trust boundary.

- [ ] **Step 3: Scan for forbidden release wording**

Run:

```bash
rg -n "token|cookie|auth header|session|prompt|response|private key|notary password" docs/release README.md SECURITY.md
```

Expected: matches are warnings or key-custody rules only.

- [ ] **Step 4: Commit**

```bash
git add docs/release README.md SECURITY.md
git commit -m "docs: add Public V1 release checklist"
```

## Task 7: Final Verification

**Files:**
- All changed files.

- [ ] **Step 1: Install JS dependencies if missing**

Run:

```bash
pnpm install --frozen-lockfile
```

Expected: dependencies install without lockfile changes.

- [ ] **Step 2: Run full tests**

Run:

```bash
pnpm --filter @whatthetoken/core test
cd apps/mac && swift test
```

Expected: both pass.

- [ ] **Step 3: Run Xcode debug build**

Run:

```bash
xcodebuild -project apps/mac/WhatTheToken.xcodeproj -scheme WhatTheToken -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Expected: build succeeds.

- [ ] **Step 4: Run release-script dry-runs**

Run the dry-run commands from Task 5 Step 4.

Expected: all pass.

- [ ] **Step 5: Document credential-gated verification**

Record that Developer ID signing, notarization submission, stapling of a real DMG, and Sparkle EdDSA signing require maintainer credentials and cannot be completed in an unauthenticated coding workspace.
