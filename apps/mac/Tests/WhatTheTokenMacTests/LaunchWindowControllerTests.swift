import Testing
@testable import WhatTheTokenMac

@Suite struct LaunchWindowControllerTests {
    @MainActor
    @Test func openCreatesActivatesAndOrdersWindowFront() {
        var events: [String] = []
        let window = SpyLaunchWindow(events: { events.append($0) })
        let controller = LaunchWindowController(
            makeWindow: {
                events.append("makeWindow")
                return window
            },
            activate: { events.append("activate") }
        )

        controller.open()

        #expect(events == ["makeWindow", "activate", "orderFront"])
        #expect(window.orderFrontCount == 1)
    }

    @MainActor
    @Test func openReusesExistingWindowOnSubsequentRequests() {
        var makeWindowCount = 0
        let window = SpyLaunchWindow()
        let controller = LaunchWindowController(
            makeWindow: {
                makeWindowCount += 1
                return window
            },
            activate: {}
        )

        controller.open()
        controller.open()

        #expect(makeWindowCount == 1)
        #expect(window.centerCount == 0)
        #expect(window.orderFrontCount == 2)
    }

    @MainActor
    @Test func openTabSelectsRequestedPaneAndReusesExistingWindow() {
        let navigation = LaunchWindowNavigation()
        var makeWindowCount = 0
        let window = SpyLaunchWindow()
        let controller = LaunchWindowController(
            navigation: navigation,
            makeWindow: {
                makeWindowCount += 1
                return window
            },
            activate: {}
        )

        controller.open()
        controller.open(tab: .connectors)

        #expect(navigation.selection == .connectors)
        #expect(makeWindowCount == 1)
        #expect(window.orderFrontCount == 2)
    }

    @Test func liveWindowPersistsFrameAcrossLaunches() throws {
        let source = try String(
            contentsOfFile: "\(macPackageRootURL().path)/Sources/WhatTheTokenMac/LaunchWindowController.swift",
            encoding: .utf8
        )

        #expect(source.contains("setFrameAutosaveName(\"WhatTheTokenLaunchWindow\")"))
        #expect(source.contains("setFrameUsingName(\"WhatTheTokenLaunchWindow\")"))
    }
}

@MainActor
private final class SpyLaunchWindow: LaunchWindowPresenting {
    var centerCount = 0
    var orderFrontCount = 0
    var isVisible = false
    private let events: (String) -> Void

    init(events: @escaping (String) -> Void = { _ in }) {
        self.events = events
    }

    func center() {
        centerCount += 1
        events("center")
    }

    func makeKeyAndOrderFront(_ sender: Any?) {
        orderFrontCount += 1
        isVisible = true
        events("orderFront")
    }
}
