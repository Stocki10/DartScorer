import SwiftUI
import UIKit

struct DartsGameView: View {
    @ObservedObject var game: DartsGame
    @ObservedObject var session: MultipeerSessionManager
    @AppStorage("appThemeMode") private var appThemeModeRaw = AppThemeMode.light.rawValue
    @AppStorage("newGamePlayerNamesJSON") private var storedNewGamePlayerNamesJSON = ""
    @AppStorage("newGamePlayerProfileIDsJSON") private var storedPlayerProfileIDsJSON = ""
    @AppStorage("newGameFinishRule") private var storedNewGameFinishRuleRaw = FinishRule.doubleOut.rawValue
    @AppStorage("newGameInRule") private var storedNewGameInRuleRaw = InRule.default.rawValue
    @AppStorage("newGameStartScore") private var storedNewGameStartScoreRaw = StartScoreOption.score501.rawValue
    @AppStorage("newGameSetModeEnabled") private var storedNewGameSetModeEnabled = false
    @AppStorage("newGameLegsToWin") private var storedNewGameLegsToWin = 3
    @AppStorage("appAccentRed") private var appAccentRed = AppAccentColor.defaultRed
    @AppStorage("appAccentGreen") private var appAccentGreen = AppAccentColor.defaultGreen
    @AppStorage("appAccentBlue") private var appAccentBlue = AppAccentColor.defaultBlue
    @State private var selectedMultiplier: DartMultiplier = .single
    @State private var isShowingNewGameSetup = false
    @State private var setupPlayers: [SetupPlayer] = []
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
    @StateObject private var historyStore = GameHistoryStore()
    @ObservedObject var profileStore: PlayerProfileStore
    @State private var draftThemeMode: AppThemeMode = .light
    @State private var draftAccentColor: Color = AppAccentColor.makeColor(
        red: AppAccentColor.defaultRed,
        green: AppAccentColor.defaultGreen,
        blue: AppAccentColor.defaultBlue
    )

    private let numberColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    private var isInputLocked: Bool { session.isInputLocked }

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

                checkoutBadge
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

