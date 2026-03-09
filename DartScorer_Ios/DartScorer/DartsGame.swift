import Foundation
import Combine

enum FinishRule: String, CaseIterable, Identifiable {
    case doubleOut = "Double Out"
    case singleOut = "Single Out"

    var id: String { rawValue }
}

enum StartScoreOption: Int, CaseIterable, Identifiable {
    case score101 = 101
    case score301 = 301
    case score501 = 501
    case score701 = 701
    case score1001 = 1001

    var id: Int { rawValue }

    var label: String { "\(rawValue)" }
}

enum InRule: String, CaseIterable, Identifiable {
    case `default` = "Default"
    case doubleIn = "Double In"

    var id: String { rawValue }
}

final class DartsGame: ObservableObject {
    @Published var players: [Player]
    @Published private(set) var activePlayerIndex: Int = 0
    @Published var currentTurn: Turn
    @Published private(set) var winner: Player?
    @Published private(set) var statusMessage: String?
    @Published private(set) var finishRule: FinishRule
    @Published private(set) var inRule: InRule
    @Published private(set) var startingScore: Int
    @Published private(set) var setModeEnabled: Bool
    @Published private(set) var legsToWin: Int
    @Published private(set) var legsWonByPlayerID: [UUID: Int] = [:]
    @Published private(set) var setWinner: Player?
    @Published private(set) var lastTurnThrowsByPlayerID: [UUID: [Int]] = [:]
    @Published private(set) var pointsScoredByPlayerID: [UUID: Int] = [:]
    @Published private(set) var dartsThrownByPlayerID: [UUID: Int] = [:]
    @Published private(set) var hasOpenedLegByPlayerID: [UUID: Bool] = [:]
    @Published private(set) var highestTurnScoreByPlayerID: [UUID: Int] = [:]
    @Published private(set) var checkoutOpportunitiesByPlayerID: [UUID: Int] = [:]
    @Published private(set) var checkoutConversionsByPlayerID: [UUID: Int] = [:]
    @Published private(set) var highestCheckoutByPlayerID: [UUID: Int] = [:]

    private var history: [GameSnapshot] = []

    init(
        playerCount: Int = 2,
        startingScore: Int = 501,
        finishRule: FinishRule = .doubleOut,
        inRule: InRule = .default,
        setModeEnabled: Bool = false,
        legsToWin: Int = 3
    ) {
        let clampedCount = min(max(2, playerCount), 5)
        self.startingScore = startingScore
        self.finishRule = finishRule
        self.inRule = inRule
        self.setModeEnabled = setModeEnabled
        self.legsToWin = max(1, legsToWin)
        self.players = (1...clampedCount).map { Player(name: "Player \($0)", score: startingScore) }
        self.currentTurn = Turn(startingScore: startingScore, openedAtTurnStart: inRule == .default)
        resetSetState()
        resetOpenState()
        resetLegStats()
        recordCheckoutOpportunityForCurrentPlayer()
    }

    var activePlayer: Player {
        players[activePlayerIndex]
    }

    var remainingDarts: Int {
        currentTurn.dartsRemaining
    }

    var canUndo: Bool {
        !history.isEmpty
    }

    var bestPossibleFinishLine: String? {
        bestPossibleFinishLines.first
    }

    var bestPossibleFinishLines: [String] {
        guard winner == nil, remainingDarts > 0 else { return [] }
        let score = activePlayer.score
        guard !Self.bogeyScores.contains(score) else { return [] }
        return findTopRoutes(for: score, dartsRemaining: remainingDarts, maxRoutes: 3)
    }

    var isCurrentScoreBogey: Bool {
        guard winner == nil else { return false }
        return Self.bogeyScores.contains(activePlayer.score)
    }

    private static let bogeyScores: Set<Int> = [169, 168, 166, 165, 163, 162, 159]

    var isLegInProgress: Bool {
        guard winner == nil else { return false }
        return dartsThrownByPlayerID.values.contains { $0 > 0 }
    }

