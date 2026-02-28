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

    private var history: [GameSnapshot] = []

    init(
        playerCount: Int = 2,
        startingScore: Int = 501,
        finishRule: FinishRule = .doubleOut,
        inRule: InRule = .default,
        setModeEnabled: Bool = false,
        legsToWin: Int = 3
    ) {
        let clampedCount = min(max(1, playerCount), 4)
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

    func newGame(playerCount: Int) {
        let clampedCount = min(max(1, playerCount), 4)
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
        // statusMessage = "Bust for \(player.name)."
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
                inRule: inRule,
                setModeEnabled: setModeEnabled,
                legsToWin: legsToWin,
                legsWonByPlayerID: legsWonByPlayerID,
                setWinner: setWinner,
                lastTurnThrowsByPlayerID: lastTurnThrowsByPlayerID,
                pointsScoredByPlayerID: pointsScoredByPlayerID,
                dartsThrownByPlayerID: dartsThrownByPlayerID,
                hasOpenedLegByPlayerID: hasOpenedLegByPlayerID
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
}
