import Foundation

@MainActor
enum AppStartupRoutine {
    static func run(
        loadPersistedState: () async throws -> Void,
        logger: AppLogger,
        registerHotkey: () async -> Void,
        startRefresh: () -> Void,
        autoOpenLaunchWindow: () -> Void
    ) async {
        do {
            try await loadPersistedState()
            await registerHotkey()
            startRefresh()
            autoOpenLaunchWindow()
        } catch {
            logger.error("Failed to load persisted state: \(error.localizedDescription)")
        }
    }
}
