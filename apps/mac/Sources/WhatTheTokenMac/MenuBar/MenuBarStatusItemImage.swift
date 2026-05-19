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
            usesPaletteRendering: false,
            fillColorName: "labelColor",
            outlineColorName: isCritical ? "systemRed" : "clear"
        )
    }

    #if canImport(AppKit)
    @MainActor
    static func make(isCritical: Bool) -> NSImage {
        let d = descriptor(isCritical: isCritical)
        let base = NSImage(systemSymbolName: d.symbolName, accessibilityDescription: d.accessibilityLabel)
            ?? NSImage()
        base.isTemplate = true
        guard isCritical else { return base }

        let composite = NSImage(size: base.size, flipped: false) { rect in
            base.draw(in: rect)
            NSColor.systemRed.setFill()
            let dotSize: CGFloat = 5
            NSBezierPath(ovalIn: NSRect(x: rect.maxX - dotSize, y: 0, width: dotSize, height: dotSize)).fill()
            return true
        }
        composite.isTemplate = false
        return composite
    }
    #endif
}
