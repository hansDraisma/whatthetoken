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

    @Test func descriptorChoosesTemplateRendering() {
        let descriptor = MenuBarStatusItemImage.descriptor(isCritical: false)

        #expect(descriptor.usesPaletteRendering == false)
        #expect(descriptor.symbolName.isEmpty == false)
    }

    #if canImport(AppKit)
    @MainActor
    @Test func renderedImageIsTemplateForMenuBarTinting() {
        let normal = MenuBarStatusItemImage.make(isCritical: false)

        #expect(normal.isTemplate == true)
    }

    @MainActor
    @Test func criticalityRendersDistinctOverlay() {
        let normal = MenuBarStatusItemImage.make(isCritical: false)
        let critical = MenuBarStatusItemImage.make(isCritical: true)

        #expect(normal.tiffRepresentation != critical.tiffRepresentation)
    }
    #endif
}
