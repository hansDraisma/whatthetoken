# Public V1 Release Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the remaining Stage 5 release-readiness gaps so WhatTheToken can produce a public Mac DMG through a documented, testable, credential-gated release flow.

**Architecture:** Keep SwiftPM as the fast development and unit-test path. Use the Xcode app target as the only public release owner because it can compile the asset catalog, embed Sparkle, archive, export, and sign nested code correctly. Split repo-executable work from maintainer-gated release rehearsal so local agents can complete asset, docs, tests, and script improvements without pretending to possess Developer ID, notarization, or Sparkle private key material.

**Tech Stack:** Swift 6, Swift Testing, Xcode app target, macOS 14, Sparkle 2, Developer ID signing, hardened runtime, `xcodebuild`, `hdiutil`, `xcrun notarytool`, `xcrun stapler`, `spctl`, `shasum`, GitHub Releases.

---

## Source Inputs

- Distribution spec: `docs/superpowers/specs/2026-05-09-distribution-hardening-design.md`
- Current release checklist: `docs/release/public-v1-checklist.md`
- Current Xcode target: `apps/mac/WhatTheToken.xcodeproj/project.pbxproj`
- Current packaging metadata: `apps/mac/Packaging/Info.plist`, `apps/mac/Packaging/WhatTheToken.xcconfig`, `apps/mac/Packaging/WhatTheToken-Release.xcconfig`, `apps/mac/Packaging/WhatTheToken.entitlements`
- Current release scripts: `apps/mac/Scripts/archive-release.sh`, `apps/mac/Scripts/create-dmg.sh`, `apps/mac/Scripts/notarize-dmg.sh`, `apps/mac/Scripts/verify-release-artifacts.sh`, `apps/mac/Scripts/generate-appcast.sh`, `apps/mac/Scripts/package-app.sh`
- Current monolithic release guard tests: `apps/mac/Tests/WhatTheTokenMacTests/MacBundleInfoTests.swift`
- Apple Developer ID reference: `https://developer.apple.com/developer-id/`
- Apple notarization reference: `https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution`
- Apple packaging reference: `https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution`
- Apple disk image signing reference: `https://developer.apple.com/library/archive/technotes/tn2206/_index.html`
- Sparkle official setup reference: `https://sparkle-project.org/documentation/`
- Sparkle official customization reference: `https://sparkle-project.org/documentation/customization/`

## Recommendation And Tradeoffs

Recommended Public V1 posture:

- Ship a signed, notarized, stapled DMG through GitHub Releases.
- Keep App Sandbox disabled for Public V1 unless the compatibility matrix passes.
- Keep Sparkle packaged but inert for Public V1: no automatic checks, no silent installs, no visible `Check for Updates` UI, and no background network behavior.
- Do not publish an appcast until Sparkle EdDSA custody, stable HTTPS hosting, and signed old-build to new-build update smoke are complete.
- Treat the existing `package-app.sh` path as development-only and make that explicit in docs/tests.

Tradeoffs:

- This delays in-app updates, but avoids adding first-launch network behavior and updater prompts before the first trusted public install path is proven.
- Shipping without App Sandbox reduces platform isolation, but preserves local developer-tool interoperability. Hardened runtime, notarization, explicit connector consent, and public source review carry the Public V1 trust story.
- Requiring a real Xcode archive/export rehearsal before launch costs maintainer time, but it is the only reliable proof that Sparkle helpers, nested code signing, asset catalogs, hardened runtime, and notarization work together.
- Keeping Sparkle private key generation outside the repo prevents automation of one step, but that is the correct security boundary. The repo should document the exact command and custody record; it should not hold private update-signing material.

## Execution Gates

Agent-executable in this workspace:

- Add and wire the public app icon asset catalog.
- Split release guard tests into focused files.
- Add an unsigned Xcode archive smoke script, signed-DMG step, mount/layout verification, and a release rehearsal wrapper.
- Add sandbox compatibility, Sparkle key custody, rollback, and release docs.
- Update tests so accidental Sparkle/network/appcast behavior cannot slip in.
- Run Swift, TypeScript, plist, scheme, script dry-run, and documentation checks.

Maintainer-gated on the signing machine:

- Run Xcode first-launch setup if `xcodebuild` cannot load required plugins.
- Select and install Developer ID Application certificate access.
- Configure `NOTARY_KEYCHAIN_PROFILE`.
- Generate and custody Sparkle EdDSA private key material in Keychain and a secure backup outside the repo.
- Run real `xcodebuild archive` and `xcodebuild -exportArchive`.
- Notarize, staple, verify Gatekeeper, install from the DMG on a fresh macOS account, and publish GitHub Release artifacts.

## File Structure

- Create: `apps/mac/Tests/WhatTheTokenMacTests/PackagingTestSupport.swift` - shared test helpers for release metadata, project, scripts, and docs.
- Create: `apps/mac/Tests/WhatTheTokenMacTests/MacBundleMetadataTests.swift` - Info.plist, entitlements, versioning, and Sparkle default posture tests.
- Create: `apps/mac/Tests/WhatTheTokenMacTests/MacXcodeProjectTests.swift` - Xcode target, Sparkle package, app icon asset catalog, and project-resource tests.
- Create: `apps/mac/Tests/WhatTheTokenMacTests/MacReleaseScriptTests.swift` - release script shape and secret-safety tests.
- Delete: `apps/mac/Tests/WhatTheTokenMacTests/MacBundleInfoTests.swift` after equivalent coverage has moved into focused files.
- Create: `apps/mac/Sources/WhatTheTokenMac/Assets.xcassets/AppIcon.appiconset/Contents.json` - public macOS app icon catalog.
- Create: `apps/mac/Brand/AppIconSource.prompt.md` - reproducible icon-generation brief.
- Create: `apps/mac/Brand/AppIconSource.png` - 1024x1024 source icon approved for Public V1.
- Create: generated icon PNGs under `apps/mac/Sources/WhatTheTokenMac/Assets.xcassets/AppIcon.appiconset/`.
- Modify: `apps/mac/WhatTheToken.xcodeproj/project.pbxproj` - add the asset catalog file reference and resource build phase entry.
- Modify: `apps/mac/Packaging/Info.plist` - bind the compiled asset catalog icon with `CFBundleIconName = AppIcon`.
- Create: `apps/mac/Scripts/smoke-archive-unsigned.sh` - local Xcode archive proof that does not require signing credentials.
- Create: `apps/mac/Scripts/sign-dmg.sh` - Developer ID sign and verify the final DMG before notarization.
- Create: `apps/mac/Scripts/rehearse-release.sh` - wrapper for dry-run, unsigned-smoke, and signed release rehearsal flows.
- Modify: `apps/mac/Scripts/verify-release-artifacts.sh` - verify, mount, inspect, checksum, and detach the DMG.
- Modify: `apps/mac/Scripts/package-app.sh` - label it as development-only in output/help comments.
- Create: `docs/release/app-sandbox-compatibility-matrix.md` - explicit sandbox test matrix and Public V1 unsandboxed decision rule.
- Create: `docs/release/sparkle-key-custody.md` - Sparkle EdDSA generation, public-key embedding gate, appcast gate, and private-key custody record.
- Create: `docs/release/rollback-and-hotfix.md` - build number, appcast, DMG, and GitHub Release rollback rules.
- Modify: `docs/release/public-v1-checklist.md` - include app icon, sandbox, Sparkle, release rehearsal, rollback, and fresh-machine gates.
- Modify: `README.md` - keep install/update language aligned with manual Public V1 updates and future Sparkle.
- Modify: `docs/roadmap/development-roadmap.md` - mark Stage 5A repo work versus Stage 5B/5C credentialed work.

---

### Task 1: Establish Local Gate Baseline

**Files:**
- Read: `apps/mac/WhatTheToken.xcodeproj/project.pbxproj`
- Read: `apps/mac/Tests/WhatTheTokenMacTests/MacBundleInfoTests.swift`
- Read: `docs/release/public-v1-checklist.md`

- [ ] **Step 1: Confirm worktree state**

Run:

```bash
git status --short
git branch --show-current
git diff origin/main... --stat
```

Expected:

- Current branch is not renamed.
- No unexpected uncommitted changes block the plan.
- Existing Stage 5 commits appear in the diff against `origin/main`.

- [ ] **Step 2: Confirm Xcode command availability**

Run:

```bash
xcode-select -p
xcodebuild -version
xcrun notarytool --version
xcrun stapler version
```

Expected:

- `xcode-select -p` prints an Xcode developer directory.
- `xcodebuild -version` prints the installed Xcode version or fails with the known first-launch/plugin error.
- `notarytool` and `stapler` print versions/help text.

If `xcodebuild -version` or a later `xcodebuild` command fails with `IDESimulatorFoundation` plugin loading or first-launch package errors, stop Xcode execution and record this maintainer gate:

```bash
sudo xcodebuild -runFirstLaunch
```

Expected after maintainer action:

- The same `xcodebuild -version` command succeeds.

