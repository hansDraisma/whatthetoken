import SwiftUI

struct ConnectorRowView: View {
    let title: String
    let stateTitle: String
    let detail: String
    let trustMessage: String
    let actionTitle: String
    let isWorking: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(stateTitle)
                    .font(.subheadline)
                if detail != stateTitle {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(trustMessage)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(actionTitle, action: action)
                .disabled(isWorking)
        }
        .padding(.vertical, 6)
    }
}
