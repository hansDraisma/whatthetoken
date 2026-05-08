import SwiftUI

struct StatusBannerView: View {
    let state: BannerState

    var body: some View {
        switch state {
        case .hidden:
            EmptyView()
        case let .critical(text):
            banner(text: text, foreground: .red, background: Color.red.opacity(0.15))
        case let .low(text):
            banner(text: text, foreground: .orange, background: Color.orange.opacity(0.15))
        case let .stale(text):
            banner(text: text, foreground: .secondary, background: Color.gray.opacity(0.12))
        case let .disconnected(text):
            banner(text: text, foreground: .accentColor, background: Color.accentColor.opacity(0.12))
        }
    }

    private func banner(text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(background)
    }
}
