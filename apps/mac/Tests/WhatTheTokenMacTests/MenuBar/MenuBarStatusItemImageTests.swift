import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct MenuBarStatusItemImageTests {
    @Test func criticalImageDeclaresCriticalAccessibilityLabel() {
        let descriptor = MenuBarStatusItemImage.descriptor(isCritical: true)

        #expect(descriptor.accessibilityLabel.contains("critical"))
    }

    @Test func okImageDeclaresOkAccessibilityLabel() {
        let descriptor = MenuBarStatusItemImage.descriptor(isCritical: false)

        #expect(descriptor.accessibilityLabel.contains("OK"))
    }

    @Test func descriptorChoosesPaletteRendering() {
        let descriptor = MenuBarStatusItemImage.descriptor(isCritical: false)

        #expect(descriptor.usesPaletteRendering == true)
        #expect(descriptor.symbolName.isEmpty == false)
    }
}
