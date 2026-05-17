import Foundation
#if canImport(AppKit)
import AppKit
#endif

@MainActor
protocol MacAppDelegateActions: AnyObject {
    func openPopover()
    func pulseMenuBarIcon()
}

@MainActor
final class MacAppDelegate: NSObject {
    let actions: MacAppDelegateActions

    init(actions: MacAppDelegateActions) {
        self.actions = actions
    }

    @discardableResult
    func applicationShouldHandleReopen(hasVisibleWindows: Bool) -> Bool {
        actions.openPopover()
        actions.pulseMenuBarIcon()
        return false
    }
}

#if canImport(AppKit)
extension MacAppDelegate: NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        applicationShouldHandleReopen(hasVisibleWindows: flag)
    }
}
#endif

@MainActor
enum FirstLaunchAutoOpenSignaler {
    static func signalIfNeeded(settings: AppSettings, open: () -> Void) {
        guard settings.onboarding.firstLaunchCompleted == false else { return }
        open()
    }
}
