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

@Test func xcodeProjectDefinesReleaseTargetAndRuntimePackages() throws {
    let project = try macFileContents("WhatTheToken.xcodeproj/project.pbxproj")

    #expect(project.contains("name = WhatTheToken;"))
    #expect(project.contains("WhatTheTokenApp.swift"))
    #expect(project.contains("XcodeBundleModule.swift"))
    #expect(project.contains("https://github.com/sparkle-project/Sparkle"))
    #expect(project.contains("productName = Sparkle;"))
    #expect(project.contains("https://github.com/getsentry/sentry-cocoa"))
    #expect(project.contains("productName = Sentry;"))
    #expect(project.contains("Packaging/WhatTheToken-Release.xcconfig"))
    #expect(project.contains("Packaging/WhatTheToken-Debug.xcconfig"))
}

@Test func xcodeProjectIncludesEveryMacSourceFile() throws {
    let project = try macFileContents("WhatTheToken.xcodeproj/project.pbxproj")
    let sourceRoot = macPackageRootURL().appendingPathComponent("Sources/WhatTheTokenMac")
    let enumerator = FileManager.default.enumerator(
        at: sourceRoot,
        includingPropertiesForKeys: nil
    )
    let sourcePaths = try #require(enumerator?.compactMap { item -> String? in
        guard let url = item as? URL, url.pathExtension == "swift" else {
            return nil
        }
        let relativePath = url.path.replacingOccurrences(
            of: macPackageRootURL().path + "/",
            with: ""
        )
        return relativePath
    })

    for sourcePath in sourcePaths.sorted() {
        #expect(project.contains(sourcePath))
    }
}

@Test func xcodeProjectReferencesOnlyExistingSwiftFiles() throws {
    let project = try macFileContents("WhatTheToken.xcodeproj/project.pbxproj")
    let regex = try #require(try? NSRegularExpression(pattern: #"path = ([^;]+\.swift);"#))
    let range = NSRange(project.startIndex..<project.endIndex, in: project)
    let referencedPaths = regex.matches(in: project, range: range).compactMap { match -> String? in
        guard let pathRange = Range(match.range(at: 1), in: project) else { return nil }
        return String(project[pathRange])
    }

    for referencedPath in referencedPaths.sorted() {
        let url = macPackageRootURL().appendingPathComponent(referencedPath)
        #expect(FileManager.default.fileExists(atPath: url.path), "Missing Xcode Swift source: \(referencedPath)")
    }
}

@Test func xcodePackageResolutionPinsSparkleForReleaseReproducibility() throws {
    let resolved = try macFileContents("WhatTheToken.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved")

    #expect(resolved.contains("\"identity\" : \"sparkle\""))
    #expect(resolved.contains("\"location\" : \"https://github.com/sparkle-project/Sparkle\""))
    #expect(resolved.contains("\"revision\" : "))
    #expect(resolved.contains("\"version\" : "))
}

@Test func xcodePackageResolutionPinsSentryForReleaseReproducibility() throws {
    let resolved = try macFileContents("WhatTheToken.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved")

    #expect(resolved.contains("\"identity\" : \"sentry-cocoa\""))
    #expect(resolved.contains("\"location\" : \"https://github.com/getsentry/sentry-cocoa\""))
}

@Test func swiftPackageResolutionPinsSentryForTestReproducibility() throws {
    let resolved = try macFileContents("Package.resolved")

    #expect(resolved.contains("\"identity\" : \"sentry-cocoa\""))
    #expect(resolved.contains("\"location\" : \"https://github.com/getsentry/sentry-cocoa\""))
    #expect(resolved.contains("\"version\" : \"9.22.0\""))
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

@Test func xcodeProjectDeclaresAndEmbedsWidgetExtensionTarget() throws {
    let project = try macFileContents("WhatTheToken.xcodeproj/project.pbxproj")

    #expect(project.contains("name = WhatTheTokenWidget;"))
    #expect(project.contains("productType = \"com.apple.product-type.app-extension\";"))
    #expect(project.contains("WidgetKit.framework"))
    #expect(project.contains("WhatTheTokenWidget.appex"))
    #expect(project.contains("name = \"Embed App Extensions\";"))
    #expect(project.contains("dstSubfolderSpec = 13;"))
    #expect(project.contains("Widget/Info.plist"))
    #expect(project.contains("Packaging/WhatTheTokenWidget.entitlements"))
}

@Test func widgetTargetBuildConfigurationsInheritSharedXcconfigs() throws {
    let project = try macFileContents("WhatTheToken.xcodeproj/project.pbxproj")

    #expect(projectMatches(
        project,
        #"000000000000000000000033 = \{\s*isa = XCBuildConfiguration;\s*baseConfigurationReference = 000000000000000000000016;"#
    ))
    #expect(projectMatches(
        project,
        #"000000000000000000000034 = \{\s*isa = XCBuildConfiguration;\s*baseConfigurationReference = 000000000000000000000017;"#
    ))
}

