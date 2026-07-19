import Foundation
import Testing
@testable import WhatTheTokenMac

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

@Test func packagingInfoPlistAcceptsBuildTimeSentryDSN() throws {
    let plist = try packagingInfoPlist()

    #expect(plist["SentryDSN"] as? String == "$(SENTRY_DSN)")
}

@Test func sentryConfigurationRejectsMissingAndUnexpandedDSNs() {
    #expect(SentryMonitoring.configuredDSN(infoDictionary: [:], environment: [:]) == nil)
    #expect(SentryMonitoring.configuredDSN(
        infoDictionary: ["SentryDSN": "$(SENTRY_DSN)"],
        environment: [:]
    ) == nil)
    #expect(SentryMonitoring.configuredDSN(
        infoDictionary: ["SentryDSN": "https://public@example.ingest.sentry.io/1"],
        environment: [:]
    ) == "https://public@example.ingest.sentry.io/1")
}

@Test func sparkleDefaultsRemainManualAndSilentForPublicV1() throws {
    let plist = try packagingInfoPlist()

    #expect(plist["SUEnableAutomaticChecks"] as? Bool == false)
    #expect(plist["SUAutomaticallyUpdate"] as? Bool == false)
    #expect(plist["SUEnableSystemProfiling"] == nil)
    #expect(plist["SUFeedURL"] as? String == "https://hansdraisma.github.io/whatthetoken-releases/appcast.xml")
    #expect(plist["SUPublicEDKey"] as? String == "rwQnge6z/GQvR9NwGuQFBpN44ZcaUBzixfISv77Z2hg=")
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
    #expect(plist["teamID"] == nil)
}

@Test func releaseDeploymentTargetMatchesInfoPlistMinimumSystemVersion() throws {
    let plist = try packagingInfoPlist()
    let sharedConfig = try macFileContents("Packaging/WhatTheToken.xcconfig")
    let expected = try #require(plist["LSMinimumSystemVersion"] as? String)

    #expect(sharedConfig.contains("\nMACOSX_DEPLOYMENT_TARGET = \(expected)\n"))
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

@Test func sharedXcconfigPinsCurrentPublicVersionAndBuild() throws {
    let sharedConfig = try macFileContents("Packaging/WhatTheToken.xcconfig")

    #expect(sharedConfig.contains("\nMARKETING_VERSION = 0.1.3\n"))
    #expect(sharedConfig.contains("\nCURRENT_PROJECT_VERSION = 4\n"))
    #expect(sharedConfig.contains("\nASSETCATALOG_COMPILER_APPICON_NAME = AppIcon\n"))
}
