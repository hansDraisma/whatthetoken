import Foundation
import Testing

// These source-content checks are smoke tests for widget target wiring. The
// Xcode build remains the compile coverage for the WidgetKit extension.
@Suite struct WidgetExtensionFilesTests {
    @Test func widgetInfoPlistDeclaresWidgetKitExtensionPoint() throws {
        let plist = try widgetPlist("Widget/Info.plist")
        let extensionDict = try #require(plist["NSExtension"] as? [String: Any])

        #expect(extensionDict["NSExtensionPointIdentifier"] as? String == "com.apple.widgetkit-extension")
    }

    @Test func widgetInfoPlistUsesReleaseBuildSettingVersions() throws {
        let plist = try widgetPlist("Widget/Info.plist")

        #expect(plist["CFBundleShortVersionString"] as? String == "$(MARKETING_VERSION)")
        #expect(plist["CFBundleVersion"] as? String == "$(CURRENT_PROJECT_VERSION)")
    }

    @Test func widgetBundleSourceUsesTimelineProvider() throws {
        let source = try widgetFileContents("Widget/WhatTheTokenWidget.swift")

        #expect(source.contains("@main"))
        #expect(source.contains("WidgetTimelineProvider()"))
        #expect(source.contains("WidgetSmallView(entry: entry)"))
        #expect(source.contains(".supportedFamilies([.systemSmall])"))
    }

    @Test func widgetTimelineProviderReadsSharedSnapshotCache() throws {
        let source = try widgetFileContents("Widget/WidgetTimelineProvider.swift")

        #expect(source.contains("SnapshotEntryBuilder"))
        #expect(source.contains("SnapshotCache"))
        #expect(source.contains("SnapshotCache.decodeValidated"))
        #expect(source.contains("WidgetSnapshotCacheFile.readableURLs"))
        #expect(source.contains("SnapshotCache.decodeValidated"))
    }

    @Test func widgetSmallViewUsesSharedPreviewView() throws {
        let source = try widgetFileContents("Widget/WidgetSmallView.swift")

        #expect(source.contains("WidgetPreviewView(payload: entry.payload)"))
    }

    @Test func widgetSmallViewAppliesContainerBackground() throws {
        let source = try widgetFileContents("Widget/WidgetSmallView.swift")

        #expect(source.contains(".containerBackground"))
        #expect(source.contains("for: .widget"))
    }
}

private func widgetPackageRootURL(filePath: String = #filePath) -> URL {
    URL(fileURLWithPath: filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func widgetFileContents(_ relativePath: String, filePath: String = #filePath) throws -> String {
    let url = widgetPackageRootURL(filePath: filePath).appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}

private func widgetPlist(_ relativePath: String, filePath: String = #filePath) throws -> [String: Any] {
    let url = widgetPackageRootURL(filePath: filePath).appendingPathComponent(relativePath)
    let data = try Data(contentsOf: url)
    return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
}