- [ ] **Step 3: Confirm official docs used for Sparkle details**

Run:

```bash
open https://sparkle-project.org/documentation/
open https://sparkle-project.org/documentation/customization/
```

Expected:

- Sparkle docs confirm `generate_keys`, `SUPublicEDKey`, `SUFeedURL`, `generate_appcast`, and Xcode Archive/Developer ID distribution guidance.

- [ ] **Step 4: Commit checkpoint**

No commit is required for this task unless a gate note is written to `.context`.

---

### Task 2: Split Release Guard Tests

**Files:**
- Create: `apps/mac/Tests/WhatTheTokenMacTests/PackagingTestSupport.swift`
- Create: `apps/mac/Tests/WhatTheTokenMacTests/MacBundleMetadataTests.swift`
- Create: `apps/mac/Tests/WhatTheTokenMacTests/MacXcodeProjectTests.swift`
- Create: `apps/mac/Tests/WhatTheTokenMacTests/MacReleaseScriptTests.swift`
- Delete: `apps/mac/Tests/WhatTheTokenMacTests/MacBundleInfoTests.swift`

- [ ] **Step 1: Add shared packaging test support**

Create `apps/mac/Tests/WhatTheTokenMacTests/PackagingTestSupport.swift`:

```swift
import Foundation
import Testing

func macPackageRootURL(filePath: String = #filePath) -> URL {
    URL(fileURLWithPath: filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

func macRepositoryRootURL(filePath: String = #filePath) -> URL {
    macPackageRootURL(filePath: filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

func macFileContents(_ relativePath: String, filePath: String = #filePath) throws -> String {
    let url = macPackageRootURL(filePath: filePath).appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}

func repositoryFileContents(_ relativePath: String, filePath: String = #filePath) throws -> String {
    let url = macRepositoryRootURL(filePath: filePath).appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}

func packagingInfoPlist(filePath: String = #filePath) throws -> [String: Any] {
    let url = macPackageRootURL(filePath: filePath).appendingPathComponent("Packaging/Info.plist")
    let data = try Data(contentsOf: url)
    return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
}

func packagingPlist(_ relativePath: String, filePath: String = #filePath) throws -> [String: Any] {
    let url = macPackageRootURL(filePath: filePath).appendingPathComponent(relativePath)
    let data = try Data(contentsOf: url)
    return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
}

func decodedJSONFile<T: Decodable>(_ relativePath: String, as type: T.Type, filePath: String = #filePath) throws -> T {
    let url = macPackageRootURL(filePath: filePath).appendingPathComponent(relativePath)
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(T.self, from: data)
}
```

- [ ] **Step 2: Move metadata tests**

Create `apps/mac/Tests/WhatTheTokenMacTests/MacBundleMetadataTests.swift`:

```swift
import Foundation
import Testing

@Test func packagingInfoPlistDeclaresAgentOnlyApp() throws {
    let plist = try packagingInfoPlist()

    #expect(plist["LSUIElement"] as? Bool == true)
    #expect(plist["CFBundleExecutable"] as? String == "WhatTheTokenMac")
    #expect(plist["CFBundlePackageType"] as? String == "APPL")
    #expect(plist["CFBundleIdentifier"] as? String == "com.whatthetoken.mac")
    #expect(plist["LSMinimumSystemVersion"] as? String == "14.0")
}

@Test func packagingInfoPlistUsesReleaseBuildSettingVersions() throws {
    let plist = try packagingInfoPlist()

    #expect(plist["CFBundleShortVersionString"] as? String == "$(MARKETING_VERSION)")
    #expect(plist["CFBundleVersion"] as? String == "$(CURRENT_PROJECT_VERSION)")
    #expect(plist["LSApplicationCategoryType"] as? String == "public.app-category.developer-tools")
}

@Test func sparkleDefaultsRemainManualAndSilentForPublicV1() throws {
    let plist = try packagingInfoPlist()

    #expect(plist["SUEnableAutomaticChecks"] as? Bool == false)
    #expect(plist["SUAutomaticallyUpdate"] as? Bool == false)
    #expect(plist["SUEnableSystemProfiling"] == nil)

    if plist["SUFeedURL"] != nil {
        let publicKey = plist["SUPublicEDKey"] as? String
        #expect(publicKey?.isEmpty == false)
    }
}

@Test func releaseEntitlementsStayMinimal() throws {
    let plist = try packagingPlist("Packaging/WhatTheToken.entitlements")

    #expect(plist["com.apple.security.get-task-allow"] == nil)
    #expect(plist["com.apple.security.app-sandbox"] == nil)
}

@Test func developerIDExportOptionsUseDeveloperIDMethod() throws {
    let plist = try packagingPlist("Packaging/ExportOptions.DeveloperID.plist")

    #expect(plist["method"] as? String == "developer-id")
    #expect(plist["signingStyle"] as? String == "manual")
    #expect(plist["manageAppVersionAndBuildNumber"] as? Bool == false)
}

@Test func releaseXcconfigEnablesHardenedRuntimeAndEntitlements() throws {
    let releaseConfig = try macFileContents("Packaging/WhatTheToken-Release.xcconfig")
    let sharedConfig = try macFileContents("Packaging/WhatTheToken.xcconfig")
    let debugConfig = try macFileContents("Packaging/WhatTheToken-Debug.xcconfig")

    #expect(releaseConfig.contains("ENABLE_HARDENED_RUNTIME = YES"))
    #expect(sharedConfig.contains("CODE_SIGN_ENTITLEMENTS = Packaging/WhatTheToken.entitlements"))
    #expect(releaseConfig.contains("CODE_SIGN_IDENTITY = Developer ID Application"))
    #expect(debugConfig.contains("CODE_SIGNING_ALLOWED = NO"))
    #expect(debugConfig.contains("ENABLE_HARDENED_RUNTIME = NO"))
}

@Test func sharedXcconfigPinsInitialPublicVersionAndBuild() throws {
    let sharedConfig = try macFileContents("Packaging/WhatTheToken.xcconfig")

    #expect(sharedConfig.contains("\nMARKETING_VERSION = 0.1.0\n"))
    #expect(sharedConfig.contains("\nCURRENT_PROJECT_VERSION = 1\n"))
    #expect(sharedConfig.contains("\nASSETCATALOG_COMPILER_APPICON_NAME = AppIcon\n"))
}
```

- [ ] **Step 3: Move Xcode project tests**

Create `apps/mac/Tests/WhatTheTokenMacTests/MacXcodeProjectTests.swift`:

```swift
import Foundation
import Testing

private struct AppIconContents: Decodable {
    struct Image: Decodable, Hashable {
        let size: String
        let idiom: String
        let filename: String
        let scale: String
    }

    let images: [Image]
}

@Test func xcodeProjectDefinesReleaseTargetAndSparklePackage() throws {
    let project = try macFileContents("WhatTheToken.xcodeproj/project.pbxproj")

    #expect(project.contains("name = WhatTheToken;"))
    #expect(project.contains("WhatTheTokenApp.swift"))
    #expect(project.contains("XcodeBundleModule.swift"))
    #expect(project.contains("https://github.com/sparkle-project/Sparkle"))
    #expect(project.contains("productName = Sparkle;"))
    #expect(project.contains("Packaging/WhatTheToken-Release.xcconfig"))
    #expect(project.contains("Packaging/WhatTheToken-Debug.xcconfig"))
}

@Test func xcodeProjectRegistersAppIconAssetCatalogAsResource() throws {
    let project = try macFileContents("WhatTheToken.xcodeproj/project.pbxproj")

    #expect(project.contains("Sources/WhatTheTokenMac/Assets.xcassets"))
    #expect(project.contains("lastKnownFileType = folder.assetcatalog"))
    #expect(project.contains("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon"))
}

@Test func releaseInfoPlistBindsAppIconAssetCatalog() throws {
    let plist = try packagingInfoPlist()

    #expect(plist["CFBundleIconName"] as? String == "AppIcon")
}

@Test func appIconAssetCatalogContainsRequiredMacIconSlots() throws {
    let contents = try decodedJSONFile(
        "Sources/WhatTheTokenMac/Assets.xcassets/AppIcon.appiconset/Contents.json",
        as: AppIconContents.self
    )
    let slots = Set(contents.images.map { "\($0.idiom):\($0.size):\($0.scale):\($0.filename)" })

    #expect(slots.contains("mac:16x16:1x:icon_16x16.png"))
    #expect(slots.contains("mac:16x16:2x:icon_16x16@2x.png"))
    #expect(slots.contains("mac:32x32:1x:icon_32x32.png"))
    #expect(slots.contains("mac:32x32:2x:icon_32x32@2x.png"))
    #expect(slots.contains("mac:128x128:1x:icon_128x128.png"))
    #expect(slots.contains("mac:128x128:2x:icon_128x128@2x.png"))
    #expect(slots.contains("mac:256x256:1x:icon_256x256.png"))
    #expect(slots.contains("mac:256x256:2x:icon_256x256@2x.png"))
    #expect(slots.contains("mac:512x512:1x:icon_512x512.png"))
    #expect(slots.contains("mac:512x512:2x:icon_512x512@2x.png"))
}

@Test func sparkleUpdateControllerIsManualCheckOnly() throws {
    let source = try macFileContents("Sources/WhatTheTokenMac/Updates/SparkleUpdateController.swift")

    #expect(source.contains("#if canImport(Sparkle)"))
    #expect(source.contains("SPUStandardUpdaterController"))
    #expect(source.contains("startingUpdater: false"))
    #expect(source.contains("checkForUpdates"))
    #expect(source.contains("startUpdater()"))
    #expect(!source.contains("checkForUpdatesInBackground"))
}
```

