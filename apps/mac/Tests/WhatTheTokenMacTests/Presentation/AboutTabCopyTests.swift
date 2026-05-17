import Foundation
import Testing
@testable import WhatTheTokenMac

@Suite struct AboutTabCopyTests {
    @Test func privacyCopyStatesLocalSanitizedStorage() {
        #expect(AboutTabCopy.privacyText == "WhatTheToken stores and displays only sanitized usage status. Provider credentials, prompts, responses, and raw provider payloads never leave your device.")
    }

    @Test func privacyURLPointsAtRepositoryNotice() {
        #expect(AboutTabCopy.privacyURL.absoluteString == "https://github.com/whatthetoken/whatthetoken/blob/main/PRIVACY.md")
    }

    @Test func quitButtonTitleIsExplicit() {
        #expect(AboutTabCopy.quitButtonTitle == "Quit WhatTheToken")
    }
}
