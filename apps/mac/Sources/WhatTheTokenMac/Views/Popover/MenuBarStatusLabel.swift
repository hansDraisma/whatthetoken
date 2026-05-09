import SwiftUI

struct MenuBarStatusLabel: View {
    let viewModel: StatusViewModel

    var body: some View {
        let isCritical = PopoverChromeState.hasCriticalProvider(viewModel: viewModel)
        Label(
            PopoverChromeState.menuBarTitle(isCritical: isCritical),
            systemImage: PopoverChromeState.menuBarSystemImage(isCritical: isCritical)
        )
    }
}
