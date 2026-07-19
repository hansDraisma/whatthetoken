import Foundation
import Testing

@Test func developmentPackageScriptIsClearlyNotThePublicReleasePath() throws {
    let script = try macFileContents("Scripts/package-app.sh")

    #expect(script.contains("Development-only"))
    #expect(script.contains("Public releases must use WhatTheToken.xcodeproj"))
}

@Test func developmentPackageScriptEmbedsWidgetExtensionForLocalTesting() throws {
    let script = try macFileContents("Scripts/package-app.sh")

    #expect(script.contains("xcodebuild"))
    #expect(script.contains("WhatTheToken.xcodeproj"))
    #expect(script.contains("CONFIGURATION_BUILD_DIR"))
    #expect(script.contains("Contents/PlugIns/WhatTheTokenWidget.appex"))
    #expect(script.contains("SPARKLE_FRAMEWORK=\"$APP_DIR/Contents/Frameworks/Sparkle.framework\""))
    #expect(script.contains("codesign --force --deep --sign - \"$SPARKLE_FRAMEWORK\""))
    #expect(script.contains("codesign --force --sign - --entitlements \"$ROOT_DIR/Packaging/WhatTheTokenWidget.entitlements\" \"$WIDGET_EXTENSION\""))
    #expect(script.contains("codesign --force --sign - --entitlements \"$ROOT_DIR/Packaging/WhatTheToken.entitlements\" \"$APP_DIR\""))
    #expect(script.contains("codesign --verify --strict --verbose=2 \"$APP_DIR\""))
    #expect(script.contains("codesign --verify --strict --verbose=2 \"$WIDGET_EXTENSION\""))
    #expect(script.contains("\"$LSREGISTER\" -f -R -trusted \"$APP_DIR\""))
    #expect(script.contains("pluginkit -m -A -i com.whatthetoken.mac.widget -vv"))
    #expect(script.contains("expected PlugInKit to register widget at $WIDGET_EXTENSION"))
}

@Test func developmentPackageScriptNormalizesXcodeConfigurationInput() throws {
    let script = try macFileContents("Scripts/package-app.sh")

    #expect(script.contains(#"case "$CONFIGURATION" in"#))
    #expect(script.contains(#"debug|Debug)"#))
    #expect(script.contains(#"release|Release)"#))
    #expect(script.contains("CONFIGURATION must be Debug or Release"))
}

@Test func developmentPackageScriptRetriesPlugInKitRegistrationAndReportsState() throws {
    let script = try macFileContents("Scripts/package-app.sh")

    #expect(script.contains("for attempt in 1 2 3 4 5; do"))
    #expect(script.contains("PLUGIN_OUTPUT=\"$(pluginkit -m -A -i com.whatthetoken.mac.widget -vv 2>&1 || true)\""))
    #expect(script.contains("grep -qF \"Path = $WIDGET_EXTENSION\""))
    #expect(script.contains("printf '%s\\n' \"$PLUGIN_OUTPUT\" >&2"))
    #expect(script.contains("sleep 1"))
}

@Test func developmentPackageScriptDocumentsDevOnlyDeepSigningAndMissingSparkle() throws {
    let script = try macFileContents("Scripts/package-app.sh")

    #expect(script.contains("--deep is intentional for this ad-hoc development helper"))
    #expect(script.contains("note: Sparkle.framework not present, skipping re-sign"))
}

@Test func releaseArtifactVerificationDoesNotDeepVerifyOuterAppPath() throws {
    let script = try macFileContents("Scripts/verify-release-artifacts.sh")

    #expect(!script.contains("run_command codesign --verify --deep --strict --verbose=2 \"$APP_PATH\""))
    #expect(script.contains("run_command codesign --verify --strict --verbose=2 \"$APP_PATH\""))
}

