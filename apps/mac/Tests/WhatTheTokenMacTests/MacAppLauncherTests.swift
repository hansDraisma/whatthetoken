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
@Test func interactiveLaunchConfiguresRegularForegroundApp() {
    let application = RecordingMacApplication()

    MacAppLauncher.configureForInteractiveLaunch(
        arguments: ["WhatTheTokenMac"],
        application: application
    )

    #expect(application.policies == [.regular])
    #expect(application.activateCount == 1)
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
