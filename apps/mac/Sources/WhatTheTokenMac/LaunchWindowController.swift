import Foundation
#if canImport(AppKit)
import AppKit
import SwiftUI
#endif

@MainActor
protocol LaunchWindowPresenting: AnyObject {
    var isVisible: Bool { get }
    func center()
    func makeKeyAndOrderFront(_ sender: Any?)
}

#if canImport(AppKit)
extension NSWindow: LaunchWindowPresenting {}
#endif

@MainActor
final class LaunchWindowController {
    private let makeWindow: @MainActor () -> LaunchWindowPresenting
    private let activate: @MainActor () -> Void
    private var window: LaunchWindowPresenting?

    init(
        makeWindow: @MainActor @escaping () -> LaunchWindowPresenting,
        activate: @MainActor @escaping () -> Void
    ) {
        self.makeWindow = makeWindow
        self.activate = activate
    }

    func open() {
        let window = existingOrNewWindow()
        activate()
        window.makeKeyAndOrderFront(nil)
    }

    var hasVisibleWindow: Bool {
        window?.isVisible == true
    }

    func bringToFront() {
        guard let window else {
            open()
            return
        }
        activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func existingOrNewWindow() -> LaunchWindowPresenting {
        if let window {
            return window
        }

        let window = makeWindow()
        self.window = window
        return window
    }
}

#if canImport(AppKit)
extension LaunchWindowController {
    convenience init(viewModel: StatusViewModel) {
        self.init(
            makeWindow: { Self.makeWindow(viewModel: viewModel) },
            activate: { NSApplication.shared.activate(ignoringOtherApps: true) }
        )
    }

    private static func makeWindow(viewModel: StatusViewModel) -> NSWindow {
        let controller = NSHostingController(rootView: LaunchWindowRootView(viewModel: viewModel))
        let window = NSWindow(contentViewController: controller)
        window.title = "WhatTheToken"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 820, height: 560))
        window.minSize = NSSize(width: 720, height: 480)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.setFrameAutosaveName("WhatTheTokenLaunchWindow")
        if !window.setFrameUsingName("WhatTheTokenLaunchWindow") {
            window.center()
        }
        return window
    }
}
#endif
