import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct MenuBarControllerTests {
    @MainActor
    @Test func openPopoverDelegatesToHosting() {
        let hosting = SpyMenuBarHosting()
        let controller = MenuBarController(hosting: hosting, pulseAnimator: SpyPulseAnimator())

        controller.openPopover()

        #expect(hosting.openCount == 1)
    }

    @MainActor
    @Test func openPopoverActivatesAppBeforeShow() {
        let hosting = SpyMenuBarHosting()
        let controller = MenuBarController(hosting: hosting, pulseAnimator: SpyPulseAnimator())

        controller.openPopover()

        #expect(hosting.calls == ["activateAppForPopover", "openPopover"])
    }

    @MainActor
    @Test func togglePopoverOpensWhenClosed() {
        let hosting = SpyMenuBarHosting()
        hosting.isOpen = false
        let controller = MenuBarController(hosting: hosting, pulseAnimator: SpyPulseAnimator())

        controller.togglePopover()

        #expect(hosting.openCount == 1)
        #expect(hosting.closeCount == 0)
    }

    @MainActor
    @Test func togglePopoverClosesWhenOpen() {
        let hosting = SpyMenuBarHosting()
        hosting.isOpen = true
        let controller = MenuBarController(hosting: hosting, pulseAnimator: SpyPulseAnimator())

        controller.togglePopover()

        #expect(hosting.closeCount == 1)
        #expect(hosting.openCount == 0)
    }

    @MainActor
    @Test func pulseInvokesAnimator() {
        let hosting = SpyMenuBarHosting()
        let animator = SpyPulseAnimator()
        let controller = MenuBarController(hosting: hosting, pulseAnimator: animator)

        controller.pulse()

        #expect(animator.pulseCount == 1)
    }

    @MainActor
    @Test func updateCriticalStateRewritesIcon() {
        let hosting = SpyMenuBarHosting()
        let controller = MenuBarController(hosting: hosting, pulseAnimator: SpyPulseAnimator())

        controller.updateCriticalState(isCritical: true)

        #expect(hosting.lastSetCriticalState == true)
    }

    @MainActor
    @Test func releasingControllerTearsDownHosting() async {
        let hosting = SpyMenuBarHosting()

        do { _ = MenuBarController(hosting: hosting, pulseAnimator: SpyPulseAnimator()) }
        await Task.yield()

        #expect(hosting.calls.contains("teardown"))
    }

    @Test func menuBarControllerDoesNotAssumeMainActorInDeinit() throws {
        let source = try menuSourceContents("MenuBarController.swift")

        #expect(!source.contains("MainActor.assumeIsolated"))
    }

    @Test func liveMenuBarHostingClosesPopoverWithoutUnnecessaryMainActorHop() throws {
        let source = try menuSourceContents("MenuBarController.swift")

        #expect(!source.contains("Task { @MainActor in self?.popover.performClose(nil) }"))
        #expect(!source.contains("Task { @MainActor in self?.removeGlobalMonitor() }"))
    }

    private func menuSourceContents(_ name: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/WhatTheTokenMac/MenuBar/\(name)")
        return try String(contentsOf: url, encoding: .utf8)
    }
}

@MainActor
final class SpyMenuBarHosting: MenuBarHosting, @unchecked Sendable {
    var openCount = 0
    var closeCount = 0
    var isOpen = false
    var lastSetCriticalState: Bool?
    var calls: [String] = []

    func openPopover() { openCount += 1; calls.append("openPopover") }
    func closePopover() { closeCount += 1; calls.append("closePopover") }
    func setIconCritical(_ isCritical: Bool) { lastSetCriticalState = isCritical; calls.append("setIconCritical(\(isCritical))") }
    func activateAppForPopover() { calls.append("activateAppForPopover") }
    func teardown() { calls.append("teardown") }
}

@MainActor
final class SpyPulseAnimator: MenuBarPulsing {
    var pulseCount = 0
    func pulse() { pulseCount += 1 }
}
