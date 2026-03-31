import Foundation
import Combine

enum TournamentFormat: String, CaseIterable, Identifiable, Codable {
    case singleElimination
    case roundRobin

    nonisolated var id: String { rawValue }

    nonisolated var label: String {
        switch self {
        case .singleElimination:
            return "Single Elimination"
        case .roundRobin:
            return "Round Robin"
        }
    }
}

enum TournamentRoundRobinMode: String, CaseIterable, Identifiable, Codable {
    case single
    case double

    nonisolated var id: String { rawValue }

    nonisolated var label: String {
        switch self {
        case .single:
            return "Single Round Robin"
        case .double:
            return "Double Round Robin"
        }
    }
}

enum TournamentStatus: String, Codable {
    case draft
    case inProgress
    case completed
}

enum TournamentMatchStatus: String, Codable {
    case pending
    case ready
    case inProgress
    case completed
    case bye
}

struct TournamentParticipant: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let profileID: UUID
    let name: String
    let colorHex: String
    let seed: Int

    init(id: UUID = UUID(), profileID: UUID, name: String, colorHex: String, seed: Int) {
        self.id = id
        self.profileID = profileID
        self.name = name
        self.colorHex = colorHex
        self.seed = seed
    }
}

struct TournamentMatchRules: Codable, Equatable {
    var gameMode: GameMode = .x01
    var startingScore: StartScoreOption = .score501
    var inRule: InRule = .default
    var finishRule: FinishRule = .doubleOut
    var setModeEnabled: Bool = false
    var legsToWin: Int = 3

    var formatSummary: String {
        switch gameMode {
        case .x01:
            if setModeEnabled {
                return "\(startingScore.label) • \(finishRule.label) • First to \(legsToWin)"
            }
            return "\(startingScore.label) • \(finishRule.label)"
        case .cricket:
            return GameMode.cricket.label
        case .practice:
            return GameMode.practice.label
        }
    }
}

struct TournamentMatchResult: Codable, Equatable {
    let completedAt: Date
    let winnerParticipantID: UUID
    let playerALegsWon: Int
    let playerBLegsWon: Int
    let wasBye: Bool
}

struct TournamentMatch: Identifiable, Codable, Equatable {
    let id: UUID
    let tournamentID: UUID
    let roundIndex: Int
    let slotIndex: Int
    var playerAParticipantID: UUID?
    var playerBParticipantID: UUID?
    let playerASourceMatchID: UUID?
    let playerBSourceMatchID: UUID?
    var status: TournamentMatchStatus
    var winnerParticipantID: UUID?
    var gameRecordID: UUID?
    var result: TournamentMatchResult?

    init(
        id: UUID = UUID(),
        tournamentID: UUID,
        roundIndex: Int,
        slotIndex: Int,
        playerAParticipantID: UUID? = nil,
        playerBParticipantID: UUID? = nil,
        playerASourceMatchID: UUID? = nil,
        playerBSourceMatchID: UUID? = nil,
        status: TournamentMatchStatus = .pending,
        winnerParticipantID: UUID? = nil,
        gameRecordID: UUID? = nil,
        result: TournamentMatchResult? = nil
    ) {
        self.id = id
        self.tournamentID = tournamentID
        self.roundIndex = roundIndex
        self.slotIndex = slotIndex
        self.playerAParticipantID = playerAParticipantID
        self.playerBParticipantID = playerBParticipantID
        self.playerASourceMatchID = playerASourceMatchID
        self.playerBSourceMatchID = playerBSourceMatchID
        self.status = status
        self.winnerParticipantID = winnerParticipantID
        self.gameRecordID = gameRecordID
        self.result = result
    }
}

struct TournamentRound: Identifiable, Codable, Equatable {
    let id: UUID
    let index: Int
    let title: String
    let matchIDs: [UUID]

    init(id: UUID = UUID(), index: Int, title: String, matchIDs: [UUID]) {
        self.id = id
        self.index = index
        self.title = title
        self.matchIDs = matchIDs
    }
}

struct TournamentStanding: Identifiable, Equatable {
    let id: UUID
    let participant: TournamentParticipant
    let wins: Int
    let losses: Int
    let legsWon: Int
    let legsLost: Int

