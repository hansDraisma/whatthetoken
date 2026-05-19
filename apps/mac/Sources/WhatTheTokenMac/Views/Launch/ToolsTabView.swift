import SwiftUI

enum ToolsTabCopy {
    static let appearanceSection = "Appearance"
    static let showInDockTitle = "Show in Dock"
    static let showInDockRestartNote = "Takes effect after the next app launch."
    static let hotkeySection = "Global hotkey"
    static let launchAtLoginSection = "Launch at login"
    static let launchAtLoginTitle = "Launch WhatTheToken at login"
    static let widgetSection = "Desktop widget"
    static let widgetInstructionsTitle = "How to add the desktop widget"
    static let onboardingSection = "Onboarding"
    static let replayOnboardingTitle = "Replay onboarding"
    static let pulseMenuBarIconTitle = "Pulse the menu bar icon"
}

struct ToolsTabView: View {
    let viewModel: StatusViewModel

    var body: some View {
        Form {
            Section(ToolsTabCopy.appearanceSection) {
                Toggle(ToolsTabCopy.showInDockTitle, isOn: Binding(
                    get: { viewModel.settings.appearance.showInDock },
                    set: { value in Task { await viewModel.setShowInDock(value) } }
                ))
                Text(ToolsTabCopy.showInDockRestartNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(ToolsTabCopy.hotkeySection) {
                HotkeyRecorderField(
                    combination: Binding(
                        get: { viewModel.settings.hotkey.combination },
                        set: { value in Task { _ = await viewModel.setHotkey(value) } }
                    ),
                    onRecord: { value in Task { _ = await viewModel.setHotkey(value) } },
                    warningText: viewModel.hotkeyRegistrationWarning
                )
            }

            Section(ToolsTabCopy.launchAtLoginSection) {
                Toggle(ToolsTabCopy.launchAtLoginTitle, isOn: Binding(
                    get: { viewModel.settings.launchAtLogin.isEnabled },
                    set: { value in Task { await viewModel.setLaunchAtLoginEnabled(value) } }
                ))
                if let message = viewModel.launchAtLoginStatusMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section(ToolsTabCopy.widgetSection) {
                DisclosureGroup(ToolsTabCopy.widgetInstructionsTitle) {
                    WidgetInstructionsView()
                }
            }

            Section(ToolsTabCopy.onboardingSection) {
                Button(ToolsTabCopy.replayOnboardingTitle) {
                    Task { await viewModel.replayOnboarding() }
                }
                Button(ToolsTabCopy.pulseMenuBarIconTitle) {
                    Task { await viewModel.pulseMenuBarIcon() }
                }
            }
        }
        .formStyle(.grouped)
    }
}
