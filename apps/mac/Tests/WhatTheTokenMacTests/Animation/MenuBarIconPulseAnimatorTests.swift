import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct MenuBarIconPulseAnimatorTests {
    @MainActor
    @Test func pulseChoosesFadePathWhenReduceMotionIsTrue() {
        let driver = SpyPulseDriver()
        let animator = MenuBarIconPulseAnimator(driver: driver, reduceMotion: { true })

        animator.pulse()

        #expect(driver.invocations == [.fadeHold])
    }

    @MainActor
    @Test func pulseChoosesFullPulsePathWhenReduceMotionIsFalse() {
        let driver = SpyPulseDriver()
        let animator = MenuBarIconPulseAnimator(driver: driver, reduceMotion: { false })

        animator.pulse()

        #expect(driver.invocations == [.repeatingPulse])
    }

    @MainActor
    @Test func multiplePulsesEachInvokeDriver() {
        let driver = SpyPulseDriver()
        let animator = MenuBarIconPulseAnimator(driver: driver, reduceMotion: { false })

        animator.pulse()
        animator.pulse()

        #expect(driver.invocations == [.repeatingPulse, .repeatingPulse])
    }

    @MainActor
    @Test func startingRepeatingPulseRemovesPriorFade() {
        let driver = SpyPulseDriver()
        let animator = MenuBarIconPulseAnimator(driver: driver, reduceMotion: { false })

        animator.pulse()
        animator.pulse()

        #expect(driver.removedKeys.contains("wtt-pulse-fade"))
    }
}

final class SpyPulseDriver: PulseAnimationDriving, @unchecked Sendable {
    enum Invocation: Equatable { case fadeHold, repeatingPulse }
    var invocations: [Invocation] = []
    var removedKeys: [String] = []

    func runFadeHold() { invocations.append(.fadeHold) }
    func runRepeatingPulse() { invocations.append(.repeatingPulse) }
    func removeAnimation(forKey key: String) { removedKeys.append(key) }
}
