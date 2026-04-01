import SwiftUI

struct WinnerOverlayView: View {
    let winnerName: String
    let title: String
    let subtitle: String
    let summary: MatchShareSummary?
    let isPreparingShare: Bool
    let showNewLeg: Bool
    let canUndo: Bool
    let canUndoLocally: Bool
    let onNewLegRandom: (() -> Void)?
    let onNewGame: (() -> Void)?
    let primaryActionTitle: String?
    let onPrimaryAction: (() -> Void)?
    let secondaryActionTitle: String?
    let onSecondaryAction: (() -> Void)?
    let onShareSummary: (() -> Void)?
    let onUndo: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.96)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    Text(title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if let summary {
                        WinnerSummaryCard(summary: summary)
                    }

                    if let primaryActionTitle, let onPrimaryAction {
                        Button(primaryActionTitle, action: onPrimaryAction)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                    }

                    if let secondaryActionTitle, let onSecondaryAction {
                        Button(secondaryActionTitle, action: onSecondaryAction)
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                    }
                }
                .padding()
                .padding(.top, 88)
                .frame(maxWidth: 620)
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 10) {
                if showNewLeg, let onNewLegRandom {
                    Button(L10n.string("Rematch"), action: onNewLegRandom)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }

                if let onNewGame {
                    Button(showNewLeg ? L10n.string("New Game") : L10n.string("Start New Game"), action: onNewGame)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }

                if let onShareSummary {
                    Button(action: onShareSummary) {
                        if isPreparingShare {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isPreparingShare)
                    .accessibilityLabel(L10n.string("Share Summary"))
                }

                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!canUndo || !canUndoLocally)
            }
            .padding(.top, 20)
            .padding(.trailing, 12)
        }
    }
}

private struct WinnerSummaryCard: View {
    let summary: MatchShareSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(summary.format)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(summary.dateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let winnerName = summary.winnerName {
                HStack(spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .font(.title2)
                        .foregroundStyle(winnerAccent)
                    Text(winnerName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(winnerAccent)
                }
            }

            if !summary.details.isEmpty {
                HStack(spacing: 10) {
                    ForEach(summary.details) { detail in
                        WinnerDetailBadge(title: detail.title, value: detail.value)
                    }
                }
            }

            VStack(spacing: 10) {
                ForEach(summary.playerLines) { line in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            HStack(spacing: 6) {
                                if line.isWinner {
                                    Image(systemName: "trophy.fill")
                                        .foregroundStyle(winnerAccent)
                                        .font(.caption)
                                }
                                Text(line.name)
                                    .font(.headline.weight(line.isWinner ? .bold : .semibold))
                            }
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
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(line.isWinner ? winnerAccent.opacity(0.12) : Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(line.isWinner ? winnerAccent.opacity(0.7) : Color.black.opacity(0.04), lineWidth: line.isWinner ? 2 : 1)
                    )
                    .opacity(line.isWinner ? 1 : 0.72)
                }
            }
        }
        .padding(18)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private var winnerAccent: Color {
        summary.winnerColorHex.flatMap { Color(hex: $0) } ?? .yellow
    }
}

private struct WinnerDetailBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
