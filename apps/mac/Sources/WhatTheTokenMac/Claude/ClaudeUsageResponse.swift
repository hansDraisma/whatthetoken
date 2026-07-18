import Foundation

struct ClaudeUsageResponse: Decodable, Equatable, Sendable {
    let windows: [String: ClaudeWindowUsage]
    let extraUsage: ClaudeExtraUsage?
    let malformedUsageKeys: [String]

    var fiveHour: ClaudeWindowUsage? { windows["five_hour"] }
    var sevenDay: ClaudeWindowUsage? { windows["seven_day"] }
    var sevenDayOpus: ClaudeWindowUsage? { windows["seven_day_opus"] }
    var sevenDaySonnet: ClaudeWindowUsage? { windows["seven_day_sonnet"] }

    init(
        windows: [String: ClaudeWindowUsage],
        extraUsage: ClaudeExtraUsage? = nil,
        malformedUsageKeys: [String] = []
    ) {
        self.windows = windows
        self.extraUsage = extraUsage
        self.malformedUsageKeys = malformedUsageKeys.sorted()
    }

    init(
        fiveHour: ClaudeWindowUsage?,
        sevenDay: ClaudeWindowUsage?,
        sevenDayOpus: ClaudeWindowUsage?,
        sevenDaySonnet: ClaudeWindowUsage?,
        extraUsage: ClaudeExtraUsage?
    ) {
        var windows: [String: ClaudeWindowUsage] = [:]
        windows["five_hour"] = fiveHour
        windows["seven_day"] = sevenDay
        windows["seven_day_opus"] = sevenDayOpus
        windows["seven_day_sonnet"] = sevenDaySonnet

        self.init(windows: windows, extraUsage: extraUsage)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var windows: [String: ClaudeWindowUsage] = [:]
        var malformedUsageKeys: [String] = []
        var extraUsage: ClaudeExtraUsage?

        for key in container.allKeys {
            if key.stringValue == "extra_usage" {
                do {
                    extraUsage = try container.decodeIfPresent(ClaudeExtraUsage.self, forKey: key)
                } catch {
                    malformedUsageKeys.append(key.stringValue)
                }
                continue
            }

            do {
                if let window = try container.decodeIfPresent(ClaudeWindowUsage.self, forKey: key) {
                    windows[key.stringValue] = window
                }
            } catch {
                if Self.looksLikeUsageWindowKey(key.stringValue)
                    || Self.containsUtilizationField(container: container, key: key) {
                    malformedUsageKeys.append(key.stringValue)
                }
            }
        }

        self.init(
            windows: windows,
            extraUsage: extraUsage,
            malformedUsageKeys: malformedUsageKeys
        )
    }

    private static func looksLikeUsageWindowKey(_ key: String) -> Bool {
        key == "five_hour"
            || key == "seven_day"
            || key.hasPrefix("seven_day_")
            || key.hasSuffix("_hour")
            || key.hasSuffix("_day")
    }

    private static func containsUtilizationField(
        container: KeyedDecodingContainer<DynamicCodingKey>,
        key: DynamicCodingKey
    ) -> Bool {
        guard let utilizationKey = DynamicCodingKey(stringValue: "utilization"),
              let nested = try? container.nestedContainer(
                keyedBy: DynamicCodingKey.self,
                forKey: key
              ) else {
            return false
        }
        return nested.contains(utilizationKey)
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

struct ClaudeWindowUsage: Codable, Equatable, Sendable {
    let utilization: Double
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

struct ClaudeExtraUsage: Codable, Equatable, Sendable {
    let isEnabled: Bool
    let utilization: Double?
    let usedCredits: Double?
    let monthlyLimit: Double?

    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case utilization
        case usedCredits = "used_credits"
        case monthlyLimit = "monthly_limit"
    }
}
