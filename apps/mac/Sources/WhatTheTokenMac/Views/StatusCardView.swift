import SwiftUI

struct StatusCardView: View {
    let snapshot: UsageSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(snapshot.confidence.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Text(primaryMetric)
                .font(.system(size: 28, weight: .semibold))

            ProgressView(value: snapshot.utilization ?? 0)
                .progressViewStyle(.linear)

            Text("Updated \(snapshot.lastUpdatedAt)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 320, alignment: .leading)
    }

    private var title: String {
        "\(snapshot.provider.capitalized) / \(snapshot.product.replacingOccurrences(of: "_", with: " "))"
    }

    private var primaryMetric: String {
        guard let remaining = snapshot.remaining else {
            return "Usage observed"
        }

        switch snapshot.unit {
        case "utilization":
            return "\(Int(remaining))% remaining"
        case "credits":
            return "\(remaining.formatted()) credits remaining"
        case "tokens":
            return "\(Int(remaining)) tokens remaining"
        case "requests":
            return "\(Int(remaining)) requests remaining"
        case "messages":
            return "\(Int(remaining)) messages remaining"
        default:
            return "\(remaining.formatted()) remaining"
        }
    }
}
