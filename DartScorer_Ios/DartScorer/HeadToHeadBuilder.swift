import Foundation

struct HeadToHeadOpponentSummary: Identifiable {
    let opponentProfileID: UUID
    let opponentName: String
    let opponentColorHex: String
    let matchesPlayed: Int
    let wins: Int
    let losses: Int
    let winRate: Double
    let playerAverage: Double?
    let opponentAverage: Double?
    let playerFirstNineAverage: Double?
    let opponentFirstNineAverage: Double?
    let playerBestCheckout: Int?
    let opponentBestCheckout: Int?
    let lastPlayedDate: Date
    let currentStreak: Int

    var id: UUID { opponentProfileID }

    var recordText: String {
        "\(wins)–\(losses)"
    }

    var streakLabel: String? {
        guard currentStreak != 0 else { return nil }
        return currentStreak > 0 ? "W\(currentStreak)" : "L\(-currentStreak)"
    }
}

struct HeadToHeadMeetingSummary: Identifiable {
    let recordID: UUID
    let record: GameRecord
    let date: Date
    let modeLabel: String
    let winnerName: String
    let playerWon: Bool

    var id: UUID { recordID }
}

struct HeadToHeadDetailSnapshot {
    let opponent: HeadToHeadOpponentSummary
    let recentMeetings: [HeadToHeadMeetingSummary]
}

struct HeadToHeadSnapshot {
    let opponents: [HeadToHeadOpponentSummary]
    let hasCompetitiveHistory: Bool

    var hasOpponents: Bool {
        !opponents.isEmpty
    }
}

private struct HeadToHeadOutcome {
    let date: Date
    let playerWon: Bool
}

private struct HeadToHeadAccumulator {
    let opponentProfile: PlayerProfile
    var matchesPlayed = 0
    var wins = 0
    var losses = 0
    var playerTotalDarts = 0
    var playerTotalPoints = 0
    var playerTotalFirstNinePoints = 0
    var playerTotalFirstNineDarts = 0
    var opponentTotalDarts = 0
    var opponentTotalPoints = 0
    var opponentTotalFirstNinePoints = 0
    var opponentTotalFirstNineDarts = 0
    var playerBestCheckout = 0
    var opponentBestCheckout = 0
    var lastPlayedDate: Date = .distantPast
    var outcomes: [HeadToHeadOutcome] = []
}

enum HeadToHeadBuilder {
    nonisolated static func makeSnapshot(
        for profile: PlayerProfile,
        profiles: [PlayerProfile],
        records: [GameRecord],
        filter: GameRecordFilter,
        now: Date = Date()
    ) -> HeadToHeadSnapshot {
        let profilesByID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        let hasCompetitiveHistory = !eligibleCompetitiveRecords(
            for: profile.id,
            profilesByID: profilesByID,
            records: records,
            filter: GameRecordFilter(),
            now: now
        ).isEmpty

        let competitiveRecords = eligibleCompetitiveRecords(
            for: profile.id,
            profilesByID: profilesByID,
            records: records,
            filter: filter.dateOnlyScope,
            now: now
        )

        var accumulators: [UUID: HeadToHeadAccumulator] = [:]

        for (record, playerResult, opponentProfile, opponentResult, playerWon) in competitiveRecords {
            var accumulator = accumulators[opponentProfile.id] ?? HeadToHeadAccumulator(opponentProfile: opponentProfile)
            accumulator.matchesPlayed += 1
            accumulator.wins += playerWon ? 1 : 0
            accumulator.losses += playerWon ? 0 : 1
            accumulator.playerTotalDarts += playerResult.totalDartsThrown
            accumulator.playerTotalPoints += playerResult.totalPointsScored
            accumulator.playerTotalFirstNinePoints += playerResult.totalFirstNinePoints
            accumulator.playerTotalFirstNineDarts += playerResult.totalFirstNineDarts
            accumulator.opponentTotalDarts += opponentResult.totalDartsThrown
            accumulator.opponentTotalPoints += opponentResult.totalPointsScored
            accumulator.opponentTotalFirstNinePoints += opponentResult.totalFirstNinePoints
            accumulator.opponentTotalFirstNineDarts += opponentResult.totalFirstNineDarts
            accumulator.playerBestCheckout = max(accumulator.playerBestCheckout, playerResult.highestCheckout)
            accumulator.opponentBestCheckout = max(accumulator.opponentBestCheckout, opponentResult.highestCheckout)
            accumulator.lastPlayedDate = max(accumulator.lastPlayedDate, record.date)
            accumulator.outcomes.append(HeadToHeadOutcome(date: record.date, playerWon: playerWon))
            accumulators[opponentProfile.id] = accumulator
        }

        let opponents = accumulators.values
            .map(makeSummary(from:))
            .sorted {
                if $0.matchesPlayed != $1.matchesPlayed {
                    return $0.matchesPlayed > $1.matchesPlayed
                }
                return $0.lastPlayedDate > $1.lastPlayedDate
            }

        return HeadToHeadSnapshot(
            opponents: opponents,
            hasCompetitiveHistory: hasCompetitiveHistory
        )
    }