@Test func releaseArtifactDryRunPipelinesArePrintedAsShellCommands() throws {
    let script = try macFileContents("Scripts/verify-release-artifacts.sh")

    #expect(script.contains("print_shell_command"))
    #expect(!script.contains("quote_command WIDGET_TEAM="))
    #expect(!script.contains("quote_command APP_TEAM="))
    #expect(!script.contains("quote_command codesign -d --entitlements :- \"$APP_PATH\" \"|\" grep"))
    #expect(!script.contains("quote_command codesign -d --entitlements :- \"$WIDGET_PATH\" \"|\" grep"))
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
                "EXPORT_OPTIONS_RESOLVED",
                "PlistBuddy",
                "teamID",
                "Print :teamID",
                "plutil -lint",
                "release-inputs.sh",
                "validate_release_build",
                "assert_release_matches_xcconfig",
                "rm -rf \"$ARCHIVE_PATH\"",
                "rm -rf \"$EXPORT_DIR\"",
                "DEVELOPER_ID_TEAM_ID",
                "DEVELOPER_ID_APP_PROFILE_SPECIFIER",
                "DEVELOPER_ID_WIDGET_PROFILE_SPECIFIER",
                "WTT_DEVELOPER_ID_APP_PROFILE_SPECIFIER",
                "WTT_DEVELOPER_ID_WIDGET_PROFILE_SPECIFIER",
                "SENTRY_DSN",
                "SENTRY_DSN must be set to an https Sentry DSN",
                "provisioningProfiles",
                "plutil -replace 'provisioningProfiles.com.whatthetoken.mac' -string",
                "plutil -replace 'provisioningProfiles.com.whatthetoken.mac.widget' -string",
                "com.whatthetoken.mac.widget",
                "-verify_arch"
            ]
        ),
        (
            "create-dmg.sh",
            [
                "hdiutil",
                "ln -s /Applications",
                "WhatTheToken.app",
                "WhatTheToken $VERSION",
                "release-inputs.sh",
                "validate_release_version"
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
                "codesign --force --timestamp --sign",
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
                "spctl --status",
                "assessments enabled",
                "shasum -a 256",
                "shasum -a 256 -c",
                "cd \"$(dirname \"$DMG_PATH\")\"",
                "shasum -a 256 \"$(basename \"$DMG_PATH\")\"",
                "xcrun stapler validate",
                "hdiutil verify",
                "hdiutil attach",
                "hdiutil detach",
                "-verify_arch",
                "CFBundleIconName",
                "Assets.car",
                "PrivacyInfo.xcprivacy",
                "Timestamp=",
                "Contents/PlugIns/WhatTheTokenWidget.appex",
                "test -d \"$APP_PATH/Contents/PlugIns/WhatTheTokenWidget.appex\"",
                "codesign --verify --strict",
                "com.whatthetoken.mac.widget",
                "WIDGET_TEAM=",
                "APP_TEAM=",
                "widget TeamIdentifier",
                "codesign -d --entitlements",
                "group.com.whatthetoken.mac",
                "App Group entitlement",
                "cd \"$(dirname \"$DMG_PATH\")\" && shasum -a 256 \"$(basename \"$DMG_PATH\")\""
            ]
        ),
        (
            "generate-appcast.sh",
            [
                "generate_appcast",
                "SPARKLE_BIN_DIR",
                "command -v generate_appcast",
                "SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast",
                "appcast.xml"
            ]
        ),
        (
            "publish-release.sh",
            [
                "hansDraisma/whatthetoken-releases",
                "https://hansdraisma.github.io/whatthetoken-releases/appcast.xml",
                "verify-release-provenance.sh",
                "verify-release-artifacts.sh",
                "git ls-remote --exit-code --tags origin",
                "gh release create",
                "--draft",
                "gh release edit",
                "gh release upload",
                "--draft=false",
                "--resume",
                "Hosted DMG does not match the locally verified artifact",
                "Published release is missing an immutable asset",
                "Cannot resume because the public release does not exist",
                "generate-appcast.sh",
                "sparkle:edSignature",
                "contents/appcast.xml",
                "immutable-releases",
                "Immutable releases must be enabled before publication",
                "refusing to replace immutable public artifacts",
                "curl -fL",
                "shasum -a 256 -c"
            ]
        ),
        (
            "release-preflight.sh",
            [
                "git status --porcelain",
                "git branch --show-current",
                "git rev-parse origin/main",
                "DEVELOPER_ID_TEAM_ID",
                "DEVELOPER_ID_SIGNING_IDENTITY",
                "DEVELOPER_ID_APP_PROFILE_SPECIFIER",
                "DEVELOPER_ID_WIDGET_PROFILE_SPECIFIER",
                "SENTRY_DSN",
                "NOTARY_KEYCHAIN_PROFILE",
                "security find-identity",
                "openssl x509 -checkend 2592000",
                "security cms -D -i",
                "com.whatthetoken.mac.widget",
                "xcrun notarytool history",
                "https://sparkle-project.org",
                "immutable-releases",
                "PUBLIC_APPCAST_URL",
                "xmllint --noout",
                "Release preflight passed"
            ]
        ),
        (
            "smoke-archive-unsigned.sh",
            [
                "xcodebuild",
                "CODE_SIGNING_ALLOWED=NO",
                "PrivacyInfo.xcprivacy",
                "Products/Applications/WhatTheToken.app",
                "release-inputs.sh",
                "validate_release_build"
            ]
        ),
        (
            "rehearse-release.sh",
            [
                "smoke-archive-unsigned.sh",
                "verify-release-provenance.sh",
                "archive-release.sh",
                "sign-dmg.sh",
                "notarize-dmg.sh",
                "verify-release-artifacts.sh",
                "step \"1/6 Verify release provenance\"",
                "test -d",
                "test -f",
                "-verify_arch",
                "codesign --verify",
                "xcrun stapler validate",
                "release-inputs.sh",
                "validate_release_build",
                "cd \"$(dirname \"$DMG_PATH\")\"",
                "shasum -a 256 \"$(basename \"$DMG_PATH\")\"",
                "cd \"$(dirname \"$DMG_PATH\")\" && shasum -a 256 \"$(basename \"$DMG_PATH\")\""
            ]
        ),
        (
            "bump-version.sh",
            [
                "MARKETING_VERSION",
                "CURRENT_PROJECT_VERSION",
                "Version rewrite did not round-trip",
                "Build rewrite did not round-trip",
                "release-inputs.sh",
                "validate_release_build",
                "assert_release_build_increases",
                "grep -E"
            ]
        ),
        (
            "verify-release-provenance.sh",
            [
                "git status --porcelain",
                "git fetch --tags origin main",
                "git branch --show-current",
                "git rev-parse origin/main",
                "Public releases must be created from main",
                "Public release HEAD must match origin/main",
                "git rev-parse HEAD",
                "git rev-list -n 1 \"refs/tags/$TAG\"",
                "git verify-tag",
                "Package.resolved",
                "release-inputs.sh",
                "validate_release_build",
                "assert_release_matches_xcconfig"
            ]
        )
    ]

    for scriptInfo in scripts {
        let script = try macFileContents("Scripts/\(scriptInfo.name)")
        let scriptURL = macPackageRootURL().appendingPathComponent("Scripts/\(scriptInfo.name)")
        let attributes = try FileManager.default.attributesOfItem(atPath: scriptURL.path)
        let mode = try #require(attributes[.posixPermissions] as? NSNumber).intValue

        #expect(script.hasPrefix("#!/usr/bin/env bash\nset -euo pipefail"))
        #expect(mode & 0o111 != 0)
        for fragment in scriptInfo.requiredFragments {
            #expect(script.contains(fragment))
        }
        #expect(!script.contains("echo \"$NOTARY"))
        #expect(!script.contains("echo \"${NOTARY"))
        #expect(!script.contains("echo \"$SPARKLE"))
        #expect(!script.contains("echo \"${SPARKLE"))
        #expect(!script.contains(" rg "))
        #expect(!script.contains("| rg"))
    }
}