    func submitThrow(segment: DartSegment, multiplier: DartMultiplier) {
        guard winner == nil else { return }
        guard remainingDarts > 0 else { return }

        guard let throwValue = DartThrow(segment: segment, multiplier: multiplier) else {
            statusMessage = "Invalid throw."
            return
        }

        recordSnapshot()
        statusMessage = nil

        let player = activePlayer
        let effectivePoints = effectivePointsForThrow(throwValue, playerID: player.id)
        let proposedScore = player.score - effectivePoints

        appendThrowToHistory(playerID: player.id, points: throwValue.points)
        recordDartThrown(for: player.id)

        if isBust(proposedScore: proposedScore, throwValue: throwValue, effectivePoints: effectivePoints) {
            rollbackTurnScoringForBust(playerID: player.id)
            hasOpenedLegByPlayerID[player.id] = currentTurn.openedAtTurnStart
            handleBust(for: player)
            return
        }

        addScoredPoints(effectivePoints, for: player.id)
        players[activePlayerIndex].score = proposedScore
        currentTurn.darts.append(throwValue)

        if proposedScore == 0 {
            let winningPlayer = players[activePlayerIndex]
            let checkoutScore = currentTurn.startingScore
            updateHighestTurnScore(for: winningPlayer.id, score: checkoutScore)
            highestCheckoutByPlayerID[winningPlayer.id] = max(highestCheckoutByPlayerID[winningPlayer.id] ?? 0, checkoutScore)
            checkoutConversionsByPlayerID[winningPlayer.id, default: 0] += 1
            if setModeEnabled {
                legsWonByPlayerID[winningPlayer.id, default: 0] += 1
                if (legsWonByPlayerID[winningPlayer.id] ?? 0) >= legsToWin {
                    winner = winningPlayer
                    setWinner = winningPlayer
                    statusMessage = "\(winningPlayer.name) wins the set."
                } else {
                    startNewLeg(randomSequence: false, invertedSequence: true)
                }
            } else {
                winner = winningPlayer
                statusMessage = "\(winningPlayer.name) wins the leg."
            }
            return
        }

        if currentTurn.dartsUsed == 3 {
            updateHighestTurnScore(
                for: players[activePlayerIndex].id,
                score: currentTurn.startingScore - players[activePlayerIndex].score
            )
            endTurn()
        }
    }

    func restartLeg() {
        startNewLeg(randomSequence: false, invertedSequence: false)
    }

    func restartLegRandomSequence() {
        startNewLeg(randomSequence: true, invertedSequence: false)
    }

    func restartLegInvertedSequence() {
        startNewLeg(randomSequence: false, invertedSequence: true)
    }

    func newGame(playerNames: [String], finishRule: FinishRule, startingScore: Int) {
        newGame(
            playerNames: playerNames,
            finishRule: finishRule,
            inRule: inRule,
            startingScore: startingScore,
            setModeEnabled: setModeEnabled,
            legsToWin: legsToWin
        )
    }

    func newGame(
        playerNames: [String],
        finishRule: FinishRule,
        inRule: InRule,
        startingScore: Int,
        setModeEnabled: Bool,
        legsToWin: Int
    ) {
        history.removeAll()
        lastTurnThrowsByPlayerID.removeAll()
        let preparedNames = sanitizeAndClampNames(playerNames)
        self.startingScore = startingScore
        self.finishRule = finishRule
        self.inRule = inRule
        self.setModeEnabled = setModeEnabled
        self.legsToWin = max(1, legsToWin)
        players = preparedNames.map { Player(name: $0, score: self.startingScore) }
        resetSetState()
        resetOpenState()
        resetLegStats()
        winner = nil
        setWinner = nil
        statusMessage = nil
        activePlayerIndex = 0
        currentTurn = Turn(
            startingScore: self.startingScore,
            openedAtTurnStart: hasOpenedLegByPlayerID[players[activePlayerIndex].id] ?? (inRule == .default)
        )
        recordCheckoutOpportunityForCurrentPlayer()
    }

    func newGame(playerNames: [String], finishRule: FinishRule) {
        newGame(
            playerNames: playerNames,
            finishRule: finishRule,
            inRule: inRule,
            startingScore: startingScore,
            setModeEnabled: setModeEnabled,
            legsToWin: legsToWin
        )
    }

    func newGame(
        players inputPlayers: [Player],
        finishRule: FinishRule,
        inRule: InRule,
        startingScore: Int,
        setModeEnabled: Bool,
        legsToWin: Int
    ) {
        history.removeAll()
        lastTurnThrowsByPlayerID.removeAll()
        self.startingScore = startingScore
        self.finishRule = finishRule
        self.inRule = inRule
        self.setModeEnabled = setModeEnabled
        self.legsToWin = max(1, legsToWin)
        players = inputPlayers.map { p in
            var player = p
            player.score = startingScore
            return player
        }
        resetSetState()
        resetOpenState()
        resetLegStats()
        winner = nil
        setWinner = nil
        statusMessage = nil
        activePlayerIndex = 0
        currentTurn = Turn(
            startingScore: self.startingScore,
            openedAtTurnStart: hasOpenedLegByPlayerID[players[activePlayerIndex].id] ?? (inRule == .default)
        )
        recordCheckoutOpportunityForCurrentPlayer()
    }

