import Foundation
import Testing
@testable import WhatTheTokenMac

private let syncBaseURL = URL(string: "http://127.0.0.1:4318")!
private let syncToken = "synthetic-local-sync-token-32-characters"

@Test func syncClientFetchesValidatedCache() async throws {
    var cache = SnapshotCache.empty
    cache.replaceSnapshots(
        [UsageSnapshotFixture.claudeSample()],
        for: .claude,
        at: Date(timeIntervalSince1970: 1_000)
    )
    let data = try JSONEncoder.cacheEncoder.encode(cache)
    let loader = StubSnapshotSyncLoader { request in
        #expect(request.url?.absoluteString == "http://127.0.0.1:4318/v1/snapshot-cache")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(syncToken)")
        return (data, syncHTTPResponse(status: 200))
    }

    let loaded = try await HTTPSnapshotCacheSyncClient(
        baseURL: syncBaseURL,
        token: syncToken,
        loader: loader
    ).fetch()

    #expect(loaded == cache)
}

@Test func syncClientTreatsMissingRemoteCacheAsEmptyResult() async throws {
    let client = HTTPSnapshotCacheSyncClient(
        baseURL: syncBaseURL,
        token: syncToken,
        loader: StubSnapshotSyncLoader { _ in (Data(), syncHTTPResponse(status: 404)) }
    )

    #expect(try await client.fetch() == nil)
}

@Test func syncingStoreRestoresRemoteCacheLocally() async throws {
    var remoteCache = SnapshotCache.empty
    remoteCache.replaceSnapshots(
        [UsageSnapshotFixture.codexSample()],
        for: .codex,
        at: Date(timeIntervalSince1970: 2_000)
    )
    let local = InMemorySnapshotCacheStore()
    let store = NeonSyncingSnapshotCacheStore(
        local: local,
        remote: StubSnapshotCacheSyncer(fetched: remoteCache)
    )

    #expect(await store.load() == remoteCache)
    #expect(await local.load() == remoteCache)
}

@Test func syncingStoreFallsBackToLocalCacheWhenNeonIsUnavailable() async {
    var localCache = SnapshotCache.empty
    localCache.replaceSnapshots(
        [UsageSnapshotFixture.claudeSample()],
        for: .claude,
        at: Date(timeIntervalSince1970: 1_000)
    )
    let local = InMemorySnapshotCacheStore(
        data: try! JSONEncoder.cacheEncoder.encode(localCache)
    )
    let store = NeonSyncingSnapshotCacheStore(
        local: local,
        remote: StubSnapshotCacheSyncer(error: .requestFailed)
    )

    #expect(await store.load() == localCache)
}

@Test func syncingStoreReportsSaveFailureWhenRemoteWriteFails() async {
    let store = NeonSyncingSnapshotCacheStore(
        local: InMemorySnapshotCacheStore(),
        remote: StubSnapshotCacheSyncer(error: .requestFailed)
    )

    #expect(await store.save(.empty) == false)
}

@Test func syncConfigurationRequiresBothEndpointAndLongToken() {
    let local = InMemorySnapshotCacheStore()
    let disabled = NeonSnapshotSyncConfiguration.wrapping(local: local, environment: [:])
    let invalid = NeonSnapshotSyncConfiguration.wrapping(
        local: local,
        environment: ["WTT_SYNC_BASE_URL": syncBaseURL.absoluteString, "WTT_SYNC_TOKEN": "short"]
    )

    #expect(disabled is InMemorySnapshotCacheStore)
    #expect(invalid is InMemorySnapshotCacheStore)
}

private struct StubSnapshotSyncLoader: SnapshotSyncURLLoading {
    let handler: @Sendable (URLRequest) throws -> (Data, URLResponse)

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try handler(request)
    }
}

private struct StubSnapshotCacheSyncer: SnapshotCacheSyncing {
    var fetched: SnapshotCache?
    var error: SnapshotSyncError?

    init(fetched: SnapshotCache? = nil, error: SnapshotSyncError? = nil) {
        self.fetched = fetched
        self.error = error
    }

    func fetch() async throws -> SnapshotCache? {
        if let error { throw error }
        return fetched
    }

    func upload(_ cache: SnapshotCache) async throws {
        if let error { throw error }
    }
}

private func syncHTTPResponse(status: Int) -> HTTPURLResponse {
    HTTPURLResponse(
        url: syncBaseURL.appendingPathComponent("v1/snapshot-cache"),
        statusCode: status,
        httpVersion: nil,
        headerFields: nil
    )!
}
