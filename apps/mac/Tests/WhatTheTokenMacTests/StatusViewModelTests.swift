import Foundation
import Testing
@testable import WhatTheTokenMac

@Test func loadsFixtureSnapshot() throws {
    let snapshot = try StatusViewModel.loadFixtureSnapshot()

    #expect(snapshot.product == "claude_code")
    #expect(snapshot.confidence == "verified")
    #expect(snapshot.remaining == 38)
    #expect(snapshot.staleReason == nil)
    #expect(snapshot.source.connector == "manual_fixture")
    #expect(snapshot.source.state == .connected)
    #expect(snapshot.source.parserVersion == "fixture-v1")
}

@Test func sectionTrustLineHoistsConfidenceConnectorLabelAndUpdatedTime() throws {
    let snapshot = try StatusViewModel.loadFixtureSnapshot()
    let section = StatusSectionDisplayModel(snapshots: [snapshot], now: Date())
    let expected = localUpdatedLabel(for: snapshot.lastUpdatedAt)

    #expect(section.trustLine == "Verified by Fixture · \(expected)")
}

@Test func fixtureJSONDoesNotContainSensitiveKeys() throws {
    let data = try StatusViewModel.loadFixtureData()
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let disallowedKeys = [
        "prompt",
        "completion",
        "conversation",
        "conversationUrl",
        "cookie",
        "authHeader",
        "bearerToken",
        "sessionToken"
    ]

    #expect(sensitiveKeyMatches(in: object, disallowedKeys: disallowedKeys).isEmpty)
}

@Test func sensitiveKeyScanFindsNestedMatches() {
    let object: [String: Any] = [
        "provider": "anthropic",
        "metadata": [
            "conversation": "should not be collected",
            "usage": [
                ["remaining": 38],
                ["sessionToken": "should not be collected"]
            ]
        ]
    ]

    #expect(sensitiveKeyMatches(in: object, disallowedKeys: ["conversation", "sessionToken"]) == [
        "metadata.conversation",
        "metadata.usage[1].sessionToken"
    ])
}

private func sensitiveKeyMatches(
    in value: Any,
    disallowedKeys: [String],
    path: String = ""
) -> [String] {
    if let dictionary = value as? [String: Any] {
        return dictionary.keys.sorted().flatMap { key -> [String] in
            let childPath = path.isEmpty ? key : "\(path).\(key)"
            let currentMatch = disallowedKeys.contains(key) ? [childPath] : []
            return currentMatch + sensitiveKeyMatches(
                in: dictionary[key] as Any,
                disallowedKeys: disallowedKeys,
                path: childPath
            )
        }
    }

    if let array = value as? [Any] {
        return array.indices.flatMap { index in
            sensitiveKeyMatches(
                in: array[index],
                disallowedKeys: disallowedKeys,
                path: "\(path)[\(index)]"
            )
        }
    }

    return []
}

private func localUpdatedLabel(for isoString: String) -> String {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    let date = fractional.date(from: isoString) ?? plain.date(from: isoString)!
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return "Updated \(formatter.string(from: date))"
}
