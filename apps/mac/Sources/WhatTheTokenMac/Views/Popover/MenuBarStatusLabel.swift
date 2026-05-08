import SwiftUI

struct MenuBarStatusLabel: View {
    let viewModel: StatusViewModel

    var body: some View {
        Label(
            PopoverChromeState.menuBarTitle(viewModel: viewModel),
            systemImage: PopoverChromeState.menuBarSystemImage(viewModel: viewModel)
        )
    }
}