    func newGame(playerCount: Int) {
        let clampedCount = min(max(2, playerCount), 5)
        let names = (1...clampedCount).map { index in
            players.indices.contains(index - 1) ? players[index - 1].name : "Player \(index)"
        }
        newGame(
            playerNames: names,
            finishRule: finishRule,
            inRule: inRule,
            startingScore: startingScore,
            setModeEnabled: setModeEnabled,
            legsToWin: legsToWin
        )
    }

    func updatePlayerName(index: Int, name: String) {
        guard players.indices.contains(index) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        players[index].name = trimmed.isEmpty ? "Player \(index + 1)" : trimmed
    }

    func undoLastThrow() {
        guard let previous = history.popLast() else { return }
        players = previous.players
        activePlayerIndex = previous.activePlayerIndex
        currentTurn = previous.currentTurn
        winner = previous.winner
        statusMessage = previous.statusMessage
        inRule = previous.inRule
        setModeEnabled = previous.setModeEnabled
        legsToWin = previous.legsToWin
        legsWonByPlayerID = previous.legsWonByPlayerID
        setWinner = previous.setWinner
        lastTurnThrowsByPlayerID = previous.lastTurnThrowsByPlayerID
        pointsScoredByPlayerID = previous.pointsScoredByPlayerID
        dartsThrownByPlayerID = previous.dartsThrownByPlayerID
        hasOpenedLegByPlayerID = previous.hasOpenedLegByPlayerID
        highestTurnScoreByPlayerID = previous.highestTurnScoreByPlayerID
        checkoutOpportunitiesByPlayerID = previous.checkoutOpportunitiesByPlayerID
        checkoutConversionsByPlayerID = previous.checkoutConversionsByPlayerID
        highestCheckoutByPlayerID = previous.highestCheckoutByPlayerID
    }

    func lastTurnThrows(for player: Player) -> [Int] {
        lastTurnThrowsByPlayerID[player.id] ?? []
    }

    func legAverage(for player: Player) -> Double? {
        let darts = dartsThrownByPlayerID[player.id] ?? 0
        guard darts > 0 else { return nil }
        let points = pointsScoredByPlayerID[player.id] ?? 0
        return (Double(points) / Double(darts)) * 3.0
    }

    func legsWon(for player: Player) -> Int {
        legsWonByPlayerID[player.id] ?? 0
    }

    func buildGameRecord() -> GameRecord {
        let results = players.map { player in
            let darts = dartsThrownByPlayerID[player.id] ?? 0
            let points = pointsScoredByPlayerID[player.id] ?? 0
            let avg = darts > 0 ? (Double(points) / Double(darts)) * 3.0 : 0.0
            let highest = highestTurnScoreByPlayerID[player.id] ?? 0
            let opportunities = checkoutOpportunitiesByPlayerID[player.id] ?? 0
            let conversions = checkoutConversionsByPlayerID[player.id] ?? 0
            let checkoutPct: Double? = opportunities > 0 ? Double(conversions) / Double(opportunities) : nil
            let highestCheckout = highestCheckoutByPlayerID[player.id] ?? 0
            return PlayerGameResult(
                id: player.id,
                name: player.name,
                average: avg,
                highestTurnScore: highest,
                checkoutPercentage: checkoutPct,
                isWinner: winner?.id == player.id,
                profileID: player.profileID,
                totalDartsThrown: darts,
                totalPointsScored: points,
                highestCheckout: highestCheckout
            )
        }
        return GameRecord(
            id: UUID(),
            date: Date(),
            startingScore: startingScore,
            finishRule: finishRule.rawValue,
            playerResults: results
        )
    }

    private func isBust(proposedScore: Int, throwValue: DartThrow, effectivePoints: Int) -> Bool {
        if effectivePoints == 0 { return false }
        if proposedScore < 0 { return true }
        if finishRule == .doubleOut {
            if proposedScore == 1 { return true }
            if proposedScore == 0 && !throwValue.isDouble { return true }
        }
        return false
    }

    private func handleBust(for player: Player) {
        players[activePlayerIndex].score = currentTurn.startingScore
        endTurn()
    }

    private func endTurn() {
        activePlayerIndex = (activePlayerIndex + 1) % players.count
        let nextScore = players[activePlayerIndex].score
        let nextPlayer = players[activePlayerIndex]
        currentTurn = Turn(
            startingScore: nextScore,
            openedAtTurnStart: hasOpenedLegByPlayerID[nextPlayer.id] ?? (inRule == .default)
        )
        recordCheckoutOpportunityForCurrentPlayer()
    }

