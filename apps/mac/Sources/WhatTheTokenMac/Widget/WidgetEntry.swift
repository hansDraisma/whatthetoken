import Foundation

enum WidgetProvider: String, Codable, Equatable, Sendable, CaseIterable {
    case claude
    case codex

    var displayName: String {
        switch self {
        case .claude:
            return "Claude"
        case .codex:
            return "Codex"
        }
    }

    var cacheID: CachedProviderID {
        switch self {
        case .claude:
            return .claude
        case .codex:
            return .codex
        }
    }
}

enum WidgetRowState: Equatable, Sendable {
    case notConnected
    case connected(percentage: Int)
}

struct WidgetRow: Equatable, Sendable {
    let provider: WidgetProvider
    let state: WidgetRowState
}

struct WidgetEntry: Equatable, Sendable {
    let rows: [WidgetRow]
    let isStale: Bool
    let asOf: Date
}
