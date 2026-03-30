import SwiftUI

struct TournamentListView: View {
    @ObservedObject var store: TournamentStore
    @ObservedObject var profileStore: PlayerProfileStore
    @ObservedObject var historyStore: GameHistoryStore
    let onPlayMatch: (TournamentMatchLaunchContext) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isShowingCreateTournament = false
    @State private var pendingDeleteTournamentIDs: [UUID] = []

    private var ongoingTournaments: [Tournament] {
        store.tournaments.filter { $0.status != .completed }
    }

    private var completedTournaments: [Tournament] {
        store.tournaments.filter { $0.status == .completed }
    }

    var body: some View {
        NavigationStack {
            List {
                if ongoingTournaments.isEmpty && completedTournaments.isEmpty {
                    ContentUnavailableView(
                        "No Tournaments Yet",
                        systemImage: "trophy",
                        description: Text("Create a tournament to manage a bracket or round robin schedule.")
                    )
                }

                if !ongoingTournaments.isEmpty {
                    Section("Ongoing") {
                        ForEach(ongoingTournaments) { tournament in
                            NavigationLink {
                                TournamentDetailView(
                                    store: store,
                                    historyStore: historyStore,
                                    tournamentID: tournament.id,
                                    onPlayMatch: { context in
                                        dismiss()
                                        onPlayMatch(context)
                                    }
                                )
                            } label: {
                                TournamentListRow(tournament: tournament)
                            }
                        }
                        .onDelete { offsets in
                            pendingDeleteTournamentIDs = offsets.map { ongoingTournaments[$0].id }
                        }
                    }
                }

                if !completedTournaments.isEmpty {
                    Section("Completed") {
                        ForEach(completedTournaments) { tournament in
                            NavigationLink {
                                TournamentDetailView(
                                    store: store,
                                    historyStore: historyStore,
                                    tournamentID: tournament.id,
                                    onPlayMatch: { context in
                                        dismiss()
                                        onPlayMatch(context)
                                    }
                                )
                            } label: {
                                TournamentListRow(tournament: tournament)
                            }
                        }
                        .onDelete { offsets in
                            pendingDeleteTournamentIDs = offsets.map { completedTournaments[$0].id }
                        }
                    }
                }
            }
            .navigationTitle("Tournaments")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingCreateTournament = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingCreateTournament) {
                TournamentSetupView(profileStore: profileStore) { name, format, roundRobinMode, participants, rules in
                    _ = store.createTournament(
                        name: name,
                        format: format,
                        participants: participants,
                        rules: rules,
                        roundRobinMode: roundRobinMode
                    )
                }
            }
            .alert(deleteAlertTitle, isPresented: pendingDeleteAlertBinding) {
                Button("Cancel", role: .cancel) {
                    pendingDeleteTournamentIDs = []
                }
                Button("Delete", role: .destructive) {
                    pendingDeleteTournamentIDs.forEach(store.delete)
                    pendingDeleteTournamentIDs = []
                }
            } message: {
                Text(deleteAlertMessage)
            }
        }
    }

    private var pendingDeleteAlertBinding: Binding<Bool> {
        Binding(
            get: { !pendingDeleteTournamentIDs.isEmpty },
            set: { if !$0 { pendingDeleteTournamentIDs = [] } }
        )
    }

    private var deleteAlertTitle: String {
        pendingDeleteTournamentIDs.count == 1 ? "Delete Tournament?" : "Delete Tournaments?"
    }

    private var deleteAlertMessage: String {
        pendingDeleteTournamentIDs.count == 1
            ? "This will permanently remove the tournament and its bracket or standings."
            : "This will permanently remove the selected tournaments and their brackets or standings."
    }
}

private struct TournamentListRow: View {
    let tournament: Tournament

    private var participantCountText: String {
        "\(tournament.participants.count) players"
    }