    private func startNewLeg(randomSequence: Bool, invertedSequence: Bool) {
        history.removeAll()
        lastTurnThrowsByPlayerID.removeAll()
        resetLegStats()
        winner = nil
        statusMessage = nil

        if invertedSequence {
            players.reverse()
        } else if randomSequence {
            let previousStarterID = players.first?.id
            players.shuffle()
            if players.count > 1, let previousStarterID, players.first?.id == previousStarterID {
                if let swapIndex = players.indices.dropFirst().randomElement() {
                    players.swapAt(players.startIndex, swapIndex)
                }
            }
        }

        activePlayerIndex = 0
        resetOpenState()
        for index in players.indices {
            players[index].score = startingScore
        }
        currentTurn = Turn(
            startingScore: startingScore,
            openedAtTurnStart: hasOpenedLegByPlayerID[players[activePlayerIndex].id] ?? (inRule == .default)
        )
        recordCheckoutOpportunityForCurrentPlayer()
    }

    private func findTopRoutes(for score: Int, dartsRemaining: Int, maxRoutes: Int) -> [String] {
        guard score > 0 else { return [] }
        let candidates = checkoutCandidates
        var notations: [String] = []
        var usedFinisherPoints: Set<Int> = []

        while notations.count < maxRoutes {
            var found = false
            for dartCount in 1...dartsRemaining {
                if let route = findRouteExcluding(
                    target: score,
                    dartsLeft: dartCount,
                    candidates: candidates,
                    excludedFinisherPoints: usedFinisherPoints,
                    current: []
                ) {
                    usedFinisherPoints.insert(route.last!.points)
                    notations.append(route.map(throwNotation).joined(separator: " "))
                    found = true
                    break
                }
            }
            if !found { break }
        }
        return notations
    }

    private func findRouteExcluding(
        target: Int,
        dartsLeft: Int,
        candidates: [DartThrow],
        excludedFinisherPoints: Set<Int>,
        current: [DartThrow]
    ) -> [DartThrow]? {
        guard target >= 0, dartsLeft > 0 else { return nil }

        for dart in candidates {
            let remaining = target - dart.points
            if remaining < 0 { continue }

            if dartsLeft == 1 {
                if remaining == 0 && canFinish(with: dart) && !excludedFinisherPoints.contains(dart.points) {
                    return current + [dart]
                }
                continue
            }

            if let route = findRouteExcluding(
                target: remaining,
                dartsLeft: dartsLeft - 1,
                candidates: candidates,
                excludedFinisherPoints: excludedFinisherPoints,
                current: current + [dart]
            ) {
                return route
            }
        }
        return nil
    }

    private func canFinish(with dart: DartThrow) -> Bool {
        switch finishRule {
        case .singleOut:
            return true
        case .doubleOut:
            return dart.isDouble
        }
    }

    private func throwNotation(_ dart: DartThrow) -> String {
        switch dart.segment {
        case .number(let value):
            switch dart.multiplier {
            case .single:
                return "\(value)"
            case .double:
                return "D\(value)"
            case .triple:
                return "T\(value)"
            }
        case .bull:
            return dart.multiplier == .double ? "Bull" : "25"
        }
    }

    private var checkoutCandidates: [DartThrow] {
        var result: [DartThrow] = []

        for value in stride(from: 20, through: 1, by: -1) {
            if let triple = DartThrow(segment: .number(value), multiplier: .triple) {
                result.append(triple)
            }
        }
        for value in stride(from: 20, through: 1, by: -1) {
            if let double = DartThrow(segment: .number(value), multiplier: .double) {
                result.append(double)
            }
        }
        for value in stride(from: 20, through: 1, by: -1) {
            if let single = DartThrow(segment: .number(value), multiplier: .single) {
                result.append(single)
            }
        }
        if let bull = DartThrow(segment: .bull, multiplier: .double) {
            result.append(bull)
        }
        if let outerBull = DartThrow(segment: .bull, multiplier: .single) {
            result.append(outerBull)
        }

        return result
    }

    private func effectivePointsForThrow(_ throwValue: DartThrow, playerID: UUID) -> Int {
        if inRule == .doubleIn {
            if hasOpenedLegByPlayerID[playerID] == true {
                return throwValue.points
            }
            if throwValue.isDouble {
                hasOpenedLegByPlayerID[playerID] = true
                return throwValue.points
            }
            return 0
        }
        return throwValue.points
    }
}

