import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    let viewModel: StatusViewModel
    let refreshController: PopoverRefreshController

    init(viewModel: StatusViewModel) {
        self.viewModel = viewModel
        self.refreshController = PopoverRefreshController(viewModel: viewModel)
        Task { await viewModel.loadPersistedState() }
    }

    static func live() -> AppModel {
        let directory = applicationSupportDirectory()
        let settingsStore = JSONFileAppSettingsStore(url: directory.appendingPathComponent("settings.json"))
        let cacheStore = JSONFileSnapshotCacheStore(url: directory.appendingPathComponent("snapshot-cache.json"))
        return AppModel(viewModel: .live(settingsStore: settingsStore, cacheStore: cacheStore))
    }

    private static func applicationSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("WhatTheToken", isDirectory: true)
    }
}
