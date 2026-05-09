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
- GitHub Releases reference: `https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases`
- GitHub release asset link reference: `https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases`
- GitHub Pages publishing source reference: `https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site`
- Sparkle official setup reference: `https://sparkle-project.org/documentation/`
- Sparkle official customization reference: `https://sparkle-project.org/documentation/customization/`
- Sparkle publishing update reference: `https://sparkle-project.org/documentation/publishing/`

## Recommendation And Tradeoffs

Recommended Public V1 posture:

- Ship a signed, notarized, stapled DMG through GitHub Releases.
- Keep App Sandbox disabled for Public V1 unless the compatibility matrix passes.
- Host Sparkle's stable `appcast.xml` on GitHub Pages at `https://hansdraisma.github.io/whatthetoken/appcast.xml`.
- Point appcast download URLs at the versioned DMG asset on GitHub Releases, for example `https://github.com/hansDraisma/whatthetoken/releases/download/v0.1.0/WhatTheToken-0.1.0.dmg`.
- Ship Sparkle manual update checks in Public V1 once the signed old-build to new-build smoke passes: visible `Check for Updates`, no silent installs, and no automatic background checks.
- Treat the existing `package-app.sh` path as development-only and make that explicit in docs/tests.
- Defer an owned site/custom domain to a Stage 5D roadmap item after Public V1 is stable. GitHub is the simplest correct hosting path now; moving update infrastructure later requires redirect and appcast migration design for already-installed apps.
- Do not add a separate `.app.zip` artifact for Public V1. Keep the support surface to one signed, notarized, stapled DMG until release operations are proven.

Tradeoffs:

- Manual Sparkle checks give users a real update path without first-launch network behavior or silent installs.
- Shipping without App Sandbox reduces platform isolation, but preserves local developer-tool interoperability. Hardened runtime, notarization, explicit connector consent, and public source review carry the Public V1 trust story.
- Requiring a real Xcode archive/export rehearsal before launch costs maintainer time, but it is the only reliable proof that Sparkle helpers, nested code signing, asset catalogs, hardened runtime, and notarization work together.
- Keeping Sparkle private key generation outside the repo prevents automation of one step, but that is the correct security boundary. The repo should document the exact command and custody record; it should not hold private update-signing material.
- GitHub Releases plus GitHub Pages avoids a server for Public V1, but gives up first-party branding, download analytics control, and custom redirect control until the owned-site roadmap item lands.
- A DMG-only release is simpler to test and explain, but users who prefer zip downloads will wait until there is a clear support need.

## Execution Gates

Agent-executable in this workspace:

- Add and wire the public app icon asset catalog.
- Split release guard tests into focused files.
- Add an unsigned Xcode archive smoke script, signed-DMG step, mount/layout verification, and a release rehearsal wrapper.
- Pin Xcode Swift package resolution, verify CPU architectures, capture notarization logs, and enforce clean release provenance.
- Add the simplest GitHub-hosted update channel: GitHub Releases for DMGs, GitHub Pages for `appcast.xml`, and manual Sparkle checks in the app.
- Add sandbox compatibility, Sparkle key custody, rollback, and release docs.
- Update tests so accidental Sparkle/network/appcast behavior cannot slip in.
- Run Swift, TypeScript, plist, scheme, script dry-run, and documentation checks.

Maintainer-gated on the signing machine:

- Run Xcode first-launch setup if `xcodebuild` cannot load required plugins.
- Select and install Developer ID Application certificate access.
- Configure `NOTARY_KEYCHAIN_PROFILE`.
- Generate and custody Sparkle EdDSA private key material in Keychain and a secure backup outside the repo.
- Enable GitHub Pages from the `main` branch `/docs` folder.
- Run real `xcodebuild archive` and `xcodebuild -exportArchive`.
- Notarize, staple, verify Gatekeeper, install from the DMG on a fresh macOS account, publish GitHub Release artifacts, publish `docs/appcast.xml`, and smoke test manual Sparkle update.

## File Structure

- Create: `apps/mac/Tests/WhatTheTokenMacTests/PackagingTestSupport.swift` - shared test helpers for release metadata, project, scripts, and docs.
- Create: `apps/mac/Tests/WhatTheTokenMacTests/MacBundleMetadataTests.swift` - Info.plist, entitlements, versioning, and Sparkle default posture tests.
- Create: `apps/mac/Tests/WhatTheTokenMacTests/MacXcodeProjectTests.swift` - Xcode target, Sparkle package, app icon asset catalog, and project-resource tests.
- Create: `apps/mac/Tests/WhatTheTokenMacTests/MacReleaseScriptTests.swift` - release script shape and secret-safety tests.
- Delete: `apps/mac/Tests/WhatTheTokenMacTests/MacBundleInfoTests.swift` after equivalent coverage has moved into focused files.
- Create: `apps/mac/Sources/WhatTheTokenMac/Assets.xcassets/AppIcon.appiconset/Contents.json` - public macOS app icon catalog.
- Create: `apps/mac/Brand/AppIconSource.prompt.md` - reproducible icon-generation brief.
- Create: `apps/mac/Brand/AppIconSource.png` - 1024x1024 source icon approved for Public V1.
- Create: `apps/mac/Brand/AppIconSource.approval.md` - maintainer approval record and source PNG checksum.
- Create: generated icon PNGs under `apps/mac/Sources/WhatTheTokenMac/Assets.xcassets/AppIcon.appiconset/`.
- Modify: `apps/mac/WhatTheToken.xcodeproj/project.pbxproj` - add the asset catalog file reference and resource build phase entry.
- Modify: `apps/mac/Packaging/Info.plist` - bind the compiled asset catalog icon with `CFBundleIconName = AppIcon`.
- Create: `apps/mac/Packaging/PrivacyInfo.xcprivacy` - privacy manifest for the release app.
- Modify: `apps/mac/Packaging/WhatTheToken-Release.xcconfig` - explicitly build Universal 2 with `ARCHS = arm64 x86_64`.
- Create: `apps/mac/Scripts/smoke-archive-unsigned.sh` - local Xcode archive proof that does not require signing credentials.
- Create: `apps/mac/Scripts/bump-version.sh` - single command to update version/build metadata and prevent accidental build reuse.
- Create: `apps/mac/Scripts/verify-release-provenance.sh` - clean source, exact tag, package-resolution, and release manifest guard.
- Create: `apps/mac/Scripts/sign-dmg.sh` - Developer ID sign and verify the final DMG before notarization.
- Create: `apps/mac/Scripts/rehearse-release.sh` - wrapper for dry-run, unsigned-smoke, and signed release rehearsal flows.
- Modify: `apps/mac/Scripts/verify-release-artifacts.sh` - verify, mount, inspect, checksum, and detach the DMG.
- Modify: `apps/mac/Scripts/notarize-dmg.sh` - capture notary submission JSON and sanitized notary log under ignored build artifacts.
- Modify: `apps/mac/Scripts/package-app.sh` - label it as development-only in output/help comments.
- Create: `apps/mac/WhatTheToken.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` - pinned Xcode Swift package resolution for Sparkle.
- Modify: `apps/mac/Sources/WhatTheTokenMac/AppModel.swift` - own the Sparkle update controller.
- Modify: `apps/mac/Sources/WhatTheTokenMac/WhatTheTokenApp.swift` - pass a manual update action into the popover.
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/Popover/PopoverRootView.swift` - pass manual update action into the footer.
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/Popover/PopoverFooterView.swift` - expose `Check for Updates` after release smoke enables it.
- Create: `docs/.nojekyll` - keep GitHub Pages static for appcast hosting.
- Create: `docs/appcast.xml` - generated Sparkle appcast committed only after release artifact publication.
- Create: `docs/release/app-sandbox-compatibility-matrix.md` - explicit sandbox test matrix and Public V1 unsandboxed decision rule.
- Create: `docs/release/github-hosting-and-updates.md` - exact GitHub Releases plus GitHub Pages hosting model.
- Create: `docs/release/release-notes-template.md` - release notes template with privacy/security sections.
- Create: `docs/release/sparkle-key-custody.md` - Sparkle EdDSA generation, public-key embedding gate, appcast gate, and private-key custody record.
- Create: `docs/release/rollback-and-hotfix.md` - build number, appcast, DMG, and GitHub Release rollback rules.
- Modify: `docs/release/public-v1-checklist.md` - include app icon, sandbox, Sparkle, release rehearsal, rollback, and fresh-machine gates.
- Modify: `README.md` - keep install/update language aligned with manual Public V1 updates and future Sparkle.
- Modify: `.github/workflows/test.yml` - run release plist/scheme/script dry-runs on PRs.
- Modify: `docs/roadmap/development-roadmap.md` - mark Stage 5A repo work versus Stage 5B/5C credentialed work and add a long-term owned-site/custom-domain distribution item.

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
    #expect(releaseConfig.contains("ARCHS = arm64 x86_64"))
    #expect(sharedConfig.contains("CODE_SIGN_ENTITLEMENTS = Packaging/WhatTheToken.entitlements"))
    #expect(releaseConfig.contains("CODE_SIGN_IDENTITY = Developer ID Application"))
    #expect(debugConfig.contains("CODE_SIGNING_ALLOWED = NO"))
    #expect(debugConfig.contains("ENABLE_HARDENED_RUNTIME = NO"))
}