- [ ] **Step 4: Move release script tests**

Create `apps/mac/Tests/WhatTheTokenMacTests/MacReleaseScriptTests.swift`:

```swift
import Foundation
import Testing

@Test func developmentPackageScriptIsClearlyNotThePublicReleasePath() throws {
    let script = try macFileContents("Scripts/package-app.sh")

    #expect(script.contains("Development-only"))
    #expect(script.contains("RESOURCE_BUNDLE=\"$TRIPLE/${PRODUCT_NAME}_${PRODUCT_NAME}.bundle\""))
    #expect(script.contains("cp -R \"$RESOURCE_BUNDLE\" \"$APP_DIR/\""))
}

@Test func releaseScriptsUseExpectedToolsAndAvoidSecretEchoes() throws {
    let scripts: [(name: String, requiredFragments: [String])] = [
        (
            "archive-release.sh",
            [
                "xcodebuild",
                "archive",
                "-exportArchive",
                "ExportOptions.DeveloperID.plist",
                "DEVELOPER_ID_TEAM_ID"
            ]
        ),
        (
            "create-dmg.sh",
            [
                "hdiutil",
                "ln -s /Applications",
                "WhatTheToken.app"
            ]
        ),
        (
            "notarize-dmg.sh",
            [
                "xcrun notarytool submit",
                "xcrun stapler staple",
                "NOTARY_KEYCHAIN_PROFILE"
            ]
        ),
        (
            "sign-dmg.sh",
            [
                "codesign --force --sign",
                "DEVELOPER_ID_SIGNING_IDENTITY",
                "hdiutil verify",
                "codesign --verify"
            ]
        ),
        (
            "verify-release-artifacts.sh",
            [
                "codesign --verify",
                "spctl",
                "shasum -a 256",
                "xcrun stapler validate",
                "hdiutil verify",
                "hdiutil attach",
                "hdiutil detach",
                "CFBundleIconName",
                "Assets.car"
            ]
        ),
        (
            "generate-appcast.sh",
            [
                "generate_appcast",
                "SPARKLE_BIN_DIR",
                "appcast.xml"
            ]
        ),
        (
            "smoke-archive-unsigned.sh",
            [
                "xcodebuild",
                "CODE_SIGNING_ALLOWED=NO",
                "Products/Applications/WhatTheToken.app"
            ]
        ),
        (
            "rehearse-release.sh",
            [
                "smoke-archive-unsigned.sh",
                "archive-release.sh",
                "sign-dmg.sh",
                "notarize-dmg.sh",
                "verify-release-artifacts.sh"
            ]
        )
    ]

    for scriptInfo in scripts {
        let script = try macFileContents("Scripts/\(scriptInfo.name)")

        #expect(script.hasPrefix("#!/usr/bin/env bash\nset -euo pipefail"))
        for fragment in scriptInfo.requiredFragments {
            #expect(script.contains(fragment))
        }
        #expect(!script.contains("echo \"$NOTARY"))
        #expect(!script.contains("echo \"${NOTARY"))
        #expect(!script.contains("echo \"$SPARKLE"))
        #expect(!script.contains("echo \"${SPARKLE"))
    }
}
```

- [ ] **Step 5: Remove the old monolithic test file**

Delete:

```bash
apps/mac/Tests/WhatTheTokenMacTests/MacBundleInfoTests.swift
```

- [ ] **Step 6: Run tests and confirm expected failures**

Run:

```bash
cd apps/mac
swift test --filter MacBundleMetadataTests
swift test --filter MacXcodeProjectTests
swift test --filter MacReleaseScriptTests
cd ../..
```

Expected before Tasks 3 and 4:

- Metadata tests pass.
- Xcode project tests fail because `Assets.xcassets` and the `CFBundleIconName` binding do not exist yet.
- Release script tests fail because `smoke-archive-unsigned.sh`, `rehearse-release.sh`, and the development-only label do not exist yet.

- [ ] **Step 7: Commit checkpoint**

After Tasks 3 and 4 make these tests pass, commit the split with the implementation:

```bash
git add apps/mac/Tests/WhatTheTokenMacTests
git commit -m "test(mac): split release packaging guard tests"
```

---

### Task 3: Add Public App Icon Asset Catalog

**Files:**
- Create: `apps/mac/Brand/AppIconSource.prompt.md`
- Create: `apps/mac/Brand/AppIconSource.png`
- Create: `apps/mac/Sources/WhatTheTokenMac/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: generated PNG icon slots under `apps/mac/Sources/WhatTheTokenMac/Assets.xcassets/AppIcon.appiconset/`
- Modify: `apps/mac/WhatTheToken.xcodeproj/project.pbxproj`
- Modify: `apps/mac/Packaging/Info.plist`

- [ ] **Step 1: Add reproducible icon prompt**

Create `apps/mac/Brand/AppIconSource.prompt.md`:

```markdown
# WhatTheToken Public V1 App Icon Prompt

Create a polished macOS app icon for "WhatTheToken", a privacy-first menu bar utility that shows Claude Code and Codex usage limits without copying credentials.

Composition:
- A rounded macOS icon square with subtle depth.
- Main symbol: a clean token coin or meter dial fused with a small code prompt mark.
- Visual idea: local usage visibility, developer tooling, trust, and precision.
- Avoid text, letters, provider logos, Apple logos, OpenAI logos, Anthropic logos, padlocks, shields, and generic robot imagery.
- Make the silhouette readable at 16px.
- Use a dark graphite base, warm gold token highlight, crisp cyan status accent, and a small neutral off-white glint.
- Keep it premium and simple, suitable for a Mac menu bar developer utility.

