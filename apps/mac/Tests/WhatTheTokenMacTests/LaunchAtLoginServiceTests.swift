import Foundation
import Testing
@testable import WhatTheTokenMac

@MainActor
@Suite struct LaunchAtLoginServiceTests {
    @Test func enablingLaunchAtLoginUpdatesServiceThenPersistsSetting() async {
        let service = RecordingLaunchAtLoginService()
        let store = InMemoryAppSettingsStore()
        let viewModel = StatusViewModel(settingsStore: store, launchAtLoginService: service)

        let saved = await viewModel.setLaunchAtLoginEnabled(true)
        let persisted = await store.load()

        #expect(saved)
        #expect(service.requests == [true])
        #expect(viewModel.settings.launchAtLogin.isEnabled)
        #expect(persisted.launchAtLogin.isEnabled)
        #expect(viewModel.launchAtLoginStatusMessage == nil)
    }

    @Test func failedServiceUpdateDoesNotPersistSetting() async {
        let service = RecordingLaunchAtLoginService(errorOnSet: LaunchAtLoginTestError.requiresApproval)
        let store = InMemoryAppSettingsStore()
        let viewModel = StatusViewModel(settingsStore: store, launchAtLoginService: service)

        let saved = await viewModel.setLaunchAtLoginEnabled(true)
        let persisted = await store.load()

        #expect(!saved)
        #expect(service.requests == [true])
        #expect(viewModel.settings.launchAtLogin.isEnabled == false)
        #expect(persisted.launchAtLogin.isEnabled == false)
        #expect(viewModel.launchAtLoginStatusMessage == "Launch at Login could not be updated: requires approval in System Settings")
    }

    @Test func failedSettingsSaveRollsBackService() async {
        let service = RecordingLaunchAtLoginService()
        let store = FailingAppSettingsStore()
        let viewModel = StatusViewModel(settingsStore: store, launchAtLoginService: service)

        let saved = await viewModel.setLaunchAtLoginEnabled(true)

        #expect(!saved)
        #expect(service.requests == [true, false])
        #expect(viewModel.settings.launchAtLogin.isEnabled == false)
        #expect(viewModel.launchAtLoginStatusMessage == "Launch at Login could not be saved")
    }
}

@MainActor
private final class RecordingLaunchAtLoginService: LaunchAtLoginServicing {
    var requests: [Bool] = []
    var isEnabled = false
    let errorOnSet: Error?

    init(errorOnSet: Error? = nil) {
        self.errorOnSet = errorOnSet
    }

    func setEnabled(_ enabled: Bool) throws {
        requests.append(enabled)
        if let errorOnSet {
            throw errorOnSet
        }
        isEnabled = enabled
    }
}

private enum LaunchAtLoginTestError: LocalizedError {
    case requiresApproval

    var errorDescription: String? {
        "requires approval in System Settings"
    }
}

private final class FailingAppSettingsStore: AppSettingsStore, @unchecked Sendable {
    func load() async -> AppSettings {
        .defaults
    }

    func save(_ settings: AppSettings) async -> Bool {
        false
    }
}
