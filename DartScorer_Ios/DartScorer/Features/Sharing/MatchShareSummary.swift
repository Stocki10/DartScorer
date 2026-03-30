import Foundation

struct MatchShareSummary {
    struct Detail: Identifiable {
        let id: String
        let title: String
        let value: String

        init(title: String, value: String) {
            self.id = title
            self.title = title
            self.value = value
        }
    }

    struct PlayerLine: Identifiable {
        struct Stat: Identifiable {
            let id: String
            let title: String
            let value: String

            init(title: String, value: String) {
                self.id = title
                self.title = title
                self.value = value
            }
        }

        let id: UUID
        let name: String
        let isWinner: Bool
        let colorHex: String?
        let stats: [Stat]
    }

    let title: String
    let format: String
    let dateText: String
    let winnerName: String?
    let winnerColorHex: String?
    let details: [Detail]
    let playerLines: [PlayerLine]
    let footerText: String

    init(record: GameRecord, playerColors: [UUID: String?] = [:]) {
        title = "Just a Darts Scorer"
        dateText = record.date.formatted(date: .abbreviated, time: .omitted)
        footerText = L10n.string("Scored with Just a Darts Scorer")

        let localizedRule: String
        if record.finishRule == GameMode.practice.rawValue {
            localizedRule = record.practiceMode.map(L10n.localizedStoredRule) ?? L10n.localizedStoredRule(record.finishRule)
        } else {
            localizedRule = L10n.localizedStoredRule(record.finishRule)
        }
        format = record.startingScore > 0 ? "\(record.startingScore) • \(localizedRule)" : localizedRule
        winnerName = record.playerResults.first(where: \.isWinner)?.name
        winnerColorHex = record.playerResults.first(where: \.isWinner).flatMap { playerColors[$0.id] ?? nil }
        details = []

        let isCricket = record.finishRule == GameMode.cricket.rawValue
        let isPractice = record.finishRule == GameMode.practice.rawValue

        playerLines = record.playerResults.map { result in
            let stats: [PlayerLine.Stat]
            if isCricket || isPractice {
                stats = [
                    .init(title: L10n.string("Score"), value: "\(result.totalPointsScored)"),
                    .init(title: L10n.string("Darts"), value: "\(result.totalDartsThrown)"),
                    .init(title: L10n.string("Best Turn"), value: "\(result.highestTurnScore)")
                ]
            } else {
                var x01Stats: [PlayerLine.Stat] = [
                    .init(
                        title: L10n.string("Average"),
                        value: result.average > 0 ? L10n.decimal(result.average) : L10n.string("—")
                    )
                ]
                if result.highestCheckout > 0 {
                    x01Stats.append(.init(title: L10n.string("Best Checkout"), value: "\(result.highestCheckout)"))
                }
                if result.highestTurnScore > 0 {
                    x01Stats.append(.init(title: L10n.string("Best Turn"), value: "\(result.highestTurnScore)"))
                }
                stats = x01Stats
            }

            return PlayerLine(
                id: result.id,
                name: result.name,
                isWinner: result.isWinner,
                colorHex: playerColors[result.id] ?? nil,
                stats: stats
            )
        }
    }

    init(record: GameRecord, leg: LegRecord, playerColors: [UUID: String?] = [:]) {
        title = "Just a Darts Scorer"
        dateText = record.date.formatted(date: .abbreviated, time: .omitted)
        footerText = L10n.string("Scored with Just a Darts Scorer")

        let localizedRule: String
        if record.finishRule == GameMode.practice.rawValue {
            localizedRule = record.practiceMode.map(L10n.localizedStoredRule) ?? L10n.localizedStoredRule(record.finishRule)
        } else {
            localizedRule = L10n.localizedStoredRule(record.finishRule)
        }
        format = record.startingScore > 0 ? "\(record.startingScore) • \(localizedRule)" : localizedRule
        winnerName = leg.playerResults.first(where: { $0.playerID == leg.winnerPlayerID })?.name
        winnerColorHex = playerColors[leg.winnerPlayerID] ?? nil

        var legDetails: [Detail] = []
        if let checkoutScore = leg.checkoutScore {
            legDetails.append(.init(title: L10n.string("Checkout"), value: "\(checkoutScore)"))
        }
        if let winnerResult = leg.playerResults.first(where: { $0.playerID == leg.winnerPlayerID }) {
            legDetails.append(.init(title: L10n.string("Darts"), value: "\(winnerResult.dartsThrown)"))
        }
        if let route = leg.winningCheckoutRoute {
            legDetails.append(.init(title: L10n.string("Finish"), value: route))
        }
        details = legDetails

        playerLines = leg.playerResults.map { result in
            var stats: [PlayerLine.Stat] = []
            if result.average > 0 {
                stats.append(.init(title: L10n.string("Average"), value: L10n.decimal(result.average)))
            } else {
                stats.append(.init(title: L10n.string("Average"), value: L10n.string("—")))
            }
            stats.append(.init(title: L10n.string("Darts"), value: "\(result.dartsThrown)"))
            if result.highestTurnScore > 0 {
                stats.append(.init(title: L10n.string("Best Turn"), value: "\(result.highestTurnScore)"))
            }

            return PlayerLine(
                id: result.playerID,
                name: result.name,
                isWinner: result.playerID == leg.winnerPlayerID,
                colorHex: playerColors[result.playerID] ?? nil,
                stats: stats
            )
        }
    }

    var textSummary: String {
        var lines = [title, format, dateText]
        if let winnerName {
            lines.append(L10n.format("Winner: %@", winnerName))
        }
        if !details.isEmpty {
            lines.append(details.map { "\($0.title): \($0.value)" }.joined(separator: " • "))
        }
        for line in playerLines {
            let statLine = line.stats.map { "\($0.title) \($0.value)" }.joined(separator: " • ")
            lines.append("\(line.name): \(statLine)")
        }
        lines.append(footerText)
        return lines.joined(separator: "\n")
    }
}
