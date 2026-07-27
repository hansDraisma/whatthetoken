import SwiftUI

struct PopoverFooterView: View {
    let state: PopoverFooterState
    let onRefresh: () -> Void
    let canCheckForUpdates: Bool
    let onOpenConnectors: () -> Void
    let onCheckForUpdates: () -> Void
    let onOpenDeveloperWindow: (() -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            updatedLabel
                .frame(maxWidth: .infinity, alignment: .leading)
            refreshButton
            Menu {
                Button("Connectors...", action: onOpenConnectors)
                Button("Check for Updates...", action: onCheckForUpdates)
                    .disabled(!canCheckForUpdates)
                Button("About WhatTheToken") {
                    // Activate before showing the panel so it comes to front
                    // in `.accessory` mode (where the app is not frontmost
                    // when the menu-bar popover is shown).
                    MacChromeActions.showAbout()
                }
                #if DEBUG
                if let onOpenDeveloperWindow {
                    Button("Open Developer Window", action: onOpenDeveloperWindow)
                }
                #endif
                Divider()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
        }
        .padding(.vertical, 8)
        .padding(.leading, 12)
        .padding(.trailing, 6)
    }

    private var updatedLabel: some View {
        Text(state.labelText())
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    private var refreshButton: some View {
        Button(action: onRefresh) {
            if state.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
        .buttonStyle(.borderless)
        .disabled(!state.canRefresh)
    }
}
