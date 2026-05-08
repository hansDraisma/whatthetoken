import SwiftUI

struct ConnectorRowView: View {
    let title: String
    let stateTitle: String
    let detail: String
    let trustMessage: String
    let actionTitle: String
    let isWorking: Bool
    let isEnabled: Bool
    let canDisconnect: Bool
    let onEnabledChange: (Bool) -> Void
    let onDisconnect: () -> Void
    let action: () -> Void

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

                Toggle("Enabled", isOn: Binding(
                    get: { isEnabled },
                    set: { enabled in onEnabledChange(enabled) }
                ))

                Button("Disconnect", role: .destructive, action: onDisconnect)
                    .disabled(!canDisconnect)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(actionTitle, action: action)
                .disabled(isWorking || !isEnabled)
        }
        .padding(.vertical, 6)
    }
}
