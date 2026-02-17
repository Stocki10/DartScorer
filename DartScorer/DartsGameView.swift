import SwiftUI

struct DartsGameView: View {
    @StateObject private var game = DartsGame(playerCount: 2)
    @State private var selectedMultiplier: DartMultiplier = .single
    @State private var isShowingNewGameSetup = false
    @State private var setupPlayerNames: [String] = []
    @State private var setupFinishRule: FinishRule = .doubleOut

    private let numberColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Darts 501")
                        .font(.title2)
                        .fontWeight(.semibold)

                    controlBar

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(game.players.enumerated()), id: \.element.id) { index, player in
                            HStack {
                                Text(player.name)
                                let throwsForBadge = throwsToDisplay(for: player, at: index)
                                if !throwsForBadge.isEmpty {
                                    HStack(spacing: 4) {
                                        ForEach(Array(throwsForBadge.enumerated()), id: \.offset) { _, value in
                                            Text("\(value)")
                                                .font(.footnote)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color(.tertiarySystemBackground))
                                                .clipShape(RoundedRectangle(cornerRadius: 5))
                                        }
                                    }
                                }
                                Spacer()
                                Text("\(player.score)")
                                    .fontWeight(.semibold)
                            }
                            .padding(10)
                            .background(index == game.activePlayerIndex ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(.horizontal)

                Divider()

                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("Active: \(game.activePlayer.name)")
                            .fontWeight(.medium)
                        Text("Darts remaining: \(game.remainingDarts)")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        if game.currentTurn.darts.isEmpty {
                            Text("No throws")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(game.currentTurn.darts.enumerated()), id: \.offset) { _, throwValue in
                                Text(throwValue.displayText)
                                    .font(.subheadline)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let statusMessage = game.statusMessage {
                        Text(statusMessage)
                            .foregroundStyle(.secondary)
                    }

                    multiplierPicker
                    numberPad
                }
                .padding(.horizontal)
                .padding(.bottom)
            }

            if let winner = game.winner {
                winnerOverlay(for: winner)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $isShowingNewGameSetup) {
            NewGameSetupView(
                playerNames: $setupPlayerNames,
                finishRule: $setupFinishRule,
                onCancel: { isShowingNewGameSetup = false },
                onStart: {
                    game.newGame(playerNames: setupPlayerNames, finishRule: setupFinishRule)
                    isShowingNewGameSetup = false
                }
            )
        }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            Button("New Game") {
                presentNewGameSetup()
            }
            .buttonStyle(.bordered)

            Button("Restart Leg") {
                game.restartLeg()
            }
            .buttonStyle(.bordered)

            Button {
                game.undoLastThrow()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(.bordered)
            .disabled(!game.canUndo)
        }
    }

    private var multiplierPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Multiplier", selection: $selectedMultiplier) {
                ForEach(DartMultiplier.allCases) { multiplier in
                    Text(multiplier.label).tag(multiplier)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var numberPad: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Throw")
                .font(.headline)

            LazyVGrid(columns: numberColumns, spacing: 8) {
                ForEach(1...20, id: \.self) { value in
                    Button("\(value)") {
                        game.submitThrow(segment: .number(value), multiplier: selectedMultiplier)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(game.winner != nil)
                }

                Button("Bull") {
                    game.submitThrow(segment: .bull, multiplier: selectedMultiplier)
                }
                .buttonStyle(.borderedProminent)
                .disabled(game.winner != nil || selectedMultiplier == .triple)
            }
        }
    }

    private func winnerOverlay(for winner: Player) -> some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.96)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Leg Won")
                    .font(.title)
                    .fontWeight(.bold)
                Text(winner.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(winningSubtitle)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button("Restart Leg") {
                        game.restartLeg()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("New Game") {
                        presentNewGameSetup()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
    }

    private var winningSubtitle: String {
        game.finishRule == .doubleOut ? "Finished with a double-out." : "Finished with single-out rules."
    }

    private func presentNewGameSetup() {
        setupPlayerNames = game.players.map(\.name)
        setupFinishRule = game.finishRule
        isShowingNewGameSetup = true
    }

    private func throwsToDisplay(for player: Player, at index: Int) -> [Int] {
        if index == game.activePlayerIndex {
            return game.currentTurn.darts.map(\.points)
        }
        return game.lastTurnThrows(for: player)
    }
}

private struct NewGameSetupView: View {
    @Binding var playerNames: [String]
    @Binding var finishRule: FinishRule

    let onCancel: () -> Void
    let onStart: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Game Settings") {
                    Stepper("Players: \(playerNames.count)", value: playerCountBinding, in: 1...4)

                    Picker("Finish Mode", selection: $finishRule) {
                        ForEach(FinishRule.allCases) { rule in
                            Text(rule.rawValue).tag(rule)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Player Order") {
                    Text("Drag rows to set the throw sequence.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    List {
                        ForEach(playerNames.indices, id: \.self) { index in
                            HStack {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(.secondary)
                                TextField("Player \(index + 1)", text: $playerNames[index])
                                    .textInputAutocapitalization(.words)
                                    .disableAutocorrection(true)
                            }
                        }
                        .onMove(perform: movePlayers)
                    }
                    .frame(minHeight: 50)
                    .environment(\.editMode, .constant(.active))
                }
            }
            .navigationTitle("New Game")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start", action: onStart)
                }
            }
        }
        .onAppear {
            if playerNames.isEmpty {
                playerNames = ["Player 1", "Player 2"]
            }
        }
    }

    private var playerCountBinding: Binding<Int> {
        Binding(
            get: { playerNames.count },
            set: { newValue in
                let clamped = min(max(1, newValue), 4)
                if clamped > playerNames.count {
                    let start = playerNames.count + 1
                    for index in start...clamped {
                        playerNames.append("Player \(index)")
                    }
                } else if clamped < playerNames.count {
                    playerNames = Array(playerNames.prefix(clamped))
                }
            }
        )
    }

    private func movePlayers(from source: IndexSet, to destination: Int) {
        playerNames.move(fromOffsets: source, toOffset: destination)
    }
}
