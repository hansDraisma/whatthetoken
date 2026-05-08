import Testing
@testable import WhatTheTokenMac

@Suite struct AppModelTests {
    @MainActor
    @Test func live_initializesWiredDependencies() {
        let app = AppModel.live()
        #expect(app.viewModel.isRefreshAllInFlight == false)
        app.refreshController.userTappedRefresh()
    }
}