Output:
- 1024x1024 PNG.
- No transparent background.
- No visible words or numerals.
- Centered subject with safe margins for macOS icon rounding.
```

- [ ] **Step 2: Generate the source icon**

Use the `imagegen` skill with the exact prompt from `apps/mac/Brand/AppIconSource.prompt.md`.

Save the approved 1024x1024 PNG as:

```bash
apps/mac/Brand/AppIconSource.png
```

Expected:

- The file is a square PNG.
- The icon contains no readable text, no provider marks, and no Apple marks.

- [ ] **Step 3: Generate macOS icon slots**

Run:

```bash
mkdir -p apps/mac/Sources/WhatTheTokenMac/Assets.xcassets/AppIcon.appiconset
sips -z 16 16 apps/mac/Brand/AppIconSource.png --out apps/mac/Sources/WhatTheTokenMac/Assets.xcassets/AppIcon.appiconset/icon_16x16.png
sips -z 32 32 apps/mac/Brand/AppIconSource.png --out apps/mac/Sources/WhatTheTokenMac/Assets.xcassets/AppIcon.appiconset/icon_16x16@2x.png
sips -z 32 32 apps/mac/Brand/AppIconSource.png --out apps/mac/Sources/WhatTheTokenMac/Assets.xcassets/AppIcon.appiconset/icon_32x32.png
sips -z 64 64 apps/mac/Brand/AppIconSource.png --out apps/mac/Sources/WhatTheTokenMac/Assets.xcassets/AppIcon.appiconset/icon_32x32@2x.png
sips -z 128 128 apps/mac/Brand/AppIconSource.png --out apps/mac/Sources/WhatTheTokenMac/Assets.xcassets/AppIcon.appiconset/icon_128x128.png
sips -z 256 256 apps/mac/Brand/AppIconSource.png --out apps/mac/Sources/WhatTheTokenMac/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png
sips -z 256 256 apps/mac/Brand/AppIconSource.png --out apps/mac/Sources/WhatTheTokenMac/Assets.xcassets/AppIcon.appiconset/icon_256x256.png
sips -z 512 512 apps/mac/Brand/AppIconSource.png --out apps/mac/Sources/WhatTheTokenMac/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png
sips -z 512 512 apps/mac/Brand/AppIconSource.png --out apps/mac/Sources/WhatTheTokenMac/Assets.xcassets/AppIcon.appiconset/icon_512x512.png
sips -z 1024 1024 apps/mac/Brand/AppIconSource.png --out apps/mac/Sources/WhatTheTokenMac/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png
```

Expected:

- Each command prints `Finished`.
- Ten PNG files exist in the app icon set.

- [ ] **Step 4: Add asset catalog Contents.json**

Create `apps/mac/Sources/WhatTheTokenMac/Assets.xcassets/AppIcon.appiconset/Contents.json`:

```json
{
  "images": [
    {
      "filename": "icon_16x16.png",
      "idiom": "mac",
      "scale": "1x",
      "size": "16x16"
    },
    {
      "filename": "icon_16x16@2x.png",
      "idiom": "mac",
      "scale": "2x",
      "size": "16x16"
    },
    {
      "filename": "icon_32x32.png",
      "idiom": "mac",
      "scale": "1x",
      "size": "32x32"
    },
    {
      "filename": "icon_32x32@2x.png",
      "idiom": "mac",
      "scale": "2x",
      "size": "32x32"
    },
    {
      "filename": "icon_128x128.png",
      "idiom": "mac",
      "scale": "1x",
      "size": "128x128"
    },
    {
      "filename": "icon_128x128@2x.png",
      "idiom": "mac",
      "scale": "2x",
      "size": "128x128"
    },
    {
      "filename": "icon_256x256.png",
      "idiom": "mac",
      "scale": "1x",
      "size": "256x256"
    },
    {
      "filename": "icon_256x256@2x.png",
      "idiom": "mac",
      "scale": "2x",
      "size": "256x256"
    },
    {
      "filename": "icon_512x512.png",
      "idiom": "mac",
      "scale": "1x",
      "size": "512x512"
    },
    {
      "filename": "icon_512x512@2x.png",
      "idiom": "mac",
      "scale": "2x",
      "size": "512x512"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

- [ ] **Step 5: Wire asset catalog into Xcode project**

Modify `apps/mac/WhatTheToken.xcodeproj/project.pbxproj`.

Add to `PBXBuildFile`:

```text
		00000000000000000000001D = {isa = PBXBuildFile; fileRef = 00000000000000000000001E; };
```

Add to `PBXFileReference`:

```text
		00000000000000000000001E = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Sources/WhatTheTokenMac/Assets.xcassets; sourceTree = "<group>"; };
```

Add `00000000000000000000001E` to the `Resources` group children:

```text
			children = (
				00000000000000000000001B,
				00000000000000000000001E,
			);
```

Add `00000000000000000000001D` to the `PBXResourcesBuildPhase` files:

```text
			files = (
				00000000000000000000001C,
				00000000000000000000001D,
			);
```

- [ ] **Step 6: Bind the app icon in Info.plist**

In `apps/mac/Packaging/Info.plist`, add this key immediately after `CFBundleExecutable`:

```xml
	<key>CFBundleIconName</key>
	<string>AppIcon</string>
```

This makes the archived app use the compiled asset catalog icon. The archive smoke in Task 4 verifies both `CFBundleIconName` and `Contents/Resources/Assets.car` in the built `.app`.

- [ ] **Step 7: Verify icon tests**

Run:

```bash
cd apps/mac
swift test --filter MacXcodeProjectTests
cd ../..
```

Expected:

- `MacXcodeProjectTests` passes.

- [ ] **Step 8: Verify project syntax**

Run:

```bash
plutil -lint apps/mac/WhatTheToken.xcodeproj/project.pbxproj
```

Expected:

```text
apps/mac/WhatTheToken.xcodeproj/project.pbxproj: OK
```

- [ ] **Step 9: Commit checkpoint**

Run:

```bash
git add apps/mac/Brand apps/mac/Sources/WhatTheTokenMac/Assets.xcassets apps/mac/Packaging/Info.plist apps/mac/WhatTheToken.xcodeproj/project.pbxproj apps/mac/Tests/WhatTheTokenMacTests
git commit -m "build(mac): add public app icon asset catalog"
```

---

### Task 4: Add Release Rehearsal Scripts

**Files:**
- Create: `apps/mac/Scripts/smoke-archive-unsigned.sh`
- Create: `apps/mac/Scripts/sign-dmg.sh`
- Create: `apps/mac/Scripts/rehearse-release.sh`
- Modify: `apps/mac/Scripts/package-app.sh`
- Modify: `apps/mac/Scripts/verify-release-artifacts.sh`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/MacReleaseScriptTests.swift`

- [ ] **Step 1: Label the SwiftPM app packager as development-only**

Add this comment immediately after `set -euo pipefail` in `apps/mac/Scripts/package-app.sh`:

```bash
# Development-only app bundle helper for local SwiftPM smoke tests.
# Public releases must use WhatTheToken.xcodeproj through archive-release.sh.
```

Add this output before the final `echo "$APP_DIR"`:

```bash
echo "Development-only app bundle. Do not notarize or publish this artifact." >&2
```

- [ ] **Step 2: Add unsigned Xcode archive smoke script**

Create `apps/mac/Scripts/smoke-archive-unsigned.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/WhatTheToken.xcodeproj"
SCHEME="WhatTheToken"
CONFIGURATION="Release"
ARCHIVE_PATH="$ROOT_DIR/.build/archive-smoke/WhatTheToken.xcarchive"
VERSION=""
BUILD=""

usage() {
    printf 'Usage: %s --version <version> --build <build> [--archive-path <path>]\n' "$0"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            VERSION="${2:-}"
            shift 2
            ;;
        --build)
            BUILD="${2:-}"
            shift 2
            ;;
        --archive-path)
            ARCHIVE_PATH="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 64
            ;;
    esac
done

if [[ -z "$VERSION" || -z "$BUILD" ]]; then
    usage >&2
    exit 64
fi

rm -rf "$ARCHIVE_PATH"
mkdir -p "$(dirname "$ARCHIVE_PATH")"

xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    DEVELOPMENT_TEAM="" \
    archive

APP_PATH="$ARCHIVE_PATH/Products/Applications/WhatTheToken.app"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
ASSETS_CAR="$APP_PATH/Contents/Resources/Assets.car"

if [[ ! -d "$APP_PATH" ]]; then
    printf 'Archived app not found: %s\n' "$APP_PATH" >&2
    exit 66
fi

if [[ ! -f "$INFO_PLIST" ]]; then
    printf 'Archived Info.plist not found: %s\n' "$INFO_PLIST" >&2
    exit 66
fi

/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST" | grep -Fx "$VERSION" >/dev/null
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST" | grep -Fx "$BUILD" >/dev/null
/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$INFO_PLIST" | grep -Fx "true" >/dev/null
/usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$INFO_PLIST" | grep -Fx "AppIcon" >/dev/null

if [[ ! -f "$ASSETS_CAR" ]]; then
    printf 'Compiled asset catalog not found: %s\n' "$ASSETS_CAR" >&2
    exit 66
fi

printf '%s\n' "$APP_PATH"
```

- [ ] **Step 3: Add Developer ID DMG signing script**

Create `apps/mac/Scripts/sign-dmg.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

DMG_PATH=""
SIGNING_IDENTITY="${DEVELOPER_ID_SIGNING_IDENTITY:-Developer ID Application}"
DRY_RUN=0

usage() {
    printf 'Usage: %s --dmg <path> [--signing-identity <identity>] [--dry-run]\n' "$0"
}

quote_command() {
    printf '%q ' "$@"
    printf '\n'
}

run_command() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        quote_command "$@"
    else
        "$@"
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dmg)
            DMG_PATH="${2:-}"
            shift 2
            ;;
        --signing-identity)
            SIGNING_IDENTITY="${2:-}"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 64
            ;;
    esac
done

if [[ -z "$DMG_PATH" ]]; then
    usage >&2
    exit 64
fi

if [[ "$DRY_RUN" -eq 0 && ! -f "$DMG_PATH" ]]; then
    printf 'DMG not found: %s\n' "$DMG_PATH" >&2
    exit 66
fi

run_command hdiutil verify "$DMG_PATH"
run_command codesign --force --sign "$SIGNING_IDENTITY" "$DMG_PATH"
run_command codesign --verify --verbose=2 "$DMG_PATH"

if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'Dry run only. No DMG was signed.\n'
fi
```

This follows Apple's direct-distribution guidance: sign the app, sign the disk image, then notarize the disk image.

- [ ] **Step 4: Add release artifact round-trip verification**

Replace `apps/mac/Scripts/verify-release-artifacts.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail

DMG_PATH=""
APP_PATH=""
DRY_RUN=0

usage() {
    printf 'Usage: %s --dmg <path> [--app <WhatTheToken.app>] [--dry-run]\n' "$0"
}

quote_command() {
    printf '%q ' "$@"
    printf '\n'
}

run_command() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        quote_command "$@"
    else
        "$@"
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dmg)
            DMG_PATH="${2:-}"
            shift 2
            ;;
        --app)
            APP_PATH="${2:-}"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 64
            ;;
    esac
done

if [[ -z "$DMG_PATH" ]]; then
    usage >&2
    exit 64
fi

if [[ "$DRY_RUN" -eq 0 && ! -f "$DMG_PATH" ]]; then
    printf 'DMG not found: %s\n' "$DMG_PATH" >&2
    exit 66
fi

if [[ -n "$APP_PATH" ]]; then
    if [[ "$DRY_RUN" -eq 0 && ! -d "$APP_PATH" ]]; then
        printf 'App bundle not found: %s\n' "$APP_PATH" >&2
        exit 66
    fi
    run_command codesign --verify --deep --strict --verbose=2 "$APP_PATH"
    run_command spctl -a -vv -t exec "$APP_PATH"
