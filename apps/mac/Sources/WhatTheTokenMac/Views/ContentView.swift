import SwiftUI

struct ContentView: View {
    let viewModel: StatusViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.snapshots.isEmpty {
                Text("No usage signal")
                    .font(.headline)
                    .padding()
            } else {
                ForEach(viewModel.snapshots, id: \.id) { snapshot in
                    StatusCardView(snapshot: snapshot)
                }
            }
        }
        .padding()
    }
}
