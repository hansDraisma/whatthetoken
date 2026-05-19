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

    static func accessibilityStatus(for state: OnboardingStepState) -> String {
        switch state {
        case .pending:
            return "pending"
        case .done:
            return "completed"
        case .skipped:
            return "skipped"
        }
    }
}

struct GetStartedBanner<StepBody: View>: View {
    let state: OnboardingState
    let stepBody: (OnboardingStep) -> StepBody
    let onSkipAll: () -> Void
    @AccessibilityFocusState private var focusedStep: OnboardingStep?

    init(
        state: OnboardingState,
        @ViewBuilder stepBody: @escaping (OnboardingStep) -> StepBody,
        onSkipAll: @escaping () -> Void
    ) {
        self.state = state
        self.stepBody = stepBody
        self.onSkipAll = onSkipAll
    }

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
                    focusedStep: $focusedStep
                ) {
                    stepBody(step)
                }
            }

            Button("Skip onboarding", action: onSkipAll)
                .buttonStyle(.link)
                .font(.caption)
        }
        .onChange(of: state.nextStep) { _, nextStep in
            focusedStep = nextStep
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.accentColor.opacity(0.2)))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct StepRow<ExpandedBody: View>: View {
    let step: OnboardingStep
    let state: OnboardingStepState
    let isNext: Bool
    var focusedStep: AccessibilityFocusState<OnboardingStep?>.Binding
    let expandedBody: () -> ExpandedBody

    init(
        step: OnboardingStep,
        state: OnboardingStepState,
        isNext: Bool,
        focusedStep: AccessibilityFocusState<OnboardingStep?>.Binding,
        @ViewBuilder expandedBody: @escaping () -> ExpandedBody
    ) {
        self.step = step
        self.state = state
        self.isNext = isNext
        self.focusedStep = focusedStep
        self.expandedBody = expandedBody
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            StepHeader(step: step, state: state, isNext: isNext)
                .accessibilityFocused(focusedStep, equals: step)
            if isNext {
                expandedBody()
                    .padding(.leading, 26)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct StepHeader: View {
    let step: OnboardingStep
    let state: OnboardingStepState
    let isNext: Bool

    var body: some View {
        HStack(spacing: 10) {
            checkmark
            Text(GetStartedBannerCopy.title(for: step))
                .fontWeight(isNext ? .semibold : .regular)
                .foregroundStyle(state == .pending && !isNext ? .secondary : .primary)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(GetStartedBannerCopy.title(for: step)), \(GetStartedBannerCopy.accessibilityStatus(for: state))")
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
        .accessibilityHidden(true)
    }
}