            if session.isReconnecting {
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

                    Button("Abort Connection") {
                        session.endSession()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .padding(.bottom, 24)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
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
                profileStore: profileStore,
                session: session,
                onCancel: { isShowingNewGameSetup = false },
                onStart: {
                    persistNewGameSettings()
                    let playerObjects = setupPlayers.map { sp in
                        Player(
                            id: sp.profileID ?? sp.id,
                            name: sp.name,
                            score: setupStartScore.rawValue,
                            colorHex: sp.colorHex,
                            profileID: sp.profileID
                        )
                    }
                    game.newGame(
                        players: playerObjects,
                        finishRule: setupFinishRule,
                        inRule: setupInRule,
                        startingScore: setupStartScore.rawValue,
                        setModeEnabled: setupSetModeEnabled,
                        legsToWin: setupLegsToWin
                    )
                    if session.role == .host {
                        session.handleNewLeg()
                        session.broadcastGameStarted()
                    }
                    isShowingNewGameSetup = false
                }
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
                game.restartLeg()
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
                            .background(player.colorHex.flatMap { Color(hex: $0) } ?? Color.accentColor)
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
                .background {
                    let playerColor = player.colorHex.flatMap { Color(hex: $0) } ?? Color.accentColor
                    return index == game.activePlayerIndex ? playerColor.opacity(0.18) : Color(.secondarySystemBackground)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }   

    private var controlBar: some View {
        HStack(spacing: 8) {
            Button {
                presentNewGameSetup()
            } label: {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.bordered)
            .disabled(session.isActive && game.isLegInProgress)

            Button {
                if game.isLegInProgress {
                    isShowingRestartAlert = true
                } else {
                    game.restartLeg()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(!game.isLegInProgress)

            Spacer(minLength: 0)

            if session.role == .host {
                Button {
                    isShowingDisconnectAlert = true
                } label: {
                    Image(systemName: "wifi.slash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else if session.role == .joiner {
                Button {
                    isShowingDisconnectAlert = true
                } label: {
                    Image(systemName: "person.fill.xmark")
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }

            Button {
                isShowingProfiles = true
            } label: {
                Image(systemName: "person.crop.circle")
            }
            .buttonStyle(.bordered)

            Button {
                isShowingHistory = true
            } label: {
                Image(systemName: "clock")
            }
            .buttonStyle(.bordered)

            Button {
                draftThemeMode = AppThemeMode(rawValue: appThemeModeRaw) ?? .light
                draftAccentColor = AppAccentColor.makeColor(
                    red: appAccentRed,
                    green: appAccentGreen,
                    blue: appAccentBlue
                )
                isShowingThemeSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.bordered)

            Button {
                session.handleUndo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(.bordered)
            .disabled(!game.canUndo || (session.isActive && !session.canUndoLocally))
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

    private var checkoutBadge: some View {
        let routes = game.bestPossibleFinishLines
        let isBogey = game.isCurrentScoreBogey
        let isHighlighted = !routes.isEmpty

        let label: String
        if isBogey {
            label = "Bogey — no finish possible"
        } else if routes.isEmpty {
            label = "No finish available"
        } else {
            label = routes.joined(separator: "   ·   ")
        }

        return Text(label)
            .font(.subheadline)
            .fontWeight(isHighlighted ? .bold : .regular)
            .lineLimit(1)
            .foregroundStyle(isBogey ? Color.orange : (isHighlighted ? Color.white : Color.primary))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isBogey ? Color.orange.opacity(0.12) : (isHighlighted ? Color.accentColor : Color(.secondarySystemBackground)))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var numberPad: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: numberColumns, spacing: 8) {
                ForEach(1...20, id: \.self) { value in
                    Button("\(value)") {
                        submitThrowAndReset(.number(value), multiplier: selectedMultiplier)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(game.winner != nil || isInputLocked)
                }

                Button(selectedMultiplier == .single ? "25" : "Bull") {
                    submitThrowAndReset(.bull, multiplier: selectedMultiplier)
                }
                .buttonStyle(.borderedProminent)
                .disabled(game.winner != nil || selectedMultiplier == .triple || isInputLocked)

                Button("0") {
                    submitThrowAndReset(.number(0), multiplier: .single)
                }
                .buttonStyle(.bordered)
                .disabled(game.winner != nil || isInputLocked)

                Color.clear.frame(height: 1)
                Color.clear.frame(height: 1)

                Button("No Score") {
                    submitNoScoreTurn()
                }
                .buttonStyle(.bordered)
                .disabled(game.winner != nil || isInputLocked)
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

                if session.role != .joiner {
                    HStack(spacing: 12) {
                        if game.setWinner == nil {
                            Button("New Leg (Random)") {
                                let record = game.buildGameRecord()
                                historyStore.record(record)
                                profileStore.updateStatsFromGameRecord(record)
                                session.broadcastStatsUpdate()
                                game.restartLegRandomSequence()
                                session.handleNewLeg()
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        Button(game.setWinner == nil ? "New Game" : "Start New Game") {
                            presentNewGameSetup()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            Button {
                session.handleUndo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(.bordered)
            .disabled(!game.canUndo || (session.isActive && !session.canUndoLocally))
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
        let previousScore = game.activePlayer.score
        session.handleThrow(segment: segment, multiplier: multiplier)
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
        submitThrowAndReset(.number(0), multiplier: .single)
    }

    private func presentNewGameSetup() {
        if game.winner != nil {
            let record = game.buildGameRecord()
            historyStore.record(record)
            profileStore.updateStatsFromGameRecord(record)
        }
        let persistedNames = persistedNewGamePlayerNames()
        let fallbackNames = game.players.enumerated().map { index, player in
            SetupPlayer(name: player.name, defaultName: "Player \(index + 1)", colorHex: player.colorHex, profileID: player.profileID)
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

private struct NewGameSetupView: View {
    @Binding var setupPlayers: [SetupPlayer]
    @Binding var finishRule: FinishRule
    @Binding var inRule: InRule
    @Binding var startScore: StartScoreOption
    @Binding var setModeEnabled: Bool
    @Binding var legsToWin: Int
    let profileStore: PlayerProfileStore
    @ObservedObject var session: MultipeerSessionManager

    let onCancel: () -> Void
    let onStart: () -> Void

    @State private var profilePickerPlayerID: UUID?
    @State private var isShowingProfileManagement = false
    @State private var multiplayerInputMode: InputMode = .free
    @State private var multiplayerUndoPermission: UndoPermission = .anyPlayer
    @State private var isShowingHosting = false
    @State private var isShowingJoining = false

    private var maxPlayers: Int {
        guard session.role == .host, !session.connectedPeers.isEmpty else { return 5 }
        return min(5, session.connectedPeers.count + 1)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Game Settings") {
                    Stepper("Players: \(setupPlayers.count)", value: playerCountBinding, in: 2...maxPlayers)

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
                                Button {
                                    profilePickerPlayerID = player.id
                                } label: {
                                    Circle()
                                        .fill(player.colorHex.flatMap { Color(hex: $0) } ?? Color(.systemGray4))
                                        .frame(width: 22, height: 22)
                                        .overlay(
                                            Circle().strokeBorder(Color(.systemGray3), lineWidth: player.colorHex == nil ? 1.5 : 0)
                                        )
                                }
                                .buttonStyle(.plain)

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
                    .sheet(item: Binding(
                        get: { profilePickerPlayerID.map { ProfilePickerTarget(id: $0) } },
                        set: { profilePickerPlayerID = $0?.id }
                    )) { target in
                        let excludedIDs = Set(setupPlayers.compactMap { sp in
                            sp.id == target.id ? nil : sp.profileID
                        })
                        ProfilePickerView(
                            profiles: profileStore.profiles,
                            excludedProfileIDs: excludedIDs
                        ) { selectedProfile in
                            if let idx = setupPlayers.firstIndex(where: { $0.id == target.id }) {
                                if let profile = selectedProfile {
                                    setupPlayers[idx].name = profile.name
                                    setupPlayers[idx].colorHex = profile.colorHex
                                    setupPlayers[idx].profileID = profile.id
                                } else {
                                    setupPlayers[idx].colorHex = nil
                                    setupPlayers[idx].profileID = nil
                                }
                            }
                        }
                    }
                }

                multiplayerSection
            }
            .navigationTitle("New Game")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .destructive, action: onCancel)
                }
                ToolbarItem(placement: .principal) {
                    Button {
                        isShowingProfileManagement = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start", action: onStart)
                        .disabled(session.role == .joiner)
                }
            }
            .sheet(isPresented: $isShowingProfileManagement) {
                PlayerProfileView(store: profileStore)
            }
            .sheet(isPresented: $isShowingHosting) {
                NavigationStack {
                    QRHostView(
                        session: session,
                        players: setupPlayersAsPlayers,
                        onDismiss: { isShowingHosting = false }
                    )
                }
            }
            .sheet(isPresented: $isShowingJoining) {
                NavigationStack {
                    QRJoinerView(
                        session: session,
                        onDismiss: { isShowingJoining = false }
                    )
                }
            }
            .onChange(of: session.gameHasStarted) { _, started in
                guard started && session.role == .joiner else { return }
                isShowingJoining = false
            }
        }
        .onAppear {
            if setupPlayers.isEmpty {
                setupPlayers = [
                    SetupPlayer(name: "Player 1", defaultName: "Player 1"),
                    SetupPlayer(name: "Player 2", defaultName: "Player 2")
                ]
            }
            // Sync local pickers to session values when already in a session
            if session.role != .none {
                multiplayerInputMode = session.inputMode
                multiplayerUndoPermission = session.undoPermission
            }
        }
    }

    // MARK: - Multiplayer Section

    @ViewBuilder
    private var multiplayerSection: some View {
        Section("Local Multiplayer") {
            switch session.role {
            case .none:
                Picker("Input Mode", selection: $multiplayerInputMode) {
                    ForEach(InputMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                Text(multiplayerInputMode.explanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Picker("Undo", selection: $multiplayerUndoPermission) {
                    ForEach(UndoPermission.allCases) { p in
                        Text(p.label).tag(p)
                    }
                }

                Button {
                    session.hostSession(inputMode: multiplayerInputMode, undoPermission: multiplayerUndoPermission)
                    isShowingHosting = true
                } label: {
                    Label("Host a Game", systemImage: "qrcode")
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Button { isShowingJoining = true } label: {
                    Label("Join a Game", systemImage: "camera")
                        .frame(maxWidth: .infinity, alignment: .center)
                }

            case .host:
                Label("Hosting: \(session.sessionToken)", systemImage: "wifi")
                    .foregroundStyle(.secondary)
                Text(session.connectedPeers.isEmpty
                    ? "Waiting for devices to join…"
                    : "\(session.connectedPeers.count + 1) device(s) connected")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Picker("Input Mode", selection: $multiplayerInputMode) {
                    ForEach(InputMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .disabled(session.connectedPeers.isEmpty)
                .onChange(of: multiplayerInputMode) { _, mode in
                    session.updateSessionConfig(inputMode: mode, undoPermission: multiplayerUndoPermission)
                }
                Text(multiplayerInputMode.explanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Picker("Undo", selection: $multiplayerUndoPermission) {
                    ForEach(UndoPermission.allCases) { p in
                        Text(p.label).tag(p)
                    }
                }
                .disabled(session.connectedPeers.isEmpty)
                .onChange(of: multiplayerUndoPermission) { _, perm in
                    session.updateSessionConfig(inputMode: multiplayerInputMode, undoPermission: perm)
                }

                Button { isShowingHosting = true } label: {
                    Label("Manage Players", systemImage: "person.2")
                }
                Button("Stop Local Multiplayer", role: .destructive) {
                    session.endSession()
                }

            case .joiner:
                if session.connectedPeers.isEmpty {
                    Label("Connecting…", systemImage: "wifi")
                        .foregroundStyle(.secondary)
                } else if session.gameHasStarted {
                    Label("Game Starting", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("Joined — Waiting for host to start", systemImage: "checkmark.circle")
                        .foregroundStyle(.tint)
                }
                Button("Leave Session", role: .destructive) {
                    session.endSession()
                }
            }
        }
    }

    private var setupPlayersAsPlayers: [Player] {
        setupPlayers.map { sp in
            Player(
                id: sp.profileID ?? sp.id,
                name: sp.name,
                score: 0,
                colorHex: sp.colorHex,
                profileID: sp.profileID
            )
        }
    }

    private var playerCountBinding: Binding<Int> {
        Binding(
            get: { setupPlayers.count },
            set: { newValue in
                let clamped = min(max(2, newValue), maxPlayers)
                if clamped > setupPlayers.count {
                    let start = setupPlayers.count + 1
                    for index in start...clamped {
                        setupPlayers.append(SetupPlayer(name: "Player \(index)", defaultName: "Player \(index)", colorHex: nil, profileID: nil))
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
    var colorHex: String?
    var profileID: UUID?

    init(id: UUID = UUID(), name: String, defaultName: String, colorHex: String? = nil, profileID: UUID? = nil) {
        self.id = id
        self.name = name
        self.defaultName = defaultName
        self.colorHex = colorHex
        self.profileID = profileID
    }
}

private struct ProfilePickerTarget: Identifiable {
    let id: UUID
}