    private var winnerName: String? {
        guard let winnerParticipantID = tournament.winnerParticipantID else { return nil }
        return tournament.participants.first(where: { $0.id == winnerParticipantID })?.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(tournament.name)
                    .font(.headline)
                Spacer()
                Text(tournament.format.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(participantCountText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let winnerName {
                Text("Winner: \(winnerName)")
                    .font(.subheadline.weight(.semibold))
            } else {
                Text("\(tournament.completedMatchCount) of \(tournament.playableMatchCount) matches complete")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private enum TournamentDetailTab: String, CaseIterable, Identifiable {
    case bracket
    case table
    case matches

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bracket:
            return "Bracket"
        case .table:
            return "Table"
        case .matches:
            return "Matches"
        }
    }
}

struct TournamentDetailView: View {
    @ObservedObject var store: TournamentStore
    @ObservedObject var historyStore: GameHistoryStore
    let tournamentID: UUID
    let onPlayMatch: (TournamentMatchLaunchContext) -> Void

    @State private var selectedTab: TournamentDetailTab = .matches

    private var tournament: Tournament? {
        store.tournament(id: tournamentID)
    }

    private var availableTabs: [TournamentDetailTab] {
        guard let tournament else { return [.matches] }
        return tournament.format == .singleElimination ? [.bracket, .matches] : [.table, .matches]
    }

    var body: some View {
        Group {
            if let tournament {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        TournamentHeaderCard(tournament: tournament)

                        Picker("Section", selection: $selectedTab) {
                            ForEach(availableTabs) { tab in
                                Text(tab.label).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)

                        switch selectedTab {
                        case .bracket:
                            TournamentBracketView(
                                store: store,
                                tournament: tournament,
                                historyStore: historyStore,
                                onPlayMatch: playMatch
                            )
                        case .table:
                            TournamentStandingsView(
                                tournament: tournament,
                                standings: store.standings(for: tournament)
                            )
                        case .matches:
                            TournamentMatchesView(
                                store: store,
                                tournament: tournament,
                                historyStore: historyStore,
                                onPlayMatch: playMatch
                            )
                        }
                    }
                    .padding()
                }
                .navigationTitle(tournament.name)
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    if let firstTab = availableTabs.first {
                        selectedTab = firstTab
                    }
                }
            } else {
                ContentUnavailableView(
                    "Tournament Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This tournament could not be loaded.")
                )
            }
        }
    }

    private func playMatch(_ context: TournamentMatchLaunchContext) {
        onPlayMatch(context)
    }
}

private struct TournamentHeaderCard: View {
    let tournament: Tournament

    private var winner: TournamentParticipant? {
        guard let winnerParticipantID = tournament.winnerParticipantID else { return nil }
        return tournament.participants.first(where: { $0.id == winnerParticipantID })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tournament.format.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(tournament.rules.formatSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(tournament.statusLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Players")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(tournament.participants.count)")
                        .font(.title3.weight(.semibold))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(tournament.completedMatchCount)/\(tournament.playableMatchCount)")
                        .font(.title3.weight(.semibold))
                }

                Spacer()
            }

            if let winner {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(hex: winner.colorHex) ?? .accentColor)
                        .frame(width: 12, height: 12)
                    Text("Winner: \(winner.name)")
                        .font(.headline)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct TournamentBracketView: View {
    @ObservedObject var store: TournamentStore
    let tournament: Tournament
    let historyStore: GameHistoryStore
    let onPlayMatch: (TournamentMatchLaunchContext) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(tournament.rounds) { round in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(round.title)
                            .font(.headline)

                        ForEach(matches(for: round)) { match in
                            NavigationLink {
                                TournamentMatchDetailView(
                                    store: store,
                                    historyStore: historyStore,
                                    tournamentID: tournament.id,
                                    matchID: match.id,
                                    onPlayMatch: onPlayMatch
                                )
                            } label: {
                                TournamentMatchCard(
                                    tournament: tournament,
                                    match: match
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(width: 250, alignment: .topLeading)
                }
            }
            .padding(.bottom, 8)
        }
    }

    private func matches(for round: TournamentRound) -> [TournamentMatch] {
        let matchesByID = Dictionary(uniqueKeysWithValues: tournament.matches.map { ($0.id, $0) })
        return round.matchIDs.compactMap { matchesByID[$0] }
    }
}

private struct TournamentStandingsView: View {
    let tournament: Tournament
    let standings: [TournamentStanding]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Player")
                Spacer()
                Text("W")
                    .frame(width: 26)
                Text("L")
                    .frame(width: 26)
                Text("+/-")
                    .frame(width: 40)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.bottom, 6)