@Test func widgetTargetBuildConfigurationsInheritVersionSettingsFromXcconfig() throws {
    let project = try macFileContents("WhatTheToken.xcodeproj/project.pbxproj")

    #expect(!projectMatches(
        project,
        #"(?s)000000000000000000000033 = \{.*?CURRENT_PROJECT_VERSION ="#
    ))
    #expect(!projectMatches(
        project,
        #"(?s)000000000000000000000033 = \{.*?MARKETING_VERSION ="#
    ))
    #expect(!projectMatches(
        project,
        #"(?s)000000000000000000000034 = \{.*?CURRENT_PROJECT_VERSION ="#
    ))
    #expect(!projectMatches(
        project,
        #"(?s)000000000000000000000034 = \{.*?MARKETING_VERSION ="#
    ))
}

@Test func widgetTargetDoesNotInheritHostFrameworksRpath() throws {
    let project = try macFileContents("WhatTheToken.xcodeproj/project.pbxproj")
    let widgetSection = try #require(project.range(of: "WTT_WIDGET_EXTENSION").flatMap {
        let end = project.index($0.lowerBound, offsetBy: 4_000, limitedBy: project.endIndex) ?? project.endIndex
        return String(project[$0.lowerBound..<end])
    })

    #expect(!widgetSection.contains("@executable_path/../../../../Frameworks"))
}

@Test func releaseBuildConfigurationsUseTargetSpecificProvisioningProfileSpecifiers() throws {
    let project = try macFileContents("WhatTheToken.xcodeproj/project.pbxproj")

    #expect(projectMatches(
        project,
        #"(?s)000000000000000000000012 = \{.*?PROVISIONING_PROFILE_SPECIFIER = "\$\(WTT_DEVELOPER_ID_APP_PROFILE_SPECIFIER\)";"#
    ))
    #expect(projectMatches(
        project,
        #"(?s)000000000000000000000034 = \{.*?PROVISIONING_PROFILE_SPECIFIER = "\$\(WTT_DEVELOPER_ID_WIDGET_PROFILE_SPECIFIER\)";"#
    ))
}

@Test func ciVerifiesResolvedReleaseHardenedRuntimeBuildSetting() throws {
    let workflow = try repositoryFileContents(".github/workflows/test.yml")

    #expect(workflow.contains("xcodebuild -project apps/mac/WhatTheToken.xcodeproj"))
    #expect(workflow.contains("-configuration Release"))
    #expect(workflow.contains("-showBuildSettings"))
    #expect(workflow.contains("ENABLE_HARDENED_RUNTIME = YES"))
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

@Test func appIconSourceHasApprovalRecord() throws {
    let packageRoot = macPackageRootURL()
    let sourceURL = packageRoot.appendingPathComponent("Brand/AppIconSource.png")
    let approval = try macFileContents("Brand/AppIconSource.approval.md")
    let sourceData = try Data(contentsOf: sourceURL)

    #expect(sourceData.starts(with: [0x89, 0x50, 0x4e, 0x47]))
    #expect(approval.contains("SHA-256:"))
    #expect(approval.contains("maintainer-approved for Public V1"))
}

@Test func sparkleUpdateControllerIsManualCheckOnly() throws {
    let source = try macFileContents("Sources/WhatTheTokenMac/Updates/SparkleUpdateController.swift")
    let appModelSource = try macFileContents("Sources/WhatTheTokenMac/AppModel.swift")
    let rootSource = try macFileContents("Sources/WhatTheTokenMac/Views/Popover/PopoverRootView.swift")

    #expect(source.contains("#if canImport(Sparkle)"))
    #expect(source.contains("SPUStandardUpdaterController"))
    #expect(source.contains("startingUpdater: false"))
    #expect(source.contains("checkForUpdates"))
    #expect(source.contains("startUpdater()"))
    #expect(appModelSource.contains("canCheckForUpdates: { updateController.canCheckForUpdates }"))
    #expect(rootSource.contains("canCheckForUpdates: canCheckForUpdates()"))
    #expect(!source.contains("checkForUpdatesInBackground"))
}

private func projectMatches(_ project: String, _ pattern: String) -> Bool {
    project.range(of: pattern, options: .regularExpression) != nil
}
