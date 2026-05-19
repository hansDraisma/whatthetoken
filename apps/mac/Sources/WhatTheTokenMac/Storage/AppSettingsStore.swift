import Foundation

protocol AppSettingsStore: Sendable {
    func load() async -> AppSettings
    func loadValidated() async throws -> AppSettings
    @discardableResult
    func save(_ settings: AppSettings) async -> Bool
}

extension AppSettingsStore {
    func loadValidated() async throws -> AppSettings {
        await load()
    }
}

struct JSONFileAppSettingsStore: AppSettingsStore {
    let url: URL
    let logger: (any AppLogger)?

    init(url: URL, logger: (any AppLogger)? = OSLogAppLogger(category: "AppSettingsStore")) {
        self.url = url
        self.logger = logger
    }

    func load() async -> AppSettings {
        do {
            let data = try Data(contentsOf: url)
            return try AppSettings.decodeValidated(from: data, logger: logger)
        } catch {
            return .defaults
        }
    }

    func loadValidated() async throws -> AppSettings {
        do {
            let data = try Data(contentsOf: url)
            return try AppSettings.decodeValidated(from: data, logger: logger)
        } catch CocoaError.fileReadNoSuchFile {
            return .defaults
        }
    }

    @discardableResult
    func save(_ settings: AppSettings) async -> Bool {
        let temporaryURL = url
            .deletingLastPathComponent()
            .appendingPathComponent("\(url.lastPathComponent).\(UUID().uuidString).tmp")
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder.prettyStable.encode(settings)
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

final class InMemoryAppSettingsStore: AppSettingsStore, @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?
    private let logger: (any AppLogger)?

    init(data: Data? = nil, logger: (any AppLogger)? = nil) {
        self.data = data
        self.logger = logger
    }

    func load() async -> AppSettings {
        lock.withLock {
            guard let data else { return .defaults }
            return (try? AppSettings.decodeValidated(from: data, logger: logger)) ?? .defaults
        }
    }

    func loadValidated() async throws -> AppSettings {
        let loadedData = lock.withLock { data }
        guard let loadedData else { return .defaults }
        return try AppSettings.decodeValidated(from: loadedData, logger: logger)
    }

    @discardableResult
    func save(_ settings: AppSettings) async -> Bool {
        guard let encoded = try? JSONEncoder.prettyStable.encode(settings) else { return false }
        lock.withLock {
            data = encoded
        }
        return true
    }
}