            ForEach(standings) { standing in
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: standing.participant.colorHex) ?? .accentColor)
                            .frame(width: 10, height: 10)
                        Text(standing.participant.name)
                    }
                    Spacer()
                    Text("\(standing.wins)")
                        .frame(width: 26)
                    Text("\(standing.losses)")
                        .frame(width: 26)
                    Text("\(standing.legDifference)")
                        .frame(width: 40)
                }
                .font(.subheadline)
                .padding(.vertical, 8)

                if standing.id != standings.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct TournamentMatchesView: View {
    @ObservedObject var store: TournamentStore
    let tournament: Tournament
    let historyStore: GameHistoryStore
    let onPlayMatch: (TournamentMatchLaunchContext) -> Void

    var body: some View {
        TournamentMatchesSection(
            store: store,
            tournament: tournament,
            historyStore: historyStore,
            onPlayMatch: onPlayMatch
        )
    }
}

private struct TournamentMatchesSection: View {
    @ObservedObject var store: TournamentStore
    let tournament: Tournament
    let historyStore: GameHistoryStore
    let onPlayMatch: (TournamentMatchLaunchContext) -> Void

    private var sortedMatches: [TournamentMatch] {
        tournament.matches.sorted {
            if $0.roundIndex != $1.roundIndex { return $0.roundIndex < $1.roundIndex }
            return $0.slotIndex < $1.slotIndex
        }
    }

    private var roundRobinSections: [(title: String, matches: [TournamentMatch])] {
        [
            ("In Progress", sortedMatches.filter { $0.status == .inProgress }),
            ("Ready", sortedMatches.filter { $0.status == .ready }),
            ("Completed", sortedMatches.filter { $0.status == .completed })
        ]
        .filter { !$0.matches.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if tournament.format == .roundRobin {
                ForEach(roundRobinSections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.title)
                            .font(.headline)

                        ForEach(section.matches) { match in
                            matchLink(for: match)
                        }
                    }
                }
            } else {
                ForEach(sortedMatches) { match in
                    matchLink(for: match)
                }
            }
        }
    }

    private func matchLink(for match: TournamentMatch) -> some View {
        NavigationLink {
            TournamentMatchDetailView(
                store: store,
                historyStore: historyStore,
                tournamentID: tournament.id,
                matchID: match.id,
                onPlayMatch: onPlayMatch
            )
        } label: {
            TournamentMatchCard(
                tournament: tournament,
                match: match
            )
        }
        .buttonStyle(.plain)
    }
}

private struct TournamentMatchCard: View {
    let tournament: Tournament
    let match: TournamentMatch

    private var playerA: TournamentParticipant? {
        match.playerAParticipantID.flatMap { id in tournament.participants.first(where: { $0.id == id }) }
    }

