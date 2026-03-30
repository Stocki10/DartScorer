import SwiftUI

struct NewGameSetupView: View {
    @Binding var setupPlayers: [SetupPlayer]
    @Binding var gameMode: GameMode
    @Binding var practiceMode: PracticeMode
    @Binding var practiceCompetitiveEnabled: Bool
    @Binding var practiceSuccessesToWin: Int
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
    @StateObject private var historyStore = GameHistoryStore()

    private var maxPlayers: Int {
        guard session.role == .host, !session.connectedPeers.isEmpty else { return 5 }
        return min(5, session.connectedPeers.count + 1)
    }

    private var minimumPlayers: Int {
        gameMode == .practice ? 1 : 2
    }

    private var modeDescriptionTitle: String {
        switch gameMode {
        case .x01:
            return startScore.label
        case .practice:
            return practiceMode.label
        case .cricket:
            return GameMode.cricket.label
        }
    }

    private var modeDescriptionText: String {
        switch gameMode {
        case .x01:
            let inText = inRule == .doubleIn ? L10n.string("double-in") : L10n.string("default-in")
            let outText = finishRule == .doubleOut ? L10n.string("double-out") : L10n.string("single-out")
            return L10n.format("Start on %@ and check out with %@, %@ rules.", startScore.label, inText, outText)
        case .practice:
            switch practiceMode {
            case .scoringDrill:
                return L10n.string("Score keeps going up. Turns rotate after three darts and there is no bust or checkout.")
            case .checkoutPractice:
                return L10n.string("Get a random checkout target. Finish it within the visit to score a success.")
            case .doublesPractice:
                return L10n.string("A random double is called. Hit it within the visit to score a success.")
            case .aroundTheClock:
                return L10n.string("Work through 1 to 20 and Bull in order. Any multiplier counts for the current target.")
            case .first9Challenge:
                return L10n.string("Play exactly three visits and compare the first 9 average.")
            case .pressureFinishes:
                return L10n.string("Get a random checkout target. Miss it within the visit and your success count resets to zero.")
            case .streakMode:
                return L10n.string("Keep hitting the same called target. A miss resets your streak and rolls a new call.")
            case .randomTarget:
                return L10n.string("A target is called each visit. Hit it once to score and move to the next call.")
            }
        case .cricket:
            return L10n.string("Hit 20 through 15 and Bull to close them. Extra marks score only if opponents are still open.")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                gameSettingsSection
                playerOrderSection
                if AppFeatureFlags.localMultiplayerEnabled {
                    multiplayerSection
                }
            }
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .destructive, action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start", action: onStart)
                        .disabled(session.role == .joiner)
                }
            }
            .sheet(isPresented: $isShowingProfileManagement) {
                PlayerProfileView(store: profileStore, historyStore: historyStore)
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
                setupPlayers = gameMode == .practice
                    ? [SetupPlayer(name: "Player 1", defaultName: "Player 1")]
                    : [
                        SetupPlayer(name: "Player 1", defaultName: "Player 1"),
                        SetupPlayer(name: "Player 2", defaultName: "Player 2")
                    ]
            }
            if session.role != .none {
                multiplayerInputMode = session.inputMode
                multiplayerUndoPermission = session.undoPermission
            }
        }
        .onChange(of: gameMode) { _, mode in
            if mode == .practice {
                setModeEnabled = false
                legsToWin = 1
                if !practiceMode.supportsCompetitiveGoal {
                    practiceCompetitiveEnabled = false
                }
                if setupPlayers.isEmpty {
                    setupPlayers = [SetupPlayer(name: "Player 1", defaultName: "Player 1")]
                }
            } else if setupPlayers.count < 2 {
                setupPlayers.append(SetupPlayer(name: "Player 2", defaultName: "Player 2"))
            }
        }
        .onChange(of: practiceMode) { _, mode in
            if !mode.supportsCompetitiveGoal {
                practiceCompetitiveEnabled = false
            }
        }
    }

    private var gameSettingsSection: some View {
        Section("Game Settings") {
            modeSelectionRows
            modeDescriptionCard
            modeConfigurationRows
            setModeBlock
            playerCountRow
        }
    }

    private var modeSelectionRows: some View {
        Picker("Mode", selection: $gameMode) {
            ForEach(GameMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.menu)
    }

    private var modeDescriptionCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(modeDescriptionTitle)
                .font(.subheadline.weight(.semibold))
            Text(modeDescriptionText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var modeConfigurationRows: some View {
        if gameMode == .x01 {
            Picker("Game", selection: $startScore) {
                ForEach(StartScoreOption.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.menu)

            Picker("In Mode", selection: $inRule) {
                ForEach(InRule.allCases) { rule in
                    Text(rule.label).tag(rule)
                }
            }
            .pickerStyle(.menu)

            Picker("Finish Mode", selection: $finishRule) {
                ForEach(FinishRule.allCases) { rule in
                    Text(rule.label).tag(rule)
                }
            }
            .pickerStyle(.menu)
        } else if gameMode == .practice {
            Picker("Practice Mode", selection: $practiceMode) {
                ForEach(PracticeMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.menu)

            if practiceMode.supportsCompetitiveGoal {
                Toggle("Competitive Practice", isOn: $practiceCompetitiveEnabled)

                if practiceCompetitiveEnabled && setupPlayers.count > 1 {
                    Stepper(
                        L10n.format("First to %@ Wins", "\(practiceSuccessesToWin)"),
                        value: $practiceSuccessesToWin,
                        in: 1...20
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var setModeBlock: some View {
        if gameMode == .x01 {
            Toggle(
                "Set Mode",
                isOn: Binding(
                    get: { setModeEnabled },
                    set: { newValue in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            setModeEnabled = newValue
                        }
                    }
                )
            )
            .padding(.top, 6)

            if setModeEnabled {
                Stepper(
                    L10n.format("Legs to Win: %@", "\(legsToWin)"),
                    value: $legsToWin,
                    in: 1...10
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var playerCountRow: some View {
        Stepper(
            L10n.format("Players: %@", "\(setupPlayers.count)"),
            value: playerCountBinding,
            in: minimumPlayers...maxPlayers
        )
    }

    private var playerOrderListHeight: CGFloat {
        max(220, CGFloat(setupPlayers.count) * 52 + 16)
    }

    private var playerOrderSection: some View {
        Section("Player Order") {
            Button {
                isShowingProfileManagement = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle")
                        .foregroundStyle(.tint)

                    Text(L10n.string("Manage Profiles"))
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Text(L10n.string("Drag to reorder players and assign profiles"))
                .font(.footnote)
                .foregroundStyle(.secondary)

            List {
                ForEach($setupPlayers) { $player in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(player.colorHex.flatMap { Color(hex: $0) } ?? Color(.systemGray4))
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle().strokeBorder(
                                    Color(.systemGray3),
                                    lineWidth: player.colorHex == nil ? 1.5 : 0
                                )
                            )

                        TextField(player.defaultName, text: $player.name)
                            .textFieldStyle(.plain)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .font(.body.weight(.medium))

                        Spacer(minLength: 8)

                        Button {
                            profilePickerPlayerID = player.id
                        } label: {
                            HStack(spacing: 8) {
                                if let label = profileButtonLabel(for: player) {
                                    Text(label)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                        .foregroundStyle(player.profileID == nil ? Color.secondary : Color.primary)
                                }

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(height: 24)
                    .padding(.vertical, 0)
                }
                .onMove(perform: movePlayers)
            }
            .listStyle(.plain)
            .scrollDisabled(true)
            .frame(height: playerOrderListHeight)
            .environment(\.defaultMinListRowHeight, 38)
            .environment(\.editMode, .constant(.active))
            .sheet(item: Binding(
                get: { profilePickerPlayerID.map { ProfilePickerTarget(id: $0) } },
                set: { profilePickerPlayerID = $0?.id }
            )) { target in
                let excludedIDs = Set(setupPlayers.compactMap { player in
                    player.id == target.id ? nil : player.profileID
                })
                ProfilePickerView(
                    profiles: profileStore.profiles,
                    excludedProfileIDs: excludedIDs
                ) { selectedProfile in
                    if let index = setupPlayers.firstIndex(where: { $0.id == target.id }) {
                        if let profile = selectedProfile {
                            setupPlayers[index].name = profile.name
                            setupPlayers[index].colorHex = profile.colorHex
                            setupPlayers[index].profileID = profile.id
                        } else {
                            setupPlayers[index].colorHex = nil
                            setupPlayers[index].profileID = nil
                        }
                    }
                }
            }
        }
    }

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
                    ForEach(UndoPermission.allCases) { permission in
                        Text(permission.label).tag(permission)
                    }
                }

                Button {
                    session.hostSession(inputMode: multiplayerInputMode, undoPermission: multiplayerUndoPermission)
                    isShowingHosting = true
                } label: {
                    Label("Host a Game", systemImage: "qrcode")
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Button {
                    isShowingJoining = true
                } label: {
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
                    ForEach(UndoPermission.allCases) { permission in
                        Text(permission.label).tag(permission)
                    }
                }
                .disabled(session.connectedPeers.isEmpty)
                .onChange(of: multiplayerUndoPermission) { _, permission in
                    session.updateSessionConfig(inputMode: multiplayerInputMode, undoPermission: permission)
                }

                Button {
                    isShowingHosting = true
                } label: {
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
        setupPlayers.map { player in
            Player(
                id: player.profileID ?? player.id,
                name: player.name,
                score: 0,
                colorHex: player.colorHex,
                profileID: player.profileID
            )
        }
    }

    private var playerCountBinding: Binding<Int> {
        Binding(
            get: { setupPlayers.count },
            set: { newValue in
                let clamped = min(max(minimumPlayers, newValue), maxPlayers)
                if clamped > setupPlayers.count {
                    let start = setupPlayers.count + 1
                    for index in start...clamped {
                        setupPlayers.append(
                            SetupPlayer(
                                name: "Player \(index)",
                                defaultName: "Player \(index)",
                                colorHex: nil,
                                profileID: nil
                            )
                        )
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

    private func profileButtonLabel(for player: SetupPlayer) -> String? {
        if let profileID = player.profileID,
           let profile = profileStore.profiles.first(where: { $0.id == profileID }) {
            let trimmedPlayerName = player.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedProfileName = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedPlayerName.isEmpty,
               trimmedPlayerName.caseInsensitiveCompare(trimmedProfileName) == .orderedSame {
                return nil
            }
            return profile.name
        }
        return L10n.string("Assign")
    }
}
