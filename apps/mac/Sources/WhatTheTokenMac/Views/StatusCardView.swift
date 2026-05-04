import SwiftUI

struct StatusCardView: View {
    private let snapshot: UsageSnapshot
    private let display: StatusCardDisplayModel

    init(snapshot: UsageSnapshot) {
        self.snapshot = snapshot
        display = StatusCardDisplayModel(snapshot: snapshot)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(display.title)
                    .font(.headline)
                Spacer()
                Text(display.confidenceLabel)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Text(display.primaryMetric)
                .font(.system(size: 28, weight: .semibold))

            ProgressView(value: display.progressValue)
                .progressViewStyle(.linear)

            Text(StatusCardCopy.sourceLine(for: snapshot))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(StatusCardCopy.riskLine(for: snapshot))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(display.updatedLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 320, alignment: .leading)
    }
}

enum StatusCardCopy {
    static func sourceLine(for snapshot: UsageSnapshot) -> String {
        "\(snapshot.confidence.capitalized) by \(snapshot.source.label)"
    }

    static func riskLine(for snapshot: UsageSnapshot) -> String {
        switch snapshot.undercountRisk {
        case "none":
            return "No undercount risk"
        case "possible":
            return "Undercount possible"
        case "likely":
            return "Undercount likely"
        default:
            return "Undercount risk unknown"
        }
    }
}