fi

run_command hdiutil verify "$DMG_PATH"
run_command xcrun stapler validate "$DMG_PATH"
run_command spctl -a -vv -t open --context context:primary-signature "$DMG_PATH"

if [[ "$DRY_RUN" -eq 0 ]]; then
    MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/whatthetoken-dmg.XXXXXX")"
    COPY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/whatthetoken-copy.XXXXXX")"
    detach_dmg() {
        hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
        rm -rf "$MOUNT_DIR" "$COPY_DIR"
    }
    trap detach_dmg EXIT

    hdiutil attach "$DMG_PATH" -readonly -nobrowse -mountpoint "$MOUNT_DIR" >/dev/null

    if [[ ! -d "$MOUNT_DIR/WhatTheToken.app" ]]; then
        printf 'Mounted DMG does not contain WhatTheToken.app.\n' >&2
        exit 66
    fi
    if [[ ! -L "$MOUNT_DIR/Applications" ]]; then
        printf 'Mounted DMG does not contain an Applications symlink.\n' >&2
        exit 66
    fi

    cp -R "$MOUNT_DIR/WhatTheToken.app" "$COPY_DIR/WhatTheToken.app"
    codesign --verify --deep --strict --verbose=2 "$COPY_DIR/WhatTheToken.app"
    spctl -a -vv -t exec "$COPY_DIR/WhatTheToken.app"
    /usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$COPY_DIR/WhatTheToken.app/Contents/Info.plist" | grep -Fx "AppIcon" >/dev/null
    test -f "$COPY_DIR/WhatTheToken.app/Contents/Resources/Assets.car"
else
    quote_command hdiutil attach "$DMG_PATH" -readonly -nobrowse -mountpoint /tmp/whatthetoken-dmg
    quote_command test -d /tmp/whatthetoken-dmg/WhatTheToken.app
    quote_command test -L /tmp/whatthetoken-dmg/Applications
    quote_command hdiutil detach /tmp/whatthetoken-dmg
fi

checksum_path="$DMG_PATH.sha256"
if [[ "$DRY_RUN" -eq 1 ]]; then
    quote_command shasum -a 256 "$DMG_PATH" ">" "$checksum_path"
else
    shasum -a 256 "$DMG_PATH" > "$checksum_path"
    printf '%s\n' "$checksum_path"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'Dry run only. No release artifacts were verified or checksummed.\n'
fi
```

This is the shareability check: the final DMG must verify, mount read-only, expose `WhatTheToken.app`, expose the `/Applications` symlink, copy the app out, preserve signing, and preserve the compiled icon assets.

- [ ] **Step 5: Add release rehearsal wrapper**

Create `apps/mac/Scripts/rehearse-release.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION=""
BUILD=""
MODE="dry-run"

usage() {
    printf 'Usage: %s --version <version> --build <build> [--mode dry-run|unsigned-smoke|signed]\n' "$0"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            VERSION="${2:-}"
            shift 2
            ;;
        --build)
            BUILD="${2:-}"
            shift 2
            ;;
        --mode)
            MODE="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 64
            ;;
    esac
done

if [[ -z "$VERSION" || -z "$BUILD" ]]; then
    usage >&2
    exit 64
fi

case "$MODE" in
    dry-run)
        "$ROOT_DIR/Scripts/archive-release.sh" --version "$VERSION" --build "$BUILD" --dry-run
        "$ROOT_DIR/Scripts/create-dmg.sh" --version "$VERSION" --dry-run
        "$ROOT_DIR/Scripts/sign-dmg.sh" --dmg "$ROOT_DIR/.build/dmg/WhatTheToken-$VERSION.dmg" --dry-run
        "$ROOT_DIR/Scripts/notarize-dmg.sh" --dmg "$ROOT_DIR/.build/dmg/WhatTheToken-$VERSION.dmg" --dry-run
        "$ROOT_DIR/Scripts/verify-release-artifacts.sh" --dmg "$ROOT_DIR/.build/dmg/WhatTheToken-$VERSION.dmg" --app "$ROOT_DIR/.build/export/WhatTheToken.app" --dry-run
        ;;
    unsigned-smoke)
        APP_PATH="$("$ROOT_DIR/Scripts/smoke-archive-unsigned.sh" --version "$VERSION" --build "$BUILD")"
        DMG_PATH="$ROOT_DIR/.build/dmg-smoke/WhatTheToken-$VERSION-unsigned-smoke.dmg"
        "$ROOT_DIR/Scripts/create-dmg.sh" --version "$VERSION" --app "$APP_PATH" --output "$DMG_PATH"
        hdiutil verify "$DMG_PATH" >/dev/null
        MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/whatthetoken-smoke-dmg.XXXXXX")"
        trap 'hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true; rm -rf "$MOUNT_DIR"' EXIT
        hdiutil attach "$DMG_PATH" -readonly -nobrowse -mountpoint "$MOUNT_DIR" >/dev/null
        test -d "$MOUNT_DIR/WhatTheToken.app"
        test -L "$MOUNT_DIR/Applications"
        hdiutil detach "$MOUNT_DIR" >/dev/null
        trap - EXIT
        rm -rf "$MOUNT_DIR"
        shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"
        printf '%s\n' "$DMG_PATH"
        ;;
    signed)
        "$ROOT_DIR/Scripts/archive-release.sh" --version "$VERSION" --build "$BUILD"
        "$ROOT_DIR/Scripts/create-dmg.sh" --version "$VERSION"
        "$ROOT_DIR/Scripts/sign-dmg.sh" --dmg "$ROOT_DIR/.build/dmg/WhatTheToken-$VERSION.dmg"
        "$ROOT_DIR/Scripts/notarize-dmg.sh" --dmg "$ROOT_DIR/.build/dmg/WhatTheToken-$VERSION.dmg"
        "$ROOT_DIR/Scripts/verify-release-artifacts.sh" \
            --dmg "$ROOT_DIR/.build/dmg/WhatTheToken-$VERSION.dmg" \
            --app "$ROOT_DIR/.build/export/WhatTheToken.app"
        ;;
    *)
        usage >&2
        exit 64
        ;;
esac
```

- [ ] **Step 6: Make scripts executable**

Run:

```bash
chmod +x apps/mac/Scripts/smoke-archive-unsigned.sh apps/mac/Scripts/sign-dmg.sh apps/mac/Scripts/rehearse-release.sh
```

Expected:

- All three scripts have executable bits.

- [ ] **Step 7: Run release script tests**

Run:

```bash
cd apps/mac
swift test --filter MacReleaseScriptTests
cd ../..
```

Expected:

- `MacReleaseScriptTests` passes.

- [ ] **Step 8: Run dry-run rehearsal**

Run:

```bash
apps/mac/Scripts/rehearse-release.sh --version 0.1.0 --build 1 --mode dry-run
```

Expected output includes:

- `archive-release.sh` dry-run `xcodebuild archive`
- `create-dmg.sh` dry-run `hdiutil create`
- `sign-dmg.sh` dry-run `codesign --force --sign`
- `notarize-dmg.sh` dry-run `xcrun notarytool submit`
- `verify-release-artifacts.sh` dry-run `hdiutil verify`, `hdiutil attach`, `spctl`, `stapler`, and `shasum`

- [ ] **Step 9: Run unsigned Xcode archive smoke when Xcode is initialized**

Run:

```bash
apps/mac/Scripts/rehearse-release.sh --version 0.1.0 --build 1 --mode unsigned-smoke
```

Expected on initialized Xcode:

- The command prints `apps/mac/.build/dmg-smoke/WhatTheToken-0.1.0-unsigned-smoke.dmg`.
- A `.sha256` file exists next to the DMG.
- The unsigned smoke DMG verifies with `hdiutil`, mounts read-only, contains `WhatTheToken.app`, and contains an `Applications` symlink.

Expected on an uninitialized local Xcode:

- The command fails before archive with the known Xcode first-launch/plugin issue. Record the maintainer gate from Task 1; do not weaken the script.

- [ ] **Step 10: Commit checkpoint**

Run:

```bash
git add apps/mac/Scripts apps/mac/Tests/WhatTheTokenMacTests/MacReleaseScriptTests.swift
git commit -m "build(mac): add release rehearsal scripts"
```

---

### Task 5: Document Sandbox Compatibility Decision

**Files:**
- Create: `docs/release/app-sandbox-compatibility-matrix.md`
- Modify: `docs/release/public-v1-checklist.md`
- Modify: `docs/superpowers/specs/2026-05-09-distribution-hardening-design.md`

- [ ] **Step 1: Create the compatibility matrix**

Create `docs/release/app-sandbox-compatibility-matrix.md`:

```markdown
# App Sandbox Compatibility Matrix

Public V1 ships Developer ID signed, hardened-runtime enabled, notarized, and unsandboxed unless every matrix row passes in a sandbox-enabled release candidate.

