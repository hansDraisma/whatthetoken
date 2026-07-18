import SwiftUI
import AppKit

#if canImport(Sentry)
import Sentry
#endif

enum SentryMonitoring {
    static func configuredDSN(
        infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:],
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String? {
        let candidate = environment["SENTRY_DSN"]
            ?? infoDictionary["SentryDSN"] as? String
        guard let dsn = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
              !dsn.isEmpty,
              !dsn.contains("$("),
              URL(string: dsn)?.scheme == "https" else {
            return nil
        }
        return dsn
    }

    @MainActor
    static func start(dsn: String? = configuredDSN()) {
        #if canImport(Sentry)
        guard let dsn else { return }

        SentrySDK.start { options in
            options.dsn = dsn
            options.sendDefaultPii = false

            // This integration is intentionally limited to explicit, sanitized
            // schema-drift errors from the Claude usage parser.
            options.enableCrashHandler = false
            options.enableAutoSessionTracking = false
            options.enableWatchdogTerminationTracking = false
            options.enableNetworkBreadcrumbs = false
            options.enableAutoBreadcrumbTracking = false
            options.enableAutoPerformanceTracing = false
            options.enableNetworkTracking = false
            options.enableFileIOTracing = false
            options.enableCoreDataTracing = false
            options.enableAppHangTracking = false
            options.enableSwizzling = false
            options.enableLogs = false
            options.maxBreadcrumbs = 0
            options.tracesSampleRate = 0
            #if DEBUG
            options.environment = "development"
            #else
            options.environment = "production"
            #endif
        }
        #endif
    }
}

enum AppLaunchRouter {
    static func route<LaunchApp>(
        arguments: [String],
        shouldRunClaudeSmoke: ([String]) -> Bool,
        shouldRunCodexSmoke: ([String]) -> Bool,
        startClaudeSmoke: () -> Void,
        startCodexSmoke: () -> Void,
        configureInteractiveLaunch: () -> Void,
        makeLiveApp: () -> LaunchApp
    ) -> LaunchApp? {
        if shouldRunClaudeSmoke(arguments) {
            startClaudeSmoke()
            return nil
        }
        if shouldRunCodexSmoke(arguments) {
            startCodexSmoke()
            return nil
        }

        configureInteractiveLaunch()
        return makeLiveApp()
    }
}

@main
struct WhatTheTokenApp: App {
    private let app: AppModel?
    @Environment(\.openWindow) private var openWindow
    @NSApplicationDelegateAdaptor(MacAppDelegateAdaptor.self) private var delegateAdaptor

    init() {
        SentryMonitoring.start()
        let app = Self.makeAppForLaunch(
            arguments: CommandLine.arguments,
            makeLiveApp: { AppModel.live() },
            startClaudeSmoke: { _ = ClaudeConnectorSmokeCommand.startCommandLineSmoke() },
            startCodexSmoke: { _ = CodexConnectorSmokeCommand.startCommandLineSmoke() },
            configureInteractiveLaunch: { MacAppLauncher.configureLaunch() }
        )
        self.app = app
        delegateAdaptor.bind(app: app)
    }

    @MainActor
    static func makeAppForLaunch(
        arguments: [String],
        makeLiveApp: () -> AppModel,
        startClaudeSmoke: () -> Void,
        startCodexSmoke: () -> Void,
        configureInteractiveLaunch: () -> Void
    ) -> AppModel? {
        AppLaunchRouter.route(
            arguments: arguments,
            shouldRunClaudeSmoke: { ClaudeConnectorSmokeCommand.shouldRun(arguments: $0) },
            shouldRunCodexSmoke: { CodexConnectorSmokeCommand.shouldRun(arguments: $0) },
            startClaudeSmoke: startClaudeSmoke,
            startCodexSmoke: startCodexSmoke,
            configureInteractiveLaunch: configureInteractiveLaunch,
            makeLiveApp: makeLiveApp
        )
    }

    @SceneBuilder
    var body: some Scene {
        #if DEBUG
        Window("WhatTheToken - Developer", id: "developer") {
            if let app {
                DeveloperWindowView(viewModel: app.viewModel)
            } else {
                EmptyView()
            }
        }
        .commands {
            CommandMenu("Debug") {
                Button("Developer Window") {
                    openWindow(id: "developer")
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }
        #else
        Window("WhatTheToken", id: "command-host") {
            EmptyView()
        }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button("Settings...") {
                        MacChromeActions.openLaunchWindow(
                            dismissPopover: { app?.menuBarController.closePopover() },
                            openWindow: { app?.launchWindowController.open() }
                        )
                    }
                    .keyboardShortcut(",", modifiers: .command)
                }
            }
        #endif
    }
}

@MainActor
final class MacAppDelegateAdaptor: NSObject, NSApplicationDelegate {
    private weak var app: AppModel?
    private var delegate: MacAppDelegate?

    func bind(app: AppModel?) {
        self.app = app
        if let app {
            delegate = MacAppDelegate(actions: AppModelDelegateActions(app: app))
        } else {
            delegate = nil
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        delegate?.applicationShouldHandleReopen(hasVisibleWindows: flag) ?? true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        delegate?.applicationShouldTerminateAfterLastWindowClosed() ?? false
    }
}

@MainActor
private final class AppModelDelegateActions: MacAppDelegateActions {
    let app: AppModel

    init(app: AppModel) {
        self.app = app
    }

    func openPopover() {
        Task { await app.viewModel.openPopoverProgrammatically() }
    }

    func pulseMenuBarIcon() {
        Task { await app.viewModel.pulseMenuBarIcon() }
    }

    var hasVisibleLaunchWindow: Bool {
        app.launchWindowController.hasVisibleWindow
    }

    func openLaunchWindow() {
        app.launchWindowController.open()
    }

    func bringLaunchWindowForward() {
        app.launchWindowController.bringToFront()
    }
}