@Test func releaseArchiveRequiresDistinctProvisioningProfilesForAppAndWidget() throws {
    let result = try runMacReleaseScript(
        "archive-release.sh",
        arguments: ["--version", "0.1.0", "--build", "1", "--team-id", "3U98C8T3DT"],
        environmentOverrides: [
            "DEVELOPER_ID_APP_PROFILE_SPECIFIER": nil,
            "DEVELOPER_ID_WIDGET_PROFILE_SPECIFIER": nil
        ],
        baseEnvironment: ProcessInfo.processInfo.environment.merging([
            "DEVELOPER_ID_APP_PROFILE_SPECIFIER": "Installed App Profile",
            "DEVELOPER_ID_WIDGET_PROFILE_SPECIFIER": "Installed Widget Profile"
        ]) { _, new in new }
    )

    #expect(result.exitCode != 0)
    #expect(result.output.contains("DEVELOPER_ID_APP_PROFILE_SPECIFIER is required"))
    #expect(result.output.contains("DEVELOPER_ID_WIDGET_PROFILE_SPECIFIER is required"))
    #expect(!result.output.contains("xcodebuild"))
}

@Test func releaseArchiveReportsOnlyTheMissingProfileVariable() throws {
    let result = try runMacReleaseScript(
        "archive-release.sh",
        arguments: ["--version", "0.1.0", "--build", "1", "--team-id", "3U98C8T3DT"],
        environmentOverrides: [
            "DEVELOPER_ID_APP_PROFILE_SPECIFIER": nil
        ],
        baseEnvironment: ProcessInfo.processInfo.environment.merging([
            "DEVELOPER_ID_WIDGET_PROFILE_SPECIFIER": "Installed Widget Profile"
        ]) { _, new in new }
    )

    #expect(result.exitCode != 0)
    #expect(result.output.contains("DEVELOPER_ID_APP_PROFILE_SPECIFIER is required"))
    #expect(!result.output.contains("DEVELOPER_ID_WIDGET_PROFILE_SPECIFIER is required"))
}

