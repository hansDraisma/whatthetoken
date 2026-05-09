import Foundation

#if canImport(Sparkle)
import Sparkle
#endif

@MainActor
final class SparkleUpdateController {
    #if canImport(Sparkle)
    private let updaterController: SPUStandardUpdaterController
    private var hasStartedUpdater = false

    init(
        updaterController: SPUStandardUpdaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    ) {
        self.updaterController = updaterController
    }

    func checkForUpdates(_ sender: Any? = nil) {
        startUpdaterIfNeeded()
        updaterController.checkForUpdates(sender)
    }

    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }

    private func startUpdaterIfNeeded() {
        guard !hasStartedUpdater else { return }
        updaterController.startUpdater()
        hasStartedUpdater = true
    }
    #else
    init() {}

    func checkForUpdates(_ sender: Any? = nil) {}

    var canCheckForUpdates: Bool {
        false
    }
    #endif
}
