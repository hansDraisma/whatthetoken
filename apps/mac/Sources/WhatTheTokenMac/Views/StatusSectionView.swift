import SwiftUI

struct StatusSectionView: View {
    let snapshots: [UsageSnapshot]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let model = StatusSectionDisplayModel(snapshots: snapshots, now: context.date)

            VStack(alignment: .leading, spacing: 0) {
                header(model)
                    .padding(.bottom, 12)
                    .overlay(alignment: .bottom) {
                        Divider()
                    }

                ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                    StatusRowView(row: row)
                        .padding(.vertical, 12)
                        .overlay(alignment: .bottom) {
                            if index < model.rows.count - 1 {
                                Divider()
                            }
                        }
                }
            }
            .padding(20)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.secondary.opacity(0.18), lineWidth: 1)
            }
            .frame(maxWidth: 420, alignment: .leading)
        }
    }

    @ViewBuilder
    private func header(_ model: StatusSectionDisplayModel) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                if let brandTitle = model.brandTitle {
                    Text(brandTitle)
                        .font(.subheadline.weight(.semibold))
                }
                if let trustLine = model.trustLine {
                    Text(trustLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 16)

            if let compareLink = model.compareLink {
                Link(compareLink.title, destination: compareLink.url)
                    .font(.caption)
            }
        }
    }
}

private struct StatusRowView: View {
    let row: StatusRowDisplayModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Text(row.name)
                        .font(.subheadline.weight(.semibold))

                    ForEach(row.badges, id: \.self) { badge in
                        BadgeView(badge: badge)
                    }
                }

                Spacer(minLength: 12)

                if let resetHint = row.resetHint {
                    Text(resetHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .firstTextBaseline) {
                Text(row.heroText)
                    .font(.system(size: row.state == .empty ? 18 : 24, weight: .semibold))
                    .foregroundStyle(row.heroTintsRed ? Color.red : .primary)

                Spacer(minLength: 12)

                if let echoText = row.echoText {
                    Text(echoText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            if row.showsBar {
                ProgressView(value: row.progressValue)
                    .progressViewStyle(.linear)
                    .tint(color(for: row.state))
            }

            if row.showsStatus {
                HStack(spacing: 4) {
                    Circle()
                        .frame(width: 6, height: 6)
                        .foregroundStyle(color(for: row.state))

                    Text(row.statusWord)
                        .font(.caption)
                        .foregroundStyle(color(for: row.state))
                }
            }

            if let staleReason = row.staleReason {
                Text(staleReason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func color(for state: StatusUsageState) -> Color {
        switch state {
        case .healthy:
            return .green
        case .low:
            return .orange
        case .critical, .empty:
            return .red
        }
    }
}

private struct BadgeView: View {
    let badge: StatusRowBadge

    var body: some View {
        Text(badge.label)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(.yellow.opacity(0.18))
            .foregroundStyle(.orange)
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.orange.opacity(0.35), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .help(badge.tooltip)
    }
}