    var legDifference: Int { legsWon - legsLost }
}

struct Tournament: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let createdAt: Date
    var completedAt: Date?
    let format: TournamentFormat
    let roundRobinMode: TournamentRoundRobinMode
    var status: TournamentStatus
    let participants: [TournamentParticipant]
    let rules: TournamentMatchRules
    var rounds: [TournamentRound]
    var matches: [TournamentMatch]
    var winnerParticipantID: UUID?

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        format: TournamentFormat,
        roundRobinMode: TournamentRoundRobinMode = .single,
        status: TournamentStatus = .draft,
        participants: [TournamentParticipant],
        rules: TournamentMatchRules,
        rounds: [TournamentRound],
        matches: [TournamentMatch],
        winnerParticipantID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.format = format
        self.roundRobinMode = roundRobinMode
        self.status = status
        self.participants = participants
        self.rules = rules
        self.rounds = rounds
        self.matches = matches
        self.winnerParticipantID = winnerParticipantID
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt
        case completedAt
        case format
        case roundRobinMode
        case status
        case participants
        case rules
        case rounds
        case matches
        case winnerParticipantID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        format = try container.decode(TournamentFormat.self, forKey: .format)
        roundRobinMode = try container.decodeIfPresent(TournamentRoundRobinMode.self, forKey: .roundRobinMode) ?? .single
        status = try container.decode(TournamentStatus.self, forKey: .status)
        participants = try container.decode([TournamentParticipant].self, forKey: .participants)
        rules = try container.decode(TournamentMatchRules.self, forKey: .rules)
        rounds = try container.decode([TournamentRound].self, forKey: .rounds)
        matches = try container.decode([TournamentMatch].self, forKey: .matches)
        winnerParticipantID = try container.decodeIfPresent(UUID.self, forKey: .winnerParticipantID)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encode(format, forKey: .format)
        try container.encode(roundRobinMode, forKey: .roundRobinMode)
        try container.encode(status, forKey: .status)
        try container.encode(participants, forKey: .participants)
        try container.encode(rules, forKey: .rules)
        try container.encode(rounds, forKey: .rounds)
        try container.encode(matches, forKey: .matches)
        try container.encodeIfPresent(winnerParticipantID, forKey: .winnerParticipantID)
    }
}

struct TournamentMatchLaunchContext: Identifiable, Equatable, Codable {
    let tournamentID: UUID
    let tournamentName: String
    let tournamentFormat: TournamentFormat
    let matchID: UUID
    let roundTitle: String
    let rules: TournamentMatchRules
    let participants: [TournamentParticipant]

    var id: UUID { matchID }
}