## Decision Rule

- Do not enable `com.apple.security.app-sandbox` for Public V1 unless every row below passes on a signed/notarized release candidate.
- If any connector row fails, Public V1 remains unsandboxed and the release notes explain that WhatTheToken is a local developer utility that interoperates with local developer tools only after explicit connector consent.
- Hardened runtime and notarization remain mandatory either way.

## Matrix

| Area | Verification | Required Result | Public V1 Status |
|---|---|---|---|
| Finder launch | Install from notarized DMG and launch from `/Applications` | App launches without Gatekeeper friction | Not run |
| Menu bar extra | Launch installed app | Menu bar item appears, Dock icon remains hidden | Not run |
| Settings persistence | Change Launch at Login off/on/off and relaunch | Preference persists only after OS registration succeeds | Not run |
| Snapshot cache | Connect provider, refresh, quit, relaunch | Sanitized status persists; raw provider payloads are absent | Not run |
| Claude opt-in | Click Connect Claude Code | App reads Claude Code status only after explicit consent | Not run |
| Keychain boundary | Run Claude connector path using `/usr/bin/security find-generic-password` | Provider credentials stay in provider storage; app stores no copied secret | Not run |
| Claude network request | Refresh Claude usage | Request succeeds after consent and sanitized status renders | Not run |
| Codex discovery | Click Connect Codex | App discovers expected Codex executable path | Not run |
| Codex app-server | Refresh Codex usage | App launches or connects over stdio without credential leakage | Not run |
| Codex rate limits | Refresh Codex usage | Sanitized rate-limit status renders | Not run |
| Sparkle framework load | Launch release app | Sparkle framework loads without helper or sandbox violations | Not run |
| Sparkle test feed | Invoke approved manual update check against test appcast | Signed update check succeeds with no background checks | Not run |
| Launch at login | Toggle Launch at Login and log out/in | `SMAppService.mainApp` registration works and no provider refresh runs before consent | Not run |

## Current Public V1 Decision

Public V1 remains unsandboxed. The current connector model depends on local developer-tool interoperability that has not passed the sandbox matrix. This does not reduce the Public V1 requirement for Developer ID signing, hardened runtime, notarization, stapling, Gatekeeper verification, explicit provider consent, sanitized persistence, and no default telemetry.
```

- [ ] **Step 2: Link the matrix from the release checklist**

In `docs/release/public-v1-checklist.md`, add this under `## Preconditions`:

```markdown
- Confirm `docs/release/app-sandbox-compatibility-matrix.md` still records Public V1 as unsandboxed, or every matrix row has passed on a sandbox-enabled signed/notarized release candidate.
```

- [ ] **Step 3: Keep the spec aligned**

In `docs/superpowers/specs/2026-05-09-distribution-hardening-design.md`, update the `Remaining before Public V1` sandbox bullet to:

```markdown
- documented sandbox compatibility matrix and explicit Public V1 unsandboxed decision unless every matrix row passes
```

- [ ] **Step 4: Verify docs contain the matrix link**

Run:

```bash
rg -n "app-sandbox-compatibility-matrix|Public V1 remains unsandboxed|com.apple.security.app-sandbox" docs/release docs/superpowers/specs/2026-05-09-distribution-hardening-design.md
```

Expected:

- The new matrix file and checklist/spec links are present.

- [ ] **Step 5: Commit checkpoint**

Run:

```bash
git add docs/release/app-sandbox-compatibility-matrix.md docs/release/public-v1-checklist.md docs/superpowers/specs/2026-05-09-distribution-hardening-design.md
git commit -m "docs(release): document app sandbox decision matrix"
```

---

### Task 6: Document Sparkle Key Custody And Inert Public V1 Posture

**Files:**
- Create: `docs/release/sparkle-key-custody.md`
- Modify: `docs/release/public-v1-checklist.md`
- Modify: `README.md`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/MacBundleMetadataTests.swift`

- [ ] **Step 1: Create Sparkle custody doc**

Create `docs/release/sparkle-key-custody.md`:

````markdown
# Sparkle Key Custody

Public V1 includes Sparkle as release architecture but keeps update behavior inert:

- `SUEnableAutomaticChecks` is `false`.
- `SUAutomaticallyUpdate` is `false`.
- No visible `Check for Updates` UI ships until signed old-build to new-build update smoke passes.
- No appcast is published until release artifacts are already available and the update archive is signed.

## Maintainer Key Generation

Run this on the Mac that owns release signing authority after Xcode has resolved the Sparkle package:

```bash
SPARKLE_BIN_DIR="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*/SourcePackages/artifacts/sparkle/Sparkle/bin' -type d -print -quit)"
test -n "$SPARKLE_BIN_DIR"
"$SPARKLE_BIN_DIR/generate_keys"
```

Expected:

- Sparkle stores the private EdDSA key in the maintainer's login Keychain.
- Sparkle prints a base64 public key.
- The private key is not copied into this repository, release hosting, issue trackers, docs, shell history, or CI.

## Public Key Gate

Add `SUPublicEDKey` to `apps/mac/Packaging/Info.plist` only after the maintainer has generated the key and approved committing the printed public key.

The public key is safe to commit. The private key is never committed.

## Feed URL Gate

Add `SUFeedURL` to `apps/mac/Packaging/Info.plist` only after a stable HTTPS appcast URL controlled by the project exists.

Recommended first appcast location if GitHub Pages is enabled for the repository:

```text
https://hansdraisma.github.io/whatthetoken/appcast.xml
```

Do not use a local path, temporary URL, Conductor workspace path, private GitHub attachment URL, or release-candidate URL in `SUFeedURL`.

## Appcast Publication Rule

Publish appcast changes only after:

1. The DMG is Developer ID signed, notarized, stapled, and accepted by Gatekeeper.
2. The DMG and checksum are already attached to the GitHub Release.
3. `generate_appcast` has signed the update archive with the private EdDSA key from Keychain.
4. A signed old-build to signed new-build update smoke passes on a fresh macOS account.

## Custody Record

For each public release, the maintainer records privately:

- Release version and build.
- Git commit and tag.
- Developer ID Team ID used.
- Notary Keychain profile name used.
- Confirmation that Sparkle private key stayed in Keychain plus secure backup.
- Appcast URL used, if a feed is enabled.
- SHA-256 checksum for the final DMG.
````

- [ ] **Step 2: Update the release checklist Sparkle section**

Replace the `## Sparkle Appcast` section in `docs/release/public-v1-checklist.md` with:

````markdown
## Sparkle Appcast

Public V1 keeps Sparkle inert unless the signed update path has already passed. See `docs/release/sparkle-key-custody.md`.

Before adding `SUPublicEDKey`:

```bash
SPARKLE_BIN_DIR="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*/SourcePackages/artifacts/sparkle/Sparkle/bin' -type d -print -quit)"
test -n "$SPARKLE_BIN_DIR"
"$SPARKLE_BIN_DIR/generate_keys"
```

Before adding `SUFeedURL`:

- Confirm the appcast URL is stable HTTPS infrastructure controlled by the project.
- Confirm the URL is not a local path, private attachment URL, release-candidate URL, or internal workspace URL.

Generate an appcast entry only after a signed old-build to signed new-build update smoke test passes:

```bash
apps/mac/Scripts/generate-appcast.sh \
  --updates-dir "$HOME/ReleaseArtifacts/WhatTheToken/updates" \
  --download-url-prefix https://hansdraisma.github.io/whatthetoken/
```

Before publishing appcast changes:

- Confirm the private EdDSA key stayed outside the repo, CI, and hosting machine.
- Confirm the appcast points only to published artifacts.
- Confirm the old installed build updates to the new signed/notarized build.
````

Create the local staging directory before running the command:

```bash
mkdir -p "$HOME/ReleaseArtifacts/WhatTheToken/updates"
```

- [ ] **Step 3: Keep README aligned**

Ensure `README.md` install/update language contains this exact posture:

```markdown
Public V1 ships as a signed and notarized DMG attached to GitHub Releases. Updates are manual for Public V1: download the newest signed and notarized DMG from GitHub Releases and replace the installed app. Sparkle is prepared in the release target for a future manual update path, but automatic background checks and silent installs remain disabled.
```

- [ ] **Step 4: Verify metadata tests cover Sparkle safety**

Run:

```bash
cd apps/mac
swift test --filter MacBundleMetadataTests
cd ../..
```

Expected:

- The test `sparkleDefaultsRemainManualAndSilentForPublicV1` passes.

- [ ] **Step 5: Commit checkpoint**

Run:

```bash
git add docs/release/sparkle-key-custody.md docs/release/public-v1-checklist.md README.md apps/mac/Tests/WhatTheTokenMacTests/MacBundleMetadataTests.swift
git commit -m "docs(release): document sparkle key custody"
```

---

### Task 7: Add Rollback And Hotfix Rules

**Files:**
- Create: `docs/release/rollback-and-hotfix.md`
- Modify: `docs/release/public-v1-checklist.md`

- [ ] **Step 1: Create rollback and hotfix doc**