private struct GameSnapshot {
    let players: [Player]
    let activePlayerIndex: Int
    let currentTurn: Turn
    let winner: Player?
    let statusMessage: String?
    let inRule: InRule
    let setModeEnabled: Bool
    let legsToWin: Int
    let legsWonByPlayerID: [UUID: Int]
    let setWinner: Player?
    let lastTurnThrowsByPlayerID: [UUID: [Int]]
    let pointsScoredByPlayerID: [UUID: Int]
    let dartsThrownByPlayerID: [UUID: Int]
    let hasOpenedLegByPlayerID: [UUID: Bool]
    let highestTurnScoreByPlayerID: [UUID: Int]
    let checkoutOpportunitiesByPlayerID: [UUID: Int]
    let checkoutConversionsByPlayerID: [UUID: Int]
    let highestCheckoutByPlayerID: [UUID: Int]
}

private extension DartsGame {
    func sanitizeAndClampNames(_ names: [String]) -> [String] {
        let clamped = Array(names.prefix(5))
        let withFallbacks = clamped.enumerated().map { index, name in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Player \(index + 1)" : trimmed
        }
        if withFallbacks.isEmpty { return ["Player 1", "Player 2"] }
        if withFallbacks.count == 1 { return withFallbacks + ["Player 2"] }
        return withFallbacks
    }

    func recordSnapshot() {
        history.append(
            GameSnapshot(
                players: players,
                activePlayerIndex: activePlayerIndex,
                currentTurn: currentTurn,
                winner: winner,
                statusMessage: statusMessage,
                inRule: inRule,
                setModeEnabled: setModeEnabled,
                legsToWin: legsToWin,
                legsWonByPlayerID: legsWonByPlayerID,
                setWinner: setWinner,
                lastTurnThrowsByPlayerID: lastTurnThrowsByPlayerID,
                pointsScoredByPlayerID: pointsScoredByPlayerID,
                dartsThrownByPlayerID: dartsThrownByPlayerID,
                hasOpenedLegByPlayerID: hasOpenedLegByPlayerID,
                highestTurnScoreByPlayerID: highestTurnScoreByPlayerID,
                checkoutOpportunitiesByPlayerID: checkoutOpportunitiesByPlayerID,
                checkoutConversionsByPlayerID: checkoutConversionsByPlayerID,
                highestCheckoutByPlayerID: highestCheckoutByPlayerID
            )
        )
    }

    func appendThrowToHistory(playerID: UUID, points: Int) {
        var values = lastTurnThrowsByPlayerID[playerID] ?? []
        values.append(points)
        if values.count > 3 {
            values = Array(values.suffix(3))
        }
        lastTurnThrowsByPlayerID[playerID] = values
    }

    func resetLegStats() {
        pointsScoredByPlayerID = [:]
        dartsThrownByPlayerID = [:]
        highestTurnScoreByPlayerID = [:]
        checkoutOpportunitiesByPlayerID = [:]
        checkoutConversionsByPlayerID = [:]
        highestCheckoutByPlayerID = [:]
        for player in players {
            pointsScoredByPlayerID[player.id] = 0
            dartsThrownByPlayerID[player.id] = 0
            highestTurnScoreByPlayerID[player.id] = 0
            checkoutOpportunitiesByPlayerID[player.id] = 0
            checkoutConversionsByPlayerID[player.id] = 0
            highestCheckoutByPlayerID[player.id] = 0
        }
    }

    func recordDartThrown(for playerID: UUID) {
        dartsThrownByPlayerID[playerID, default: 0] += 1
    }

    func addScoredPoints(_ points: Int, for playerID: UUID) {
        pointsScoredByPlayerID[playerID, default: 0] += points
    }

    func rollbackTurnScoringForBust(playerID: UUID) {
        let turnPoints = currentTurn.darts.reduce(0) { $0 + $1.points }
        pointsScoredByPlayerID[playerID, default: 0] -= turnPoints
    }

    func resetSetState() {
        legsWonByPlayerID = [:]
        for player in players {
            legsWonByPlayerID[player.id] = 0
        }
        setWinner = nil
    }

    func resetOpenState() {
        hasOpenedLegByPlayerID = [:]
        for player in players {
            hasOpenedLegByPlayerID[player.id] = (inRule == .default)
        }
    }

    func updateHighestTurnScore(for playerID: UUID, score: Int) {
        guard score > 0 else { return }
        highestTurnScoreByPlayerID[playerID] = max(highestTurnScoreByPlayerID[playerID] ?? 0, score)
    }

    func recordCheckoutOpportunityForCurrentPlayer() {
        let score = players[activePlayerIndex].score
        guard score > 1, score <= 170 else { return }
        checkoutOpportunitiesByPlayerID[players[activePlayerIndex].id, default: 0] += 1
    }
}
