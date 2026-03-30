import SwiftUI

enum MatchShareCardLayout {
    case verticalSocial
    case horizontalCompact

    var canvasSize: CGSize {
        switch self {
        case .verticalSocial:
            return CGSize(width: 1080, height: 1350)
        case .horizontalCompact:
            return CGSize(width: 1350, height: 1080)
        }
    }
}

struct MatchShareCardView: View {
    let summary: MatchShareSummary
    var layout: MatchShareCardLayout = .verticalSocial

    var body: some View {
        ZStack {
            backgroundGradient
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(winnerAccent.opacity(0.2))
                        .frame(width: 440, height: 440)
                        .blur(radius: 90)
                        .offset(x: -120, y: -100)
                }
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 360, height: 360)
                        .blur(radius: 100)
                        .offset(x: 80, y: 100)
                }

            switch layout {
            case .verticalSocial:
                verticalCard
            case .horizontalCompact:
                horizontalCard
            }
        }
        .frame(width: layout.canvasSize.width, height: layout.canvasSize.height)
    }

    private var verticalCard: some View {
        VStack {
            Spacer(minLength: 0)

            VStack(spacing: 34) {
                heroBlock(titleSize: 76, winsSize: 24, subtitleSize: 28, dateSize: 19)

                VStack(spacing: 10) {
                    if !opponentsLine.isEmpty {
                        Text(opponentsLine)
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.78))
                            .multilineTextAlignment(.center)
                    }
                }

                VStack(spacing: 16) {
                    ForEach(heroStats.prefix(3)) { stat in
                        ShareVerticalStatRow(title: stat.title, value: stat.value, accent: winnerAccent)
                    }
                }

                Text(summary.title)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.48))
            }
            .padding(.horizontal, 58)
            .padding(.vertical, 64)
            .frame(maxWidth: .infinity)
            .background(cardBackgroundShape)

            Spacer(minLength: 0)
        }
        .padding(72)
    }

    private var horizontalCard: some View {
        HStack(spacing: 30) {
            VStack(alignment: .leading, spacing: 22) {
                heroBlock(titleSize: 62, winsSize: 22, subtitleSize: 24, dateSize: 18, alignment: .leading)

                if !opponentsLine.isEmpty {
                    Text(opponentsLine)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.leading)
                }

                Text(summary.title)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.48))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 14) {
                ForEach(heroStats.prefix(3)) { stat in
                    ShareVerticalStatRow(title: stat.title, value: stat.value, accent: winnerAccent)
                }
            }
            .frame(width: 360)
        }
        .padding(.horizontal, 62)
        .padding(.vertical, 56)
        .background(cardBackgroundShape)
        .padding(72)
    }

    private func heroBlock(
        titleSize: CGFloat,
        winsSize: CGFloat,
        subtitleSize: CGFloat,
        dateSize: CGFloat,
        alignment: HorizontalAlignment = .center
    ) -> some View {
        VStack(alignment: alignment, spacing: 14) {
            ZStack {
                Circle()
                    .fill(winnerAccent.opacity(0.18))
                    .frame(width: 104, height: 104)
                    .blur(radius: 16)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(winnerAccent)
            }

            if let winnerName = summary.winnerName {
                Text(winnerName)
                    .font(.system(size: titleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(alignment == .center ? .center : .leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            } else {
                Text(L10n.string("Winner"))
                    .font(.system(size: titleSize * 0.88, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(alignment == .center ? .center : .leading)
            }

            Text("WINS")
                .font(.system(size: winsSize, weight: .semibold, design: .rounded))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.62))

            VStack(alignment: alignment, spacing: 6) {
                Text(summary.format)
                    .font(.system(size: subtitleSize, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(alignment == .center ? .center : .leading)
                Text(summary.dateText)
                    .font(.system(size: dateSize, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.28))
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
    }

    private var winnerAccent: Color {
        summary.winnerColorHex.flatMap { Color(hex: $0) } ?? Color(red: 0.97, green: 0.77, blue: 0.14)
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.09, blue: 0.16),
                Color(red: 0.08, green: 0.11, blue: 0.19),
                winnerAccent.opacity(0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cardBackgroundShape: some View {
        RoundedRectangle(cornerRadius: 44, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.11, green: 0.13, blue: 0.18).opacity(0.96),
                        Color(red: 0.085, green: 0.095, blue: 0.145).opacity(0.985)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 44, style: .continuous)
                    .stroke(.white.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 26, x: 0, y: 16)
    }

    private var heroStats: [ShareHeroStat] {
        let stats = summary.playerLines.first(where: \.isWinner)?.stats ?? []
        return stats.prefix(3).map { stat in
            ShareHeroStat(title: shareTitle(for: stat.title), value: stat.value)
        }
    }

    private var opponentsLine: String {
        let opponents = summary.playerLines
            .filter { !$0.isWinner }
            .map(\.name)

        guard !opponents.isEmpty else { return "" }
        return "Beat: " + opponents.joined(separator: " • ")
    }

    private func shareTitle(for title: String) -> String {
        switch title {
        case L10n.string("Best Checkout"):
            return L10n.string("Checkout")
        case L10n.string("Best Turn"):
            return L10n.string("Best Turn")
        case L10n.string("Average"):
            return "Avg"
        default:
            return title
        }
    }
}

private struct ShareHeroStat: Identifiable {
    let id: String
    let title: String
    let value: String

    init(title: String, value: String) {
        self.id = title
        self.title = title
        self.value = value
    }
}

private struct ShareVerticalStatRow: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 21, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.56))
            Spacer()
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
                .minimumScaleFactor(0.72)
                .lineLimit(2)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        )
    }
}
