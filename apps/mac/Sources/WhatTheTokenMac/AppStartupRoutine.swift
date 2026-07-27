import Foundation

@MainActor
enum AppStartupRoutine {
    static func run(
        loadPersistedState: () async throws -> Void,
        logger: AppLogger,
        registerHotkey: () async -> Void,
        verifyConnectors: () async -> Void,
        activateReconnectWatcher: () -> Void,
        startRefresh: () -> Void
    ) async {
        do {
            try await loadPersistedState()
            await registerHotkey()
            await verifyConnectors()
            activateReconnectWatcher()
            startRefresh()
        } catch {
            logger.error("Failed to load persisted state: \(error.localizedDescription)")
        }
    }
}
