import Foundation

enum StatusRowCopy {
    static func heroText(snapshot: UsageSnapshot, state: StatusUsageState) -> String {
        if isFallbackCredits(snapshot), state == .empty {
            return "No extra credits available"
        }

        if snapshot.unit == "credits",
           snapshot.used == nil,
           snapshot.limit == nil,
           let remaining = snapshot.remaining {
            return formatted(remaining)
        }

        if state == .empty {
            return emptyHero(unit: snapshot.unit)
        }

        guard let remaining = snapshot.remaining else {
            return "Usage observed"
        }

        switch snapshot.unit {
        case "utilization":
            let percent: Int
            if let utilization = snapshot.utilization {
                percent = 100 - Int(round(utilization * 100))
            } else {
                percent = Int(round(remaining))
            }
            return "\(min(max(percent, 0), 100))% remaining"
        case "credits":
            return "\(formatted(remaining)) credits remaining"
        case "tokens":
            return "\(Int(remaining)) tokens remaining"
        case "requests":
            return "\(Int(remaining)) requests remaining"
        case "messages":
            return "\(Int(remaining)) messages remaining"
        default:
            return "\(formatted(remaining)) remaining"
        }
    }

    static func echoText(snapshot: UsageSnapshot) -> String? {
        guard snapshot.unit == "utilization",
              let utilization = snapshot.utilization else {
            return nil
        }

        let percent = Int(round(utilization * 100))
        return "\(percent)% used"
    }

    static func statusWord(state: StatusUsageState) -> String {
        switch state {
        case .healthy:
            return "Plenty left"
        case .low:
            return "Running low"
        case .critical:
            return "Almost empty"
        case .empty:
            return "Empty"
        }
    }

    static func resetHint(resetAt: String?, now: Date) -> String? {
        guard let resetAt, let resetDate = parseISODate(resetAt) else {
            return nil
        }

        let interval = resetDate.timeIntervalSince(now)
        guard interval > 0 else { return nil }

        if interval < 24 * 60 * 60 {
            let totalMinutes = Int(interval / 60)
            guard totalMinutes > 0 else {
                return "Resets in <1m"
            }
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return "Resets in \(hours)h \(minutes)m"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEE HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "Resets \(formatter.string(from: resetDate))"
    }

    private static func parseISODate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }

    private static func emptyHero(unit: String) -> String {
        switch unit {
        case "utilization":
            return "Out of capacity"
        case "credits":
            return "Out of credits"
        case "tokens":
            return "Out of tokens"
        case "requests":
            return "Out of requests"
        case "messages":
            return "Out of messages"
        default:
            return "Empty"
        }
    }

    private static func isFallbackCredits(_ snapshot: UsageSnapshot) -> Bool {
        snapshot.poolKey == "anthropic_claude_extra_usage"
            || snapshot.poolKey == "openai_codex_credits"
    }

    private static func formatted(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return value.formatted()
    }
}