Create `docs/release/rollback-and-hotfix.md`:

```markdown
# Rollback And Hotfix Rules

Public artifacts must be immutable once published. A failed public build number is never reused for a different binary.

## Build Number Rules

- `CFBundleVersion` is a monotonically increasing integer.
- If a release candidate fails after archive, export, signing, notarization, Gatekeeper, Sparkle, or fresh-machine smoke, increment the build number for the next candidate.
- If a GitHub Release draft is discarded before publication, the build number may remain unused in public docs but must still not be reused if any external tester received the artifact.

## DMG Rollback

If a published DMG is bad:

1. Mark the GitHub Release as withdrawn in the release notes.
2. Keep the original tag and artifacts available for audit unless they expose secrets.
3. Publish a new hotfix tag with a higher build number.
4. Attach a new notarized DMG and checksum.
5. Update docs to point users to the hotfix release.

## Appcast Rollback

If an appcast points to a bad update:

1. Remove or correct the bad appcast item.
2. Publish the corrected appcast.
3. Do not lower `sparkle:version`.
4. Do not reuse the bad build number.
5. Publish a higher-build hotfix if users may already have seen the update.

## Security Withdrawal

If an artifact exposes secrets, internal credentials, private keys, raw provider payloads, or sensitive diagnostics:

1. Remove the artifact from GitHub Releases.
2. Rotate the exposed secret or key through the owning service.
3. Record the incident privately with commit, tag, artifact name, and checksum.
4. Publish a replacement build with a higher build number after verification passes.

## Fresh Install Recovery

If install or launch fails on a fresh macOS account:

1. Keep the failed artifact unpublished if still in draft.
2. If published, withdraw the release notes and publish a hotfix build.
3. Capture the failing command and sanitized output in maintainer notes.
4. Add a regression check to the release checklist before the next public artifact.
```

- [ ] **Step 2: Link rollback rules from checklist**

Add this section before `## Credential-Gated Verification` in `docs/release/public-v1-checklist.md`:

```markdown
## Rollback And Hotfix

Before publishing, read `docs/release/rollback-and-hotfix.md`.

- Confirm the public build number has not been used for another public or external-test artifact.
- If a release candidate fails after external distribution, increment `CURRENT_PROJECT_VERSION`.
- Do not replace a published DMG with a different binary under the same version/build/checksum.
- If appcast publication fails or points to a bad artifact, publish a corrected feed and use a higher build for the next update.
```

- [ ] **Step 3: Verify docs**

Run:

```bash
rg -n "rollback-and-hotfix|build number|appcast" docs/release/public-v1-checklist.md docs/release/rollback-and-hotfix.md
```

Expected:

- The checklist links to rollback rules.
- The rollback doc covers DMG and appcast recovery.

- [ ] **Step 4: Commit checkpoint**

Run:

```bash
git add docs/release/rollback-and-hotfix.md docs/release/public-v1-checklist.md
git commit -m "docs(release): add rollback and hotfix rules"
```

---

### Task 8: Update Public V1 Checklist And Roadmap

**Files:**
- Modify: `docs/release/public-v1-checklist.md`
- Modify: `docs/roadmap/development-roadmap.md`
- Modify: `docs/superpowers/specs/2026-05-09-distribution-hardening-design.md`

- [ ] **Step 1: Add app icon and unsigned rehearsal to checklist preconditions**

In `docs/release/public-v1-checklist.md`, add under `## Preconditions`:

```markdown
- Confirm `apps/mac/Sources/WhatTheTokenMac/Assets.xcassets/AppIcon.appiconset/Contents.json` exists and the icon appears in the archived app.
- Confirm `apps/mac/Scripts/rehearse-release.sh --version 0.1.0 --build 1 --mode unsigned-smoke` passes on an initialized Xcode installation, or record the Xcode first-launch gate before proceeding.
- Confirm the signed release flow signs the DMG before notarization and `verify-release-artifacts.sh` mounts the final DMG, copies out `WhatTheToken.app`, and verifies the copied app still has `CFBundleIconName = AppIcon` plus `Contents/Resources/Assets.car`.
```

- [ ] **Step 2: Add release rehearsal command**

In `docs/release/public-v1-checklist.md`, add after `## Build And Test`:

````markdown
## Release Rehearsal

Review the command chain without credentials:

```bash
apps/mac/Scripts/rehearse-release.sh --version 0.1.0 --build 1 --mode dry-run
```

On an initialized Xcode installation, create an unsigned archive and smoke DMG:

```bash
apps/mac/Scripts/rehearse-release.sh --version 0.1.0 --build 1 --mode unsigned-smoke
```

The unsigned smoke proves the Xcode target archives and the DMG script packages the app. It is not a public release artifact.
````

- [ ] **Step 3: Update archive command to use the rehearsal wrapper for signed release**

In `docs/release/public-v1-checklist.md`, under `## Archive And Export`, use:

```bash
apps/mac/Scripts/rehearse-release.sh --version 0.1.0 --build 1 --mode signed
```

Expected output remains:

- `apps/mac/.build/archive/WhatTheToken.xcarchive`
- `apps/mac/.build/export/WhatTheToken.app`
- `apps/mac/.build/dmg/WhatTheToken-0.1.0.dmg`
- `apps/mac/.build/dmg/WhatTheToken-0.1.0.dmg.sha256`

Expected verification includes:

- The app is Developer ID signed.
- The DMG is Developer ID signed before notarization.
- The DMG is notarized and stapled.
- The DMG mounts read-only.
- The mounted DMG contains `WhatTheToken.app` and an `Applications` symlink.
- A copied app from the mounted DMG passes `codesign`, `spctl`, and icon asset checks.

- [ ] **Step 4: Update roadmap Stage 5 status**

In `docs/roadmap/development-roadmap.md`, update the Stage 5 distribution section around the current Stage 5 entry to distinguish:

```markdown
Stage 5A repo foundation is complete when release metadata, Xcode target, Sparkle-ready wiring, launch-at-login, scripts, release checklist, app icon, sandbox matrix, rollback rules, and tests are committed.

Stage 5B credentialed rehearsal remains gated on maintainer Xcode setup, Developer ID certificate access, notarization profile, real archive/export, notarized DMG, Gatekeeper verification, and fresh-account smoke.

Stage 5C public launch remains gated on GitHub Release publication, checksum publication, public docs, repository visibility scan, and Sparkle appcast publication only after signed update smoke passes.
```

- [ ] **Step 5: Verify roadmap/checklist sync**

Run:

```bash
rg -n "Stage 5A|Stage 5B|Stage 5C|unsigned-smoke|rollback-and-hotfix|sparkle-key-custody|app-sandbox-compatibility-matrix" docs/release/public-v1-checklist.md docs/roadmap/development-roadmap.md docs/superpowers/specs/2026-05-09-distribution-hardening-design.md
```

Expected:

- All three docs mention the same gates.

- [ ] **Step 6: Commit checkpoint**

Run:

```bash
git add docs/release/public-v1-checklist.md docs/roadmap/development-roadmap.md docs/superpowers/specs/2026-05-09-distribution-hardening-design.md
git commit -m "docs(release): sync Public V1 readiness gates"
```

---

### Task 9: Full Repo-Side Verification

**Files:**
- Verify all modified files.

- [ ] **Step 1: Install dependencies**

Run:

```bash
pnpm install --frozen-lockfile
```

Expected:

- Command succeeds.

- [ ] **Step 2: Run core tests**

Run:

```bash
pnpm --filter @whatthetoken/core test
```

Expected:

- Core tests pass.

- [ ] **Step 3: Run macOS tests**

Run:

```bash
cd apps/mac
swift test
cd ../..
```

Expected:

- Swift tests pass.

- [ ] **Step 4: Validate plists and scheme**

Run:

```bash
plutil -lint apps/mac/Packaging/Info.plist
plutil -lint apps/mac/Packaging/ExportOptions.DeveloperID.plist
plutil -lint apps/mac/Packaging/WhatTheToken.entitlements
plutil -lint apps/mac/WhatTheToken.xcodeproj/project.pbxproj
xmllint --noout apps/mac/WhatTheToken.xcodeproj/xcshareddata/xcschemes/WhatTheToken.xcscheme
```

Expected:

- Each `plutil` command prints `OK`.
- `xmllint` exits with code 0.

- [ ] **Step 5: Run release script dry-runs**

Run:

```bash
apps/mac/Scripts/rehearse-release.sh --version 0.1.0 --build 1 --mode dry-run
apps/mac/Scripts/sign-dmg.sh --dry-run --dmg apps/mac/.build/dmg/WhatTheToken-0.1.0.dmg
apps/mac/Scripts/generate-appcast.sh --dry-run --updates-dir /tmp/whatthetoken-updates --download-url-prefix https://hansdraisma.github.io/whatthetoken/
```

Expected:

- Commands print intended release commands without requiring signing credentials.
- No secret values are printed.

- [ ] **Step 6: Run unsigned Xcode archive smoke if local Xcode is initialized**

