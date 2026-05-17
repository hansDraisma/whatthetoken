import Testing
@testable import WhatTheTokenMac

@MainActor
private final class RecordingMacApplication: MacApplicationActivating {
    private(set) var policies: [MacAppActivationPolicy] = []
    private(set) var activateCount = 0

    func setActivationPolicy(_ policy: MacAppActivationPolicy) {
        policies.append(policy)
    }

    func activateIgnoringOtherApps() {
        activateCount += 1
    }
}

@MainActor
@Test func interactiveLaunchConfiguresAccessoryByDefault() {
    let application = RecordingMacApplication()

    MacAppLauncher.configureForInteractiveLaunch(
        arguments: ["WhatTheTokenMac"],
        application: application,
        showInDock: { false }
    )

    #expect(application.policies == [.accessory])
    #expect(application.activateCount == 0)
}

@MainActor
@Test func smokeLaunchDoesNotActivateForegroundApp() {
    let application = RecordingMacApplication()

    MacAppLauncher.configureForInteractiveLaunch(
        arguments: ["WhatTheTokenMac", "--claude-connector-smoke"],
        application: application
    )

    #expect(application.policies.isEmpty)
    #expect(application.activateCount == 0)
}

@MainActor
@Test func accessoryLaunchSetsAccessoryPolicy_noActivate() {
    let application = RecordingMacApplication()

    MacAppLauncher.configureLaunch(
        arguments: ["WhatTheTokenMac"],
        application: application,
        showInDock: { false }
    )

    #expect(application.policies == [.accessory])
    #expect(application.activateCount == 0)
}

@MainActor
@Test func developerWindowFlagSetsRegularAndActivates() {
    let application = RecordingMacApplication()

    MacAppLauncher.configureLaunch(arguments: ["WhatTheTokenMac", "--developer-window"], application: application)

    #expect(application.policies == [.regular])
    #expect(application.activateCount == 1)
}

@MainActor
@Test func claudeSmokeIsNoop() {
    let application = RecordingMacApplication()

    MacAppLauncher.configureLaunch(arguments: ["WhatTheTokenMac", "--claude-connector-smoke"], application: application)

    #expect(application.policies.isEmpty)
    #expect(application.activateCount == 0)
}

@MainActor
@Test func codexSmokeIsNoop() {
    let application = RecordingMacApplication()

    MacAppLauncher.configureLaunch(arguments: ["WhatTheTokenMac", "--codex-connector-smoke"], application: application)

    #expect(application.policies.isEmpty)
    #expect(application.activateCount == 0)
}

@MainActor
@Test func choosesRegularWhenShowInDockIsTrue() {
    let application = RecordingMacApplication()

    MacAppLauncher.configureLaunch(
        arguments: ["WhatTheToken"],
        application: application,
        showInDock: { true }
    )

    #expect(application.policies == [.regular])
}

@MainActor
@Test func choosesAccessoryWhenShowInDockIsFalse() {
    let application = RecordingMacApplication()

    MacAppLauncher.configureLaunch(
        arguments: ["WhatTheToken"],
        application: application,
        showInDock: { false }
    )

    #expect(application.policies == [.accessory])
}

@MainActor
@Test func developerWindowOverrideAlwaysForcesRegular() {
    let application = RecordingMacApplication()

    MacAppLauncher.configureLaunch(
        arguments: ["WhatTheToken", "--developer-window"],
        application: application,
        showInDock: { false }
    )

    #expect(application.policies == [.regular])
}
