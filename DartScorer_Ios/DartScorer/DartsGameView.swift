import SwiftUI
import UIKit

struct DartsGameView: View {
    @ObservedObject var game: DartsGame
    @ObservedObject var session: MultipeerSessionManager
    @AppStorage("appThemeMode") private var appThemeModeRaw = AppThemeMode.light.rawValue
    @AppStorage("newGamePlayerNamesJSON") private var storedNewGamePlayerNamesJSON = ""
    @AppStorage("newGamePlayerProfileIDsJSON") private var storedPlayerProfileIDsJSON = ""
    @AppStorage("newGameMode") private var storedNewGameModeRaw = GameMode.x01.rawValue
    @AppStorage("newGameFinishRule") private var storedNewGameFinishRuleRaw = FinishRule.doubleOut.rawValue
    @AppStorage("newGameInRule") private var storedNewGameInRuleRaw = InRule.default.rawValue
    @AppStorage("newGameStartScore") private var storedNewGameStartScoreRaw = StartScoreOption.score501.rawValue
    @AppStorage("newGameSetModeEnabled") private var storedNewGameSetModeEnabled = false
    @AppStorage("newGameLegsToWin") private var storedNewGameLegsToWin = 3
    @AppStorage("appAccentRed") private var appAccentRed = AppAccentColor.defaultRed
    @AppStorage("appAccentGreen") private var appAccentGreen = AppAccentColor.defaultGreen
    @AppStorage("appAccentBlue") private var appAccentBlue = AppAccentColor.defaultBlue
    @AppStorage("scoreEntryMode") private var storedScoreEntryModeRaw = ScoreEntryMode.throwsMode.rawValue
    @State private var selectedMultiplier: DartMultiplier = .single
    @State private var isShowingNewGameSetup = false
    @State private var setupPlayers: [SetupPlayer] = []
    @State private var setupGameMode: GameMode = .x01
    @State private var setupFinishRule: FinishRule = .doubleOut
    @State private var setupInRule: InRule = .default
    @State private var setupStartScore: StartScoreOption = .score501
    @State private var setupSetModeEnabled = false
    @State private var setupLegsToWin = 3
    @State private var isShowingRestartAlert = false
    @State private var isShowingDisconnectAlert = false
    @State private var disconnectedPeerName: String?
    @State private var hasPresentedInitialSetup = false
    @State private var isShowingThemeSettings = false
    @State private var isShowingHistory = false
    @State private var isShowingProfiles = false
    @State private var hasPersistedCompletedGame = false
    @StateObject private var historyStore = GameHistoryStore()
    @ObservedObject var profileStore: PlayerProfileStore
    @State private var draftThemeMode: AppThemeMode = .light
    @State private var draftAccentColor: Color = AppAccentColor.makeColor(
        red: AppAccentColor.defaultRed,
        green: AppAccentColor.defaultGreen,
        blue: AppAccentColor.defaultBlue
    )

    private var isInputLocked: Bool { session.isInputLocked }

    private var scoreEntryMode: Binding<ScoreEntryMode> {
        Binding(
            get: { ScoreEntryMode(rawValue: storedScoreEntryModeRaw) ?? .throwsMode },
            set: { storedScoreEntryModeRaw = $0.rawValue }
        )
    }

    private var canUseQuickScoreMode: Bool {
        game.gameMode != .cricket
    }

    private var isVisitOpenInThrowsMode: Bool {
        game.currentTurn.dartsUsed > 0
    }

    private var winnerTitle: String {
        game.gameMode == .x01
            ? (game.setWinner == nil ? L10n.string("Leg Won") : L10n.string("Winner"))
            : L10n.string("Winner")
    }

    private var winningSubtitle: String {
        if game.gameMode == .practice {
            return L10n.string("Practice session.")
        }
        if game.gameMode == .cricket {
            return L10n.string("Closed all targets and finished ahead.")
        }
        if game.setWinner != nil {
            return L10n.string("Match complete.")
        }
        let outText = game.finishRule == .doubleOut ? L10n.string("double-out") : L10n.string("single-out")
        let inText = game.inRule == .doubleIn ? L10n.string("double-in") : L10n.string("default-in")
        return L10n.format("Played %@, %@.", inText, outText)
    }

