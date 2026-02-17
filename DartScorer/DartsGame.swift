import Foundation
import Combine

enum FinishRule: String, CaseIterable, Identifiable {
    case doubleOut = "Double Out"
    case singleOut = "Single Out"

    var id: String { rawValue }
}

enum StartScoreOption: Int, CaseIterable, Identifiable {
    case score501 = 501
    case score301 = 301

    var id: Int { rawValue }

    var label: String { "\(rawValue)" }
}

final class DartsGame: ObservableObject {
    @Published var players: [Player]
    @Published private(set) var activePlayerIndex: Int = 0
    @Published var currentTurn: Turn
    @Published private(set) var winner: Player?
    @Published private(set) var statusMessage: String?
    @Published private(set) var finishRule: FinishRule
    @Published private(set) var startingScore: Int
    @Published private(set) var lastTurnThrowsByPlayerID: [UUID: [Int]] = [:]
    @Published private(set) var pointsScoredByPlayerID: [UUID: Int] = [:]
    @Published private(set) var dartsThrownByPlayerID: [UUID: Int] = [:]

    private var history: [GameSnapshot] = []

    init(playerCount: Int = 2, startingScore: Int = 501, finishRule: FinishRule = .doubleOut) {
        let clampedCount = min(max(1, playerCount), 4)
        self.startingScore = startingScore
        self.finishRule = finishRule
        self.players = (1...clampedCount).map { Player(name: "Player \($0)", score: startingScore) }
        self.currentTurn = Turn(startingScore: startingScore)
        resetLegStats()
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

    var bestPossibleFinishLine: String {
        guard winner == nil else { return "" }
        let score = activePlayer.score
        let darts = remainingDarts
        guard darts > 0 else { return "No finish available" }

        if let route = bestFinishRoute(for: score, dartsRemaining: darts) {
            let text = route.map(throwNotation).joined(separator: " ")
            return "\(text)"
        }
        return "No finish available"
    }

    var hasBestPossibleFinish: Bool {
        bestPossibleFinishLine != "No finish available"
    }

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
        let proposedScore = player.score - throwValue.points

        appendThrowToHistory(playerID: player.id, points: throwValue.points)
        recordDartThrown(for: player.id)

        if isBust(proposedScore: proposedScore, throwValue: throwValue) {
            rollbackTurnScoringForBust(playerID: player.id)
            handleBust(for: player)
            return
        }

        addScoredPoints(throwValue.points, for: player.id)
        players[activePlayerIndex].score = proposedScore
        currentTurn.darts.append(throwValue)

        if proposedScore == 0 {
            winner = players[activePlayerIndex]
            statusMessage = "\(player.name) wins the leg."
            return
        }

        if currentTurn.dartsUsed == 3 {
            endTurn()
        }
    }

    func restartLeg() {
        startNewLeg(randomSequence: false)
    }

    func restartLegRandomSequence() {
        startNewLeg(randomSequence: true)
    }

    func newGame(playerNames: [String], finishRule: FinishRule, startingScore: Int) {
        history.removeAll()
        lastTurnThrowsByPlayerID.removeAll()
        resetLegStats()
        let preparedNames = sanitizeAndClampNames(playerNames)
        self.startingScore = startingScore
        self.finishRule = finishRule
        players = preparedNames.map { Player(name: $0, score: self.startingScore) }
        resetLegStats()
        winner = nil
        statusMessage = nil
        activePlayerIndex = 0
        currentTurn = Turn(startingScore: self.startingScore)
    }

    func newGame(playerNames: [String], finishRule: FinishRule) {
        newGame(playerNames: playerNames, finishRule: finishRule, startingScore: startingScore)
    }

