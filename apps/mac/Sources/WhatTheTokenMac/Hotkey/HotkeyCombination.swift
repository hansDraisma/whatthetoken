import Foundation

struct HotkeyCombination: Codable, Equatable, Hashable, Sendable {
    struct ModifierSet: OptionSet, Codable, Hashable, Sendable {
        let rawValue: Int

        static let command = ModifierSet(rawValue: 1 << 0)
        static let option  = ModifierSet(rawValue: 1 << 1)
        static let control = ModifierSet(rawValue: 1 << 2)
        static let shift   = ModifierSet(rawValue: 1 << 3)

        private enum CodingKeys: String, CodingKey {
            case rawValue
        }

        init(rawValue: Int) {
            self.rawValue = rawValue
        }

        init(from decoder: Decoder) throws {
            if let singleValue = try? decoder.singleValueContainer(),
               let rawValue = try? singleValue.decode(Int.self) {
                self.rawValue = rawValue
                return
            }

            let container = try decoder.container(keyedBy: CodingKeys.self)
            rawValue = try container.decode(Int.self, forKey: .rawValue)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(rawValue, forKey: .rawValue)
        }
    }

    var modifiers: ModifierSet
    var keyCode: UInt32

    static let `default` = HotkeyCombination(modifiers: [.control, .option], keyCode: 17)

    var isValidForGlobalRegistration: Bool {
        let hardModifiers: ModifierSet = [.command, .control, .option]
        guard !modifiers.intersection(hardModifiers).isEmpty else { return false }

        let reserved: Set<HotkeyCombination> = [
            HotkeyCombination(modifiers: [.command], keyCode: 12), // Cmd+Q
            HotkeyCombination(modifiers: [.command], keyCode: 13), // Cmd+W
            HotkeyCombination(modifiers: [.command], keyCode: 4),  // Cmd+H
            HotkeyCombination(modifiers: [.command], keyCode: 46), // Cmd+M
            HotkeyCombination(modifiers: [.command], keyCode: 48), // Cmd+Tab (kc 48 = Tab)
            HotkeyCombination(modifiers: [.command], keyCode: 49)  // Cmd+Space
        ]
        return !reserved.contains(self)
    }
}