@Test func releaseArchiveReportsOnlyWidgetSpecifierMissing() throws {
    let result = try runMacReleaseScript(
        "archive-release.sh",
        arguments: ["--version", "0.1.0", "--build", "1", "--team-id", "3U98C8T3DT"],
        environmentOverrides: [
            "DEVELOPER_ID_WIDGET_PROFILE_SPECIFIER": nil
        ],
        baseEnvironment: ProcessInfo.processInfo.environment.merging([
            "DEVELOPER_ID_APP_PROFILE_SPECIFIER": "Installed App Profile"
        ]) { _, new in new }
    )

    #expect(result.exitCode != 0)
    #expect(result.output.contains("DEVELOPER_ID_WIDGET_PROFILE_SPECIFIER is required"))
    #expect(!result.output.contains("DEVELOPER_ID_APP_PROFILE_SPECIFIER is required"))
}

@Test func releaseArchiveRequiresSentryDSNBeforeRunningXcodebuild() throws {
    let result = try runMacReleaseScript(
        "archive-release.sh",
        arguments: ["--version", "0.1.0", "--build", "1", "--team-id", "3U98C8T3DT"],
        environmentOverrides: ["SENTRY_DSN": nil],
        baseEnvironment: ProcessInfo.processInfo.environment.merging([
            "DEVELOPER_ID_APP_PROFILE_SPECIFIER": "Installed App Profile",
            "DEVELOPER_ID_WIDGET_PROFILE_SPECIFIER": "Installed Widget Profile"
        ]) { _, new in new }
    )

    #expect(result.exitCode != 0)
    #expect(result.output.contains("SENTRY_DSN must be set to an https Sentry DSN"))
    #expect(!result.output.contains("xcodebuild"))
}

@Test func releaseArchiveDryRunUsesEnvVarNamesInsteadOfAngleBracketPlaceholders() throws {
    let script = try macFileContents("Scripts/archive-release.sh")

    #expect(!script.contains("<DEVELOPER_ID_APP_PROFILE_SPECIFIER>"))
    #expect(!script.contains("<DEVELOPER_ID_WIDGET_PROFILE_SPECIFIER>"))
}

@Test func releaseArchiveDryRunAvoidsEscapedDollarPlaceholders() throws {
    let script = try macFileContents("Scripts/archive-release.sh")

    #expect(!script.contains(#"\${DEVELOPER_ID_"#))
    #expect(script.contains(#"DRY_RUN_TEAM_ID="${TEAM_ID:-DEVELOPER_ID_TEAM_ID}""#))
    #expect(script.contains(#"DRY_RUN_APP_PROFILE="${APP_PROFILE_SPECIFIER:-DEVELOPER_ID_APP_PROFILE_SPECIFIER}""#))
    #expect(script.contains(#"DRY_RUN_WIDGET_PROFILE="${WIDGET_PROFILE_SPECIFIER:-DEVELOPER_ID_WIDGET_PROFILE_SPECIFIER}""#))
    #expect(script.contains(#"ARCHIVE_SENTRY_DSN="SENTRY_DSN""#))
}

@Test func releaseInputValidatorOwnsSharedReleaseMetadataRules() throws {
    let script = try macFileContents("Scripts/release-inputs.sh")

    #expect(script.contains("validate_release_version"))
    #expect(script.contains("validate_release_build"))
    #expect(script.contains("assert_release_build_increases"))
    #expect(script.contains("assert_release_matches_xcconfig"))
    #expect(script.contains("Version must use numeric x.y.z format."))
    #expect(script.contains("Build must be a monotonically increasing integer."))
    #expect(script.contains("Build must increase"))
    #expect(script.contains("Release version/build must match committed Packaging/WhatTheToken.xcconfig."))
}

@Test func releaseScriptsPassBinaryBeforeLipoVerifyArch() throws {
    let expectedCommands: [(name: String, commands: [String])] = [
        (
            "archive-release.sh",
            [
                "quote_command lipo \"$EXPORT_DIR/WhatTheToken.app/Contents/MacOS/WhatTheTokenMac\" -verify_arch arm64 x86_64",
                "lipo \"$EXPORT_DIR/WhatTheToken.app/Contents/MacOS/WhatTheTokenMac\" -verify_arch arm64 x86_64"
            ]
        ),
        (
            "rehearse-release.sh",
            [
                "lipo \"$APP_PATH/Contents/MacOS/WhatTheTokenMac\" -verify_arch arm64 x86_64"
            ]
        ),
        (
            "smoke-archive-unsigned.sh",
            [
                "lipo \"$BINARY_PATH\" -verify_arch arm64 x86_64"
            ]
        ),
        (
            "verify-release-artifacts.sh",
            [
                "lipo \"$COPY_DIR/WhatTheToken.app/Contents/MacOS/WhatTheTokenMac\" -verify_arch arm64 x86_64"
            ]
        )
    ]

    for scriptInfo in expectedCommands {
        let script = try macFileContents("Scripts/\(scriptInfo.name)")

        for command in scriptInfo.commands {
            #expect(script.contains(command))
        }
    }
}

