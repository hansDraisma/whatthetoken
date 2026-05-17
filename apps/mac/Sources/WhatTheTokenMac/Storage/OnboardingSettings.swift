import Foundation

enum OnboardingStepState: String, Codable, Equatable, Sendable {
    case pending
    case done
    case skipped
}

struct OnboardingStepStates: Codable, Equatable, Sendable {
    var connectProviders: OnboardingStepState
    var findMenuBar: OnboardingStepState
    var addWidget: OnboardingStepState
    var allowNotifications: OnboardingStepState
    var setHotkey: OnboardingStepState
    var launchAtLogin: OnboardingStepState

    static let allPending = OnboardingStepStates(
        connectProviders: .pending,
        findMenuBar: .pending,
        addWidget: .pending,
        allowNotifications: .pending,
        setHotkey: .pending,
        launchAtLogin: .pending
    )

    static let allSkipped = OnboardingStepStates(
        connectProviders: .skipped,
        findMenuBar: .skipped,
        addWidget: .skipped,
        allowNotifications: .skipped,
        setHotkey: .skipped,
        launchAtLogin: .skipped
    )

    var allFinal: Bool {
        [connectProviders, findMenuBar, addWidget, allowNotifications, setHotkey, launchAtLogin]
            .allSatisfy { $0 != .pending }
    }
}

struct OnboardingSettings: Codable, Equatable, Sendable {
    var firstLaunchCompleted: Bool
    var steps: OnboardingStepStates

    static let `default` = OnboardingSettings(firstLaunchCompleted: false, steps: .allPending)
    static let existingUser = OnboardingSettings(firstLaunchCompleted: true, steps: .allSkipped)
}
