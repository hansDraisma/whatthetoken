import Foundation

protocol SnapshotCacheStore: Sendable {
    func load() async -> SnapshotCache
    func save(_ cache: SnapshotCache) async
}

struct JSONFileSnapshotCacheStore: SnapshotCacheStore {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    func load() async -> SnapshotCache {
        do {
            let data = try Data(contentsOf: url)
            return try SnapshotCache.decodeValidated(from: data)
        } catch {
            return .empty
        }
    }

    func save(_ cache: SnapshotCache) async {
        let temporaryURL = url
            .deletingLastPathComponent()
            .appendingPathComponent("\(url.lastPathComponent).\(UUID().uuidString).tmp")
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder.cacheEncoder.encode(cache)
            try data.write(to: temporaryURL, options: [.atomic])
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: temporaryURL)
            } else {
                try FileManager.default.moveItem(at: temporaryURL, to: url)
            }
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
        }
    }
}

final class InMemorySnapshotCacheStore: SnapshotCacheStore, @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?

    init(data: Data? = nil) {
        self.data = data
    }

    func load() async -> SnapshotCache {
        lock.withLock {
            guard let data else { return .empty }
            return (try? SnapshotCache.decodeValidated(from: data)) ?? .empty
        }
    }

    func save(_ cache: SnapshotCache) async {
        let encoded = try? JSONEncoder.cacheEncoder.encode(cache)
        lock.withLock {
            data = encoded
        }
    }
}

extension JSONEncoder {
    static var cacheEncoder: JSONEncoder {
        let encoder = JSONEncoder.prettyStable
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
