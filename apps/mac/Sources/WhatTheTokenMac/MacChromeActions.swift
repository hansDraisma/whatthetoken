#if canImport(AppKit)
import AppKit
#endif

enum MacChromeActions {
    @MainActor
    static func openSettings(
        dismissPopover: @MainActor () -> Void = defaultDismissPopover,
        activate: @MainActor () -> Void = defaultActivate,
        openSettings: @MainActor () -> Void
    ) {
        dismissPopover()
        activate()
        openSettings()
    }

    @MainActor
    static func showAbout(
        activate: @MainActor () -> Void = defaultActivate,
        showAbout: @MainActor () -> Void = defaultShowAbout
    ) {
        activate()
        showAbout()
    }

    @MainActor
    static func openDeveloperWindow(
        activate: @MainActor () -> Void = defaultActivate,
        openWindow: @MainActor () -> Void
    ) {
        activate()
        openWindow()
    }

    @MainActor
    static func openLaunchWindow(
        dismissPopover: @MainActor () -> Void = defaultDismissPopover,
        activate: @MainActor () -> Void = defaultActivate,
        openWindow: @MainActor () -> Void
    ) {
        dismissPopover()
        activate()
        openWindow()
    }

    @MainActor
    private static func defaultActivate() {
        #if canImport(AppKit)
        NSApplication.shared.activate(ignoringOtherApps: true)
        #endif
    }

    @MainActor
    private static func defaultDismissPopover() {
        #if canImport(AppKit)
        guard let key = NSApplication.shared.keyWindow else { return }
        // The MenuBarExtra(.window) popover host has an empty title; SwiftUI's
        // Settings and Developer windows always have a title. Use that to avoid
        // accidentally closing a regular scene that happens to be key.
        guard key.title.isEmpty else { return }
        key.close()
        #endif
    }

    @MainActor
    private static func defaultShowAbout() {
        #if canImport(AppKit)
        NSApplication.shared.orderFrontStandardAboutPanel(nil)
        #endif
    }
}
