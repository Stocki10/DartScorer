import SwiftUI
import UIKit

private struct PresentedTournamentDetailTarget: Identifiable {
    let id: UUID
}

struct DartsGameView: View {
    @ObservedObject var game: DartsGame
    @ObservedObject var session: MultipeerSessionManager
    @ObservedObject var tournamentStore: TournamentStore
    @AppStorage("appThemeMode") private var appThemeModeRaw = AppThemeMode.light.rawValue
    @AppStorage("newGamePlayerNamesJSON") private var storedNewGamePlayerNamesJSON = ""
    @AppStorage("newGamePlayerProfileIDsJSON") private var storedPlayerProfileIDsJSON = ""
    @AppStorage("newGameMode") private var storedNewGameModeRaw = GameMode.x01.rawValue
    @AppStorage("newGamePracticeMode") private var storedNewGamePracticeModeRaw = PracticeMode.scoringDrill.rawValue
    @AppStorage("newGamePracticeCompetitiveEnabled") private var storedPracticeCompetitiveEnabled = false
    @AppStorage("newGamePracticeSuccessesToWin") private var storedPracticeSuccessesToWin = 5
    @AppStorage("newGameFinishRule") private var storedNewGameFinishRuleRaw = FinishRule.doubleOut.rawValue
    @AppStorage("newGameInRule") private var storedNewGameInRuleRaw = InRule.default.rawValue
    @AppStorage("newGameStartScore") private var storedNewGameStartScoreRaw = StartScoreOption.score501.rawValue
    @AppStorage("newGameSetModeEnabled") private var storedNewGameSetModeEnabled = false
    @AppStorage("newGameLegsToWin") private var storedNewGameLegsToWin = 3
    @AppStorage("appAccentRed") private var appAccentRed = AppAccentColor.defaultRed
    @AppStorage("appAccentGreen") private var appAccentGreen = AppAccentColor.defaultGreen
    @AppStorage("appAccentBlue") private var appAccentBlue = AppAccentColor.defaultBlue
    @AppStorage("scoreEntryMode") private var storedScoreEntryModeRaw = ScoreEntryMode.throwsMode.rawValue
    @AppStorage("defaultProfileID") private var defaultProfileID = ""
    @State private var selectedMultiplier: DartMultiplier = .single
    @State private var isShowingNewGameSetup = false
    @State private var setupPlayers: [SetupPlayer] = []
    @State private var setupGameMode: GameMode = .x01
    @State private var setupPracticeMode: PracticeMode = .scoringDrill
    @State private var setupPracticeCompetitiveEnabled = false
    @State private var setupPracticeSuccessesToWin = 5
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
    @State private var isShowingTournaments = false
    @State private var isShowingProfiles = false
    @State private var hasPersistedCompletedGame = false
    @State private var persistedCompletedRecord: GameRecord?
    @State private var activeTournamentMatchContext: TournamentMatchLaunchContext?
    @State private var presentedTournamentDetailTarget: PresentedTournamentDetailTarget?
    @State private var sharePayload: ShareSheetPayload?
    @State private var isPreparingShare = false
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
        game.gameMode != .cricket && (game.gameMode != .practice || game.practiceMode == .scoringDrill)
    }

    private var isVisitOpenInThrowsMode: Bool {
        game.currentTurn.dartsUsed > 0
    }

    private var currentScoreEntryMode: ScoreEntryMode {
        ScoreEntryMode(rawValue: storedScoreEntryModeRaw) ?? .throwsMode
    }

    private var connectedPlayerCount: Int {
        guard session.role != .none else { return 0 }
        return max(1, session.connectedPeers.count + 1)
    }

    private var activeTournament: Tournament? {
        activeTournamentMatchContext.flatMap { context in
            tournamentStore.tournament(id: context.tournamentID)
        }
    }

    private var activeTournamentMatch: TournamentMatch? {
        guard let activeTournamentMatchContext else { return nil }
        return tournamentStore.match(
            tournamentID: activeTournamentMatchContext.tournamentID,
            matchID: activeTournamentMatchContext.matchID
        )
    }

    private var currentTournamentID: UUID? {
        activeTournamentMatchContext?.tournamentID
    }

    private var winnerTitle: String {
        if let winner = game.winner {
            if let activeTournamentMatchContext {
                if activeTournamentMatchContext.tournamentFormat == .singleElimination {
                    return "\(winner.name) advances"
                }
                return "\(winner.name) wins the match"
            }
            return L10n.format("%@ Wins", winner.name)
        }
        return L10n.string("Winner")
    }

    private var winningSubtitle: String {
        if let activeTournamentMatchContext {
            let matchNumber = activeTournamentMatch.map { "Match \($0.slotIndex + 1)" }
            return [activeTournamentMatchContext.roundTitle, matchNumber]
                .compactMap { $0 }
                .joined(separator: " • ")
        }
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
            return game.gameMode == .practice ? nil : statusMessage
        }
    }

    private var practiceObjectiveMessage: String? {
        guard game.gameMode == .practice else { return nil }
        guard let statusMessage = game.statusMessage, statusMessage != "Practice mode" else { return nil }
        return statusMessage
    }

    private var currentMatchShareSummary: MatchShareSummary? {
        guard game.winner != nil else { return nil }
        return winnerShareSummary(for: persistedCompletedRecord ?? buildCurrentGameRecord())
    }

    private var currentGameRecordTournamentContext: GameRecordTournamentContext? {
        guard let activeTournamentMatchContext else { return nil }
        return GameRecordTournamentContext(
            tournamentID: activeTournamentMatchContext.tournamentID,
            tournamentName: activeTournamentMatchContext.tournamentName,
            tournamentMatchID: activeTournamentMatchContext.matchID,
            tournamentFormat: activeTournamentMatchContext.tournamentFormat,
            roundTitle: activeTournamentMatchContext.roundTitle
        )
    }

    private var tournamentPrimaryActionTitle: String? {
        guard let activeTournamentMatchContext else { return nil }
        if activeTournamentMatchContext.tournamentFormat == .singleElimination {
            return activeTournamentMatchContext.roundTitle == activeTournament?.rounds.last?.title
                ? "Finish Tournament"
                : "Next Match"
        }
        return "Back to Tournament"
    }

    private var hasUpcomingTournamentMatch: Bool {
        guard let activeTournamentMatchContext else { return false }
        return tournamentStore.nextReadyMatchContext(
            tournamentID: activeTournamentMatchContext.tournamentID,
            after: activeTournamentMatchContext.matchID
        ) != nil
    }

    private var disconnectedPeerAlertBinding: Binding<Bool> {
        Binding(
            get: { disconnectedPeerName != nil },
            set: { if !$0 { disconnectedPeerName = nil } }
        )
    }

    private var disconnectedPeerAlertMessage: String {
        guard let name = disconnectedPeerName else { return "" }
        return session.isActive
            ? "\(name) has left the session."
            : "\(name) left — multiplayer session ended."
    }

    private var canShowStandaloneWinnerActions: Bool {
        session.role != .joiner && activeTournamentMatchContext == nil
    }

    private var winnerOverlayCanUndoLocally: Bool {
        !session.isActive || session.canUndoLocally
    }

    private var winnerOverlayPrimaryTitle: String? {
        session.role == .joiner ? nil : tournamentPrimaryActionTitle
    }

    private var winnerOverlaySecondaryTitle: String? {
        guard session.role != .joiner,
              let activeTournamentMatchContext,
              activeTournamentMatchContext.tournamentFormat == .singleElimination else {
            return nil
        }
        return "View Tournament"
    }

    private var winnerOverlayNewLegAction: (() -> Void)? {
        guard canShowStandaloneWinnerActions else { return nil }
        return {
            persistCompletedGameIfNeeded()
            game.restartLegRandomSequence()
            session.handleNewLeg()
        }
    }

    private var winnerOverlayNewGameAction: (() -> Void)? {
        guard canShowStandaloneWinnerActions else { return nil }
        return {
            presentNewGameSetup()
        }
    }

    private var winnerOverlayPrimaryAction: (() -> Void)? {
        guard session.role != .joiner, activeTournamentMatchContext != nil else { return nil }
        return advanceTournamentFlow
    }

    private var winnerOverlaySecondaryAction: (() -> Void)? {
        guard session.role != .joiner, let tournamentID = currentTournamentID else { return nil }
        return {
            _ = persistCompletedGameIfNeeded()
            clearActiveTournamentMatchIfNeeded(resetUnfinished: false)
            presentTournamentDetail(tournamentID)
        }
    }

    private var mainContent: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                GameControlBar(
                    sessionRole: session.role,
                    connectedPlayerCount: connectedPlayerCount,
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
                    onShowTournaments: { isShowingTournaments = true },
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
                } else if let practiceObjectiveMessage {
                    PracticeObjectiveBadgeView(message: practiceObjectiveMessage)
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
                                .opacity(currentScoreEntryMode == .throwsMode ? 1 : 0)
                                .allowsHitTesting(currentScoreEntryMode == .throwsMode)

                            QuickScorePadView(
                                isInputLocked: isInputLocked,
                                hasWinner: game.winner != nil,
                                isVisitOpenInThrowsMode: isVisitOpenInThrowsMode,
                                onQuickScoreTap: submitQuickScore,
                                onNoScoreTap: submitNoScoreTurn
                            )
                            .opacity(currentScoreEntryMode == .quick ? 1 : 0)
                            .allowsHitTesting(currentScoreEntryMode == .quick)
                        }
                    } else {
                        throwsInputPanel
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }

            winnerOverlay
            reconnectOverlay
            hostPreparingOverlay
            settingsOverlay
        }
    }

    private var presentedContent: some View {
        mainContent
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $isShowingNewGameSetup) {
            NewGameSetupView(
                setupPlayers: $setupPlayers,
                gameMode: $setupGameMode,
                practiceMode: $setupPracticeMode,
                practiceCompetitiveEnabled: $setupPracticeCompetitiveEnabled,
                practiceSuccessesToWin: $setupPracticeSuccessesToWin,
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
        .sheet(isPresented: $isShowingHistory) {
            GameHistoryView(store: historyStore)
        }
        .sheet(isPresented: $isShowingTournaments) {
            TournamentListView(
                store: tournamentStore,
                profileStore: profileStore,
                historyStore: historyStore,
                onPlayMatch: startTournamentMatch
            )
        }
        .sheet(item: $presentedTournamentDetailTarget) { target in
            NavigationStack {
                TournamentDetailView(
                    store: tournamentStore,
                    historyStore: historyStore,
                    tournamentID: target.id,
                    onPlayMatch: startTournamentMatch
                )
            }
        }
        .sheet(isPresented: $isShowingProfiles) {
            PlayerProfileView(store: profileStore, historyStore: historyStore)
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: payload.items) {
                sharePayload = nil
            }
        }
    }

    private var observedContent: some View {
        presentedContent
        .onChange(of: isShowingNewGameSetup) { _, isShowing in
            guard session.role == .host, session.isActive else { return }
            session.setHostPreparingNewGame(isShowing)
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
                persistedCompletedRecord = nil
            }
        }
        .onChange(of: game.gameMode) { _, mode in
            if mode == .cricket {
                storedScoreEntryModeRaw = ScoreEntryMode.throwsMode.rawValue
            }
        }
        .alert("Player Disconnected", isPresented: disconnectedPeerAlertBinding) {
            Button("OK") { disconnectedPeerName = nil }
        } message: {
            Text(disconnectedPeerAlertMessage)
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

    var body: some View {
        observedContent
    }

    @ViewBuilder
    private var winnerOverlay: some View {
        if let winner = game.winner {
            WinnerOverlayView(
                winnerName: winner.name,
                title: winnerTitle,
                subtitle: winningSubtitle,
                summary: currentMatchShareSummary,
                isPreparingShare: isPreparingShare,
                showNewLeg: activeTournamentMatchContext == nil && game.setWinner == nil,
                canUndo: game.canUndo,
                canUndoLocally: winnerOverlayCanUndoLocally,
                onNewLegRandom: winnerOverlayNewLegAction,
                onNewGame: winnerOverlayNewGameAction,
                primaryActionTitle: winnerOverlayPrimaryTitle,
                onPrimaryAction: winnerOverlayPrimaryAction,
                secondaryActionTitle: winnerOverlaySecondaryTitle,
                onSecondaryAction: winnerOverlaySecondaryAction,
                onShareSummary: shareCurrentMatchSummary,
                onUndo: undoLastThrow
            )
        }
    }

    @ViewBuilder
    private var reconnectOverlay: some View {
        if session.isReconnecting {
            ReconnectBannerView {
                session.endSession()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var hostPreparingOverlay: some View {
        if session.role == .joiner && session.hostIsPreparingNewGame {
            HostPreparingNewGameBannerView()
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var settingsOverlay: some View {
        if isShowingThemeSettings {
            SettingsPopupView(
                themeMode: $draftThemeMode,
                accentColor: $draftAccentColor
            ) {
                applySettings()
            } onClose: {
                isShowingThemeSettings = false
            }
            .transition(.opacity)
            .zIndex(20)
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
        clearActiveTournamentMatchIfNeeded(resetUnfinished: true)
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
            practiceMode: setupPracticeMode,
            practiceCompetitiveEnabled: setupPracticeCompetitiveEnabled,
            practiceSuccessesToWin: setupPracticeSuccessesToWin,
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
        clearActiveTournamentMatchIfNeeded(resetUnfinished: true)
        let persistedNames = persistedNewGamePlayerNames()
        let storedDefaultProfileID = UUID(uuidString: defaultProfileID)
        let defaultProfile = storedDefaultProfileID.flatMap { id in
            profileStore.profiles.first { $0.id == id }
        }
        let fallbackNames = game.players.enumerated().map { index, player in
            SetupPlayer(
                name: defaultName(for: player, index: index, defaultProfile: defaultProfile),
                defaultName: "Player \(index + 1)",
                colorHex: defaultColorHex(for: player, index: index, defaultProfile: defaultProfile),
                profileID: defaultProfileID(for: player, index: index, defaultProfile: defaultProfile)
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
        setupPracticeMode = PracticeMode(rawValue: storedNewGamePracticeModeRaw) ?? game.practiceMode
        setupPracticeCompetitiveEnabled = storedPracticeCompetitiveEnabled
        setupPracticeSuccessesToWin = max(1, storedPracticeSuccessesToWin)
        setupInRule = InRule(rawValue: storedNewGameInRuleRaw) ?? game.inRule
        setupStartScore = StartScoreOption(rawValue: storedNewGameStartScoreRaw)
            ?? (StartScoreOption(rawValue: game.startingScore) ?? .score501)
        setupSetModeEnabled = storedNewGameSetModeEnabled
        setupLegsToWin = max(1, storedNewGameLegsToWin)
        isShowingNewGameSetup = true
    }

    private func startTournamentMatch(_ context: TournamentMatchLaunchContext) {
        persistCompletedGameIfNeeded()
        clearActiveTournamentMatchIfNeeded(resetUnfinished: true)

        activeTournamentMatchContext = context
        persistedCompletedRecord = nil
        hasPersistedCompletedGame = false
        isShowingNewGameSetup = false
        isShowingTournaments = false
        presentedTournamentDetailTarget = nil

        let tournamentPlayers = context.participants.map { participant in
            Player(
                id: participant.profileID,
                name: participant.name,
                score: context.rules.gameMode == .x01 ? context.rules.startingScore.rawValue : 0,
                colorHex: participant.colorHex,
                profileID: participant.profileID
            )
        }

        game.newGame(
            players: tournamentPlayers,
            gameMode: context.rules.gameMode,
            practiceMode: .scoringDrill,
            practiceCompetitiveEnabled: false,
            practiceSuccessesToWin: 1,
            finishRule: context.rules.finishRule,
            inRule: context.rules.inRule,
            startingScore: context.rules.gameMode == .x01 ? context.rules.startingScore.rawValue : 0,
            setModeEnabled: context.rules.gameMode == .x01 ? context.rules.setModeEnabled : false,
            legsToWin: context.rules.legsToWin
        )
        tournamentStore.markMatchInProgress(tournamentID: context.tournamentID, matchID: context.matchID)
    }

    private func advanceTournamentFlow() {
        guard let activeTournamentMatchContext else { return }
        _ = persistCompletedGameIfNeeded()

        if activeTournamentMatchContext.tournamentFormat == .roundRobin {
            clearActiveTournamentMatchIfNeeded(resetUnfinished: false)
            presentTournamentDetail(activeTournamentMatchContext.tournamentID)
            return
        }

        if let nextContext = tournamentStore.nextReadyMatchContext(
            tournamentID: activeTournamentMatchContext.tournamentID,
            after: activeTournamentMatchContext.matchID
        ) {
            startTournamentMatch(nextContext)
        } else {
            clearActiveTournamentMatchIfNeeded(resetUnfinished: false)
            presentTournamentDetail(activeTournamentMatchContext.tournamentID)
        }
    }

    private func presentTournamentDetail(_ tournamentID: UUID) {
        isShowingTournaments = false
        presentedTournamentDetailTarget = PresentedTournamentDetailTarget(id: tournamentID)
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

    @discardableResult
    private func persistCompletedGameIfNeeded() -> GameRecord? {
        guard game.winner != nil, !hasPersistedCompletedGame else { return nil }
        let record = buildCurrentGameRecord()
        historyStore.record(record)
        profileStore.updateStatsFromGameRecord(record)
        if let activeTournamentMatchContext {
            tournamentStore.completeMatch(
                tournamentID: activeTournamentMatchContext.tournamentID,
                matchID: activeTournamentMatchContext.matchID,
                record: record
            )
        }
        if session.role == .host {
            session.broadcastStatsUpdate()
        }
        persistedCompletedRecord = record
        hasPersistedCompletedGame = true
        return record
    }

    private func applySettings() {
        appThemeModeRaw = draftThemeMode.rawValue
        let components = AppAccentColor.components(from: draftAccentColor)
        appAccentRed = components.red
        appAccentGreen = components.green
        appAccentBlue = components.blue
    }

    private func shareCurrentMatchSummary() {
        guard !isPreparingShare else { return }
        let record = persistCompletedGameIfNeeded() ?? persistedCompletedRecord ?? buildCurrentGameRecord()
        let summary = winnerShareSummary(for: record)
        isPreparingShare = true

        Task { @MainActor in
            await Task.yield()
            let items = MatchShareRenderer.shareItems(for: summary)
            sharePayload = ShareSheetPayload(items: items)
            isPreparingShare = false
        }
    }

    private func winnerShareSummary(for record: GameRecord) -> MatchShareSummary {
        let playerColors = Dictionary(uniqueKeysWithValues: game.players.map { ($0.id, $0.colorHex) })
        if let latestLeg = record.legs.last {
            return MatchShareSummary(record: record, leg: latestLeg, playerColors: playerColors)
        }
        return MatchShareSummary(record: record, playerColors: playerColors)
    }

    private func buildCurrentGameRecord() -> GameRecord {
        let recordID = persistedCompletedRecord?.id ?? UUID()
        let recordDate = persistedCompletedRecord?.date ?? Date()
        return game.buildGameRecord(
            id: recordID,
            date: recordDate,
            tournamentContext: currentGameRecordTournamentContext
        )
    }

    private func clearActiveTournamentMatchIfNeeded(resetUnfinished: Bool) {
        guard let activeTournamentMatchContext else { return }
        if resetUnfinished && !hasPersistedCompletedGame {
            tournamentStore.resetMatchToReady(
                tournamentID: activeTournamentMatchContext.tournamentID,
                matchID: activeTournamentMatchContext.matchID
            )
        }
        self.activeTournamentMatchContext = nil
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
        storedNewGamePracticeModeRaw = setupPracticeMode.rawValue
        storedPracticeCompetitiveEnabled = setupPracticeCompetitiveEnabled
        storedPracticeSuccessesToWin = max(1, setupPracticeSuccessesToWin)
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

    private func defaultName(for player: Player, index: Int, defaultProfile: PlayerProfile?) -> String {
        if index == 0, let defaultProfile {
            return defaultProfile.name
        }
        return player.name
    }

    private func defaultColorHex(for player: Player, index: Int, defaultProfile: PlayerProfile?) -> String? {
        if index == 0, let defaultProfile {
            return defaultProfile.colorHex
        }
        return player.colorHex
    }

    private func defaultProfileID(for player: Player, index: Int, defaultProfile: PlayerProfile?) -> UUID? {
        if index == 0, let defaultProfile {
            return defaultProfile.id
        }
        return player.profileID
    }
}
