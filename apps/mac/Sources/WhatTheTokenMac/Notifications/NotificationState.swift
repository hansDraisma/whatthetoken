import Foundation

enum NotificationLevel: String, Codable, Equatable, Sendable {
    case healthy
    case warning
    case critical
}

struct NotificationDedupeKey: Codable, Equatable, Hashable, Sendable {
    var provider: CachedProviderID
    var poolKey: String
    var windowKey: String

    var storageKey: String {
        "\(provider.rawValue)|\(poolKey)|\(windowKey)"
    }
}

struct NotificationRecord: Codable, Equatable, Sendable {
    var key: NotificationDedupeKey
    var lastNotifiedLevel: NotificationLevel?
    var lastNotifiedAt: Date?
    var lastObservedLevel: NotificationLevel
    var recoveredAt: Date?
}

struct NotificationState: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var records: [String: NotificationRecord]

    static let empty = NotificationState(schemaVersion: currentSchemaVersion, records: [:])

    static func decodeValidated(from data: Data) throws -> NotificationState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(NotificationState.self, from: data)
        guard decoded.schemaVersion == currentSchemaVersion else {
            throw NotificationStateDecodeError.unsupportedSchemaVersion(decoded.schemaVersion)
        }
        return decoded
    }
}

enum NotificationStateDecodeError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
}

protocol NotificationStateStore: Sendable {
    func load() async -> NotificationState
    @discardableResult
    func save(_ state: NotificationState) async -> Bool
    var didFallbackOnLoad: Bool { get async }
}

final class JSONFileNotificationStateStore: NotificationStateStore, @unchecked Sendable {
    let url: URL
    private let lock = NSLock()
    private var fallback = false

    init(url: URL) {
        self.url = url
    }

    var didFallbackOnLoad: Bool {
        get async { lock.withLock { fallback } }
    }

    func load() async -> NotificationState {
        do {
            let data = try Data(contentsOf: url)
            let state = try NotificationState.decodeValidated(from: data)
            lock.withLock { fallback = false }
            return state
        } catch {
            lock.withLock { fallback = true }
            return .empty
        }
    }

    @discardableResult
    func save(_ state: NotificationState) async -> Bool {
        let temporaryURL = url
            .deletingLastPathComponent()
            .appendingPathComponent("\(url.lastPathComponent).\(UUID().uuidString).tmp")
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder.notificationStateEncoder.encode(state)
            try data.write(to: temporaryURL, options: [.atomic])
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: temporaryURL)
            } else {
                try FileManager.default.moveItem(at: temporaryURL, to: url)
            }
            return true
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            return false
        }
    }
}

final class InMemoryNotificationStateStore: NotificationStateStore, @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?
    private var fallback = false

    init(data: Data? = nil) {
        self.data = data
    }

    var didFallbackOnLoad: Bool {
        get async { lock.withLock { fallback } }
    }

    func load() async -> NotificationState {
        lock.withLock {
            guard let data else { return .empty }
            do {
                fallback = false
                return try NotificationState.decodeValidated(from: data)
            } catch {
                fallback = true
                return .empty
            }
        }
    }

    @discardableResult
    func save(_ state: NotificationState) async -> Bool {
        guard let encoded = try? JSONEncoder.notificationStateEncoder.encode(state) else { return false }
        lock.withLock {
            data = encoded
        }
        return true
    }
}

extension JSONEncoder {
    static var notificationStateEncoder: JSONEncoder {
        let encoder = JSONEncoder.prettyStable
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
