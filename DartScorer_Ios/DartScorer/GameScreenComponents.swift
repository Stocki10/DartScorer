import SwiftUI

struct GameControlBar: View {
    let sessionRole: SessionRole
    let isLegInProgress: Bool
    let canUndo: Bool
    let canUndoLocally: Bool
    let onNewGame: () -> Void
    let onRestartLeg: () -> Void
    let onShowDisconnectAlert: () -> Void
    let onShowProfiles: () -> Void
    let onShowHistory: () -> Void
    let onShowSettings: () -> Void
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onNewGame) {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.bordered)
            .disabled(sessionRole != .none && isLegInProgress)

            Button(action: onRestartLeg) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(!isLegInProgress || sessionRole == .joiner)

            Spacer(minLength: 0)

            if sessionRole == .host {
                Button(action: onShowDisconnectAlert) {
                    Image(systemName: "wifi.slash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else if sessionRole == .joiner {
                Button(action: onShowDisconnectAlert) {
                    Image(systemName: "person.fill.xmark")
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }

            Button(action: onShowProfiles) {
                Image(systemName: "person.crop.circle")
            }
            .buttonStyle(.bordered)

            Button(action: onShowHistory) {
                Image(systemName: "clock")
            }
            .buttonStyle(.bordered)

            Button(action: onShowSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.bordered)

            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(.bordered)
            .disabled(!canUndo || (sessionRole != .none && !canUndoLocally))
        }
    }
}

struct ScoreboardSection: View {
    let players: [Player]
    let activePlayerIndex: Int
    let setModeEnabled: Bool
    let legsWon: (Player) -> Int
    let throwsToDisplay: (Player, Int) -> [Int]
    let legAverage: (Player) -> Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                HStack {
                    Text(player.name)
                    if setModeEnabled {
                        Text("\(legsWon(player))")
                            .font(.footnote)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(player.colorHex.flatMap { Color(hex: $0) } ?? Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    let throwsForBadge = throwsToDisplay(player, index)
                    if !throwsForBadge.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(Array(throwsForBadge.enumerated()), id: \.offset) { _, value in
                                Text("\(value)")
                                    .font(.footnote)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(.tertiarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                            if throwsForBadge.count == 3 {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.35))
                                    .frame(width: 1, height: 16)
                                    .padding(.horizontal, 2)
                                Text("\(throwsForBadge.reduce(0, +))")
                                    .font(.footnote)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .layoutPriority(1)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(.tertiarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(player.score)")
                            .fontWeight(.semibold)
                        Text("⌀ \(String(format: "%.1f", legAverage(player) ?? 0.0))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background {
                    let playerColor = player.colorHex.flatMap { Color(hex: $0) } ?? Color.accentColor
                    return index == activePlayerIndex ? playerColor.opacity(0.18) : Color(.secondarySystemBackground)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct CheckoutBadgeView: View {
    let routes: [String]
    let isBogey: Bool

    private var label: String {
        if isBogey {
            return "Bogey — no finish possible"
        }
        if routes.isEmpty {
            return "No finish available"
        }
        return routes.joined(separator: "   ·   ")
    }

    var body: some View {
        Text(label)
            .font(.subheadline)
            .fontWeight(routes.isEmpty ? .regular : .bold)
            .lineLimit(1)
            .foregroundStyle(isBogey ? Color.orange : (routes.isEmpty ? Color.primary : Color.white))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                isBogey
                    ? Color.orange.opacity(0.12)
                    : (routes.isEmpty ? Color(.secondarySystemBackground) : Color.accentColor)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct MultiplierPickerView: View {
    @Binding var selection: DartMultiplier

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Multiplier", selection: $selection) {
                ForEach(DartMultiplier.allCases) { multiplier in
                    Text(multiplier.label).tag(multiplier)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

struct NumberPadView: View {
    let selectedMultiplier: DartMultiplier
    let isInputLocked: Bool
    let hasWinner: Bool
    let onNumberTap: (Int) -> Void
    let onBullTap: () -> Void
    let onZeroTap: () -> Void
    let onNoScoreTap: () -> Void

    private let numberColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: numberColumns, spacing: 8) {
                ForEach(1...20, id: \.self) { value in
                    Button("\(value)") {
                        onNumberTap(value)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(hasWinner || isInputLocked)
                }

                Button(selectedMultiplier == .single ? "25" : "Bull") {
                    onBullTap()
                }
                .buttonStyle(.borderedProminent)
                .disabled(hasWinner || selectedMultiplier == .triple || isInputLocked)

                Button("0") {
                    onZeroTap()
                }
                .buttonStyle(.bordered)
                .disabled(hasWinner || isInputLocked)

                Color.clear.frame(height: 1)
                Color.clear.frame(height: 1)

                Button("No Score") {
                    onNoScoreTap()
                }
                .buttonStyle(.bordered)
                .disabled(hasWinner || isInputLocked)
                .font(.footnote)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            }
        }
    }
}

struct ReconnectBannerView: View {
    let onAbort: () -> Void

    var body: some View {
        VStack {
            HStack(spacing: 8) {
                ProgressView()
                Text("Reconnecting…")
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
            .padding(.top, 8)

            Spacer()

            Button("Abort Connection", action: onAbort)
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .padding(.bottom, 24)
        }
    }
}
