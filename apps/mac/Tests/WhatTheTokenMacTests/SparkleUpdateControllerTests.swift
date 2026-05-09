import Testing
@testable import WhatTheTokenMac

@MainActor
@Test func manualSparkleCheckIsNoopWhenReleaseMetadataIsMissing() {
    let controller = SparkleUpdateController(hasUpdateMetadata: { false })

    controller.checkForUpdates(nil)

    #expect(controller.canCheckForUpdates == false)
}
