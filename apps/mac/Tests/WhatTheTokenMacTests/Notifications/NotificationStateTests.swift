import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct NotificationStateTests {
    @Test func emptyStateUsesCurrentSchema() {
        #expect(NotificationState.empty.schemaVersion == 1)
        #expect(NotificationState.empty.records.isEmpty)
    }

    @Test func roundTripPreservesSanitizedRecords() throws {
        var state = NotificationState.empty
        let key = NotificationDedupeKey(provider: .claude, poolKey: "anthropic_claude_subscription", windowKey: "rolling_5h")
        state.records[key.storageKey] = NotificationRecord(
            key: key,
            lastNotifiedLevel: .warning,
            lastNotifiedAt: Date(timeIntervalSince1970: 100),
            lastObservedLevel: .warning,
            recoveredAt: nil
        )

        let data = try JSONEncoder.notificationStateEncoder.encode(state)
        let decoded = try NotificationState.decodeValidated(from: data)

        #expect(decoded.records[key.storageKey]?.lastNotifiedLevel == .warning)
        #expect(String(decoding: data, as: UTF8.self).contains("token") == false)
        #expect(String(decoding: data, as: UTF8.self).contains("cookie") == false)
    }

    @Test func memoryStoreFallsBackToEmptyOnInvalidData() async {
        let store = InMemoryNotificationStateStore(data: Data("not json".utf8))

        let loaded = await store.load()

        #expect(loaded == .empty)
        #expect(await store.didFallbackOnLoad == true)
    }
}