@Test func unsignedSmokeArchiveStdoutIsOnlyTheAppPath() throws {
    let script = try macFileContents("Scripts/smoke-archive-unsigned.sh")

    #expect(script.contains("APP_PATH=\"$ARCHIVE_PATH/Products/Applications/WhatTheToken.app\""))
    #expect(script.contains("printf '%s\\n' \"$APP_PATH\""))
    #expect(script.contains("    archive >&2"))
}

@Test func unsignedSmokeArchiveVerifiesEmbeddedWidgetVersionMetadata() throws {
    let script = try macFileContents("Scripts/smoke-archive-unsigned.sh")

    #expect(script.contains("WIDGET_INFO_PLIST=\"$APP_PATH/Contents/PlugIns/WhatTheTokenWidget.appex/Contents/Info.plist\""))
    #expect(script.contains("Print :CFBundleShortVersionString' \"$WIDGET_INFO_PLIST\" | grep -Fx \"$VERSION\""))
    #expect(script.contains("Print :CFBundleVersion' \"$WIDGET_INFO_PLIST\" | grep -Fx \"$BUILD\""))
}

@Test func releaseRehearsalRejectsNonIntegerBuildNumbersBeforeRunningDryRun() throws {
    let result = try runMacReleaseScript(
        "rehearse-release.sh",
        arguments: ["--version", "0.1.0", "--build", "abc", "--mode", "dry-run"]
    )

    #expect(result.exitCode != 0)
    #expect(result.output.contains("Build must be a monotonically increasing integer."))
    #expect(!result.output.contains("xcodebuild"))
}

@Test func publicReleaseDryRunDescribesSingleRepositoryPublicationWithoutMutating() throws {
    let result = try runMacReleaseScript(
        "publish-release.sh",
        arguments: [
            "--version", "0.1.0",
            "--build", "1",
            "--notes", "/tmp/WhatTheToken-release-notes.md",
            "--dry-run"
        ]
    )

    #expect(result.exitCode == 0)
    #expect(result.output.contains("hansDraisma/whatthetoken-releases"))
    #expect(result.output.contains("https://hansdraisma.github.io/whatthetoken-releases/appcast.xml"))
    #expect(result.output.contains("gh release create"))
    #expect(result.output.contains("gh release edit"))
    #expect(result.output.contains("No release, tag, asset, or appcast was published."))
}

@Test func releasePreflightDryRunListsCredentialAndHostingChecksWithoutReadingSecrets() throws {
    let result = try runMacReleaseScript(
        "release-preflight.sh",
        arguments: ["--version", "0.1.0", "--build", "1", "--dry-run"]
    )

    #expect(result.exitCode == 0)
    #expect(result.output.contains("Developer ID identity, certificate lifetime, and app/widget profiles"))
    #expect(result.output.contains("SENTRY_DSN without printing it"))
    #expect(result.output.contains("notarytool Keychain profile and Sparkle private key"))
    #expect(result.output.contains("public repository, immutable releases, Pages, and appcast"))
    #expect(result.output.contains("No credentials, profiles, tags, or artifacts were changed."))
}

private struct ScriptResult {
    let exitCode: Int32
    let output: String
}

private func runMacReleaseScript(
    _ name: String,
    arguments: [String],
    environmentOverrides: [String: String?] = [:],
    baseEnvironment: [String: String] = ProcessInfo.processInfo.environment
) throws -> ScriptResult {
    let process = Process()
    process.executableURL = macPackageRootURL().appendingPathComponent("Scripts/\(name)")
    process.arguments = arguments
    process.environment = environmentOverrides.reduce(into: baseEnvironment) { environment, override in
        if let value = override.value {
            environment[override.key] = value
        } else {
            environment.removeValue(forKey: override.key)
        }
    }

    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = outputPipe

    try process.run()
    process.waitUntilExit()

    let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return ScriptResult(exitCode: process.terminationStatus, output: output)
}
