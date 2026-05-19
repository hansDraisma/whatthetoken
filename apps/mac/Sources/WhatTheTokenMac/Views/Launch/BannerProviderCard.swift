import SwiftUI
import AppKit

struct BannerProviderCardCopy {
    let title: String
    let subtitle: String
    let isConnected: Bool
    let connectActionTitle: String

    var trailingLabel: String { isConnected ? "Connected" : connectActionTitle }
    var showsConnectButton: Bool { !isConnected }
}

struct BannerProviderCard: View {
    let title: String
    let subtitle: String
    let isConnected: Bool
    let connectActionTitle: String
    let onConnect: () -> Void

    var body: some View {
        let copy = BannerProviderCardCopy(
            title: title,
            subtitle: subtitle,
            isConnected: isConnected,
            connectActionTitle: connectActionTitle
        )
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(copy.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(copy.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if copy.showsConnectButton {
                Button(copy.trailingLabel, action: onConnect)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            } else {
                Label(copy.trailingLabel, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
            }
        }
        .padding(12)
        .background(Color(nsColor: .textBackgroundColor))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.2)))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
