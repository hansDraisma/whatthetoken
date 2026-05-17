import SwiftUI
import AppKit

enum WidgetInstructionsCopy {
    static let primaryInstruction = "Right-click your desktop → Edit Widgets → search WhatTheToken → drag the widget to your desktop."
    static let previewDisclosureTitle = "What does the widget show?"
    static let addedButtonTitle = "I added it"
    static let skipButtonTitle = "Skip step"
}

struct WidgetInstructionsView: View {
    let onAddedConfirm: (() -> Void)?
    let onSkip: (() -> Void)?

    init(onAddedConfirm: (() -> Void)? = nil, onSkip: (() -> Void)? = nil) {
        self.onAddedConfirm = onAddedConfirm
        self.onSkip = onSkip
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(WidgetInstructionsCopy.primaryInstruction)
                .font(.caption)
            DisclosureGroup(WidgetInstructionsCopy.previewDisclosureTitle) {
                WidgetPreviewView(payload: SnapshotEntryBuilder.placeholder())
                    .frame(width: 158, height: 158)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.secondary.opacity(0.2)))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.vertical, 4)
            }
            .font(.caption)

            if onAddedConfirm != nil || onSkip != nil {
                HStack {
                    if let onAddedConfirm {
                        Button(WidgetInstructionsCopy.addedButtonTitle, action: onAddedConfirm)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                    if let onSkip {
                        Button(WidgetInstructionsCopy.skipButtonTitle, action: onSkip)
                            .buttonStyle(.link)
                    }
                }
            }
        }
    }
}
