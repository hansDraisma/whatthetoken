import Foundation

#if canImport(Sparkle)
import Sparkle
#endif

@MainActor
final class SparkleUpdateController {
    #if canImport(Sparkle)
    private let updaterController: SPUStandardUpdaterController
    private let hasUpdateMetadata: @MainActor () -> Bool
    private var hasStartedUpdater = false

    init(
        updaterController: SPUStandardUpdaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        ),
        hasUpdateMetadata: @escaping @MainActor () -> Bool = SparkleUpdateController.defaultHasUpdateMetadata
    ) {
        self.updaterController = updaterController
        self.hasUpdateMetadata = hasUpdateMetadata
    }

    func checkForUpdates(_ sender: Any? = nil) {
        guard hasUpdateMetadata() else { return }
        startUpdaterIfNeeded()
        guard updaterController.updater.canCheckForUpdates else { return }
        updaterController.checkForUpdates(sender)
    }

    var canCheckForUpdates: Bool {
        guard hasUpdateMetadata() else { return false }
        return !hasStartedUpdater || updaterController.updater.canCheckForUpdates
    }

    private func startUpdaterIfNeeded() {
        guard !hasStartedUpdater else { return }
        updaterController.startUpdater()
        hasStartedUpdater = true
    }

    private static func defaultHasUpdateMetadata() -> Bool {
        guard
            let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        else {
            return false
        }

        return !feedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    #else
    private let hasUpdateMetadata: @MainActor () -> Bool

    init(hasUpdateMetadata: @escaping @MainActor () -> Bool = SparkleUpdateController.defaultHasUpdateMetadata) {
        self.hasUpdateMetadata = hasUpdateMetadata
    }

    func checkForUpdates(_ sender: Any? = nil) {
        _ = hasUpdateMetadata()
    }

    var canCheckForUpdates: Bool {
        false
    }

    private static func defaultHasUpdateMetadata() -> Bool {
        false
    }
    #endif
}
