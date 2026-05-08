import SwiftUI

struct ProviderTabBarView: View {
    @Binding var selected: ProviderTab
    let indicators: [ProviderTab: ProviderTabIndicator]

    init(
        selected: Binding<ProviderTab>,
        indicators: [ProviderTab: ProviderTabIndicator] = [:]
    ) {
        self._selected = selected
        self.indicators = indicators
    }

    var body: some View {
        HStack(spacing: 1) {
            ForEach(ProviderTab.allCases) { tab in
                let indicator = indicators[tab] ?? .none
                segment(for: tab, indicator: indicator)
            }
        }
        .padding(2)
        .background(Color.secondary.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func segment(for tab: ProviderTab, indicator: ProviderTabIndicator) -> some View {
        if let helpText = indicator.helpText {
            segmentButton(for: tab, indicator: indicator)
                .help(helpText)
        } else {
            segmentButton(for: tab, indicator: indicator)
        }
    }

    private func segmentButton(for tab: ProviderTab, indicator: ProviderTabIndicator) -> some View {
        Button {
            selected = tab
        } label: {
            tabLabelContent(for: tab, indicator: indicator)
                .frame(maxWidth: .infinity, minHeight: 24)
                .contentShape(Rectangle())
                .background(segmentBackground(for: tab))
                .foregroundStyle(selected == tab ? Color.white : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(Text(indicator.accessibilityLabel(for: tab)))
        .accessibilityValue(Text(selected == tab ? "Selected" : "Not selected"))
    }

    @ViewBuilder
    private func tabLabelContent(for tab: ProviderTab, indicator: ProviderTabIndicator) -> some View {
        HStack(spacing: 5) {
            Text(tab.title)

            if indicator.hasInlineMarker {
                Circle()
                    .fill(markerColor(for: indicator))
                    .frame(width: 6, height: 6)
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(selected == tab ? 0.85 : 0), lineWidth: 1)
                    }
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func segmentBackground(for tab: ProviderTab) -> Color {
        selected == tab ? .accentColor : .clear
    }

    private func markerColor(for indicator: ProviderTabIndicator) -> Color {
        switch indicator {
        case .none:
            return .clear
        case .warning:
            return .orange
        case .critical:
            return .red
        case .stale:
            return .secondary
        case .disconnected:
            return .accentColor
        }
    }
}
