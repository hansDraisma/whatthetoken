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

@MainActor
final class MacAppRuntime: NSObject {
    static let shared = MacAppRuntime()

    private(set) var app: AppModel?

    private override init() {
        super.init()
    }

    func bind(app: AppModel?) {
        self.app = app
    }

    func openLaunchWindow() {
        app?.launchWindowController.open()
    }

    func installOpenApplicationEventHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenApplication(_:withReplyEvent:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenApplication)
        )
    }

    @objc private func handleOpenApplication(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        let shouldOpen = AppLaunchPresentation.shouldOpenWindow(
            launchedAsLoginItem: event.paramDescriptor(
                forKeyword: AEKeyword(keyAELaunchedAsLogInItem)
            ) != nil,
            launchedAsServiceItem: event.paramDescriptor(
                forKeyword: AEKeyword(keyAELaunchedAsServiceItem)
            ) != nil
        )
        guard shouldOpen else { return }
        openLaunchWindow()
    }

    @objc private func openLaunchWindow(_ sender: Any?) {
        openLaunchWindow()
    }

    func installSettingsMenuAction() {
        guard let appMenu = NSApplication.shared.mainMenu?.items.first?.submenu,
              let settingsItem = appMenu.items.first(where: { $0.keyEquivalent == "," }) else {
            return
        }
        settingsItem.target = self
        settingsItem.action = #selector(openLaunchWindow(_:))
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
        MacAppRuntime.shared.bind(app: app)
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
        // A Settings scene hosts the main-menu commands without creating a
        // default window when this menu bar app launches. The visible window
        // is owned by LaunchWindowController below.
        Settings {
            EmptyView()
        }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button("Settings...") {
                        MacChromeActions.openLaunchWindow(
                            dismissPopover: { MacAppRuntime.shared.app?.menuBarController.closePopover() },
                            openWindow: { MacAppRuntime.shared.app?.launchWindowController.open() }
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
    private var delegate: MacAppDelegate?

    func bind(app: AppModel?) {
        MacAppRuntime.shared.bind(app: app)
        delegate = app.map { MacAppDelegate(actions: AppModelDelegateActions(app: $0)) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        delegate?.applicationShouldHandleReopen(hasVisibleWindows: flag) ?? true
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // SwiftUI owns the default handler for its scene lifecycle. Replace it
        // only after SwiftUI has installed the delegate adaptor so the initial
        // open-application event reaches the AppKit-owned launch window.
        MacAppRuntime.shared.installOpenApplicationEventHandler()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Reinstall after AppKit finishes launch in case scene setup refreshed
        // its handler between the will-finish and did-finish callbacks.
        MacAppRuntime.shared.installOpenApplicationEventHandler()

        // SwiftUI finishes assembling its menu after this callback. Rewire the
        // Settings item on the next turn so it opens the AppKit-owned window.
        DispatchQueue.main.async {
            MacAppRuntime.shared.installSettingsMenuAction()
        }
    }

    func applicationDidUpdate(_ notification: Notification) {
        MacAppRuntime.shared.installSettingsMenuAction()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        delegate?.applicationShouldTerminateAfterLastWindowClosed() ?? false
    }
}

enum AppLaunchPresentation {
    static func shouldOpenWindow(
        launchedAsLoginItem: Bool = false,
        launchedAsServiceItem: Bool = false
    ) -> Bool {
        !launchedAsLoginItem && !launchedAsServiceItem
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