    func newGame(playerCount: Int) {
        let clampedCount = min(max(1, playerCount), 4)
        let names = (1...clampedCount).map { index in
            players.indices.contains(index - 1) ? players[index - 1].name : "Player \(index)"
        }
        newGame(playerNames: names, finishRule: finishRule, startingScore: startingScore)
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
        lastTurnThrowsByPlayerID = previous.lastTurnThrowsByPlayerID
        pointsScoredByPlayerID = previous.pointsScoredByPlayerID
        dartsThrownByPlayerID = previous.dartsThrownByPlayerID
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

    private func isBust(proposedScore: Int, throwValue: DartThrow) -> Bool {
        if proposedScore < 0 { return true }
        if finishRule == .doubleOut {
            if proposedScore == 1 { return true }
            if proposedScore == 0 && !throwValue.isDouble { return true }
        }
        return false
    }

    private func handleBust(for player: Player) {
        players[activePlayerIndex].score = currentTurn.startingScore
        // statusMessage = "Bust for \(player.name)."
        endTurn()
    }

    private func endTurn() {
        activePlayerIndex = (activePlayerIndex + 1) % players.count
        let nextScore = players[activePlayerIndex].score
        currentTurn = Turn(startingScore: nextScore)
    }

    private func startNewLeg(randomSequence: Bool) {
        history.removeAll()
        lastTurnThrowsByPlayerID.removeAll()
        resetLegStats()
        winner = nil
        statusMessage = nil

        if randomSequence {
            let previousStarterID = players.first?.id
            players.shuffle()
            if players.count > 1, let previousStarterID, players.first?.id == previousStarterID {
                if let swapIndex = players.indices.dropFirst().randomElement() {
                    players.swapAt(players.startIndex, swapIndex)
                }
            }
        }

        activePlayerIndex = 0
        for index in players.indices {
            players[index].score = startingScore
        }
        currentTurn = Turn(startingScore: startingScore)
    }

    private func bestFinishRoute(for score: Int, dartsRemaining: Int) -> [DartThrow]? {
        guard score > 0 else { return nil }
        let candidates = checkoutCandidates

        for dartCount in 1...dartsRemaining {
            if let route = findRoute(
                target: score,
                dartsLeft: dartCount,
                candidates: candidates,
                current: []
            ) {
                return route
            }
        }
        return nil
    }

    private func findRoute(target: Int, dartsLeft: Int, candidates: [DartThrow], current: [DartThrow]) -> [DartThrow]? {
        guard target >= 0 else { return nil }
        guard dartsLeft > 0 else { return nil }

        for dart in candidates {
            let remaining = target - dart.points
            if remaining < 0 { continue }

            if dartsLeft == 1 {
                if remaining == 0 && canFinish(with: dart) {
                    return current + [dart]
                }
                continue
            }

            if let route = findRoute(
                target: remaining,
                dartsLeft: dartsLeft - 1,
                candidates: candidates,
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
}

private struct GameSnapshot {
    let players: [Player]
    let activePlayerIndex: Int
    let currentTurn: Turn
    let winner: Player?
    let statusMessage: String?
    let lastTurnThrowsByPlayerID: [UUID: [Int]]
    let pointsScoredByPlayerID: [UUID: Int]
    let dartsThrownByPlayerID: [UUID: Int]
}

private extension DartsGame {
    func sanitizeAndClampNames(_ names: [String]) -> [String] {
        let clamped = Array(names.prefix(4))
        let withFallbacks = clamped.enumerated().map { index, name in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Player \(index + 1)" : trimmed
        }
        return withFallbacks.isEmpty ? ["Player 1"] : withFallbacks
    }

    func recordSnapshot() {
        history.append(
            GameSnapshot(
                players: players,
                activePlayerIndex: activePlayerIndex,
                currentTurn: currentTurn,
                winner: winner,
                statusMessage: statusMessage,
                lastTurnThrowsByPlayerID: lastTurnThrowsByPlayerID,
                pointsScoredByPlayerID: pointsScoredByPlayerID,
                dartsThrownByPlayerID: dartsThrownByPlayerID
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
        for player in players {
            pointsScoredByPlayerID[player.id] = 0
            dartsThrownByPlayerID[player.id] = 0
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
}
