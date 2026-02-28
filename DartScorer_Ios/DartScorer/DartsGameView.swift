import SwiftUI

struct DartsGameView: View {
    @StateObject private var game = DartsGame(playerCount: 2)
    @AppStorage("appThemeMode") private var appThemeModeRaw = AppThemeMode.light.rawValue
    @AppStorage("newGamePlayerNamesJSON") private var storedNewGamePlayerNamesJSON = ""
    @AppStorage("newGameFinishRule") private var storedNewGameFinishRuleRaw = FinishRule.doubleOut.rawValue
    @AppStorage("newGameInRule") private var storedNewGameInRuleRaw = InRule.default.rawValue
    @AppStorage("newGameStartScore") private var storedNewGameStartScoreRaw = StartScoreOption.score501.rawValue
    @AppStorage("newGameSetModeEnabled") private var storedNewGameSetModeEnabled = false
    @AppStorage("newGameLegsToWin") private var storedNewGameLegsToWin = 3
    @State private var selectedMultiplier: DartMultiplier = .single
    @State private var isShowingNewGameSetup = false
    @State private var setupPlayers: [SetupPlayer] = []
    @State private var setupFinishRule: FinishRule = .doubleOut
    @State private var setupInRule: InRule = .default
    @State private var setupStartScore: StartScoreOption = .score501
    @State private var setupSetModeEnabled = false
    @State private var setupLegsToWin = 3
    @State private var isShowingRestartAlert = false
    @State private var hasPresentedInitialSetup = false
    @State private var isShowingThemeSettings = false
    @State private var draftThemeMode: AppThemeMode = .light

    private let numberColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                controlBar
                    .padding(.horizontal)