    private var visibleStatusMessage: String? {
        guard let statusMessage = game.statusMessage else { return nil }
        switch statusMessage {
        case "Practice mode", "Close all numbers and finish level or ahead.":
            return nil
        default:
            return statusMessage
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                GameControlBar(
                    sessionRole: session.role,
                    isLegInProgress: game.isLegInProgress,
                    canUndo: game.canUndo,
                    canUndoLocally: session.canUndoLocally,
                    onNewGame: presentNewGameSetup,
                    onRestartLeg: {
                        if game.isLegInProgress {
                            isShowingRestartAlert = true
                        } else {
                            restartLeg()
                        }
                    },
                    onShowDisconnectAlert: { isShowingDisconnectAlert = true },
                    onShowProfiles: { isShowingProfiles = true },
                    onShowHistory: { isShowingHistory = true },
                    onShowSettings: showThemeSettings,
                    onUndo: undoLastThrow
                )
                .padding(.horizontal)

                Group {
                    if game.gameMode == .cricket {
                        CricketBoardSection(
                            players: game.players,
                            activePlayerIndex: game.activePlayerIndex,
                            targets: game.cricketTargets,
                            marks: game.cricketMarks(for:target:),
                            score: game.cricketScore(for:),
                            throwsToDisplay: throwsToDisplay(for:at:)
                        )
                    } else {
                        ScoreboardSection(
                            players: game.players,
                            activePlayerIndex: game.activePlayerIndex,
                            setModeEnabled: game.setModeEnabled,
                            legsWon: game.legsWon(for:),
                            throwsToDisplay: throwsToDisplay(for:at:),
                            legAverage: game.legAverage(for:)
                        )
                    }
                }
                .padding(.horizontal)

                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 16) {
                    if let statusMessage = visibleStatusMessage {
                        Text(statusMessage)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                Spacer(minLength: 0)

                if game.gameMode == .x01 {
                    CheckoutBadgeView(
                        routes: game.bestPossibleFinishLines,
                        isBogey: game.isCurrentScoreBogey
                    )
                    .padding(.horizontal)
                }

                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    if canUseQuickScoreMode {
                        ScoreEntryModePicker(selection: scoreEntryMode)
                    }

                    if canUseQuickScoreMode {
                        ZStack(alignment: .top) {
                            throwsInputPanel
                                .opacity((ScoreEntryMode(rawValue: storedScoreEntryModeRaw) ?? .throwsMode) == .throwsMode ? 1 : 0)
                                .allowsHitTesting((ScoreEntryMode(rawValue: storedScoreEntryModeRaw) ?? .throwsMode) == .throwsMode)

                            QuickScorePadView(
                                isInputLocked: isInputLocked,
                                hasWinner: game.winner != nil,
                                isVisitOpenInThrowsMode: isVisitOpenInThrowsMode,
                                onQuickScoreTap: submitQuickScore,
                                onNoScoreTap: submitNoScoreTurn
                            )
                            .opacity((ScoreEntryMode(rawValue: storedScoreEntryModeRaw) ?? .throwsMode) == .quick ? 1 : 0)
                            .allowsHitTesting((ScoreEntryMode(rawValue: storedScoreEntryModeRaw) ?? .throwsMode) == .quick)
                        }
                    } else {
                        throwsInputPanel
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }

            if let winner = game.winner {
                WinnerOverlayView(
                    winnerName: winner.name,
                    title: winnerTitle,
                    subtitle: winningSubtitle,
                    showNewLeg: game.setWinner == nil,
                    canUndo: game.canUndo,
                    canUndoLocally: !session.isActive || session.canUndoLocally,
                    onNewLegRandom: session.role == .joiner ? nil : {
                        persistCompletedGameIfNeeded()
                        game.restartLegRandomSequence()
                        session.handleNewLeg()
                    },
                    onNewGame: session.role == .joiner ? nil : {
                        presentNewGameSetup()
                    },
                    onUndo: undoLastThrow
                )
            }

            if session.isReconnecting {
                ReconnectBannerView {
                    session.endSession()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $isShowingNewGameSetup) {
            NewGameSetupView(
                setupPlayers: $setupPlayers,
                gameMode: $setupGameMode,
                finishRule: $setupFinishRule,
                inRule: $setupInRule,
                startScore: $setupStartScore,
                setModeEnabled: $setupSetModeEnabled,
                legsToWin: $setupLegsToWin,
                profileStore: profileStore,
                session: session,
                onCancel: { isShowingNewGameSetup = false },
                onStart: startNewGame
            )
        }
        .fullScreenCover(isPresented: $isShowingThemeSettings) {
            SettingsPopupView(
                themeMode: $draftThemeMode,
                accentColor: $draftAccentColor
            ) {
                applySettings()
            }
            .presentationBackground(.clear)
        }
        .sheet(isPresented: $isShowingHistory) {
            GameHistoryView(store: historyStore)
        }
        .sheet(isPresented: $isShowingProfiles) {
            PlayerProfileView(store: profileStore)
        }
        .onChange(of: session.gameHasStarted) { _, started in
            guard started && session.role == .joiner else { return }
            isShowingNewGameSetup = false
        }
        .onChange(of: session.lastDisconnectedPeerName) { _, name in
            guard let name else { return }
            disconnectedPeerName = name
        }
        .onChange(of: game.winner?.id) { _, winnerID in
            if winnerID == nil {
                hasPersistedCompletedGame = false
            }
        }
        .onChange(of: game.gameMode) { _, mode in
            if mode == .cricket {
                storedScoreEntryModeRaw = ScoreEntryMode.throwsMode.rawValue
            }
        }
        .alert("Player Disconnected", isPresented: Binding(
            get: { disconnectedPeerName != nil },
            set: { if !$0 { disconnectedPeerName = nil } }
        )) {
            Button("OK") { disconnectedPeerName = nil }
        } message: {
            if let name = disconnectedPeerName {
                Text(session.isActive
                     ? "\(name) has left the session."
                     : "\(name) left — multiplayer session ended.")
            }
        }
        .onAppear {
            guard !hasPresentedInitialSetup else { return }
            hasPresentedInitialSetup = true
            presentNewGameSetup()
        }
        .alert("Restart Leg?", isPresented: $isShowingRestartAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Restart Leg", role: .destructive) {
                restartLeg()
            }
        } message: {
            Text("You already started this leg. This will discard current progress.")
        }
        .alert("Leave Local Multiplayer Session?", isPresented: $isShowingDisconnectAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Leave Session", role: .destructive) {
                session.endSession()
            }
        } message: {
            Text(session.role == .host
                ? "This will end the session for all connected devices."
                : "You will be disconnected from the host's game.")
        }
    }

    private func showThemeSettings() {
        draftThemeMode = AppThemeMode(rawValue: appThemeModeRaw) ?? .light
        draftAccentColor = AppAccentColor.makeColor(
            red: appAccentRed,
            green: appAccentGreen,
            blue: appAccentBlue
        )
        isShowingThemeSettings = true
    }

    private func startNewGame() {
        persistNewGameSettings()
        let playerObjects = setupPlayers.map { player in
            Player(
                id: player.profileID ?? player.id,
                name: player.name,
                score: setupStartScore.rawValue,
                colorHex: player.colorHex,
                profileID: player.profileID
            )
        }
        game.newGame(
            players: playerObjects,
            gameMode: setupGameMode,
            finishRule: setupFinishRule,
            inRule: setupInRule,
            startingScore: setupGameMode == .practice ? 0 : setupStartScore.rawValue,
            setModeEnabled: setupGameMode == .x01 ? setupSetModeEnabled : false,
            legsToWin: setupLegsToWin
        )
        if session.role == .host {
            session.handleNewLeg()
            session.broadcastGameStarted()
        }
        isShowingNewGameSetup = false
    }

    private func undoLastThrow() {
        if session.isActive {
            session.handleUndo()
        } else {
            game.undoLastThrow()
        }
    }

    private func submitThrowAndReset(_ segment: DartSegment, multiplier: DartMultiplier) {
        if game.gameMode == .practice {
            if session.isActive {
                session.handleThrow(segment: segment, multiplier: multiplier)
            } else {
                game.submitThrow(segment: segment, multiplier: multiplier)
            }
            selectedMultiplier = .single
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }

        let previousScore = game.activePlayer.score
        if session.isActive {
            session.handleThrow(segment: segment, multiplier: multiplier)
        } else {
            game.submitThrow(segment: segment, multiplier: multiplier)
        }
        selectedMultiplier = .single

        if let status = game.statusMessage {
            if status.contains("wins") {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else if previousScore < game.activePlayer.score && game.activePlayer.score > 0 {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        } else if game.activePlayer.score == 0 {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func submitNoScoreTurn() {
        let remaining = game.currentTurn.dartsRemaining
        guard remaining > 0 else { return }
        if session.isActive {
            for _ in 0..<remaining {
                session.handleThrow(segment: .number(0), multiplier: .single)
            }
        } else {
            for _ in 0..<remaining {
                game.submitThrow(segment: .number(0), multiplier: .single)
            }
        }
        selectedMultiplier = .single
    }

    private func submitQuickScore(_ score: Int) {
        guard !isVisitOpenInThrowsMode else { return }
        let previousScore = game.activePlayer.score
        if session.isActive {
            session.handleQuickScore(score)
        } else {
            game.submitQuickScore(score)
        }
        if let status = game.statusMessage {
            if status.contains("wins") {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else if previousScore < game.activePlayer.score && game.activePlayer.score > 0 {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            } else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } else if game.activePlayer.score == 0 {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    @ViewBuilder
    private var throwsInputPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            MultiplierPickerView(selection: $selectedMultiplier)
            NumberPadView(
                selectedMultiplier: selectedMultiplier,
                isInputLocked: isInputLocked,
                hasWinner: game.winner != nil,
                onNumberTap: { value in
                    submitThrowAndReset(.number(value), multiplier: selectedMultiplier)
                },
                onBullTap: {
                    submitThrowAndReset(.bull, multiplier: selectedMultiplier)
                },
                onZeroTap: {
                    submitThrowAndReset(.number(0), multiplier: .single)
                },
                onNoScoreTap: submitNoScoreTurn
            )
        }
    }

    private func presentNewGameSetup() {
        persistCompletedGameIfNeeded()
        let persistedNames = persistedNewGamePlayerNames()
        let fallbackNames = game.players.enumerated().map { index, player in
            SetupPlayer(
                name: player.name,
                defaultName: "Player \(index + 1)",
                colorHex: player.colorHex,
                profileID: player.profileID
            )
        }
        if persistedNames.isEmpty {
            setupPlayers = fallbackNames
        } else {
            let persistedProfileIDs = persistedNewGamePlayerProfileIDs()
            setupPlayers = persistedNames.enumerated().map { index, name in
                let profileID = persistedProfileIDs.indices.contains(index) ? persistedProfileIDs[index] : nil
                let profile = profileID.flatMap { id in profileStore.profiles.first { $0.id == id } }
                return SetupPlayer(
                    name: name,
                    defaultName: "Player \(index + 1)",
                    colorHex: profile?.colorHex,
                    profileID: profile?.id
                )
            }
        }

        setupFinishRule = FinishRule(rawValue: storedNewGameFinishRuleRaw) ?? game.finishRule
        setupGameMode = GameMode(rawValue: storedNewGameModeRaw) ?? game.gameMode
        setupInRule = InRule(rawValue: storedNewGameInRuleRaw) ?? game.inRule
        setupStartScore = StartScoreOption(rawValue: storedNewGameStartScoreRaw)
            ?? (StartScoreOption(rawValue: game.startingScore) ?? .score501)
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

    private func restartLeg() {
        if session.isActive {
            session.handleRestartLeg()
        } else {
            game.restartLeg()
        }
    }

    private func persistCompletedGameIfNeeded() {
        guard game.winner != nil, !hasPersistedCompletedGame else { return }
        let record = game.buildGameRecord()
        historyStore.record(record)
        profileStore.updateStatsFromGameRecord(record)
        if session.role == .host {
            session.broadcastStatsUpdate()
        }
        hasPersistedCompletedGame = true
    }

    private func applySettings() {
        appThemeModeRaw = draftThemeMode.rawValue
        let components = AppAccentColor.components(from: draftAccentColor)
        appAccentRed = components.red
        appAccentGreen = components.green
        appAccentBlue = components.blue
    }

    private func persistNewGameSettings() {
        let names = setupPlayers.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let data = try? JSONEncoder().encode(names), let json = String(data: data, encoding: .utf8) {
            storedNewGamePlayerNamesJSON = json
        }
        let profileIDs = setupPlayers.map { $0.profileID?.uuidString ?? "" }
        if let data = try? JSONEncoder().encode(profileIDs), let json = String(data: data, encoding: .utf8) {
            storedPlayerProfileIDsJSON = json
        }
        storedNewGameFinishRuleRaw = setupFinishRule.rawValue
        storedNewGameModeRaw = setupGameMode.rawValue
        storedNewGameInRuleRaw = setupInRule.rawValue
        storedNewGameStartScoreRaw = setupStartScore.rawValue
        storedNewGameSetModeEnabled = setupSetModeEnabled
        storedNewGameLegsToWin = max(1, setupLegsToWin)
    }

    private func persistedNewGamePlayerProfileIDs() -> [UUID?] {
        guard let data = storedPlayerProfileIDsJSON.data(using: .utf8),
              let ids = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return ids.map { UUID(uuidString: $0) }
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