    private var playerB: TournamentParticipant? {
        match.playerBParticipantID.flatMap { id in tournament.participants.first(where: { $0.id == id }) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(tournament.format == .singleElimination
                     ? (tournament.rounds.first(where: { $0.index == match.roundIndex })?.title ?? "Match")
                     : roundRobinMatchLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(statusLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
            }

            VStack(spacing: 8) {
                participantRow(
                    playerA,
                    isWinner: match.winnerParticipantID != nil && match.winnerParticipantID == playerA?.id
                )
                participantRow(
                    playerB,
                    isWinner: match.winnerParticipantID != nil && match.winnerParticipantID == playerB?.id
                )
            }

            if let result = match.result, !result.wasBye {
                Text("\(result.playerALegsWon) - \(result.playerBLegsWon)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(match.status == .ready || match.status == .inProgress ? "Tap to view match" : "Tap to view details")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func participantRow(_ participant: TournamentParticipant?, isWinner: Bool) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(participant.flatMap { Color(hex: $0.colorHex) } ?? Color(.systemGray4))
                .frame(width: 10, height: 10)

            Text(participant?.name ?? "TBD")
                .font(.subheadline.weight(isWinner ? .semibold : .regular))
                .foregroundStyle(participant == nil ? .secondary : .primary)

            Spacer()

            if isWinner {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    private var statusLabel: String {
        switch match.status {
        case .pending:
            return "Pending"
        case .ready:
            return "Ready"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        case .bye:
            return "Bye"
        }
    }

    private var roundRobinMatchLabel: String {
        if tournament.roundRobinMode == .double {
            return "Round \(match.roundIndex + 1) • Match \(roundRobinMatchNumber)"
        }
        return "Match \(match.slotIndex + 1)"
    }

    private var roundRobinMatchNumber: Int {
        let matchesPerCycle = max(1, tournament.participants.count * max(tournament.participants.count - 1, 0) / 2)
        return (match.slotIndex % matchesPerCycle) + 1
    }

    private var statusColor: Color {
        switch match.status {
        case .pending:
            return .secondary
        case .ready:
            return .blue
        case .inProgress:
            return .orange
        case .completed, .bye:
            return .green
        }
    }
}

private struct TournamentMatchDetailView: View {
    @ObservedObject var store: TournamentStore
    @ObservedObject var historyStore: GameHistoryStore
    let tournamentID: UUID
    let matchID: UUID
    let onPlayMatch: (TournamentMatchLaunchContext) -> Void

    @State private var selectedRecord: GameRecord?

    private var tournament: Tournament? {
        store.tournament(id: tournamentID)
    }

    private var match: TournamentMatch? {
        store.match(tournamentID: tournamentID, matchID: matchID)
    }

    private var playerA: TournamentParticipant? {
        guard let tournament, let playerAID = match?.playerAParticipantID else { return nil }
        return tournament.participants.first(where: { $0.id == playerAID })
    }

    private var playerB: TournamentParticipant? {
        guard let tournament, let playerBID = match?.playerBParticipantID else { return nil }
        return tournament.participants.first(where: { $0.id == playerBID })
    }

    private var roundTitle: String {
        guard let tournament, let match else { return "Match" }
        if tournament.format == .singleElimination {
            return tournament.rounds.first(where: { $0.index == match.roundIndex })?.title ?? "Match"
        }
        if tournament.roundRobinMode == .double {
            return "Round \(match.roundIndex + 1) • Match \(roundRobinMatchNumber(match, tournament: tournament))"
        }
        return "Match \(match.slotIndex + 1)"
    }

    private var record: GameRecord? {
        guard let recordID = match?.gameRecordID else { return nil }
        return historyStore.records.first(where: { $0.id == recordID })
    }

    private var launchContext: TournamentMatchLaunchContext? {
        store.launchContext(tournamentID: tournamentID, matchID: matchID)
    }

    private var actionTitle: String {
        guard let match else { return "Play Match" }
        return match.status == .inProgress ? "Resume Match" : "Play Match"
    }

    var body: some View {
        Group {
            if let tournament, let match {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(roundTitle)
                                        .font(.title3.weight(.semibold))
                                    Text(matchDetailSubtitle(for: tournament, match: match))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(statusLabel(for: match))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(statusColor(for: match))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(.tertiarySystemBackground))
                                    .clipShape(Capsule())
                            }

                            VStack(spacing: 10) {
                                detailParticipantRow(
                                    playerA,
                                    isWinner: match.winnerParticipantID != nil && match.winnerParticipantID == playerA?.id
                                )
                                detailParticipantRow(
                                    playerB,
                                    isWinner: match.winnerParticipantID != nil && match.winnerParticipantID == playerB?.id
                                )
                            }

                            if let result = match.result {
                                HStack(spacing: 14) {
                                    detailStatCard(title: "Result", value: result.wasBye ? "Bye" : "\(result.playerALegsWon) - \(result.playerBLegsWon)")
                                    detailStatCard(title: "State", value: result.wasBye ? "Advanced" : statusLabel(for: match))
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        if let record {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Match Result")
                                    .font(.headline)

                                Button {
                                    selectedRecord = record
                                } label: {
                                    GameRecordRow(record: record)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if let launchContext {
                            Button(actionTitle) {
                                onPlayMatch(launchContext)
                            }
                            .buttonStyle(.borderedProminent)
                        } else if match.status == .pending {
                            Text("This match will unlock once the previous result is known.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
                .navigationTitle(roundTitle)
                .navigationBarTitleDisplayMode(.inline)
                .sheet(item: $selectedRecord) { record in
                    GameRecordDetailView(record: record)
                }
            } else {
                ContentUnavailableView(
                    "Match Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This match could not be loaded.")
                )
            }
        }
    }

    private func matchDetailSubtitle(for tournament: Tournament, match: TournamentMatch) -> String {
        if tournament.format == .singleElimination {
            let matchLabel = "Match \(match.slotIndex + 1)"
            return "\(tournament.name) • \(matchLabel)"
        }
        return tournament.rules.formatSummary
    }

    private func roundRobinMatchNumber(_ match: TournamentMatch, tournament: Tournament) -> Int {
        let matchesPerCycle = max(1, tournament.participants.count * max(tournament.participants.count - 1, 0) / 2)
        return (match.slotIndex % matchesPerCycle) + 1
    }

    private func detailParticipantRow(_ participant: TournamentParticipant?, isWinner: Bool) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(participant.flatMap { Color(hex: $0.colorHex) } ?? Color(.systemGray4))
                .frame(width: 12, height: 12)

            Text(participant?.name ?? "TBD")
                .font(.body.weight(isWinner ? .semibold : .regular))
                .foregroundStyle(participant == nil ? .secondary : .primary)

            Spacer()

            if isWinner {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 4)
    }

    private func detailStatCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func statusLabel(for match: TournamentMatch) -> String {
        switch match.status {
        case .pending:
            return "Pending"
        case .ready:
            return "Ready"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        case .bye:
            return "Bye"
        }
    }

    private func statusColor(for match: TournamentMatch) -> Color {
        switch match.status {
        case .pending:
            return .secondary
        case .ready:
            return .blue
        case .inProgress:
            return .orange
        case .completed, .bye:
            return .green
        }
    }
}

struct TournamentSetupView: View {
    @ObservedObject var profileStore: PlayerProfileStore
    let onCreate: (String, TournamentFormat, TournamentRoundRobinMode, [TournamentParticipant], TournamentMatchRules) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var tournamentName = ""
    @State private var format: TournamentFormat = .singleElimination
    @State private var roundRobinMode: TournamentRoundRobinMode = .single
    @State private var randomSeedingEnabled = false
    @State private var rules = TournamentMatchRules()
    @State private var selectedProfileIDs: [UUID] = []

    private var selectedProfiles: [PlayerProfile] {
        selectedProfileIDs.compactMap { id in
            profileStore.profiles.first(where: { $0.id == id })
        }
    }

    private var canCreate: Bool {
        selectedProfileIDs.count >= 2
    }

    private var selectedPlayersListHeight: CGFloat {
        let rowHeight: CGFloat = 44
        return max(100, CGFloat(selectedProfiles.count) * rowHeight + 8)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tournament") {
                    TextField("Name", text: $tournamentName)

                    Picker("Format", selection: $format) {
                        ForEach(TournamentFormat.allCases) { format in
                            Text(format.label).tag(format)
                        }
                    }
                    .pickerStyle(.menu)

                    if format == .roundRobin {
                        Picker("Round Robin", selection: $roundRobinMode) {
                            ForEach(TournamentRoundRobinMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Toggle("Random Seeding", isOn: $randomSeedingEnabled)
                        .onChange(of: randomSeedingEnabled) { _, isEnabled in
                            guard isEnabled else { return }
                            randomizeSelectedProfiles()
                        }
                }

                Section("Available Profiles") {
                    if profileStore.profiles.isEmpty {
                        Text("Create player profiles first to run a tournament.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(profileStore.profiles) { profile in
                        Button {
                            toggleSelection(for: profile.id)
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(hex: profile.colorHex) ?? .accentColor)
                                    .frame(width: 12, height: 12)

                                Text(profile.name)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if selectedProfileIDs.contains(profile.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !randomSeedingEnabled {
                    Section("Player Order") {
                        if selectedProfiles.isEmpty {
                            Text("Select at least two profiles to start a tournament.")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Drag to reorder seeded players")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            List {
                                ForEach(selectedProfiles) { profile in
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Color(hex: profile.colorHex) ?? .accentColor)
                                            .frame(width: 12, height: 12)

                                        Text(profile.name)
                                            .font(.body.weight(.medium))

                                        Spacer()
                                    }
                                    .frame(minHeight: 28)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                }
                                .onMove(perform: moveSelectedProfiles)
                            }
                            .listStyle(.plain)
                            .scrollDisabled(true)
                            .frame(height: selectedPlayersListHeight)
                            .environment(\.defaultMinListRowHeight, 44)
                            .environment(\.editMode, .constant(.active))
                        }
                    }
                }

                Section("Match Rules") {
                    CompetitiveTournamentRulesEditor(rules: $rules)
                }
            }
            .navigationTitle("Create Tournament")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let participants = selectedProfiles.enumerated().map { index, profile in
                            TournamentParticipant(
                                profileID: profile.id,
                                name: profile.name,
                                colorHex: profile.colorHex,
                                seed: index + 1
                            )
                        }
                        onCreate(tournamentName, format, roundRobinMode, participants, rules)
                        dismiss()
                    }
                    .disabled(!canCreate)
                }
            }
        }
    }

    private func toggleSelection(for profileID: UUID) {
        if let index = selectedProfileIDs.firstIndex(of: profileID) {
            selectedProfileIDs.remove(at: index)
        } else {
            selectedProfileIDs.append(profileID)
        }

        if randomSeedingEnabled {
            randomizeSelectedProfiles()
        }
    }

    private func moveSelectedProfiles(from source: IndexSet, to destination: Int) {
        guard !randomSeedingEnabled else { return }
        selectedProfileIDs.move(fromOffsets: source, toOffset: destination)
    }

    private func randomizeSelectedProfiles() {
        guard selectedProfileIDs.count > 1 else { return }
        selectedProfileIDs.shuffle()
    }
}

private struct CompetitiveTournamentRulesEditor: View {
    @Binding var rules: TournamentMatchRules

    var body: some View {
        Group {
            Picker("Game Type", selection: $rules.gameMode) {
                Text(GameMode.x01.label).tag(GameMode.x01)
                Text(GameMode.cricket.label).tag(GameMode.cricket)
            }
            .pickerStyle(.menu)

            if rules.gameMode == .x01 {
                Picker("Game", selection: $rules.startingScore) {
                    ForEach(StartScoreOption.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Picker("In Mode", selection: $rules.inRule) {
                    ForEach(InRule.allCases) { rule in
                        Text(rule.label).tag(rule)
                    }
                }
                .pickerStyle(.menu)

                Picker("Finish Mode", selection: $rules.finishRule) {
                    ForEach(FinishRule.allCases) { rule in
                        Text(rule.label).tag(rule)
                    }
                }
                .pickerStyle(.menu)

                Toggle("Set Mode", isOn: $rules.setModeEnabled)

                if rules.setModeEnabled {
                    Stepper(
                        "Legs to Win: \(rules.legsToWin)",
                        value: $rules.legsToWin,
                        in: 1...10
                    )
                }
            }
        }
    }
}

private extension Tournament {
    var completedMatchCount: Int {
        matches.filter { $0.result != nil }.count
    }

    var playableMatchCount: Int {
        format == .singleElimination
            ? max(1, participants.count - 1)
            : matches.count
    }

    var statusLabel: String {
        switch status {
        case .draft:
            return "Draft"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        }
    }
}
