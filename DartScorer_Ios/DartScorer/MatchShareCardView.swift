import SwiftUI

struct MatchShareCardView: View {
    let summary: MatchShareSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(summary.format)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(summary.dateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let winnerName = summary.winnerName {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.string("Winner"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(winnerName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(winnerAccent)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(winnerAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(winnerAccent.opacity(0.75), lineWidth: 2)
                )
            }

            if !summary.details.isEmpty {
                HStack(spacing: 12) {
                    ForEach(summary.details) { detail in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(detail.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(detail.value)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }

            VStack(spacing: 12) {
                ForEach(summary.playerLines) { line in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(line.name)
                                .font(.headline.weight(line.isWinner ? .bold : .semibold))
                                .foregroundStyle(line.isWinner ? winnerAccent : .primary)
                            Spacer()
                        }

                        HStack(spacing: 18) {
                            ForEach(line.stats) { stat in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(stat.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(stat.value)
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        line.isWinner ? winnerAccent.opacity(0.12) : Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(line.isWinner ? winnerAccent.opacity(0.8) : Color.black.opacity(0.04), lineWidth: line.isWinner ? 2 : 1)
                    )
                    .opacity(line.isWinner ? 1 : 0.86)
                }
            }

            Text(summary.footerText)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 1080)
        .background(Color(.systemGroupedBackground))
    }

    private var winnerAccent: Color {
        summary.winnerColorHex.flatMap { Color(hex: $0) } ?? .yellow
    }
}
