import Foundation

enum WidgetSnapshotCacheFile {
    static let appGroupIdentifier = AppGroupIdentifier.shared
    static let fileName = "snapshot-cache.json"

    static func appGroupURL(fileManager: FileManager = .default) -> URL? {
        fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(fileName)
    }

    static func localAppGroupURL(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        homeDirectory
            .appendingPathComponent("Library/Group Containers/\(appGroupIdentifier)", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    static func widgetSandboxURL(fileManager: FileManager = .default) -> URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WhatTheToken", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    static func widgetContainerMirrorURL(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        homeDirectory
            .appendingPathComponent("Library/Containers/com.whatthetoken.mac.widget/Data/Library/Application Support/WhatTheToken", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    static func readableURLs(fileManager: FileManager = .default) -> [URL] {
        var urls: [URL] = []
        if let appGroup = appGroupURL(fileManager: fileManager) {
            urls.append(appGroup)
        }
        urls.append(localAppGroupURL())
        urls.append(widgetSandboxURL(fileManager: fileManager))
        return urls
    }
}

protocol SnapshotCacheStore: Sendable {
    func load() async -> SnapshotCache
    @discardableResult
    func save(_ cache: SnapshotCache) async -> Bool
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

    @discardableResult
    func save(_ cache: SnapshotCache) async -> Bool {
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
            return true
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            return false
        }
    }
}

struct MirroringSnapshotCacheStore: SnapshotCacheStore {
    let primary: SnapshotCacheStore
    let mirrors: [SnapshotCacheStore]

    func load() async -> SnapshotCache {
        let cache = await primary.load()
        for mirror in mirrors {
            _ = await mirror.save(cache)
        }
        return cache
    }

    @discardableResult
    func save(_ cache: SnapshotCache) async -> Bool {
        let saved = await primary.save(cache)
        guard saved else { return false }
        for mirror in mirrors {
            _ = await mirror.save(cache)
        }
        return true
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

    @discardableResult
    func save(_ cache: SnapshotCache) async -> Bool {
        guard let encoded = try? JSONEncoder.cacheEncoder.encode(cache) else { return false }
        lock.withLock {
            data = encoded
        }
        return true
    }
}

extension JSONEncoder {
    static var prettyStable: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static var cacheEncoder: JSONEncoder {
        let encoder = JSONEncoder.prettyStable
        encoder.dateEncodingStrategy = .custom { date, encoder in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }
}
