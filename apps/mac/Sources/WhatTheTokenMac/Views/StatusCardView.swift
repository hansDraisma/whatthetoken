import SwiftUI

struct StatusCardView: View {
    private let display: StatusCardDisplayModel

    init(snapshot: UsageSnapshot) {
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

            Text(display.updatedLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 320, alignment: .leading)
    }
}