final class TournamentStore: ObservableObject {
    @Published private(set) var tournaments: [Tournament] = []
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.fileURL = docs.appendingPathComponent("tournaments.json")
        }
        load()
    }

    @discardableResult
    func createTournament(
        name: String,
        format: TournamentFormat,
        participants: [TournamentParticipant],
        rules: TournamentMatchRules,
        roundRobinMode: TournamentRoundRobinMode = .single
    ) -> Tournament {
        let normalizedParticipants = participants.enumerated().map { index, participant in
            TournamentParticipant(
                id: participant.id,
                profileID: participant.profileID,
                name: participant.name,
                colorHex: participant.colorHex,
                seed: index + 1
            )
        }
        let tournament = Self.makeTournament(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Tournament" : name.trimmingCharacters(in: .whitespacesAndNewlines),
            format: format,
            participants: normalizedParticipants,
            rules: rules,
            roundRobinMode: roundRobinMode
        )
        tournaments.insert(tournament, at: 0)
        save()
        return tournament
    }

    func delete(_ tournamentID: UUID) {
        tournaments.removeAll { $0.id == tournamentID }
        save()
    }

    func tournament(id: UUID) -> Tournament? {
        tournaments.first { $0.id == id }
    }

    func markMatchInProgress(tournamentID: UUID, matchID: UUID) {
        updateTournament(id: tournamentID) { tournament in
            guard let matchIndex = tournament.matches.firstIndex(where: { $0.id == matchID }),
                  tournament.matches[matchIndex].status == .ready else { return }
            tournament.matches[matchIndex].status = .inProgress
            if tournament.status == .draft {
                tournament.status = .inProgress
            }
        }
    }

    func resetMatchToReady(tournamentID: UUID, matchID: UUID) {
        updateTournament(id: tournamentID) { tournament in
            guard let matchIndex = tournament.matches.firstIndex(where: { $0.id == matchID }),
                  tournament.matches[matchIndex].status == .inProgress,
                  tournament.matches[matchIndex].result == nil else { return }
            tournament.matches[matchIndex].status = tournament.matches[matchIndex].playerAParticipantID != nil && tournament.matches[matchIndex].playerBParticipantID != nil ? .ready : .pending
        }
    }

    func launchContext(tournamentID: UUID, matchID: UUID) -> TournamentMatchLaunchContext? {
        guard let tournament = tournament(id: tournamentID),
              let match = tournament.matches.first(where: { $0.id == matchID }),
              let playerAID = match.playerAParticipantID,
              let playerBID = match.playerBParticipantID,
              let playerA = tournament.participants.first(where: { $0.id == playerAID }),
              let playerB = tournament.participants.first(where: { $0.id == playerBID }),
              match.status == .ready || match.status == .inProgress else {
            return nil
        }

        return TournamentMatchLaunchContext(
            tournamentID: tournament.id,
            tournamentName: tournament.name,
            tournamentFormat: tournament.format,
            matchID: match.id,
            roundTitle: roundTitle(for: match, in: tournament),
            rules: tournament.rules,
            participants: [playerA, playerB]
        )
    }

    func match(tournamentID: UUID, matchID: UUID) -> TournamentMatch? {
        tournament(id: tournamentID)?.matches.first(where: { $0.id == matchID })
    }

    func nextReadyMatchContext(tournamentID: UUID, after currentMatchID: UUID? = nil) -> TournamentMatchLaunchContext? {
        guard let tournament = tournament(id: tournamentID) else { return nil }

        let nextReadyMatch = tournament.matches
            .sorted {
                if $0.roundIndex != $1.roundIndex { return $0.roundIndex < $1.roundIndex }
                return $0.slotIndex < $1.slotIndex
            }
            .first { match in
                match.status == .ready && match.id != currentMatchID
            }

        guard let nextReadyMatch else { return nil }
        return launchContext(tournamentID: tournamentID, matchID: nextReadyMatch.id)
    }

    func completeMatch(tournamentID: UUID, matchID: UUID, record: GameRecord) {
        updateTournament(id: tournamentID) { tournament in
            guard let matchIndex = tournament.matches.firstIndex(where: { $0.id == matchID }) else { return }
            var match = tournament.matches[matchIndex]
            guard let playerAID = match.playerAParticipantID,
                  let playerBID = match.playerBParticipantID,
                  let playerA = tournament.participants.first(where: { $0.id == playerAID }),
                  let playerB = tournament.participants.first(where: { $0.id == playerBID }),
                  let playerAResult = record.playerResults.first(where: { $0.profileID == playerA.profileID }),
                  let playerBResult = record.playerResults.first(where: { $0.profileID == playerB.profileID }) else { return }

            let playerALegsWon = Self.legsWon(for: playerAResult, in: record)
            let playerBLegsWon = Self.legsWon(for: playerBResult, in: record)
            let winnerParticipantID = playerAResult.isWinner ? playerAID : playerBID

            match.status = .completed
            match.winnerParticipantID = winnerParticipantID
            match.gameRecordID = record.id
            match.result = TournamentMatchResult(
                completedAt: record.date,
                winnerParticipantID: winnerParticipantID,
                playerALegsWon: playerALegsWon,
                playerBLegsWon: playerBLegsWon,
                wasBye: false
            )
            tournament.matches[matchIndex] = match
            tournament.status = .inProgress

            switch tournament.format {
            case .singleElimination:
                Self.advanceSingleElimination(&tournament)
            case .roundRobin:
                Self.updateRoundRobinStatus(&tournament)
            }
        }
    }

    func standings(for tournament: Tournament) -> [TournamentStanding] {
        Self.makeStandings(for: tournament)
    }

    private static func makeStandings(for tournament: Tournament) -> [TournamentStanding] {
        let participantsByID = Dictionary(uniqueKeysWithValues: tournament.participants.map { ($0.id, $0) })
        var wins: [UUID: Int] = [:]
        var losses: [UUID: Int] = [:]
        var legsWon: [UUID: Int] = [:]
        var legsLost: [UUID: Int] = [:]

        for match in tournament.matches {
            guard let result = match.result,
                  !result.wasBye,
                  let playerAID = match.playerAParticipantID,
                  let playerBID = match.playerBParticipantID else {
                continue
            }

            legsWon[playerAID, default: 0] += result.playerALegsWon
            legsLost[playerAID, default: 0] += result.playerBLegsWon
            legsWon[playerBID, default: 0] += result.playerBLegsWon
            legsLost[playerBID, default: 0] += result.playerALegsWon

            if result.winnerParticipantID == playerAID {
                wins[playerAID, default: 0] += 1
                losses[playerBID, default: 0] += 1
            } else {
                wins[playerBID, default: 0] += 1
                losses[playerAID, default: 0] += 1
            }
        }

        return tournament.participants.compactMap { participant in
            guard participantsByID[participant.id] != nil else { return nil }
            return TournamentStanding(
                id: participant.id,
                participant: participant,
                wins: wins[participant.id, default: 0],
                losses: losses[participant.id, default: 0],
                legsWon: legsWon[participant.id, default: 0],
                legsLost: legsLost[participant.id, default: 0]
            )
        }
        .sorted { lhs, rhs in
            if lhs.wins != rhs.wins { return lhs.wins > rhs.wins }
            if lhs.legDifference != rhs.legDifference { return lhs.legDifference > rhs.legDifference }
            if lhs.legsWon != rhs.legsWon { return lhs.legsWon > rhs.legsWon }
            return lhs.participant.name.localizedCaseInsensitiveCompare(rhs.participant.name) == .orderedAscending
        }
    }

    func roundMatches(for tournament: Tournament, round: TournamentRound) -> [TournamentMatch] {
        let matchesByID = Dictionary(uniqueKeysWithValues: tournament.matches.map { ($0.id, $0) })
        return round.matchIDs.compactMap { matchesByID[$0] }
    }

    func roundTitle(for match: TournamentMatch, in tournament: Tournament) -> String {
        tournament.rounds.first(where: { $0.index == match.roundIndex })?.title ?? "Round \(match.roundIndex + 1)"
    }

    private func updateTournament(id: UUID, mutation: (inout Tournament) -> Void) {
        guard let index = tournaments.firstIndex(where: { $0.id == id }) else { return }
        mutation(&tournaments[index])
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Tournament].self, from: data) else { return }
        tournaments = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(tournaments) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func makeTournament(
        name: String,
        format: TournamentFormat,
        participants: [TournamentParticipant],
        rules: TournamentMatchRules,
        roundRobinMode: TournamentRoundRobinMode
    ) -> Tournament {
        let tournamentID = UUID()
        switch format {
        case .singleElimination:
            let generated = makeSingleEliminationBracket(tournamentID: tournamentID, participants: participants)
            var tournament = Tournament(
                id: tournamentID,
                name: name,
                format: format,
                roundRobinMode: roundRobinMode,
                status: .inProgress,
                participants: participants,
                rules: rules,
                rounds: generated.rounds,
                matches: generated.matches
            )
            advanceSingleElimination(&tournament)
            return tournament
        case .roundRobin:
            let matches = makeRoundRobinMatches(
                tournamentID: tournamentID,
                participants: participants,
                mode: roundRobinMode
            )
            return Tournament(
                id: tournamentID,
                name: name,
                format: format,
                roundRobinMode: roundRobinMode,
                status: .inProgress,
                participants: participants,
                rules: rules,
                rounds: [],
                matches: matches
            )
        }
    }

    private static func makeRoundRobinMatches(
        tournamentID: UUID,
        participants: [TournamentParticipant],
        mode: TournamentRoundRobinMode
    ) -> [TournamentMatch] {
        var matches: [TournamentMatch] = []
        var slotIndex = 0
        let cycleCount = mode == .double ? 2 : 1

        for cycleIndex in 0..<cycleCount {
            for firstIndex in participants.indices {
                for secondIndex in participants.indices where secondIndex > firstIndex {
                    matches.append(
                        TournamentMatch(
                            tournamentID: tournamentID,
                            roundIndex: cycleIndex,
                            slotIndex: slotIndex,
                            playerAParticipantID: participants[firstIndex].id,
                            playerBParticipantID: participants[secondIndex].id,
                            status: .ready
                        )
                    )
                    slotIndex += 1
                }
            }
        }
        return matches
    }

    private static func makeSingleEliminationBracket(
        tournamentID: UUID,
        participants: [TournamentParticipant]
    ) -> (rounds: [TournamentRound], matches: [TournamentMatch]) {
        let bracketSize = max(2, nextPowerOfTwo(participants.count))
        let seededOrder = bracketSeedOrder(size: bracketSize)
        let seededParticipants = Dictionary(uniqueKeysWithValues: participants.enumerated().map { ($0.offset + 1, $0.element) })
        let firstRoundSlots = seededOrder.map { seededParticipants[$0]?.id }
        let roundCount = Int(log2(Double(bracketSize)))

        var rounds: [TournamentRound] = []
        var matches: [TournamentMatch] = []
        var previousRoundMatchIDs: [UUID] = []

        for roundIndex in 0..<roundCount {
            let matchCount = bracketSize / Int(pow(2.0, Double(roundIndex + 1)))
            var roundMatchIDs: [UUID] = []

            for slotIndex in 0..<matchCount {
                let matchID = UUID()
                let match: TournamentMatch

                if roundIndex == 0 {
                    let playerA = firstRoundSlots[slotIndex * 2]
                    let playerB = firstRoundSlots[slotIndex * 2 + 1]
                    let status: TournamentMatchStatus = (playerA != nil && playerB != nil) ? .ready : .pending
                    match = TournamentMatch(
                        id: matchID,
                        tournamentID: tournamentID,
                        roundIndex: roundIndex,
                        slotIndex: slotIndex,
                        playerAParticipantID: playerA,
                        playerBParticipantID: playerB,
                        status: status
                    )
                } else {
                    let sourceA = previousRoundMatchIDs[slotIndex * 2]
                    let sourceB = previousRoundMatchIDs[slotIndex * 2 + 1]
                    match = TournamentMatch(
                        id: matchID,
                        tournamentID: tournamentID,
                        roundIndex: roundIndex,
                        slotIndex: slotIndex,
                        playerASourceMatchID: sourceA,
                        playerBSourceMatchID: sourceB,
                        status: .pending
                    )
                }

                matches.append(match)
                roundMatchIDs.append(matchID)
            }

            rounds.append(
                TournamentRound(
                    index: roundIndex,
                    title: roundTitle(roundIndex: roundIndex, totalRounds: roundCount),
                    matchIDs: roundMatchIDs
                )
            )
            previousRoundMatchIDs = roundMatchIDs
        }

        return (rounds, matches)
    }

    private static func advanceSingleElimination(_ tournament: inout Tournament) {
        guard !tournament.rounds.isEmpty else { return }

        for _ in 0..<(tournament.rounds.count + 1) {
            var changed = false
            let resultsByMatchID = Dictionary(uniqueKeysWithValues: tournament.matches.map { ($0.id, $0) })

            for roundIndex in tournament.rounds.indices {
                let matchIDs = tournament.rounds[roundIndex].matchIDs
                for matchID in matchIDs {
                    guard let matchIndex = tournament.matches.firstIndex(where: { $0.id == matchID }) else { continue }
                    var match = tournament.matches[matchIndex]

                    if let sourceID = match.playerASourceMatchID,
                       let sourceMatch = resultsByMatchID[sourceID],
                       match.playerAParticipantID != sourceMatch.winnerParticipantID {
                        match.playerAParticipantID = sourceMatch.winnerParticipantID
                        if sourceMatch.winnerParticipantID != nil {
                            changed = true
                        }
                    }

                    if let sourceID = match.playerBSourceMatchID,
                       let sourceMatch = resultsByMatchID[sourceID],
                       match.playerBParticipantID != sourceMatch.winnerParticipantID {
                        match.playerBParticipantID = sourceMatch.winnerParticipantID
                        if sourceMatch.winnerParticipantID != nil {
                            changed = true
                        }
                    }

                    if match.result == nil {
                        if match.playerAParticipantID != nil, match.playerBParticipantID != nil {
                            let newStatus: TournamentMatchStatus = match.status == .inProgress ? .inProgress : .ready
                            if match.status != newStatus {
                                match.status = newStatus
                                changed = true
                            }
                        } else if let playerA = match.playerAParticipantID ?? match.playerBParticipantID {
                            let sourcesSettled = sourcesSettled(for: match, from: resultsByMatchID)
                            if sourcesSettled || roundIndex == 0 {
                                match.status = .bye
                                match.winnerParticipantID = playerA
                                match.result = TournamentMatchResult(
                                    completedAt: Date(),
                                    winnerParticipantID: playerA,
                                    playerALegsWon: match.playerAParticipantID == nil ? 0 : 1,
                                    playerBLegsWon: match.playerBParticipantID == nil ? 0 : 1,
                                    wasBye: true
                                )
                                changed = true
                            }
                        }
                    }

                    tournament.matches[matchIndex] = match
                }
            }

            if !changed {
                break
            }
        }

        if let finalRound = tournament.rounds.last,
           let finalMatchID = finalRound.matchIDs.first,
           let finalMatch = tournament.matches.first(where: { $0.id == finalMatchID }),
           let winnerParticipantID = finalMatch.winnerParticipantID {
            tournament.winnerParticipantID = winnerParticipantID
            tournament.status = .completed
            tournament.completedAt = finalMatch.result?.completedAt ?? Date()
        } else {
            tournament.status = .inProgress
            tournament.completedAt = nil
        }
    }

    private static func updateRoundRobinStatus(_ tournament: inout Tournament) {
        let allMatchesCompleted = tournament.matches.allSatisfy { $0.result != nil }
        tournament.status = allMatchesCompleted ? .completed : .inProgress
        if allMatchesCompleted {
            let standings = makeStandings(for: tournament)
            tournament.winnerParticipantID = standings.first?.participant.id
            tournament.completedAt = Date()
        } else {
            tournament.winnerParticipantID = nil
            tournament.completedAt = nil
        }
    }

    private static func sourcesSettled(for match: TournamentMatch, from matchesByID: [UUID: TournamentMatch]) -> Bool {
        let sourceMatches = [match.playerASourceMatchID, match.playerBSourceMatchID].compactMap { sourceID in
            sourceID.flatMap { matchesByID[$0] }
        }
        return !sourceMatches.isEmpty && sourceMatches.allSatisfy { $0.winnerParticipantID != nil }
    }

    private static func legsWon(for playerResult: PlayerGameResult, in record: GameRecord) -> Int {
        if !record.legs.isEmpty {
            return record.legs.filter { $0.winnerPlayerID == playerResult.id }.count
        }
        return playerResult.isWinner ? 1 : 0
    }

    private static func roundTitle(roundIndex: Int, totalRounds: Int) -> String {
        let remainingRounds = totalRounds - roundIndex
        switch remainingRounds {
        case 1:
            return "Final"
        case 2:
            return "Semifinals"
        case 3:
            return "Quarterfinals"
        default:
            let playerCount = Int(pow(2.0, Double(remainingRounds)))
            return "Round of \(playerCount)"
        }
    }

    private static func nextPowerOfTwo(_ value: Int) -> Int {
        var power = 1
        while power < value {
            power *= 2
        }
        return power
    }

    private static func bracketSeedOrder(size: Int) -> [Int] {
        guard size > 1 else { return [1] }
        var order = [1, 2]
        var currentSize = 2
        while currentSize < size {
            let nextSize = currentSize * 2
            order = order.flatMap { [$0, nextSize + 1 - $0] }
            currentSize = nextSize
        }
        return order
    }
}
