import SwiftUI
import AppKit

enum AboutTabCopy {
    static let privacyText = "WhatTheToken stores and displays only sanitized usage status. Provider credentials, prompts, responses, and raw provider payloads never leave your device."
    static let privacyURL = URL(string: "https://github.com/whatthetoken/whatthetoken/blob/main/PRIVACY.md")!
    static let privacyLinkTitle = "Read the full privacy notice"
    static let quitButtonTitle = "Quit WhatTheToken"
}

struct AboutTabView: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: Self.appVersion)
                LabeledContent("Build", value: Self.appBuild)
            }
            Section("Privacy") {
                Text(AboutTabCopy.privacyText)
                    .font(.callout)
                Link(AboutTabCopy.privacyLinkTitle, destination: AboutTabCopy.privacyURL)
            }
            Section {
                Button(AboutTabCopy.quitButtonTitle) {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .formStyle(.grouped)
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }

    private static var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    }
}
