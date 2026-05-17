import Foundation
#if canImport(AppKit)
import AppKit
#endif

@MainActor
protocol PulseAnimationDriving: AnyObject {
    func runFadeHold()
    func runRepeatingPulse()
}

@MainActor
struct MenuBarIconPulseAnimator {
    let driver: PulseAnimationDriving
    let reduceMotion: () -> Bool

    func pulse() {
        if reduceMotion() {
            driver.runFadeHold()
        } else {
            driver.runRepeatingPulse()
        }
    }
}

#if canImport(AppKit)
@MainActor
final class StatusItemPulseDriver: PulseAnimationDriving {
    private let statusItem: NSStatusItem

    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
    }

    func runFadeHold() {
        guard let layer = statusItem.button?.layer else { return }
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1.0
        animation.toValue = 0.4
        animation.duration = 0.75
        animation.autoreverses = true
        animation.repeatCount = 1
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: "wtt-pulse-fade")
    }

    func runRepeatingPulse() {
        guard let layer = statusItem.button?.layer else { return }
        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [1.0, 0.45, 1.0]
        opacity.keyTimes = [0.0, 0.5, 1.0]

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [1.0, 1.18, 1.0]
        scale.keyTimes = [0.0, 0.5, 1.0]

        let group = CAAnimationGroup()
        group.animations = [opacity, scale]
        group.duration = 0.6
        group.repeatCount = 5
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(group, forKey: "wtt-pulse-repeating")
    }
}

extension MenuBarIconPulseAnimator {
    static func liveSystem(statusItem: NSStatusItem) -> MenuBarIconPulseAnimator {
        MenuBarIconPulseAnimator(
            driver: StatusItemPulseDriver(statusItem: statusItem),
            reduceMotion: { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
        )
    }
}
#endif
