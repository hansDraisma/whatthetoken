import Foundation
import Observation
import AppKit
import SwiftUI

@MainActor
@Observable
final class AppModel {
    let viewModel: StatusViewModel
    let refreshController: PopoverRefreshController
    let backgroundRefreshController: BackgroundRefreshController
    let updateController: SparkleUpdateController
    let menuBarController: MenuBarController

    init(
        viewModel: StatusViewModel,
        refreshController: PopoverRefreshController,
        menuBarController: MenuBarController,
        updateController: SparkleUpdateController = SparkleUpdateController()
    ) {
        self.viewModel = viewModel
        self.refreshController = refreshController
        self.menuBarController = menuBarController
        self.updateController = updateController
        let backgroundRefreshController = BackgroundRefreshController(viewModel: viewModel)
        self.backgroundRefreshController = backgroundRefreshController
        self.viewModel.onSettingsChanged = { [weak backgroundRefreshController] in
            backgroundRefreshController?.settingsDidChange()
        }
        Task { @MainActor in
            await viewModel.loadPersistedState()
            await viewModel.registerCurrentHotkey()
            backgroundRefreshController.start()
            FirstLaunchAutoOpenSignaler.signalIfNeeded(settings: viewModel.settings)
        }
    }

    @MainActor
    static func openLaunchWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    static func live() -> AppModel {
        let appSupport = applicationSupportDirectory()
        let appGroup = appGroupContainerDirectory()
        let settingsStore = JSONFileAppSettingsStore(url: appSupport.appendingPathComponent("settings.json"))
        let cacheStore = JSONFileSnapshotCacheStore(url: appGroup.appendingPathComponent("snapshot-cache.json"))
        let notificationStateStore = JSONFileNotificationStateStore(url: appSupport.appendingPathComponent("notification-state.json"))

        let viewModel = StatusViewModel.live(
            settingsStore: settingsStore,
            cacheStore: cacheStore,
            notificationStateStore: notificationStateStore,
            notificationDelivery: UserNotificationDelivery()
        )
        let updateController = SparkleUpdateController()
        let refreshController = PopoverRefreshController(viewModel: viewModel)

        weak var menuBarControllerWeak: MenuBarController?
        let popoverRoot = PopoverRootView(
            viewModel: viewModel,
            controller: refreshController,
            canCheckForUpdates: { updateController.canCheckForUpdates },
            onOpenSettings: {
                MacChromeActions.openLaunchWindow(
                    dismissPopover: { menuBarControllerWeak?.closePopover() },
                    openWindow: { AppModel.openLaunchWindow() }
                )
            },
            onCheckForUpdates: { updateController.checkForUpdates(nil) },
            onOpenDeveloperWindow: nil
        )
        let popoverHosting = NSHostingController(rootView: popoverRoot)
        popoverHosting.sizingOptions = [.intrinsicContentSize]

        let menuBarController = MenuBarController.live(popoverContent: popoverHosting)
        menuBarControllerWeak = menuBarController
        viewModel.bindMenuBarController(menuBarController)

        let hotkeyService = GlobalHotkeyService(registrar: CarbonHotkeyRegistrar())
        viewModel.bindHotkeyService(hotkeyService) { [weak menuBarController] in
            menuBarController?.openPopover()
        }

        return AppModel(
            viewModel: viewModel,
            refreshController: refreshController,
            menuBarController: menuBarController,
            updateController: updateController
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
        return applicationSupportDirectory()
    }
}
