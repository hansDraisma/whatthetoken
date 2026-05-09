import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    let viewModel: StatusViewModel
    let refreshController: PopoverRefreshController
    let backgroundRefreshController: BackgroundRefreshController

    init(viewModel: StatusViewModel) {
        self.viewModel = viewModel
        self.refreshController = PopoverRefreshController(viewModel: viewModel)
        let backgroundRefreshController = BackgroundRefreshController(viewModel: viewModel)
        self.backgroundRefreshController = backgroundRefreshController
        self.viewModel.onSettingsChanged = { [weak backgroundRefreshController] in
            backgroundRefreshController?.settingsDidChange()
        }
        Task {
            await viewModel.loadPersistedState()
            backgroundRefreshController.start()
        }
    }

    static func live() -> AppModel {
        let directory = applicationSupportDirectory()
        let settingsStore = JSONFileAppSettingsStore(url: directory.appendingPathComponent("settings.json"))
        let cacheStore = JSONFileSnapshotCacheStore(url: directory.appendingPathComponent("snapshot-cache.json"))
        let notificationStateStore = JSONFileNotificationStateStore(url: directory.appendingPathComponent("notification-state.json"))
        return AppModel(
            viewModel: .live(
                settingsStore: settingsStore,
                cacheStore: cacheStore,
                notificationStateStore: notificationStateStore,
                notificationDelivery: UserNotificationDelivery()
            )
        )
    }

    private static func applicationSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("WhatTheToken", isDirectory: true)
    }
}
