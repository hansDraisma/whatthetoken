import SwiftUI

struct NotificationsTabView: View {
    let viewModel: StatusViewModel

    var body: some View {
        Form {
            if !viewModel.settings.notifications.isEnabled {
                Section {
                    Text("Notifications are off. Enable them below to be warned before quota runs out.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            NotificationAlertsView(viewModel: viewModel)
        }
        .formStyle(.grouped)
    }
}
