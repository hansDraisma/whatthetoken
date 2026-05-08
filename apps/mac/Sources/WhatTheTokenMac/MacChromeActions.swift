#if canImport(AppKit)
import AppKit
#endif

enum MacChromeActions {
    @MainActor
    static func openSettings(
        activate: @MainActor () -> Void = defaultActivate,
        openSettings: @MainActor () -> Void
    ) {
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
    private static func defaultActivate() {
        #if canImport(AppKit)
        NSApplication.shared.activate(ignoringOtherApps: true)
        #endif
    }

    @MainActor
    private static func defaultShowAbout() {
        #if canImport(AppKit)
        NSApplication.shared.orderFrontStandardAboutPanel(nil)
        #endif
    }
}
