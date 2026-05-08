import Foundation

protocol AppSettingsStore: Sendable {
    func load() async -> AppSettings
    @discardableResult
    func save(_ settings: AppSettings) async -> Bool
}

struct JSONFileAppSettingsStore: AppSettingsStore {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    func load() async -> AppSettings {
        do {
            let data = try Data(contentsOf: url)
            return try AppSettings.decodeValidated(from: data)
        } catch {
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

    init(data: Data? = nil) {
        self.data = data
    }

    func load() async -> AppSettings {
        lock.withLock {
            guard let data else { return .defaults }
            return (try? AppSettings.decodeValidated(from: data)) ?? .defaults
        }
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

extension JSONEncoder {
    static var prettyStable: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
