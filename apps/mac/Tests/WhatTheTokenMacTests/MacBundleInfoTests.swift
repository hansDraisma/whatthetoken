import Foundation
import Testing

@Test func packagingInfoPlistDeclaresAgentOnlyApp() throws {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Packaging/Info.plist")
    let data = try Data(contentsOf: url)
    let plist = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])

    #expect(plist["LSUIElement"] as? Bool == true)
    #expect(plist["CFBundleExecutable"] as? String == "WhatTheTokenMac")
    #expect(plist["CFBundlePackageType"] as? String == "APPL")
}

@Test func packagingInfoPlistUsesReleaseBuildSettingVersions() throws {
    let plist = try packagingInfoPlist()

    #expect(plist["CFBundleShortVersionString"] as? String == "$(MARKETING_VERSION)")
    #expect(plist["CFBundleVersion"] as? String == "$(CURRENT_PROJECT_VERSION)")
    #expect(plist["LSApplicationCategoryType"] as? String == "public.app-category.developer-tools")
    #expect(plist["SUEnableAutomaticChecks"] as? Bool == false)
    #expect(plist["SUAutomaticallyUpdate"] as? Bool == false)
}

@Test func releaseEntitlementsStayMinimal() throws {
    let packageRoot = packageRootURL()
    let entitlementsURL = packageRoot.appendingPathComponent("Packaging/WhatTheToken.entitlements")
    let data = try Data(contentsOf: entitlementsURL)
    let plist = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])

    #expect(plist["com.apple.security.get-task-allow"] == nil)
    #expect(plist["com.apple.security.app-sandbox"] == nil)
}

@Test func developerIDExportOptionsUseDeveloperIDMethod() throws {
    let packageRoot = packageRootURL()
    let exportOptionsURL = packageRoot.appendingPathComponent("Packaging/ExportOptions.DeveloperID.plist")
    let data = try Data(contentsOf: exportOptionsURL)
    let plist = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])

    #expect(plist["method"] as? String == "developer-id")
    #expect(plist["signingStyle"] as? String == "manual")
    #expect(plist["manageAppVersionAndBuildNumber"] as? Bool == false)
}

@Test func releaseXcconfigEnablesHardenedRuntimeAndEntitlements() throws {
    let packageRoot = packageRootURL()
    let releaseConfig = try String(
        contentsOf: packageRoot.appendingPathComponent("Packaging/WhatTheToken-Release.xcconfig"),
        encoding: .utf8
    )
    let sharedConfig = try String(
        contentsOf: packageRoot.appendingPathComponent("Packaging/WhatTheToken.xcconfig"),
        encoding: .utf8
    )
    let debugConfig = try String(
        contentsOf: packageRoot.appendingPathComponent("Packaging/WhatTheToken-Debug.xcconfig"),
        encoding: .utf8
    )

    #expect(releaseConfig.contains("ENABLE_HARDENED_RUNTIME = YES"))
    #expect(sharedConfig.contains("CODE_SIGN_ENTITLEMENTS = Packaging/WhatTheToken.entitlements"))
    #expect(releaseConfig.contains("CODE_SIGN_IDENTITY = Developer ID Application"))
    #expect(debugConfig.contains("CODE_SIGNING_ALLOWED = NO"))
    #expect(debugConfig.contains("ENABLE_HARDENED_RUNTIME = NO"))
}

@Test func packagingScriptCopiesSwiftPMResourceBundleBesideAppBundle() throws {
    let packageRoot = packageRootURL()
    let scriptURL = packageRoot.appendingPathComponent("Scripts/package-app.sh")
    let script = try String(contentsOf: scriptURL, encoding: .utf8)

    #expect(script.contains("RESOURCE_BUNDLE=\"$TRIPLE/${PRODUCT_NAME}_${PRODUCT_NAME}.bundle\""))
    #expect(script.contains("cp -R \"$RESOURCE_BUNDLE\" \"$APP_DIR/\""))
}

private func packageRootURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func packagingInfoPlist() throws -> [String: Any] {
    let url = packageRootURL().appendingPathComponent("Packaging/Info.plist")
    let data = try Data(contentsOf: url)
    return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
}
