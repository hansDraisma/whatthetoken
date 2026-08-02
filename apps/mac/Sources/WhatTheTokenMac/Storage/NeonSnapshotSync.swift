import Foundation

protocol SnapshotSyncURLLoading: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: SnapshotSyncURLLoading { }

enum SnapshotSyncError: Error, Equatable {
    case invalidResponse
    case requestFailed
    case invalidCache
}

protocol SnapshotCacheSyncing: Sendable {
    func fetch() async throws -> SnapshotCache?
    func upload(_ cache: SnapshotCache) async throws
}

struct HTTPSnapshotCacheSyncClient: SnapshotCacheSyncing {
    let endpoint: URL
    private let token: String
    private let loader: SnapshotSyncURLLoading

    init(baseURL: URL, token: String, loader: SnapshotSyncURLLoading = URLSession.shared) {
        endpoint = baseURL.appendingPathComponent("v1/snapshot-cache")
        self.token = token
        self.loader = loader
    }

    func fetch() async throws -> SnapshotCache? {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        authorize(&request)

        let (data, response) = try await perform(request)
        guard let http = response as? HTTPURLResponse else {
            throw SnapshotSyncError.invalidResponse
        }
        if http.statusCode == 404 { return nil }
        guard (200..<300).contains(http.statusCode) else {
            throw SnapshotSyncError.requestFailed
        }
        do {
            return try SnapshotCache.decodeValidated(from: data)
        } catch {
            throw SnapshotSyncError.invalidCache
        }
    }

    func upload(_ cache: SnapshotCache) async throws {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "PUT"
        request.httpBody = try JSONEncoder.cacheEncoder.encode(cache)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authorize(&request)

        let (_, response) = try await perform(request)
        guard let http = response as? HTTPURLResponse else {
            throw SnapshotSyncError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw SnapshotSyncError.requestFailed
        }
    }

    private func authorize(_ request: inout URLRequest) {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await loader.data(for: request)
        } catch let error as SnapshotSyncError {
            throw error
        } catch {
            throw SnapshotSyncError.requestFailed
        }
    }
}

struct NeonSyncingSnapshotCacheStore: SnapshotCacheStore {
    let local: SnapshotCacheStore
    let remote: SnapshotCacheSyncing

    func load() async -> SnapshotCache {
        let localCache = await local.load()
        do {
            if let remoteCache = try await remote.fetch() {
                guard await local.save(remoteCache) else { return localCache }
                return remoteCache
            }
            try await remote.upload(localCache)
        } catch {
            // Local-first fallback: a sleeping compute or offline Mac must still launch.
        }
        return localCache
    }

    @discardableResult
    func save(_ cache: SnapshotCache) async -> Bool {
        guard await local.save(cache) else { return false }
        do {
            try await remote.upload(cache)
            return true
        } catch {
            return false
        }
    }
}

enum NeonSnapshotSyncConfiguration {
    static func wrapping(
        local: SnapshotCacheStore,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> SnapshotCacheStore {
        guard
            let rawURL = environment["WTT_SYNC_BASE_URL"],
            let baseURL = URL(string: rawURL),
            let token = environment["WTT_SYNC_TOKEN"],
            token.count >= 32
        else {
            return local
        }

        return NeonSyncingSnapshotCacheStore(
            local: local,
            remote: HTTPSnapshotCacheSyncClient(baseURL: baseURL, token: token)
        )
    }
}
