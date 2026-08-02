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
    let reconnectWatcher: ClaudeReconnectWatcher
    let updateController: SparkleUpdateController
    let menuBarController: MenuBarController
    let launchWindowController: LaunchWindowController

    init(
        viewModel: StatusViewModel,
        refreshController: PopoverRefreshController,
        menuBarController: MenuBarController,
        launchWindowController: LaunchWindowController,
        updateController: SparkleUpdateController = SparkleUpdateController()
    ) {
        self.viewModel = viewModel
        self.refreshController = refreshController
        self.menuBarController = menuBarController
        self.launchWindowController = launchWindowController
        self.updateController = updateController
        let backgroundRefreshController = BackgroundRefreshController(viewModel: viewModel)
        let reconnectWatcher = ClaudeReconnectWatcher(
            probe: ClaudeCredentialProbe(
                credentialStore: MacOSClaudeCredentialStore()
            ),
            onRotationDetected: {
                await viewModel.refreshClaudeAfterCredentialRotation()
            }
        )
        self.backgroundRefreshController = backgroundRefreshController
        self.reconnectWatcher = reconnectWatcher
        self.viewModel.onSettingsChanged = { [weak backgroundRefreshController] in
            backgroundRefreshController?.settingsDidChange()
        }
        self.viewModel.onClaudeConnectorStateChanged = { [weak reconnectWatcher] state in
            reconnectWatcher?.connectorStateDidChange(to: state)
        }
        Task { @MainActor in
            await AppStartupRoutine.run(
                loadPersistedState: { try await viewModel.loadPersistedStateThrowing() },
                logger: OSLogAppLogger(category: "AppModel.live"),
                registerHotkey: { await viewModel.registerCurrentHotkey() },
                verifyConnectors: {
                    await viewModel.refreshAll(reason: .startupVerification)
                },
                activateReconnectWatcher: {
                    reconnectWatcher.activate(currentState: viewModel.connectorState)
                },
                startRefresh: {
                    backgroundRefreshController.start(
                        afterStartupVerification: true
                    )
                }
            )
        }
    }

    static func live() -> AppModel {
        let appSupport = applicationSupportDirectory()
        let settingsStore = JSONFileAppSettingsStore(url: appSupport.appendingPathComponent("settings.json"))
        let primaryCacheURL = WidgetSnapshotCacheFile.appGroupURL()
            ?? WidgetSnapshotCacheFile.localAppGroupURL()
        let localCacheStore = MirroringSnapshotCacheStore(
            primary: JSONFileSnapshotCacheStore(url: primaryCacheURL),
            mirrors: [
                JSONFileSnapshotCacheStore(url: WidgetSnapshotCacheFile.widgetContainerMirrorURL())
            ]
        )
        let cacheStore = NeonSnapshotSyncConfiguration.wrapping(local: localCacheStore)
        let notificationStateStore = JSONFileNotificationStateStore(url: appSupport.appendingPathComponent("notification-state.json"))

        let viewModel = StatusViewModel.live(
            settingsStore: settingsStore,
            cacheStore: cacheStore,
            notificationStateStore: notificationStateStore,
            notificationDelivery: UserNotificationDelivery()
        )
        let updateController = SparkleUpdateController()
        let refreshController = PopoverRefreshController(viewModel: viewModel)
        let launchWindowController = LaunchWindowController(
            viewModel: viewModel,
            updateController: updateController
        )

        weak var menuBarControllerWeak: MenuBarController?
        let popoverRoot = PopoverRootView(
            viewModel: viewModel,
            controller: refreshController,
            canCheckForUpdates: { updateController.canCheckForUpdates },
            onOpenConnectors: {
                MacChromeActions.openLaunchWindow(
                    dismissPopover: { menuBarControllerWeak?.closePopover() },
                    openWindow: { launchWindowController.open(tab: .connectors) }
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
            launchWindowController: launchWindowController,
            updateController: updateController
        )
    }

    static func applicationSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("WhatTheToken", isDirectory: true)
    }

    static func appGroupContainerDirectory() -> URL {
        if let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupIdentifier.shared
        ) {
            return url
        }
        return applicationSupportDirectory()
    }
}