    nonisolated static func makeDetailSnapshot(
        for profile: PlayerProfile,
        opponentSummary: HeadToHeadOpponentSummary,
        profiles: [PlayerProfile],
        records: [GameRecord],
        filter: GameRecordFilter,
        now: Date = Date()
    ) -> HeadToHeadDetailSnapshot {
        let profilesByID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        let meetings = eligibleCompetitiveRecords(
            for: profile.id,
            profilesByID: profilesByID,
            records: records,
            filter: filter.dateOnlyScope,
            now: now
        )
        .filter { $0.2.id == opponentSummary.opponentProfileID }
        .sorted { $0.0.date > $1.0.date }
        .prefix(5)
            .map { record, _, _, _, playerWon in
                HeadToHeadMeetingSummary(
                    recordID: record.id,
                    record: record,
                    date: record.date,
                    modeLabel: record.competitiveModeLabel,
                    winnerName: record.playerResults.first(where: { $0.isWinner })?.name ?? L10n.string("—"),
                    playerWon: playerWon
                )
            }

        return HeadToHeadDetailSnapshot(
            opponent: opponentSummary,
            recentMeetings: Array(meetings)
        )
    }

    nonisolated private static func eligibleCompetitiveRecords(
        for profileID: UUID,
        profilesByID: [UUID: PlayerProfile],
        records: [GameRecord],
        filter: GameRecordFilter,
        now: Date
    ) -> [(GameRecord, PlayerGameResult, PlayerProfile, PlayerGameResult, Bool)] {
        filter.filteredRecords(from: records, now: now)
            .filter { $0.isCompetitiveRecord }
            .flatMap { record in
                directOpponents(in: record, for: profileID, profilesByID: profilesByID)
            }
    }

    nonisolated private static func directOpponents(
        in record: GameRecord,
        for profileID: UUID,
        profilesByID: [UUID: PlayerProfile]
    ) -> [(GameRecord, PlayerGameResult, PlayerProfile, PlayerGameResult, Bool)] {
        guard let playerResult = record.playerResults.first(where: { $0.profileID == profileID }) else {
            return []
        }

        return record.playerResults.compactMap { opponentResult in
            guard let opponentProfileID = opponentResult.profileID,
                  opponentProfileID != profileID,
                  let opponentProfile = profilesByID[opponentProfileID],
                  playerResult.isWinner != opponentResult.isWinner else {
                return nil
            }

            return (record, playerResult, opponentProfile, opponentResult, playerResult.isWinner)
        }
    }

    nonisolated private static func makeSummary(from accumulator: HeadToHeadAccumulator) -> HeadToHeadOpponentSummary {
        let sortedOutcomes = accumulator.outcomes.sorted { $0.date > $1.date }
        return HeadToHeadOpponentSummary(
            opponentProfileID: accumulator.opponentProfile.id,
            opponentName: accumulator.opponentProfile.name,
            opponentColorHex: accumulator.opponentProfile.colorHex,
            matchesPlayed: accumulator.matchesPlayed,
            wins: accumulator.wins,
            losses: accumulator.losses,
            winRate: accumulator.matchesPlayed > 0 ? Double(accumulator.wins) / Double(accumulator.matchesPlayed) : 0,
            playerAverage: average(points: accumulator.playerTotalPoints, darts: accumulator.playerTotalDarts),
            opponentAverage: average(points: accumulator.opponentTotalPoints, darts: accumulator.opponentTotalDarts),
            playerFirstNineAverage: average(points: accumulator.playerTotalFirstNinePoints, darts: accumulator.playerTotalFirstNineDarts),
            opponentFirstNineAverage: average(points: accumulator.opponentTotalFirstNinePoints, darts: accumulator.opponentTotalFirstNineDarts),
            playerBestCheckout: accumulator.playerBestCheckout > 0 ? accumulator.playerBestCheckout : nil,
            opponentBestCheckout: accumulator.opponentBestCheckout > 0 ? accumulator.opponentBestCheckout : nil,
            lastPlayedDate: accumulator.lastPlayedDate,
            currentStreak: currentStreak(in: sortedOutcomes)
        )
    }

    nonisolated private static func average(points: Int, darts: Int) -> Double? {
        guard darts > 0 else { return nil }
        return (Double(points) / Double(darts)) * 3.0
    }

    nonisolated private static func currentStreak(in outcomes: [HeadToHeadOutcome]) -> Int {
        guard let firstOutcome = outcomes.first else { return 0 }

        var streak = 0
        for outcome in outcomes {
            if outcome.playerWon == firstOutcome.playerWon {
                streak += 1
            } else {
                break
            }
        }

        return firstOutcome.playerWon ? streak : -streak
    }
}

private extension GameRecord {
    nonisolated var isCompetitiveRecord: Bool {
        isX01Record || isCricketRecord
    }

    nonisolated var competitiveModeLabel: String {
        isCricketRecord ? GameMode.cricket.label : GameMode.x01.label
    }
}

private extension GameRecordFilter {
    nonisolated var dateOnlyScope: GameRecordFilter {
        GameRecordFilter(
            mode: .all,
            date: date,
            customStartDate: customStartDate,
            customEndDate: customEndDate
        )
    }
}
