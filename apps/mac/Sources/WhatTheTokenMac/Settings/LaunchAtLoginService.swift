import Foundation

#if canImport(ServiceManagement)
import ServiceManagement
#endif

@MainActor
protocol LaunchAtLoginServicing: AnyObject {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

enum LaunchAtLoginServiceError: LocalizedError, Equatable {
    case operationFailed

    var errorDescription: String? {
        "operation failed"
    }
}

@MainActor
final class SystemLaunchAtLoginService: LaunchAtLoginServicing {
    var isEnabled: Bool {
        #if canImport(ServiceManagement)
        return SMAppService.mainApp.status == .enabled
        #else
        return false
        #endif
    }

    func setEnabled(_ enabled: Bool) throws {
        #if canImport(ServiceManagement)
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        #else
        throw LaunchAtLoginServiceError.operationFailed
        #endif
    }
}
