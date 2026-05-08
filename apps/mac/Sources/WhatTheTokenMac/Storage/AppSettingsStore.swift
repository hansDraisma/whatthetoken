import Foundation

protocol AppSettingsStore: Sendable {
    func load() async -> AppSettings
    func save(_ settings: AppSettings) async
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

    func save(_ settings: AppSettings) async {
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
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
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

    func save(_ settings: AppSettings) async {
        let encoded = try? JSONEncoder.prettyStable.encode(settings)
        lock.withLock {
            data = encoded
        }
    }
}

extension JSONEncoder {
    static var prettyStable: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
