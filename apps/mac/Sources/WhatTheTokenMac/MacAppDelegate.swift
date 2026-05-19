import Foundation
#if canImport(AppKit)
import AppKit
#endif

@MainActor
protocol MacAppDelegateActions: AnyObject {
    func openPopover()
    func pulseMenuBarIcon()
    var hasVisibleLaunchWindow: Bool { get }
    func openLaunchWindow()
    func bringLaunchWindowForward()
}

@MainActor
final class MacAppDelegate: NSObject {
    let actions: MacAppDelegateActions

    init(actions: MacAppDelegateActions) {
        self.actions = actions
    }

    @discardableResult
    func applicationShouldHandleReopen(hasVisibleWindows: Bool) -> Bool {
        if actions.hasVisibleLaunchWindow {
            actions.bringLaunchWindowForward()
        } else {
            actions.openLaunchWindow()
        }
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed() -> Bool {
        false
    }
}

#if canImport(AppKit)
extension MacAppDelegate: NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        applicationShouldHandleReopen(hasVisibleWindows: flag)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        applicationShouldTerminateAfterLastWindowClosed()
    }
}
#endif

@MainActor
enum FirstLaunchAutoOpenSignaler {
    static func signalIfNeeded(
        settings: AppSettings,
        open: () -> Void
    ) {
        guard settings.onboarding.firstLaunchCompleted == false else { return }
        open()
    }
}
