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

@Test func packagingScriptCopiesSwiftPMResourceBundleBesideAppBundle() throws {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let scriptURL = packageRoot.appendingPathComponent("Scripts/package-app.sh")
    let script = try String(contentsOf: scriptURL, encoding: .utf8)

    #expect(script.contains("RESOURCE_BUNDLE=\"$TRIPLE/${PRODUCT_NAME}_${PRODUCT_NAME}.bundle\""))
    #expect(script.contains("cp -R \"$RESOURCE_BUNDLE\" \"$APP_DIR/\""))
}
