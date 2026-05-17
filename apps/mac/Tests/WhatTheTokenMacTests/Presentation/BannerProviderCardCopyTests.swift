import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct BannerProviderCardCopyTests {
    @Test func connectedStateShowsConnectedLabel() {
        let copy = BannerProviderCardCopy(
            title: "Claude Code",
            subtitle: "Anthropic",
            isConnected: true,
            connectActionTitle: "Connect"
        )

        #expect(copy.trailingLabel == "Connected")
        #expect(copy.showsConnectButton == false)
    }

    @Test func disconnectedStateShowsConnectButtonTitle() {
        let copy = BannerProviderCardCopy(
            title: "Codex",
            subtitle: "OpenAI",
            isConnected: false,
            connectActionTitle: "Connect"
        )

        #expect(copy.trailingLabel == "Connect")
        #expect(copy.showsConnectButton == true)
    }
}
