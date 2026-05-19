import Foundation

struct AppearanceSettings: Codable, Equatable, Sendable {
    var showInDock: Bool

    static let `default` = AppearanceSettings(showInDock: true)
}
