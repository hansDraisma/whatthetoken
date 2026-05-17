import SwiftUI

enum WidgetPreviewCopy {
    struct Row: Equatable {
        let providerLabel: String
        let valueLabel: String
        let isConnected: Bool
    }

    struct EmptyState: Equatable {
        let title: String
        let hint: String
    }

    struct PillAppearance: Equatable {
        let fillColorName: String
        let outlineColorName: String
    }

    static func row(for row: WidgetRow) -> Row {
        switch row.state {
        case let .connected(percentage):
            return Row(providerLabel: row.provider.displayName, valueLabel: "\(percentage)%", isConnected: true)
        case .notConnected:
            return Row(providerLabel: row.provider.displayName, valueLabel: "Not connected", isConnected: false)
        }
    }

    static func staleBadge(for entry: WidgetEntry) -> String? {
        entry.isStale ? "Stale" : nil
    }

    static func emptyState(for entry: WidgetEntry) -> EmptyState? {
        guard !entry.rows.isEmpty, entry.rows.allSatisfy(\.isNotConnected) else { return nil }
        return EmptyState(
            title: "No providers connected",
            hint: "Open the app to connect Claude or Codex."
        )
    }

    static func pillAppearance(isConnected: Bool) -> PillAppearance {
        PillAppearance(
            fillColorName: isConnected ? "systemGreen" : "controlBackgroundColor",
            outlineColorName: "labelColor"
        )
    }
}

struct WidgetPreviewView: View {
    let payload: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let emptyState = WidgetPreviewCopy.emptyState(for: payload) {
                Text(emptyState.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(emptyState.hint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(payload.rows, id: \.provider) { row in
                    rowView(for: row)
                }
            }

            Spacer()

            if let stale = WidgetPreviewCopy.staleBadge(for: payload) {
                Text(stale)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
    }

    private func rowView(for row: WidgetRow) -> some View {
        let copy = WidgetPreviewCopy.row(for: row)
        let pill = WidgetPreviewCopy.pillAppearance(isConnected: copy.isConnected)
        return HStack(spacing: 8) {
            Text(copy.providerLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(copy.isConnected ? .white : .primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(pillFillColor(named: pill.fillColorName))
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(pillOutlineColor(named: pill.outlineColorName), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Spacer()

            Text(copy.valueLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(copy.isConnected ? .primary : .secondary)
        }
    }

    private func pillFillColor(named name: String) -> Color {
        #if canImport(AppKit)
        switch name {
        case "systemGreen":
            return Color(nsColor: .systemGreen)
        case "controlBackgroundColor":
            return Color(nsColor: .controlBackgroundColor)
        default:
            return Color(nsColor: .controlBackgroundColor)
        }
        #else
        switch name {
        case "systemGreen":
            return Color.accentColor
        default:
            return Color.secondary.opacity(0.16)
        }
        #endif
    }

    private func pillOutlineColor(named name: String) -> Color {
        #if canImport(AppKit)
        switch name {
        case "labelColor":
            return Color(nsColor: .labelColor).opacity(0.24)
        default:
            return Color.primary.opacity(0.24)
        }
        #else
        return Color.primary.opacity(0.24)
        #endif
    }
}

private extension WidgetRow {
    var isNotConnected: Bool {
        if case .notConnected = state {
            return true
        }
        return false
    }
}
