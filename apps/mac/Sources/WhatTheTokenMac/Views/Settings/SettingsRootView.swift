import SwiftUI

struct SettingsRootView: View {
    let viewModel: StatusViewModel

    var body: some View {
        ConnectorsView(viewModel: viewModel)
            .frame(minWidth: 480, minHeight: 360)
    }
}
