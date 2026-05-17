import Foundation
#if canImport(AppKit)
import AppKit
#endif

struct MenuBarIconDescriptor {
    let symbolName: String
    let accessibilityLabel: String
    let usesPaletteRendering: Bool
    let fillColorName: String
    let outlineColorName: String
}

enum MenuBarStatusItemImage {
    static func descriptor(isCritical: Bool) -> MenuBarIconDescriptor {
        MenuBarIconDescriptor(
            symbolName: "gauge.with.dots.needle.bottom.50percent",
            accessibilityLabel: isCritical
                ? "WhatTheToken: critical quota"
                : "WhatTheToken: quota OK",
            usesPaletteRendering: true,
            fillColorName: isCritical ? "systemRed" : "systemGreen",
            outlineColorName: "labelColor"
        )
    }

    #if canImport(AppKit)
    @MainActor
    static func make(isCritical: Bool) -> NSImage {
        let d = descriptor(isCritical: isCritical)
        let config = NSImage.SymbolConfiguration(paletteColors: [
            isCritical ? NSColor.systemRed : NSColor.systemGreen,
            NSColor.labelColor
        ])
        let base = NSImage(systemSymbolName: d.symbolName, accessibilityDescription: d.accessibilityLabel)
            ?? NSImage()
        let configured = base.withSymbolConfiguration(config) ?? base
        configured.isTemplate = false
        return configured
    }
    #endif
}
