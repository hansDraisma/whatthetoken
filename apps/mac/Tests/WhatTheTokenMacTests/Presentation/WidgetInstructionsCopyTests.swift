import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct WidgetInstructionsCopyTests {
    @Test func primaryInstructionExplainsDesktopWidgetPath() {
        #expect(WidgetInstructionsCopy.primaryInstruction == "Right-click your desktop → Edit Widgets → search WhatTheToken → drag the widget to your desktop.")
    }

    @Test func actionsUseExpectedLabels() {
        #expect(WidgetInstructionsCopy.addedButtonTitle == "I added it")
        #expect(WidgetInstructionsCopy.skipButtonTitle == "Skip step")
        #expect(WidgetInstructionsCopy.previewDisclosureTitle == "What does the widget show?")
    }
}
