import SwiftUI

struct ConnectorRowView: View {
    let title: String
    let stateTitle: String
    let detail: String
    let trustMessage: String
    let connectionActionTitle: String
    let connectionActionRole: ButtonRole?
    let isConnectionActionDisabled: Bool
    let refreshActionTitle: String?
    let isRefreshActionDisabled: Bool
    let connectionAction: () -> Void
    let refreshAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
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

            VStack(alignment: .trailing, spacing: 8) {
                if let refreshActionTitle {
                    Button(refreshActionTitle, action: refreshAction)
                        .disabled(isRefreshActionDisabled)
                }

                Button(
                    connectionActionTitle,
                    role: connectionActionRole,
                    action: connectionAction
                )
                .disabled(isConnectionActionDisabled)
            }
        }
        .padding(.vertical, 6)
    }
}
