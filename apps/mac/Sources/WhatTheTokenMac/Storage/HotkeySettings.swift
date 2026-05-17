import Foundation

struct HotkeySettings: Codable, Equatable, Sendable {
    var combination: HotkeyCombination

    static let `default` = HotkeySettings(combination: .default)
}
