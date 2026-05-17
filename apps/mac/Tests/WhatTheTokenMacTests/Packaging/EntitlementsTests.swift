import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct EntitlementsTests {
    @Test func mainAppDeclaresAppGroup() throws {
        let url = repoURL().appendingPathComponent("apps/mac/Packaging/WhatTheToken.entitlements")
        let plist = try plistDict(at: url)

        let groups = plist["com.apple.security.application-groups"] as? [String]
        #expect(groups == ["group.com.whatthetoken.mac"])
    }

    @Test func widgetDeclaresSandboxAndAppGroupOnly() throws {
        let url = repoURL().appendingPathComponent("apps/mac/Packaging/WhatTheTokenWidget.entitlements")
        let plist = try plistDict(at: url)

        let groups = plist["com.apple.security.application-groups"] as? [String]
        #expect(groups == ["group.com.whatthetoken.mac"])

        let sandbox = plist["com.apple.security.app-sandbox"] as? Bool
        #expect(sandbox == true)

        #expect(plist["com.apple.security.network.client"] == nil)
        #expect(plist["com.apple.security.files.user-selected.read-only"] == nil)
        #expect(plist["com.apple.security.files.user-selected.read-write"] == nil)
    }

    private func repoURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Packaging
            .deletingLastPathComponent() // WhatTheTokenMacTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // mac
            .deletingLastPathComponent() // apps
            .deletingLastPathComponent() // repo
    }

    private func plistDict(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        var format = PropertyListSerialization.PropertyListFormat.xml
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: &format)
        return (plist as? [String: Any]) ?? [:]
    }
}