Run:

```bash
apps/mac/Scripts/rehearse-release.sh --version 0.1.0 --build 1 --mode unsigned-smoke
```

Expected on initialized Xcode:

- Unsigned archive smoke DMG and `.sha256` file are created.
- Unsigned smoke DMG verifies, mounts, and contains the app plus Applications symlink.
- The archived app contains `CFBundleIconName = AppIcon` and `Contents/Resources/Assets.car`.

Expected on this workspace if the known Xcode plugin/first-launch issue persists:

- Command fails before archive with the plugin/first-launch error.
- Final status must report that the repo-side work is complete but local unsigned archive proof remains maintainer-gated by `sudo xcodebuild -runFirstLaunch`.

- [ ] **Step 7: Check for accidental secrets or internal paths in release docs**

Run:

```bash
rg -n "conductor|workspaces|\\.context|NOTARY_|SPARKLE.*PRIVATE|BEGIN PRIVATE|example[.]com|/tmp/|/Users/" README.md docs/release docs/superpowers/specs/2026-05-09-distribution-hardening-design.md docs/roadmap/development-roadmap.md
```

Expected:

- No Conductor workspace paths, private-key text, or secret material appear in public docs.
- `/tmp/` may appear only in dry-run command examples.
- Placeholder HTTPS domains do not appear in release appcast instructions.

- [ ] **Step 8: Check diff hygiene**

Run:

```bash
git diff --check
git status --short
```

Expected:

- `git diff --check` reports no whitespace errors.
- `git status --short` contains only intentional files before the final commit.

- [ ] **Step 9: Commit final verification/doc cleanup**

Run:

```bash
git add README.md docs apps/mac
git commit -m "chore(release): prepare Public V1 release readiness"
```

If prior task commits already captured every change, skip this commit and record the passing verification commands in the final response.

---

### Task 10: Maintainer-Gated Credentialed Release Rehearsal

**Files:**
- Read: `docs/release/public-v1-checklist.md`
- Read: `docs/release/sparkle-key-custody.md`
- Read: `docs/release/rollback-and-hotfix.md`

- [ ] **Step 1: Initialize Xcode if required**

Maintainer runs:

```bash
sudo xcodebuild -runFirstLaunch
xcodebuild -version
```

Expected:

- `xcodebuild -version` succeeds.

- [ ] **Step 2: Confirm signing and notary access**

Maintainer runs:

```bash
security find-identity -v -p codesigning | rg "Developer ID Application"
export DEVELOPER_ID_SIGNING_IDENTITY="${DEVELOPER_ID_SIGNING_IDENTITY:-Developer ID Application}"
: "${NOTARY_KEYCHAIN_PROFILE:?Set NOTARY_KEYCHAIN_PROFILE to the existing notarytool Keychain profile name in this shell}"
xcrun notarytool history --keychain-profile "$NOTARY_KEYCHAIN_PROFILE"
```

Expected:

- At least one Developer ID Application identity appears.
- `DEVELOPER_ID_SIGNING_IDENTITY` resolves to the intended Developer ID Application identity for DMG signing.
- `notarytool history` authenticates without printing credentials.

- [ ] **Step 3: Generate Sparkle key if Public V1 will embed update metadata**

Maintainer runs:

```bash
SPARKLE_BIN_DIR="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*/SourcePackages/artifacts/sparkle/Sparkle/bin' -type d -print -quit)"
test -n "$SPARKLE_BIN_DIR"
"$SPARKLE_BIN_DIR/generate_keys"
```

Expected:

- Private EdDSA key is in Keychain.
- Public EdDSA key is printed.

Repo action after maintainer approval:

- Add `SUPublicEDKey` to `apps/mac/Packaging/Info.plist`.
- Add `SUFeedURL` only if stable appcast hosting is live.
- Keep automatic checks and automatic update installs disabled.

- [ ] **Step 4: Run signed release rehearsal**

Maintainer runs:

```bash
: "${DEVELOPER_ID_TEAM_ID:?Set DEVELOPER_ID_TEAM_ID to the Apple Developer Team ID in this shell}"
: "${NOTARY_KEYCHAIN_PROFILE:?Set NOTARY_KEYCHAIN_PROFILE to the existing notarytool Keychain profile name in this shell}"
export DEVELOPER_ID_SIGNING_IDENTITY="${DEVELOPER_ID_SIGNING_IDENTITY:-Developer ID Application}"
apps/mac/Scripts/rehearse-release.sh --version 0.1.0 --build 1 --mode signed
```

The two exported values are shell-session variables on the maintainer machine. They are not committed.

Expected:

- Archive succeeds.
- Export succeeds.
- DMG is created.
- DMG is Developer ID signed.
- Notarization is accepted.
- Stapling succeeds.
- `spctl` accepts the exported app, signed DMG, and copied app from the mounted DMG.
- DMG mounts read-only and contains `WhatTheToken.app` plus an `Applications` symlink.
- Copied app from the mounted DMG contains `CFBundleIconName = AppIcon` and `Contents/Resources/Assets.car`.
- DMG checksum is created.

- [ ] **Step 5: Fresh macOS account smoke**

Maintainer verifies:

- Copy the final DMG to `~/Downloads/WhatTheToken-0.1.0.dmg`.
- Add a download-style quarantine attribute:

```bash
DOWNLOADED_DMG="$HOME/Downloads/WhatTheToken-0.1.0.dmg"
cp apps/mac/.build/dmg/WhatTheToken-0.1.0.dmg "$DOWNLOADED_DMG"
QUARANTINE_TIME="$(printf %x "$(date +%s)")"
xattr -w com.apple.quarantine "0081;$QUARANTINE_TIME;Safari;https://github.com/hansDraisma/whatthetoken/releases/download/v0.1.0/WhatTheToken-0.1.0.dmg" "$DOWNLOADED_DMG"
open "$DOWNLOADED_DMG"
```

- Install from the notarized DMG into `/Applications`.
- Launch from Finder.
- Menu bar item appears.
- Dock icon stays hidden.
- Settings open.
- Quit works.
- Launch at login defaults off.
- Launch at login toggles only by explicit user action.
- Claude Code remains disconnected until explicit connection.
- Codex remains disconnected until explicit connection.
- Disconnect removes provider cache.
- Relaunch preserves settings and sanitized cache only.
- No automatic Sparkle prompt appears.
- No background update network request occurs.

- [ ] **Step 6: Public launch gate**

Proceed to GitHub Release publication only after every item above passes. If any item fails after an artifact reached an external tester, increment `CURRENT_PROJECT_VERSION` before the next candidate.

---

## Final Verification Matrix

Repo-side completion requires:

```bash
pnpm install --frozen-lockfile
pnpm --filter @whatthetoken/core test
cd apps/mac && swift test && cd ../..
plutil -lint apps/mac/Packaging/Info.plist
plutil -lint apps/mac/Packaging/ExportOptions.DeveloperID.plist
plutil -lint apps/mac/Packaging/WhatTheToken.entitlements
plutil -lint apps/mac/WhatTheToken.xcodeproj/project.pbxproj
xmllint --noout apps/mac/WhatTheToken.xcodeproj/xcshareddata/xcschemes/WhatTheToken.xcscheme
apps/mac/Scripts/rehearse-release.sh --version 0.1.0 --build 1 --mode dry-run
apps/mac/Scripts/sign-dmg.sh --dry-run --dmg apps/mac/.build/dmg/WhatTheToken-0.1.0.dmg
git diff --check
```

Credentialed Public V1 completion additionally requires:

```bash
apps/mac/Scripts/rehearse-release.sh --version 0.1.0 --build 1 --mode signed
```

Plus the fresh macOS account smoke in `docs/release/public-v1-checklist.md`.

The release DMG is considered shareable only after the signed rehearsal verifies all of these:

- Developer ID signed exported app.
- Developer ID signed DMG.
- Notarized and stapled DMG.
- `spctl` acceptance for app, DMG, and copied app from the mounted DMG.
- Read-only DMG mount containing `WhatTheToken.app` and `Applications` symlink.
- Copied app contains `CFBundleIconName = AppIcon` and `Contents/Resources/Assets.car`.
- Fresh-account launch from a quarantine-marked DMG copy.

## Self-Review

- App icon gap is covered by Task 3.
- Shareable/openable DMG verification is covered by Task 4, Task 9, and Task 10.
- Sandbox compatibility matrix gap is covered by Task 5.
- Sparkle inert-vs-enabled decision, EdDSA generation, key custody, public key, feed URL, and appcast gates are covered by Task 6 and Task 10.
- Public version/build origin is covered by Task 2 metadata tests and Task 8 checklist updates.
- Real archive proof is covered by Task 4 unsigned smoke and Task 10 signed rehearsal.
- Release script chain moves beyond dry-run with Task 4 unsigned smoke and Task 10 signed mode.
- Rollback and hotfix rules are covered by Task 7.
- `package-app.sh` is documented as development-only rather than treated as public release infrastructure.
- The plan separates repo-executable work from maintainer-gated credentialed release work.