                scoreboardSection
                    .padding(.horizontal)

                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 16) {

                    if let statusMessage = game.statusMessage {
                        Text(statusMessage)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                Spacer(minLength: 0)

                Text(game.bestPossibleFinishLine)
                    .font(.subheadline)
                    .fontWeight(game.hasBestPossibleFinish ? .bold : .regular)
                    .foregroundStyle(game.hasBestPossibleFinish ? Color.white : Color.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(game.hasBestPossibleFinish ? Color.accentColor : Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(.horizontal)

                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
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
                setupPlayers: $setupPlayers,
                finishRule: $setupFinishRule,
                inRule: $setupInRule,
                startScore: $setupStartScore,
                setModeEnabled: $setupSetModeEnabled,
                legsToWin: $setupLegsToWin,
                onCancel: { isShowingNewGameSetup = false },
                onStart: {
                    persistNewGameSettings()
                    game.newGame(
                        playerNames: setupPlayers.map(\.name),
                        finishRule: setupFinishRule,
                        inRule: setupInRule,
                        startingScore: setupStartScore.rawValue,
                        setModeEnabled: setupSetModeEnabled,
                        legsToWin: setupLegsToWin
                    )
                    isShowingNewGameSetup = false
                }
            )
        }
        .fullScreenCover(isPresented: $isShowingThemeSettings) {
            SettingsPopupView(
                themeMode: $draftThemeMode
            ) {
                applySettings()
            }
            .presentationBackground(.clear)
        }
        .onAppear {
            guard !hasPresentedInitialSetup else { return }
            hasPresentedInitialSetup = true
            presentNewGameSetup()
        }
        .alert("Restart Leg?", isPresented: $isShowingRestartAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Restart Leg", role: .destructive) {
                game.restartLeg()
            }
        } message: {
            Text("You already started this leg. This will discard current progress.")
        }
    }

    private var scoreboardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(game.players.enumerated()), id: \.element.id) { index, player in
                HStack {
                    Text(player.name)
                    if game.setModeEnabled {
                        Text("\(game.legsWon(for: player))")
                            .font(.footnote)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    let throwsForBadge = throwsToDisplay(for: player, at: index)
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
                        Text("⌀ \(String(format: "%.1f", game.legAverage(for: player) ?? 0.0))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(index == game.activePlayerIndex ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            Button("New Game") {
                presentNewGameSetup()
            }
            .buttonStyle(.bordered)

            Button("Restart Leg") {
                if game.isLegInProgress {
                    isShowingRestartAlert = true
                } else {
                    game.restartLeg()
                }
            }
            .buttonStyle(.bordered)

            Spacer(minLength: 0)

            Button {
                draftThemeMode = AppThemeMode(rawValue: appThemeModeRaw) ?? .light
                isShowingThemeSettings = true
            } label: {
                Image(systemName: "gearshape")
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
            LazyVGrid(columns: numberColumns, spacing: 8) {
                ForEach(1...20, id: \.self) { value in
                    Button("\(value)") {
                        submitThrowAndReset(.number(value), multiplier: selectedMultiplier)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(game.winner != nil)
                }

                Button(selectedMultiplier == .single ? "25" : "Bull") {
                    submitThrowAndReset(.bull, multiplier: selectedMultiplier)
                }
                .buttonStyle(.borderedProminent)
                .disabled(game.winner != nil || selectedMultiplier == .triple)

                Button("0") {
                    submitThrowAndReset(.number(0), multiplier: .single)
                }
                .buttonStyle(.bordered)
                .disabled(game.winner != nil)

                Color.clear.frame(height: 1)
                Color.clear.frame(height: 1)

                Button("No Score") {
                    submitNoScoreTurn()
                }
                .buttonStyle(.bordered)
                .disabled(game.winner != nil)
                .font(.footnote)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            }
        }
    }

    private func winnerOverlay(for winner: Player) -> some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.96)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text(winnerTitle)
                    .font(.title)
                    .fontWeight(.bold)
                Text(winner.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(winningSubtitle)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    if game.setWinner == nil {
                        Button("New Leg (Random)") {
                            game.restartLegRandomSequence()
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Button(game.setWinner == nil ? "New Game" : "Start New Game") {
                        presentNewGameSetup()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            Button("Back") {
                game.undoLastThrow()
            }
            .buttonStyle(.bordered)
            .disabled(!game.canUndo)
            .padding(.top, 12)
            .padding(.trailing, 12)
        }
    }

    private var winningSubtitle: String {
        if game.setWinner != nil {
            return "Match complete."
        }
        let outText = game.finishRule == .doubleOut ? "double-out" : "single-out"
        let inText = game.inRule == .doubleIn ? "double-in" : "default-in"
        return "Played \(inText), \(outText)."
    }

    private var winnerTitle: String {
        game.setWinner == nil ? "Leg Won" : "Winner"
    }

    private func submitThrowAndReset(_ segment: DartSegment, multiplier: DartMultiplier) {
        game.submitThrow(segment: segment, multiplier: multiplier)
        selectedMultiplier = .single
    }

    private func submitNoScoreTurn() {
        let used = game.currentTurn.darts.count
        for _ in 0..<used {
            game.undoLastThrow()
        }
        for _ in 0..<3 {
            game.submitThrow(segment: .number(0), multiplier: .single)
        }
        selectedMultiplier = .single
    }

    private func presentNewGameSetup() {
        let persistedNames = persistedNewGamePlayerNames()
        let fallbackNames = game.players.enumerated().map { index, player in
            SetupPlayer(name: player.name, defaultName: "Player \(index + 1)")
        }
        if persistedNames.isEmpty {
            setupPlayers = fallbackNames
        } else {
            setupPlayers = persistedNames.enumerated().map { index, name in
                SetupPlayer(name: name, defaultName: "Player \(index + 1)")
            }
        }

        setupFinishRule = FinishRule(rawValue: storedNewGameFinishRuleRaw) ?? game.finishRule
        setupInRule = InRule(rawValue: storedNewGameInRuleRaw) ?? game.inRule
        setupStartScore = StartScoreOption(rawValue: storedNewGameStartScoreRaw) ?? (StartScoreOption(rawValue: game.startingScore) ?? .score501)
        setupSetModeEnabled = storedNewGameSetModeEnabled
        setupLegsToWin = max(1, storedNewGameLegsToWin)
        isShowingNewGameSetup = true
    }

    private func throwsToDisplay(for player: Player, at index: Int) -> [Int] {
        if index == game.activePlayerIndex {
            return game.currentTurn.darts.map(\.points)
        }
        return game.lastTurnThrows(for: player)
    }

    private func applySettings() {
        appThemeModeRaw = draftThemeMode.rawValue
    }

    private func persistNewGameSettings() {
        let names = setupPlayers.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let data = try? JSONEncoder().encode(names), let json = String(data: data, encoding: .utf8) {
            storedNewGamePlayerNamesJSON = json
        }
        storedNewGameFinishRuleRaw = setupFinishRule.rawValue
        storedNewGameInRuleRaw = setupInRule.rawValue
        storedNewGameStartScoreRaw = setupStartScore.rawValue
        storedNewGameSetModeEnabled = setupSetModeEnabled
        storedNewGameLegsToWin = max(1, setupLegsToWin)
    }

    private func persistedNewGamePlayerNames() -> [String] {
        guard let data = storedNewGamePlayerNamesJSON.data(using: .utf8),
              let names = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        let trimmed = names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(trimmed.prefix(5))
    }

}

private struct NewGameSetupView: View {
    @Binding var setupPlayers: [SetupPlayer]
    @Binding var finishRule: FinishRule
    @Binding var inRule: InRule
    @Binding var startScore: StartScoreOption
    @Binding var setModeEnabled: Bool
    @Binding var legsToWin: Int

    let onCancel: () -> Void
    let onStart: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Game Settings") {
                    Stepper("Players: \(setupPlayers.count)", value: playerCountBinding, in: 2...5)

                    Picker("Game", selection: $startScore) {
                        ForEach(StartScoreOption.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Finish Mode", selection: $finishRule) {
                        ForEach(FinishRule.allCases) { rule in
                            Text(rule.rawValue).tag(rule)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("In Mode", selection: $inRule) {
                        ForEach(InRule.allCases) { rule in
                            Text(rule.rawValue).tag(rule)
                        }
                    }
                    .pickerStyle(.menu)

                    Toggle("Set Mode", isOn: $setModeEnabled)
                    if setModeEnabled {
                        Stepper("Legs to Win: \(legsToWin)", value: $legsToWin, in: 1...10)
                    }
                }

                Section("Player Order") {
                    Text("Drag rows to set the throw sequence.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    List {
                        ForEach($setupPlayers) { $player in
                            HStack {
                                TextField(player.defaultName, text: $player.name)
                                    .textInputAutocapitalization(.words)
                                    .disableAutocorrection(true)
                            }
                        }
                        .onMove(perform: movePlayers)
                    }
                    .listStyle(.plain)
                    .frame(minHeight: 250)
                    .environment(\.editMode, .constant(.active))
                }
            }
            .navigationTitle("New Game")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .destructive, action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start", action: onStart)
                }
            }
        }
        .onAppear {
            if setupPlayers.isEmpty {
                setupPlayers = [
                    SetupPlayer(name: "Player 1", defaultName: "Player 1"),
                    SetupPlayer(name: "Player 2", defaultName: "Player 2")
                ]
            }
        }
    }

    private var playerCountBinding: Binding<Int> {
        Binding(
            get: { setupPlayers.count },
            set: { newValue in
                let clamped = min(max(2, newValue), 5)
                if clamped > setupPlayers.count {
                    let start = setupPlayers.count + 1
                    for index in start...clamped {
                        setupPlayers.append(SetupPlayer(name: "Player \(index)", defaultName: "Player \(index)"))
                    }
                } else if clamped < setupPlayers.count {
                    setupPlayers = Array(setupPlayers.prefix(clamped))
                }
            }
        )
    }

    private func movePlayers(from source: IndexSet, to destination: Int) {
        setupPlayers.move(fromOffsets: source, toOffset: destination)
    }
}

private struct SetupPlayer: Identifiable, Equatable {
    let id: UUID
    var name: String
    var defaultName: String

    init(id: UUID = UUID(), name: String, defaultName: String) {
        self.id = id
        self.name = name
        self.defaultName = defaultName
    }
}
