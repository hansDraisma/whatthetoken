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
                "rm -rf \"$ARCHIVE_PATH\"",
                "rm -rf \"$EXPORT_DIR\"",
                "DEVELOPER_ID_TEAM_ID",
                "-verify_arch"
            ]
        ),
        (
            "create-dmg.sh",
            [
                "hdiutil",
                "ln -s /Applications",
                "WhatTheToken.app",
                "WhatTheToken $VERSION"
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
                "xcrun stapler validate"
            ]
        ),
        (
            "bump-version.sh",
            [
                "MARKETING_VERSION",
                "CURRENT_PROJECT_VERSION",
                "Build must increase"
            ]
        ),
        (
            "verify-release-provenance.sh",
            [
                "git status --porcelain",
                "git rev-parse HEAD",
                "git rev-list -n 1 \"refs/tags/$TAG\"",
                "git verify-tag",
                "Package.resolved"
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
    }
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
