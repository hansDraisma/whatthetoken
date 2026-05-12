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

@Test func xcodePackageResolutionPinsSparkleForReleaseReproducibility() throws {
    let resolved = try macFileContents("WhatTheToken.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved")

    #expect(resolved.contains("\"identity\" : \"sparkle\""))
    #expect(resolved.contains("\"location\" : \"https://github.com/sparkle-project/Sparkle\""))
    #expect(resolved.contains("\"revision\" : "))
    #expect(resolved.contains("\"version\" : "))
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
    let appSource = try macFileContents("Sources/WhatTheTokenMac/WhatTheTokenApp.swift")
    let rootSource = try macFileContents("Sources/WhatTheTokenMac/Views/Popover/PopoverRootView.swift")

    #expect(source.contains("#if canImport(Sparkle)"))
    #expect(source.contains("SPUStandardUpdaterController"))
    #expect(source.contains("startingUpdater: false"))
    #expect(source.contains("checkForUpdates"))
    #expect(source.contains("startUpdater()"))
    #expect(appSource.contains("canCheckForUpdates: { app.updateController.canCheckForUpdates }"))
    #expect(rootSource.contains("canCheckForUpdates: canCheckForUpdates()"))
    #expect(!source.contains("checkForUpdatesInBackground"))
}
