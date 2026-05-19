import Foundation

enum OnboardingStep: String, CaseIterable, Equatable, Sendable {
    case connectProviders
    case findMenuBar
    case addWidget
    case allowNotifications
    case setHotkey
    case launchAtLogin
}

struct OnboardingState: Equatable, Sendable {
    let stepStates: OnboardingStepStates

    var nextStep: OnboardingStep? {
        for step in OnboardingStep.allCases where stateFor(step) == .pending {
            return step
        }
        return nil
    }

    var bannerDismissable: Bool { stepStates.allFinal }

    var completedCount: Int {
        OnboardingStep.allCases.reduce(into: 0) { count, step in
            if stateFor(step) != .pending {
                count += 1
            }
        }
    }

    var totalCount: Int { OnboardingStep.allCases.count }

    func stateFor(_ step: OnboardingStep) -> OnboardingStepState {
        switch step {
        case .connectProviders:
            return stepStates.connectProviders
        case .findMenuBar:
            return stepStates.findMenuBar
        case .addWidget:
            return stepStates.addWidget
        case .allowNotifications:
            return stepStates.allowNotifications
        case .setHotkey:
            return stepStates.setHotkey
        case .launchAtLogin:
            return stepStates.launchAtLogin
        }
    }

    static func applySkipAll(to states: OnboardingStepStates) -> OnboardingStepStates {
        var updated = states
        if updated.connectProviders == .pending {
            updated.connectProviders = .skipped
        }
        if updated.findMenuBar == .pending {
            updated.findMenuBar = .skipped
        }
        if updated.addWidget == .pending {
            updated.addWidget = .skipped
        }
        if updated.allowNotifications == .pending {
            updated.allowNotifications = .skipped
        }
        if updated.setHotkey == .pending {
            updated.setHotkey = .skipped
        }
        if updated.launchAtLogin == .pending {
            updated.launchAtLogin = .skipped
        }
        return updated
    }

    static func applyReplay(to _: OnboardingStepStates) -> OnboardingStepStates {
        .allPending
    }
}
