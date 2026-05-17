import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    let viewModel: StatusViewModel
    let refreshController: PopoverRefreshController
    let backgroundRefreshController: BackgroundRefreshController
    let updateController: SparkleUpdateController

    init(
        viewModel: StatusViewModel,
        updateController: SparkleUpdateController = SparkleUpdateController()
    ) {
        self.viewModel = viewModel
        self.refreshController = PopoverRefreshController(viewModel: viewModel)
        let backgroundRefreshController = BackgroundRefreshController(viewModel: viewModel)
        self.backgroundRefreshController = backgroundRefreshController
        self.updateController = updateController
        self.viewModel.onSettingsChanged = { [weak backgroundRefreshController] in
            backgroundRefreshController?.settingsDidChange()
        }
        Task {
            await viewModel.loadPersistedState()
            backgroundRefreshController.start()
        }
    }

    static func live() -> AppModel {
        let appSupport = applicationSupportDirectory()
        let appGroup = appGroupContainerDirectory()
        let settingsStore = JSONFileAppSettingsStore(url: appSupport.appendingPathComponent("settings.json"))
        let cacheStore = JSONFileSnapshotCacheStore(url: appGroup.appendingPathComponent("snapshot-cache.json"))
        let notificationStateStore = JSONFileNotificationStateStore(url: appSupport.appendingPathComponent("notification-state.json"))
        return AppModel(
            viewModel: .live(
                settingsStore: settingsStore,
                cacheStore: cacheStore,
                notificationStateStore: notificationStateStore,
                notificationDelivery: UserNotificationDelivery()
            )
        )
    }

    static func applicationSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("WhatTheToken", isDirectory: true)
    }

    static func appGroupContainerDirectory() -> URL {
        if let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.whatthetoken.mac"
        ) {
            return url
        }
        // SwiftPM builds are not codesigned with an App Group entitlement.
        return applicationSupportDirectory()
    }
}
