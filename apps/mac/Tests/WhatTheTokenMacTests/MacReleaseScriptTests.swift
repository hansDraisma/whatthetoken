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
                "provisioningProfiles",
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
                "xcrun stapler validate",
                "hdiutil verify",
                "hdiutil attach",
                "hdiutil detach",
                "-verify_arch",
                "CFBundleIconName",
                "Assets.car",
                "PrivacyInfo.xcprivacy",
                "Timestamp="
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
                "validate_release_build"
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
        arguments: ["--version", "0.1.0", "--build", "1", "--team-id", "3U98C8T3DT"]
    )

    #expect(result.exitCode != 0)
    #expect(result.output.contains("DEVELOPER_ID_APP_PROFILE_SPECIFIER is required"))
    #expect(result.output.contains("DEVELOPER_ID_WIDGET_PROFILE_SPECIFIER is required"))
    #expect(!result.output.contains("xcodebuild"))
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

private struct ScriptResult {
    let exitCode: Int32
    let output: String
}

private func runMacReleaseScript(_ name: String, arguments: [String]) throws -> ScriptResult {
    let process = Process()
    process.executableURL = macPackageRootURL().appendingPathComponent("Scripts/\(name)")
    process.arguments = arguments

    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = outputPipe

    try process.run()
    process.waitUntilExit()

    let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return ScriptResult(exitCode: process.terminationStatus, output: output)
}
