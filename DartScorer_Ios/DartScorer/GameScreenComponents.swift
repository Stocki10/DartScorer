import SwiftUI

enum ScoreEntryMode: String, CaseIterable, Identifiable {
    case throwsMode = "Throws"
    case quick = "Quick"

    var id: String { rawValue }

    var label: String { rawValue }
}

struct CricketBoardSection: View {
    let players: [Player]
    let activePlayerIndex: Int
    let targets: [CricketTarget]
    let marks: (Player, CricketTarget) -> Int
    let score: (Player) -> Int
    let throwsToDisplay: (Player, Int) -> [Int]

    private var activePlayerID: UUID? {
        guard players.indices.contains(activePlayerIndex) else { return nil }
        return players[activePlayerIndex].id
    }

    private var activeThrowSignature: String {
        guard players.indices.contains(activePlayerIndex) else { return "" }
        return throwsToDisplay(players[activePlayerIndex], activePlayerIndex)
            .map(String.init)
            .joined(separator: "-")
    }

    private func visitLabel(for values: [Int]) -> String {
        guard !values.isEmpty else { return "No throw" }
        return values.map(String.init).joined(separator: " ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: 42, height: 1)

                ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(player.name)
                            .font(.caption.weight(index == activePlayerIndex ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("\(score(player))")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            ForEach(targets) { target in
                HStack(spacing: 0) {
                    Text(target.label)
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 42, alignment: .leading)

                    ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                        Text("\(marks(player, target))")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 28)
                            .padding(.vertical, 6)
                            .background(
                                index == activePlayerIndex
                                    ? (player.colorHex.flatMap { Color(hex: $0) } ?? Color.accentColor).opacity(0.16)
                                    : Color(.secondarySystemBackground)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            Divider()
                .padding(.top, 4)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                            let throwsForBadge = throwsToDisplay(player, index)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(player.name)
                                    .font(.caption.weight(index == activePlayerIndex ? .semibold : .regular))
                                    .foregroundStyle(index == activePlayerIndex ? .primary : .secondary)
                                    .lineLimit(1)
                                Text(visitLabel(for: throwsForBadge))
                                    .font(.caption.monospacedDigit())
                                    .lineLimit(1)
                                    .foregroundStyle(throwsForBadge.isEmpty ? .secondary : .primary)
                            }
                            .frame(width: 96, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                index == activePlayerIndex
                                    ? Color.accentColor.opacity(0.10)
                                    : Color(.tertiarySystemBackground)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .id(player.id)
                        }
                    }
                }
                .onAppear {
                    guard let activePlayerID else { return }
                    proxy.scrollTo(activePlayerID, anchor: .center)
                }
                .onChange(of: activePlayerID) { _, newValue in
                    guard let newValue else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
                .onChange(of: activeThrowSignature) { _, _ in
                    guard let activePlayerID else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(activePlayerID, anchor: .center)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

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

struct ScoreEntryModePicker: View {
    @Binding var selection: ScoreEntryMode

    var body: some View {
        Picker("Input Mode", selection: $selection) {
            ForEach(ScoreEntryMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
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

struct QuickScorePadView: View {
    @Binding var scoreText: String
    @Binding var isShowingManualInput: Bool
    let isInputLocked: Bool
    let hasWinner: Bool
    let isVisitOpenInThrowsMode: Bool
    let onQuickScoreTap: (Int) -> Void
    let onSubmitManualScore: () -> Void
    let onNoScoreTap: () -> Void

    private let primaryQuickScores = [60, 100, 140, 180]
    private let secondaryQuickScores = [26, 45, 85, 90, 120, 121]
    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    private var isDisabled: Bool {
        hasWinner || isInputLocked || isVisitOpenInThrowsMode
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(primaryQuickScores, id: \.self) { score in
                    Button("\(score)") {
                        onQuickScoreTap(score)
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(isDisabled)
                }
            }

            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(secondaryQuickScores, id: \.self) { score in
                    Button("\(score)") {
                        onQuickScoreTap(score)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(isDisabled)
                }

                Button("•••") {
                    isShowingManualInput.toggle()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .disabled(hasWinner || isInputLocked)

                Button {
                    onNoScoreTap()
                } label: {
                    Text("No Score")
                        .font(.footnote)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .disabled(hasWinner || isInputLocked)
            }

            if isShowingManualInput {
                TextField("Enter score", text: $scoreText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isDisabled)
                    .onSubmit(onSubmitManualScore)
            }

            if isVisitOpenInThrowsMode {
                Text("Finish the current visit in Throws mode.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
