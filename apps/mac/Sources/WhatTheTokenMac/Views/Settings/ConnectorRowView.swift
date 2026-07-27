import SwiftUI

struct ConnectorRowView: View {
    let title: String
    let stateTitle: String
    let detail: String
    let trustMessage: String
    let connectionActionTitle: String
    let connectionActionRole: ButtonRole?
    let isConnectionActionDisabled: Bool
    let secondaryActionTitle: String?
    let disconnectActionTitle: String?
    let connectionAction: () -> Void
    let secondaryAction: (() -> Void)?
    let disconnectAction: (() -> Void)?

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
                Button(
                    connectionActionTitle,
                    role: connectionActionRole,
                    action: connectionAction
                )
                .disabled(isConnectionActionDisabled)

                if let secondaryActionTitle, let secondaryAction {
                    Button(secondaryActionTitle, action: secondaryAction)
                }

                if let disconnectActionTitle, let disconnectAction {
                    Button(disconnectActionTitle, role: .destructive, action: disconnectAction)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