@Test func privacyManifestDeclaresNoTracking() throws {
    let plist = try packagingPlist("Packaging/PrivacyInfo.xcprivacy")

    #expect(plist["NSPrivacyTracking"] as? Bool == false)
    #expect(plist["NSPrivacyTrackingDomains"] as? [String] == [])
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

@Test func xcodeProjectRegistersPrivacyManifestAsResource() throws {
    let project = try macFileContents("WhatTheToken.xcodeproj/project.pbxproj")

    #expect(project.contains("Packaging/PrivacyInfo.xcprivacy"))
    #expect(project.contains("lastKnownFileType = text.plist.xml") || project.contains("lastKnownFileType = text.xml"))
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
    #expect(script.contains("Public releases must use WhatTheToken.xcodeproj"))
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
                "DEVELOPER_ID_TEAM_ID",
                "lipo -verify_arch"
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
                "xcrun notarytool log",
                "--output-format json",
                "xcrun stapler staple",
                "NOTARY_KEYCHAIN_PROFILE"
            ]
        ),
        (
            "sign-dmg.sh",
            [
                "codesign --force --sign",
                "DEVELOPER_ID_SIGNING_IDENTITY",
                "DEVELOPER_ID_SIGNING_IDENTITY is required",
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
                "lipo -verify_arch",
                "CFBundleIconName",
                "Assets.car",
                "Timestamp="
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
                "verify-release-artifacts.sh",
                "step \"1/5 Archive and export\"",
                "test -d",
                "test -f",
                "codesign --verify"
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
- Create: `apps/mac/Packaging/PrivacyInfo.xcprivacy`
- Modify: `apps/mac/WhatTheToken.xcodeproj/project.pbxproj`
- Modify: `apps/mac/Packaging/Info.plist`
- Modify: `apps/mac/Packaging/WhatTheToken-Release.xcconfig`

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

- [ ] **Step 2: Generate and approve the source icon**

Use the `imagegen` skill with the exact prompt from `apps/mac/Brand/AppIconSource.prompt.md`.

Save the candidate 1024x1024 PNG as:

```bash
apps/mac/Brand/AppIconSource.png
```

The maintainer must approve this exact PNG before icon slots are generated. Record the approved file checksum:

```bash
APP_ICON_SHA256="$(shasum -a 256 apps/mac/Brand/AppIconSource.png | awk '{print $1}')"
cat > apps/mac/Brand/AppIconSource.approval.md <<EOF
# App Icon Source Approval

Approved source: apps/mac/Brand/AppIconSource.png
SHA-256: $APP_ICON_SHA256
Approval: maintainer-approved for Public V1
EOF
```

Expected:

- The file is a square PNG.
- The icon contains no readable text, no provider marks, and no Apple marks.
- `apps/mac/Brand/AppIconSource.approval.md` records the SHA-256 of the committed source PNG.

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

Generate unique 24-character hex IDs before editing:

```bash
PROJECT=apps/mac/WhatTheToken.xcodeproj/project.pbxproj
ASSET_FILE_ID="$(uuidgen | tr -d '-' | cut -c1-24)"
ASSET_BUILD_ID="$(uuidgen | tr -d '-' | cut -c1-24)"
rg "$ASSET_FILE_ID|$ASSET_BUILD_ID" "$PROJECT" && exit 65 || true
printf 'ASSET_FILE_ID=%s\nASSET_BUILD_ID=%s\n' "$ASSET_FILE_ID" "$ASSET_BUILD_ID"
```

Use those generated IDs in the following snippets.

Add to `PBXBuildFile`:

```text
		<ASSET_BUILD_ID> = {isa = PBXBuildFile; fileRef = <ASSET_FILE_ID>; };
```

Add to `PBXFileReference`:

```text
		<ASSET_FILE_ID> = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Sources/WhatTheTokenMac/Assets.xcassets; sourceTree = "<group>"; };
```

Add `<ASSET_FILE_ID>` to the `Resources` group children:

```text
				children = (
					00000000000000000000001B,
					<ASSET_FILE_ID>,
				);
```

Add `<ASSET_BUILD_ID>` to the `PBXResourcesBuildPhase` files:

```text
			files = (
				00000000000000000000001C,
				<ASSET_BUILD_ID>,
			);
```

- [ ] **Step 6: Bind the app icon in Info.plist**

In `apps/mac/Packaging/Info.plist`, add this key immediately after `CFBundleExecutable`:

```xml
	<key>CFBundleIconName</key>
	<string>AppIcon</string>
```

This makes the archived app use the compiled asset catalog icon. The archive smoke in Task 4 verifies both `CFBundleIconName` and `Contents/Resources/Assets.car` in the built `.app`.

- [ ] **Step 7: Add Universal 2 release architecture and privacy manifest**

In `apps/mac/Packaging/WhatTheToken-Release.xcconfig`, add:

```xcconfig
ARCHS = arm64 x86_64
```

Create `apps/mac/Packaging/PrivacyInfo.xcprivacy`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
	<key>NSPrivacyCollectedDataTypes</key>
	<array/>
	<key>NSPrivacyAccessedAPITypes</key>
	<array/>
</dict>
</plist>
```

Wire the privacy manifest into `apps/mac/WhatTheToken.xcodeproj/project.pbxproj`.

Generate unique IDs before editing:

```bash
PROJECT=apps/mac/WhatTheToken.xcodeproj/project.pbxproj
PRIVACY_FILE_ID="$(uuidgen | tr -d '-' | cut -c1-24)"
PRIVACY_BUILD_ID="$(uuidgen | tr -d '-' | cut -c1-24)"
rg "$PRIVACY_FILE_ID|$PRIVACY_BUILD_ID" "$PROJECT" && exit 65 || true
printf 'PRIVACY_FILE_ID=%s\nPRIVACY_BUILD_ID=%s\n' "$PRIVACY_FILE_ID" "$PRIVACY_BUILD_ID"
```

Add to `PBXBuildFile`:

```text
		<PRIVACY_BUILD_ID> = {isa = PBXBuildFile; fileRef = <PRIVACY_FILE_ID>; };
```

Add to `PBXFileReference`:

```text
		<PRIVACY_FILE_ID> = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Packaging/PrivacyInfo.xcprivacy; sourceTree = "<group>"; };
```

Add `<PRIVACY_FILE_ID>` to the `Resources` group children, next to the asset catalog file reference.

Add `<PRIVACY_BUILD_ID>` to the `PBXResourcesBuildPhase` files, next to the asset catalog build file.

Run:

```bash
plutil -lint apps/mac/Packaging/PrivacyInfo.xcprivacy
```

Expected:

- The privacy manifest is valid XML plist.
- The release build explicitly targets both `arm64` and `x86_64`.
- The Xcode app target copies the privacy manifest into the app bundle resources.

- [ ] **Step 8: Verify icon and privacy manifest tests**

Run:

```bash
cd apps/mac
swift test --filter MacXcodeProjectTests
cd ../..
```

Expected:

- `MacXcodeProjectTests` passes.

- [ ] **Step 9: Verify project syntax**

Run:

```bash
plutil -lint apps/mac/WhatTheToken.xcodeproj/project.pbxproj
```

Expected:

```text
apps/mac/WhatTheToken.xcodeproj/project.pbxproj: OK
```

- [ ] **Step 10: Commit checkpoint**

Run:

```bash
git add apps/mac/Brand apps/mac/Sources/WhatTheTokenMac/Assets.xcassets apps/mac/Packaging/Info.plist apps/mac/Packaging/PrivacyInfo.xcprivacy apps/mac/Packaging/WhatTheToken-Release.xcconfig apps/mac/WhatTheToken.xcodeproj/project.pbxproj apps/mac/Tests/WhatTheTokenMacTests
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
BINARY_PATH="$APP_PATH/Contents/MacOS/WhatTheTokenMac"

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
lipo -verify_arch arm64 x86_64 "$BINARY_PATH"

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
SIGNING_IDENTITY="${DEVELOPER_ID_SIGNING_IDENTITY:-}"
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

if [[ "$DRY_RUN" -eq 0 && -z "$SIGNING_IDENTITY" ]]; then
    printf 'DEVELOPER_ID_SIGNING_IDENTITY is required for DMG signing. Use the exact certificate name, for example "Developer ID Application: Hans Draisma (TEAMID)".\n' >&2
    exit 65
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
    if [[ "$DRY_RUN" -eq 0 ]]; then
        codesign -dv --verbose=4 "$APP_PATH" 2>&1 | rg "Timestamp="
    else
        quote_command codesign -dv --verbose=4 "$APP_PATH" "2>&1" "|" rg "Timestamp="
    fi
    run_command spctl -a -vv -t exec "$APP_PATH"
fi

run_command hdiutil verify "$DMG_PATH"
if [[ "$DRY_RUN" -eq 0 ]]; then
    codesign -dv --verbose=4 "$DMG_PATH" 2>&1 | rg "Timestamp="
else
    quote_command codesign -dv --verbose=4 "$DMG_PATH" "2>&1" "|" rg "Timestamp="
fi
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
    codesign -dv --verbose=4 "$COPY_DIR/WhatTheToken.app" 2>&1 | rg "Timestamp="
    spctl -a -vv -t exec "$COPY_DIR/WhatTheToken.app"
    /usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$COPY_DIR/WhatTheToken.app/Contents/Info.plist" | grep -Fx "AppIcon" >/dev/null
    test -f "$COPY_DIR/WhatTheToken.app/Contents/Resources/Assets.car"
    lipo -verify_arch arm64 x86_64 "$COPY_DIR/WhatTheToken.app/Contents/MacOS/WhatTheTokenMac"
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

step() {
    printf '[%s]\n' "$1"
}

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
        APP_PATH="$ROOT_DIR/.build/export/WhatTheToken.app"
        DMG_PATH="$ROOT_DIR/.build/dmg/WhatTheToken-$VERSION.dmg"

        step "1/5 Archive and export"
        "$ROOT_DIR/Scripts/archive-release.sh" --version "$VERSION" --build "$BUILD"
        test -d "$APP_PATH"
        test -f "$APP_PATH/Contents/Info.plist"
        test -f "$APP_PATH/Contents/MacOS/WhatTheTokenMac"
        lipo -verify_arch arm64 x86_64 "$APP_PATH/Contents/MacOS/WhatTheTokenMac"

        step "2/5 Create DMG"
        "$ROOT_DIR/Scripts/create-dmg.sh" --version "$VERSION"
        test -f "$DMG_PATH"
        hdiutil verify "$DMG_PATH" >/dev/null

        step "3/5 Sign DMG"
        "$ROOT_DIR/Scripts/sign-dmg.sh" --dmg "$DMG_PATH"
        codesign --verify --verbose=2 "$DMG_PATH"

        step "4/5 Notarize and staple"
        "$ROOT_DIR/Scripts/notarize-dmg.sh" --dmg "$DMG_PATH"
        xcrun stapler validate "$DMG_PATH"

        step "5/5 Verify release artifacts"
        "$ROOT_DIR/Scripts/verify-release-artifacts.sh" \
            --dmg "$DMG_PATH" \
            --app "$APP_PATH"
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

### Task 6: Document Sparkle Key Custody And Manual Public V1 Updates

**Files:**
- Create: `docs/release/sparkle-key-custody.md`
- Modify: `docs/release/public-v1-checklist.md`
- Modify: `README.md`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/MacBundleMetadataTests.swift`

- [ ] **Step 1: Create Sparkle custody doc**

Create `docs/release/sparkle-key-custody.md`:

````markdown
# Sparkle Key Custody

Public V1 includes Sparkle with manual update checks:

- `SUEnableAutomaticChecks` is `false`.
- `SUAutomaticallyUpdate` is `false`.
- `Check for Updates` is visible after the signed old-build to new-build update smoke passes.
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

Public V1 uses manual Sparkle checks after the signed update path has passed. See `docs/release/sparkle-key-custody.md` and `docs/release/github-hosting-and-updates.md`.

Before adding `SUPublicEDKey`:

```bash
SPARKLE_BIN_DIR="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*/SourcePackages/artifacts/sparkle/Sparkle/bin' -type d -print -quit)"
test -n "$SPARKLE_BIN_DIR"
"$SPARKLE_BIN_DIR/generate_keys"
```

Before adding `SUFeedURL`:

- Confirm GitHub Pages is enabled from `main` branch `/docs`.
- Confirm the URL is not a local path, private attachment URL, release-candidate URL, or internal workspace URL.

Generate an appcast entry only after a signed old-build to signed new-build update smoke test passes:

```bash
apps/mac/Scripts/generate-appcast.sh \
  --updates-dir "$HOME/ReleaseArtifacts/WhatTheToken/updates" \
  --output docs/appcast.xml \
  --download-url-prefix https://github.com/hansDraisma/whatthetoken/releases/download/v0.1.0/ \
  --release-notes-url https://github.com/hansDraisma/whatthetoken/releases/tag/v0.1.0
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
Public V1 ships as a signed and notarized DMG attached to GitHub Releases. Updates use a manual Sparkle check from the menu bar popover. The Sparkle appcast is hosted on GitHub Pages at `https://hansdraisma.github.io/whatthetoken/appcast.xml`; the appcast points to versioned DMG assets on GitHub Releases. Automatic background checks and silent installs remain disabled.
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

Stage 5D owned distribution remains a later refinement: evaluate a product site, custom domain, analytics-free download page, redirect policy, and appcast migration after Public V1 is stable on GitHub-hosted infrastructure.

V1.x follow-up: extend the existing About panel with build commit, Sparkle version, and license attribution.
```

- [ ] **Step 5: Verify roadmap/checklist sync**

Run:

```bash
rg -n "Stage 5A|Stage 5B|Stage 5C|Stage 5D|owned distribution|unsigned-smoke|rollback-and-hotfix|sparkle-key-custody|app-sandbox-compatibility-matrix" docs/release/public-v1-checklist.md docs/roadmap/development-roadmap.md docs/superpowers/specs/2026-05-09-distribution-hardening-design.md
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

### Task 9: GitHub Hosting, Provenance, And Manual Sparkle Updates

**Files:**
- Create: `docs/.nojekyll`
- Create: `docs/release/github-hosting-and-updates.md`
- Create: `docs/release/release-notes-template.md`
- Create after release artifact publication: `docs/appcast.xml`
- Create: `apps/mac/Scripts/bump-version.sh`
- Create: `apps/mac/Scripts/verify-release-provenance.sh`
- Modify: `.github/workflows/test.yml`
- Modify: `apps/mac/Scripts/archive-release.sh`
- Modify: `apps/mac/Scripts/notarize-dmg.sh`
- Modify: `apps/mac/Scripts/rehearse-release.sh`
- Modify: `apps/mac/Scripts/verify-release-artifacts.sh`
- Modify: `apps/mac/Packaging/Info.plist`
- Modify: `apps/mac/Sources/WhatTheTokenMac/Updates/SparkleUpdateController.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/AppModel.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/WhatTheTokenApp.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/Popover/PopoverRootView.swift`
- Modify: `apps/mac/Sources/WhatTheTokenMac/Views/Popover/PopoverFooterView.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/MacBundleMetadataTests.swift`
- Modify: `apps/mac/Tests/WhatTheTokenMacTests/MacReleaseScriptTests.swift`

- [ ] **Step 1: Document the simplest hosting model**

Create `docs/.nojekyll` as an empty file.

Create `docs/release/github-hosting-and-updates.md`:

```markdown
# GitHub Hosting And Updates

WhatTheToken uses GitHub only for Public V1 distribution:

- GitHub Releases hosts the signed, notarized, stapled DMG.
- GitHub Pages hosts Sparkle's stable appcast feed.
- No separate server is required.

## Public URLs

- Download page: `https://github.com/hansDraisma/whatthetoken/releases`
- Versioned DMG asset pattern: `https://github.com/hansDraisma/whatthetoken/releases/download/v<version>/WhatTheToken-<version>.dmg`
- Sparkle appcast: `https://hansdraisma.github.io/whatthetoken/appcast.xml`

Use `hansDraisma` for GitHub repository URLs and `hansdraisma.github.io` for GitHub Pages URLs. Do not introduce lowercase `github.com/hansdraisma/...` links or mixed-case Pages hostnames.

## GitHub Pages Setup

In GitHub repository settings, enable Pages with:

- Source: `Deploy from a branch`
- Branch: `main`
- Folder: `/docs`

GitHub Pages must be enabled before shipping a build whose `SUFeedURL` points to `https://hansdraisma.github.io/whatthetoken/appcast.xml`.

## Release Flow

1. Build and verify `WhatTheToken-<version>.dmg`.
2. Publish a GitHub Release tagged `v<version>`.
3. Attach `WhatTheToken-<version>.dmg` and `WhatTheToken-<version>.dmg.sha256`.
4. Stage the same DMG in a local update directory.
5. Run Sparkle `generate_appcast` with the GitHub Release asset URL prefix for that version.
6. Commit the generated appcast as `docs/appcast.xml`.
7. Wait for GitHub Pages to publish the new appcast.
8. Install the previous signed build and use `Check for Updates` to verify the app sees the new release.

## Public V1 Update Behavior

Public V1 ships with manual Sparkle checks enabled:

- `SUFeedURL` points to GitHub Pages.
- `SUPublicEDKey` contains the public EdDSA key generated by the maintainer.
- `SUEnableAutomaticChecks` remains `false`.
- `SUAutomaticallyUpdate` remains `false`.
- The user chooses `Check for Updates` from the menu bar popover.

The first public DMG cannot update to itself. It must include the feed URL and public key so it can update to the next release.
```

- [ ] **Step 2: Pin Xcode Swift package resolution**

Run on an initialized Xcode installation:

```bash
xcodebuild -resolvePackageDependencies \
  -project apps/mac/WhatTheToken.xcodeproj \
  -scheme WhatTheToken
test -f apps/mac/WhatTheToken.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
rg -n '"identity" : "sparkle"|"location" : "https://github.com/sparkle-project/Sparkle"' apps/mac/WhatTheToken.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

Expected:

- `Package.resolved` exists.
- It records Sparkle and the exact resolved version/revision.

- [ ] **Step 3: Add version bump tooling and release notes template**

Create `docs/release/release-notes-template.md`:

```markdown
# WhatTheToken <version>

## Download

- DMG: <GitHub Release DMG URL>
- SHA-256: <GitHub Release checksum URL>
- Appcast: https://hansdraisma.github.io/whatthetoken/appcast.xml

## Verification

- Developer ID signed app: passed
- Developer ID signed DMG: passed
- Notarized and stapled DMG: passed
- Gatekeeper app assessment: passed
- Gatekeeper DMG assessment: passed
- Fresh macOS account install: passed
- Manual Sparkle update smoke: passed, if this release updates an earlier public build

## Changes

- <user-facing change>

## Privacy And Security

- No prompts, responses, cookies, auth headers, or provider tokens are collected for release diagnostics.
- Automatic Sparkle background checks remain disabled.
- Manual update checks use the public appcast URL only when the user chooses `Check for Updates`.

## Dependencies

- Sparkle: <resolved version from Package.resolved>

## Localization

- Public V1 interface language: English.

## Known Issues

- <known issue or "None">

## Support

- Share sanitized crash reports and diagnostics only.
- Do not share raw provider files, prompts, responses, cookies, auth headers, tokens, or private key material.
```

Create `apps/mac/Scripts/bump-version.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT_DIR/Packaging/WhatTheToken.xcconfig"
VERSION=""
BUILD=""

usage() {
    printf 'Usage: %s --version <version> --build <monotonic-integer>\n' "$0"
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

if ! [[ "$BUILD" =~ ^[0-9]+$ ]]; then
    printf 'Build must be a monotonically increasing integer.\n' >&2
    exit 64
fi

CURRENT_BUILD="$(awk -F= '/^[[:space:]]*CURRENT_PROJECT_VERSION[[:space:]]*=/{gsub(/[[:space:]]/, "", $2); print $2}' "$CONFIG")"
if [[ -n "$CURRENT_BUILD" && "$CURRENT_BUILD" =~ ^[0-9]+$ && "$BUILD" -le "$CURRENT_BUILD" ]]; then
    printf 'Build must increase. Current build is %s, requested %s.\n' "$CURRENT_BUILD" "$BUILD" >&2
    exit 65
fi

perl -0pi -e "s/\\nMARKETING_VERSION = .*\\n/\\nMARKETING_VERSION = $VERSION\\n/" "$CONFIG"
perl -0pi -e "s/\\nCURRENT_PROJECT_VERSION = .*\\n/\\nCURRENT_PROJECT_VERSION = $BUILD\\n/" "$CONFIG"

rg -n "MARKETING_VERSION = $VERSION|CURRENT_PROJECT_VERSION = $BUILD" "$CONFIG"
```

Make the script executable:

```bash
chmod +x apps/mac/Scripts/bump-version.sh
```

Expected:

- Version and build metadata have one source of truth: `apps/mac/Packaging/WhatTheToken.xcconfig`.
- Public release candidates never reuse an equal or lower build number.
- Release notes consistently include download, verification, privacy, security, and known-issue fields.

- [ ] **Step 4: Add release provenance script**

Create `apps/mac/Scripts/verify-release-provenance.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
VERSION=""
BUILD=""

usage() {
    printf 'Usage: %s --version <version> --build <build>\n' "$0"
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

cd "$REPO_ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
    printf 'Release source must be clean before creating public artifacts.\n' >&2
    git status --short >&2
    exit 65
fi

TAG="v$VERSION"
HEAD_SHA="$(git rev-parse HEAD)"
TAG_SHA="$(git rev-list -n 1 "refs/tags/$TAG")"

if [[ "$HEAD_SHA" != "$TAG_SHA" ]]; then
    printf 'Release tag %s does not point at HEAD.\n' "$TAG" >&2
    exit 65
fi

git verify-tag "$TAG" >/dev/null 2>&1 || {
    printf 'Release tag %s must be signed and verifiable on the release machine.\n' "$TAG" >&2
    exit 65
}

PACKAGE_RESOLVED="$ROOT_DIR/WhatTheToken.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
if [[ ! -f "$PACKAGE_RESOLVED" ]]; then
    printf 'Package.resolved is required for release reproducibility: %s\n' "$PACKAGE_RESOLVED" >&2
    exit 66
fi

rg -n '"identity" : "sparkle"|"location" : "https://github.com/sparkle-project/Sparkle"' "$PACKAGE_RESOLVED" >/dev/null

MANIFEST_DIR="$ROOT_DIR/.build/release-manifests"
mkdir -p "$MANIFEST_DIR"
MANIFEST="$MANIFEST_DIR/WhatTheToken-$VERSION-build-$BUILD.txt"
PACKAGE_RESOLVED_SHA="$(shasum -a 256 "$PACKAGE_RESOLVED" | awk '{print $1}')"

{
    printf 'version=%s\n' "$VERSION"
    printf 'build=%s\n' "$BUILD"
    printf 'tag=%s\n' "$TAG"
    printf 'commit=%s\n' "$HEAD_SHA"
    printf 'package_resolved_sha256=%s\n' "$PACKAGE_RESOLVED_SHA"
} > "$MANIFEST"

printf '%s\n' "$MANIFEST"
```

- [ ] **Step 5: Call provenance and verify Universal 2 in release scripts**

In `apps/mac/Scripts/archive-release.sh`, after the real export command succeeds and before printing the app path, add:

```bash
if [[ "$DRY_RUN" -eq 0 ]]; then
    lipo -verify_arch arm64 x86_64 "$EXPORT_DIR/WhatTheToken.app/Contents/MacOS/WhatTheTokenMac"
fi
```

In `apps/mac/Scripts/rehearse-release.sh`, update the `signed)` block to include release provenance as an explicit first step and keep artifact checks between every release command:

```bash
    signed)
        APP_PATH="$ROOT_DIR/.build/export/WhatTheToken.app"
        DMG_PATH="$ROOT_DIR/.build/dmg/WhatTheToken-$VERSION.dmg"

        step "1/6 Verify release provenance"
        "$ROOT_DIR/Scripts/verify-release-provenance.sh" --version "$VERSION" --build "$BUILD"

        step "2/6 Archive and export"
        "$ROOT_DIR/Scripts/archive-release.sh" --version "$VERSION" --build "$BUILD"
        test -d "$APP_PATH"
        test -f "$APP_PATH/Contents/Info.plist"
        test -f "$APP_PATH/Contents/MacOS/WhatTheTokenMac"
        lipo -verify_arch arm64 x86_64 "$APP_PATH/Contents/MacOS/WhatTheTokenMac"

        step "3/6 Create DMG"
        "$ROOT_DIR/Scripts/create-dmg.sh" --version "$VERSION"
        test -f "$DMG_PATH"
        hdiutil verify "$DMG_PATH" >/dev/null

        step "4/6 Sign DMG"
        "$ROOT_DIR/Scripts/sign-dmg.sh" --dmg "$DMG_PATH"
        codesign --verify --verbose=2 "$DMG_PATH"

        step "5/6 Notarize and staple"
        "$ROOT_DIR/Scripts/notarize-dmg.sh" --dmg "$DMG_PATH"
        xcrun stapler validate "$DMG_PATH"

        step "6/6 Verify release artifacts"
        "$ROOT_DIR/Scripts/verify-release-artifacts.sh" \
            --dmg "$DMG_PATH" \
            --app "$APP_PATH"
        ;;
```

Expected:

- `signed` mode prints a clear step banner before every major release operation.
- A missing app, binary, Info.plist, DMG, architecture slice, DMG signature, or stapled ticket fails immediately instead of being discovered at the end.

- [ ] **Step 6: Capture notary submission logs**

In `apps/mac/Scripts/notarize-dmg.sh`, add this variable near the top:

```bash
NOTARY_LOG_DIR="${NOTARY_LOG_DIR:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.build/notary"}"
```

Replace the real submit/staple execution block with:

```bash
if [[ "$DRY_RUN" -eq 1 ]]; then
    run_command "${submit_command[@]}"
    run_command "${staple_command[@]}"
    run_command "${validate_command[@]}"
    printf 'Dry run only. No notarization request was submitted.\n'
    exit 0
fi

mkdir -p "$NOTARY_LOG_DIR"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
submit_json="$NOTARY_LOG_DIR/notary-submit-$timestamp.json"

xcrun notarytool submit "$DMG_PATH" --keychain-profile "$KEYCHAIN_PROFILE" --wait --output-format json | tee "$submit_json"
submission_id="$(plutil -extract id raw -o - "$submit_json")"
log_json="$NOTARY_LOG_DIR/notary-log-$submission_id.json"
xcrun notarytool log "$submission_id" --keychain-profile "$KEYCHAIN_PROFILE" > "$log_json"

"${staple_command[@]}"
"${validate_command[@]}"
printf '%s\n' "$log_json"
```

- [ ] **Step 7: Embed Sparkle feed URL and public EdDSA key**

After the maintainer runs Sparkle `generate_keys`, copy only the printed public key to the clipboard. Then run:

```bash
PUBLIC_ED_KEY="$(pbpaste | tr -d '\n')"
test -n "$PUBLIC_ED_KEY"
printf '%s' "$PUBLIC_ED_KEY" | rg '^[A-Za-z0-9+/=]+$' >/dev/null
/usr/libexec/PlistBuddy -c 'Delete :SUFeedURL' apps/mac/Packaging/Info.plist 2>/dev/null || true
/usr/libexec/PlistBuddy -c 'Delete :SUPublicEDKey' apps/mac/Packaging/Info.plist 2>/dev/null || true
/usr/libexec/PlistBuddy -c 'Add :SUFeedURL string https://hansdraisma.github.io/whatthetoken/appcast.xml' apps/mac/Packaging/Info.plist
/usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $PUBLIC_ED_KEY" apps/mac/Packaging/Info.plist
plutil -lint apps/mac/Packaging/Info.plist
```

Expected:

- `Info.plist` contains `SUFeedURL`.
- `Info.plist` contains `SUPublicEDKey`.
- `SUEnableAutomaticChecks` remains `false`.
- `SUAutomaticallyUpdate` remains `false`.

- [ ] **Step 8: Guard and expose manual Check for Updates**

Modify `apps/mac/Sources/WhatTheTokenMac/Updates/SparkleUpdateController.swift` so manual checks are a no-op until the release build has both `SUFeedURL` and `SUPublicEDKey`:

```swift
private var hasUpdateMetadata: Bool {
    let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
    let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
    return feedURL?.isEmpty == false && publicKey?.isEmpty == false
}

func checkForUpdates(_ sender: Any? = nil) {
    guard hasUpdateMetadata else { return }
    startUpdaterIfNeeded()
    guard updaterController.updater.canCheckForUpdates else { return }
    updaterController.checkForUpdates(sender)
}

var canCheckForUpdates: Bool {
    hasUpdateMetadata && (!hasStartedUpdater || updaterController.updater.canCheckForUpdates)
}
```

Expected:

- Development builds or partially configured release builds do not start Sparkle or show Sparkle errors when feed metadata is absent.
- Public V1 still exposes a manual update check once `SUFeedURL` and `SUPublicEDKey` are embedded.

Modify `apps/mac/Sources/WhatTheTokenMac/AppModel.swift`:

```swift
@MainActor
@Observable
final class AppModel {
    let viewModel: StatusViewModel
    let refreshController: PopoverRefreshController
    let backgroundRefreshController: BackgroundRefreshController
    let updateController: SparkleUpdateController

    init(
        viewModel: StatusViewModel,
        updateController: SparkleUpdateController = SparkleUpdateController()
    ) {
        self.viewModel = viewModel
        self.refreshController = PopoverRefreshController(viewModel: viewModel)
        let backgroundRefreshController = BackgroundRefreshController(viewModel: viewModel)
        self.backgroundRefreshController = backgroundRefreshController
        self.updateController = updateController
        self.viewModel.onSettingsChanged = { [weak backgroundRefreshController] in
            backgroundRefreshController?.settingsDidChange()
        }
        Task {
            await viewModel.loadPersistedState()
            backgroundRefreshController.start()
        }
    }
```

If this branch is rebased onto `origin/main`, preserve the fetched notification/background-refresh structure exactly: `notificationStateStore`, `notificationDelivery`, `BackgroundRefreshController`, `onSettingsChanged`, and the smoke-command path that avoids constructing the live app model must remain intact. Add only the Sparkle `updateController` and manual check action.

Modify the `PopoverRootView` call in `apps/mac/Sources/WhatTheTokenMac/WhatTheTokenApp.swift`:

```swift
PopoverRootView(
    viewModel: app.viewModel,
    controller: app.refreshController,
    onOpenSettings: openSettingsAction,
    onCheckForUpdates: { app.updateController.checkForUpdates(nil) },
    onOpenDeveloperWindow: developerWindowOpener
)
```

Modify `apps/mac/Sources/WhatTheTokenMac/Views/Popover/PopoverRootView.swift`:

```swift
let onCheckForUpdates: () -> Void
```

and pass it to the footer:

```swift
PopoverFooterView(
    state: footerState,
    onRefresh: { controller.userTappedRefresh() },
    onOpenSettings: onOpenSettings,
    onCheckForUpdates: onCheckForUpdates,
    onOpenDeveloperWindow: onOpenDeveloperWindow
)
```

Modify `apps/mac/Sources/WhatTheTokenMac/Views/Popover/PopoverFooterView.swift`:

```swift
let onCheckForUpdates: () -> Void
```

Add this menu item above `Settings...`:

```swift
Button("Check for Updates", action: onCheckForUpdates)
Divider()
```

- [ ] **Step 9: Add update-hosting tests**

In `apps/mac/Tests/WhatTheTokenMacTests/MacBundleMetadataTests.swift`, add:

```swift
@Test func publicReleaseEmbedsSparkleFeedAndPublicKey() throws {
    let plist = try packagingInfoPlist()

    #expect(plist["SUFeedURL"] as? String == "https://hansdraisma.github.io/whatthetoken/appcast.xml")
    let publicKey = try #require(plist["SUPublicEDKey"] as? String)
    #expect(publicKey.count >= 32)
    #expect(!publicKey.contains("$("))
    #expect(plist["SUEnableAutomaticChecks"] as? Bool == false)
    #expect(plist["SUAutomaticallyUpdate"] as? Bool == false)
}
```

In `apps/mac/Tests/WhatTheTokenMacTests/MacXcodeProjectTests.swift`, add:

```swift
@Test func sparkleManualCheckIsGuardedUntilReleaseMetadataExists() throws {
    let source = try macFileContents("Sources/WhatTheTokenMac/Updates/SparkleUpdateController.swift")

    #expect(source.contains("hasUpdateMetadata"))
    #expect(source.contains("SUFeedURL"))
    #expect(source.contains("SUPublicEDKey"))
    #expect(source.contains("guard hasUpdateMetadata else { return }"))
    #expect(source.contains("guard updaterController.updater.canCheckForUpdates else { return }"))
}

@Test func xcodeSwiftPackageResolutionPinsSparkle() throws {
    let resolved = try macFileContents("WhatTheToken.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved")

    #expect(resolved.contains("\"sparkle\"") || resolved.contains("sparkle-project/Sparkle"))
    #expect(resolved.contains("\"version\""))
    #expect(resolved.contains("\"revision\""))
}
```

In `apps/mac/Tests/WhatTheTokenMacTests/MacXcodeProjectTests.swift`, add:

```swift
@Test func popoverMenuExposesManualUpdateCheck() throws {
    let appSource = try macFileContents("Sources/WhatTheTokenMac/WhatTheTokenApp.swift")
    let rootSource = try macFileContents("Sources/WhatTheTokenMac/Views/Popover/PopoverRootView.swift")
    let footerSource = try macFileContents("Sources/WhatTheTokenMac/Views/Popover/PopoverFooterView.swift")

    #expect(appSource.contains("updateController.checkForUpdates"))
    #expect(rootSource.contains("onCheckForUpdates"))
    #expect(footerSource.contains("Button(\"Check for Updates\""))
}
```

In `apps/mac/Tests/WhatTheTokenMacTests/MacReleaseScriptTests.swift`, update the release script table:

- Add `bump-version.sh` with required fragments `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`, and `Build must increase`.
- Add `verify-release-provenance.sh` with required fragments `git status --porcelain`, `git rev-parse HEAD`, `git rev-list -n 1 "refs/tags/$TAG"`, `git verify-tag`, and `Package.resolved`.
- Replace the `rehearse-release.sh` step expectation from `step "1/5 Archive and export"` to `step "1/6 Verify release provenance"`.
- Add `verify-release-provenance.sh`, `test -d`, `test -f`, `lipo -verify_arch`, `codesign --verify`, and `xcrun stapler validate` as required `rehearse-release.sh` fragments.

In `.github/workflows/test.yml`, add a PR smoke step for release metadata and dry-run commands on macOS:

```yaml
      - name: Validate mac release metadata
        run: |
          plutil -lint apps/mac/Packaging/Info.plist
          plutil -lint apps/mac/Packaging/ExportOptions.DeveloperID.plist
          plutil -lint apps/mac/Packaging/WhatTheToken.entitlements
          plutil -lint apps/mac/Packaging/PrivacyInfo.xcprivacy
          plutil -lint apps/mac/WhatTheToken.xcodeproj/project.pbxproj
          xmllint --noout apps/mac/WhatTheToken.xcodeproj/xcshareddata/xcschemes/WhatTheToken.xcscheme
          apps/mac/Scripts/rehearse-release.sh --version 0.1.0 --build 1 --mode dry-run
          apps/mac/Scripts/generate-appcast.sh --dry-run --updates-dir /tmp/whatthetoken-updates --download-url-prefix https://github.com/hansDraisma/whatthetoken/releases/download/v0.1.0/
```

Expected:

- PR checks catch broken plist XML, project syntax, release script dry-runs, privacy manifest syntax, and stale release command wiring.
- CI never needs Developer ID, notary, or Sparkle private key credentials.

- [ ] **Step 10: Generate the public appcast after the GitHub Release asset exists**

Run this after Task 11 has produced the signed/notarized DMG and after the GitHub Release asset is uploaded. The appcast must reference a public asset URL that an installed app can download without GitHub authentication.

After publishing the GitHub Release and uploading the DMG asset, run:

```bash
mkdir -p "$HOME/ReleaseArtifacts/WhatTheToken/updates"
cp apps/mac/.build/dmg/WhatTheToken-0.1.0.dmg "$HOME/ReleaseArtifacts/WhatTheToken/updates/WhatTheToken-0.1.0.dmg"
apps/mac/Scripts/generate-appcast.sh \
  --updates-dir "$HOME/ReleaseArtifacts/WhatTheToken/updates" \
  --output docs/appcast.xml \
  --download-url-prefix https://github.com/hansDraisma/whatthetoken/releases/download/v0.1.0/ \
  --release-notes-url https://github.com/hansDraisma/whatthetoken/releases/tag/v0.1.0
xmllint --noout docs/appcast.xml
rg -n "sparkle:edSignature|WhatTheToken-0.1.0.dmg|github.com/hansDraisma/whatthetoken/releases/download/v0.1.0" docs/appcast.xml
```

Expected:

- `docs/appcast.xml` is valid XML.
- The appcast points at the public GitHub Release DMG asset.
- The appcast contains a Sparkle EdDSA signature.

- [ ] **Step 11: Commit checkpoint**

Run:

```bash
git add .github/workflows/test.yml docs/.nojekyll docs/release/github-hosting-and-updates.md docs/release/release-notes-template.md apps/mac
git commit -m "build(mac): add GitHub-hosted Sparkle update channel"
```

Do not commit `docs/appcast.xml` in this checkpoint. Commit it only after the public GitHub Release asset exists and Task 11 completes the appcast generation and manual update smoke.

---

### Task 10: Full Repo-Side Verification

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
plutil -lint apps/mac/Packaging/PrivacyInfo.xcprivacy
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
apps/mac/Scripts/generate-appcast.sh --dry-run --updates-dir /tmp/whatthetoken-updates --download-url-prefix https://github.com/hansDraisma/whatthetoken/releases/download/v0.1.0/
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
rg -n "conductor|workspaces|\\.context|BEGIN .*PRIVATE KEY|--password|--apple-id|example[.]com|/tmp/|/Users/" README.md docs/release docs/superpowers/specs/2026-05-09-distribution-hardening-design.md docs/roadmap/development-roadmap.md
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

### Task 11: Maintainer-Gated Credentialed Release Rehearsal

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
: "${DEVELOPER_ID_SIGNING_IDENTITY:?Set DEVELOPER_ID_SIGNING_IDENTITY to the exact Developer ID Application identity, including team suffix}"
: "${NOTARY_KEYCHAIN_PROFILE:?Set NOTARY_KEYCHAIN_PROFILE to the existing notarytool Keychain profile name in this shell}"
security find-certificate -c "$DEVELOPER_ID_SIGNING_IDENTITY" -p | openssl x509 -noout -enddate
xcrun notarytool history --keychain-profile "$NOTARY_KEYCHAIN_PROFILE"
```

Expected:

- At least one Developer ID Application identity appears.
- `DEVELOPER_ID_SIGNING_IDENTITY` is the exact intended Developer ID Application identity for DMG signing.
- The Developer ID Application certificate does not expire within the next 30 days.
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

- Complete Task 9 Step 7.
- Keep automatic checks and automatic update installs disabled.

- [ ] **Step 4: Create and verify the signed release tag**

Maintainer runs after repo-side verification passes and before creating public artifacts:

```bash
git status --porcelain
test -z "$(git status --porcelain)"
git tag -s v0.1.0 -m "WhatTheToken 0.1.0"
git verify-tag v0.1.0
test "$(git rev-parse HEAD)" = "$(git rev-list -n 1 refs/tags/v0.1.0)"
```

Expected:

- The working tree is clean.
- The release tag is signed.
- The release tag points exactly at `HEAD`.
- Do not push the tag until the signed rehearsal and fresh install smoke pass.

- [ ] **Step 5: Run signed release rehearsal**

Maintainer runs:

```bash
: "${DEVELOPER_ID_TEAM_ID:?Set DEVELOPER_ID_TEAM_ID to the Apple Developer Team ID in this shell}"
: "${NOTARY_KEYCHAIN_PROFILE:?Set NOTARY_KEYCHAIN_PROFILE to the existing notarytool Keychain profile name in this shell}"
: "${DEVELOPER_ID_SIGNING_IDENTITY:?Set DEVELOPER_ID_SIGNING_IDENTITY to the exact Developer ID Application identity, including team suffix}"
apps/mac/Scripts/rehearse-release.sh --version 0.1.0 --build 1 --mode signed
```

The three shell-session values are maintainer-machine configuration. They are not committed.

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
- Copied app binary contains both `arm64` and `x86_64`.
- Notary submission JSON and notary log JSON are saved under `apps/mac/.build/notary`.
- DMG checksum is created.

- [ ] **Step 6: Fresh macOS account smoke**

Maintainer verifies:

- Copy the final DMG to `~/Downloads/WhatTheToken-0.1.0.dmg`.
- Add a download-style quarantine attribute as a local approximation of browser download quarantine:

```bash
DOWNLOADED_DMG="$HOME/Downloads/WhatTheToken-0.1.0.dmg"
cp apps/mac/.build/dmg/WhatTheToken-0.1.0.dmg "$DOWNLOADED_DMG"
QUARANTINE_TIME="$(printf %x "$(date +%s)")"
xattr -w com.apple.quarantine "0081;$QUARANTINE_TIME;Safari;https://github.com/hansDraisma/whatthetoken/releases/download/v0.1.0/WhatTheToken-0.1.0.dmg" "$DOWNLOADED_DMG"
open "$DOWNLOADED_DMG"
```

- After the GitHub Release asset is published, repeat this install smoke with the actual DMG downloaded through a browser from `https://github.com/hansDraisma/whatthetoken/releases/download/v0.1.0/WhatTheToken-0.1.0.dmg`. The `xattr` simulation is not a substitute for one real browser download.
- Install from the notarized DMG into `/Applications`.
- Launch from Finder.
- Menu bar item appears.
- Dock icon stays hidden.
- Settings open.
- Primary controls are reachable by keyboard and understandable with VoiceOver.
- Quit works.
- Launch at login defaults off.
- Launch at login toggles only by explicit user action.
- Claude Code remains disconnected until explicit connection.
- Codex remains disconnected until explicit connection.
- Disconnect removes provider cache.
- Relaunch preserves settings and sanitized cache only.
- `Check for Updates` is visible in the menu bar popover.
- `Check for Updates` reads `https://hansdraisma.github.io/whatthetoken/appcast.xml`.
- A previous signed build can update to the new signed/notarized build after `docs/appcast.xml` publishes through GitHub Pages.
- First launch makes no network request before explicit user action.
- No background update network request occurs.
- The only update network request happens after choosing `Check for Updates`.

- [ ] **Step 7: Public launch gate**

Proceed to GitHub Release publication only after the signed rehearsal and local fresh-account smoke pass. If any item fails after an artifact reached an external tester, increment `CURRENT_PROJECT_VERSION` before the next candidate.

After the gate passes:

```bash
git push origin v0.1.0
```

Then create the GitHub Release for `v0.1.0`, upload `WhatTheToken-0.1.0.dmg`, upload `WhatTheToken-0.1.0.dmg.sha256`, publish release notes from `docs/release/release-notes-template.md`, generate `docs/appcast.xml` from the published GitHub Release asset, and commit the generated appcast:

```bash
git add docs/appcast.xml
git commit -m "release: publish appcast for v0.1.0"
git push origin main
```

Wait for GitHub Pages to publish the appcast. Complete one real browser-download install smoke and the manual Sparkle update smoke before announcing the release.

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
plutil -lint apps/mac/Packaging/PrivacyInfo.xcprivacy
plutil -lint apps/mac/WhatTheToken.xcodeproj/project.pbxproj
xmllint --noout apps/mac/WhatTheToken.xcodeproj/xcshareddata/xcschemes/WhatTheToken.xcscheme
test -f apps/mac/WhatTheToken.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
rg -n '"identity" : "sparkle"|"location" : "https://github.com/sparkle-project/Sparkle"' apps/mac/WhatTheToken.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
rg -n "SUFeedURL|SUPublicEDKey|Check for Updates|github-hosting-and-updates" apps/mac docs/release
apps/mac/Scripts/rehearse-release.sh --version 0.1.0 --build 1 --mode dry-run
apps/mac/Scripts/sign-dmg.sh --dry-run --dmg apps/mac/.build/dmg/WhatTheToken-0.1.0.dmg
apps/mac/Scripts/generate-appcast.sh --dry-run --updates-dir /tmp/whatthetoken-updates --download-url-prefix https://github.com/hansDraisma/whatthetoken/releases/download/v0.1.0/
git diff --check
```

Credentialed Public V1 completion additionally requires:

```bash
git verify-tag v0.1.0
apps/mac/Scripts/rehearse-release.sh --version 0.1.0 --build 1 --mode signed
xmllint --noout docs/appcast.xml
rg -n "sparkle:edSignature|WhatTheToken-0.1.0.dmg|github.com/hansDraisma/whatthetoken/releases/download/v0.1.0" docs/appcast.xml
```

Plus the fresh macOS account smoke in `docs/release/public-v1-checklist.md`.
Plus the manual Sparkle update smoke using GitHub Pages `appcast.xml` and a GitHub Release DMG asset.

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
- Shareable/openable DMG verification is covered by Task 4, Task 10, and Task 11.
- Sandbox compatibility matrix gap is covered by Task 5.
- Sparkle manual update decision, EdDSA generation, key custody, public key, feed URL, appcast generation, and GitHub hosting are covered by Task 6, Task 9, and Task 11.
- Public version/build origin, signed release tag, and release provenance are covered by Task 2, Task 8, Task 9, and Task 11.
- Universal 2 architecture pinning and verification are covered by Task 2, Task 3, Task 4, Task 9, Task 10, and Task 11.
- Privacy manifest coverage is covered by Task 2, Task 3, Task 9, and Task 10.
- Release notes, CI dry-run release checks, and version bump tooling are covered by Task 9.
- Real archive proof is covered by Task 4 unsigned smoke and Task 11 signed rehearsal.
- Release script chain moves beyond dry-run with Task 4 unsigned smoke and Task 11 signed mode.
- Rollback and hotfix rules are covered by Task 7.
- `package-app.sh` is documented as development-only rather than treated as public release infrastructure.
- The plan separates repo-executable work from maintainer-gated credentialed release work.
- Public V1 uses GitHub Releases plus GitHub Pages as the simplest hosting option, with an owned-site/custom-domain follow-up deferred to Stage 5D.
