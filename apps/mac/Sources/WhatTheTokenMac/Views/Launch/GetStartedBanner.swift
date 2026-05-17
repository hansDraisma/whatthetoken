import SwiftUI
import AppKit

struct GetStartedBannerCopy {
    let completedCount: Int
    let totalCount: Int

    var progressLabel: String { "\(completedCount) of \(totalCount) done" }

    static func title(for step: OnboardingStep) -> String {
        switch step {
        case .connectProviders:
            return "Connect your providers"
        case .findMenuBar:
            return "Find the menu bar icon"
        case .addWidget:
            return "Add the desktop widget"
        case .allowNotifications:
            return "Allow notifications"
        case .setHotkey:
            return "Set a global hotkey"
        case .launchAtLogin:
            return "Launch at login"
        }
    }
}

struct GetStartedBanner: View {
    let state: OnboardingState
    let stepBody: (OnboardingStep) -> AnyView
    let onSkipAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Get started")
                    .font(.headline)
                Spacer()
                Text(GetStartedBannerCopy(
                    completedCount: state.completedCount,
                    totalCount: state.totalCount
                ).progressLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            ForEach(OnboardingStep.allCases, id: \.self) { step in
                StepRow(
                    step: step,
                    state: state.stateFor(step),
                    isNext: state.nextStep == step,
                    expandedBody: state.nextStep == step ? stepBody(step) : nil
                )
            }

            Button("Skip onboarding", action: onSkipAll)
                .buttonStyle(.link)
                .font(.caption)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.accentColor.opacity(0.2)))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct StepRow: View {
    let step: OnboardingStep
    let state: OnboardingStepState
    let isNext: Bool
    let expandedBody: AnyView?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                checkmark
                Text(GetStartedBannerCopy.title(for: step))
                    .fontWeight(isNext ? .semibold : .regular)
                    .foregroundStyle(state == .pending && !isNext ? .secondary : .primary)
                Spacer()
            }
            if let expandedBody {
                expandedBody.padding(.leading, 26)
            }
        }
        .padding(.vertical, 6)
    }

    private var checkmark: some View {
        Group {
            switch state {
            case .done, .skipped:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .pending where isNext:
                Image(systemName: "circle").foregroundStyle(Color.accentColor)
            case .pending:
                Image(systemName: "circle").foregroundStyle(.secondary)
            }
        }
        .frame(width: 16, height: 16)
    }
}
