import Foundation
import Combine

enum FinishRule: String, CaseIterable, Identifiable {
    case doubleOut = "Double Out"
    case singleOut = "Single Out"

    var id: String { rawValue }
}

final class DartsGame: ObservableObject {
    @Published var players: [Player]
    @Published private(set) var activePlayerIndex: Int = 0
    @Published var currentTurn: Turn
    @Published private(set) var winner: Player?
    @Published private(set) var statusMessage: String?
    @Published private(set) var finishRule: FinishRule
    @Published private(set) var lastTurnThrowsByPlayerID: [UUID: [Int]] = [:]

    private let startingScore: Int
    private var history: [GameSnapshot] = []

    init(playerCount: Int = 2, startingScore: Int = 501, finishRule: FinishRule = .doubleOut) {
        let clampedCount = min(max(1, playerCount), 4)
        self.startingScore = startingScore
        self.finishRule = finishRule
        self.players = (1...clampedCount).map { Player(name: "Player \($0)", score: startingScore) }
        self.currentTurn = Turn(startingScore: startingScore)
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

        if isBust(proposedScore: proposedScore, throwValue: throwValue) {
            handleBust(for: player)
            return
        }

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
        history.removeAll()
        lastTurnThrowsByPlayerID.removeAll()
        winner = nil
        statusMessage = nil
        activePlayerIndex = 0

        for index in players.indices {
            players[index].score = startingScore
        }

        currentTurn = Turn(startingScore: startingScore)
    }

    func newGame(playerNames: [String], finishRule: FinishRule) {
        let preparedNames = sanitizeAndClampNames(playerNames)
        history.removeAll()
        lastTurnThrowsByPlayerID.removeAll()
        self.finishRule = finishRule
        players = preparedNames.map { Player(name: $0, score: startingScore) }
        winner = nil
        statusMessage = nil
        activePlayerIndex = 0
        currentTurn = Turn(startingScore: startingScore)
    }

    func newGame(playerCount: Int) {
        let clampedCount = min(max(1, playerCount), 4)
        let names = (1...clampedCount).map { index in
            players.indices.contains(index - 1) ? players[index - 1].name : "Player \(index)"
        }
        newGame(playerNames: names, finishRule: finishRule)
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
    }

    func lastTurnThrows(for player: Player) -> [Int] {
        lastTurnThrowsByPlayerID[player.id] ?? []
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
        statusMessage = "Bust for \(player.name)."
        endTurn()
    }

    private func endTurn() {
        activePlayerIndex = (activePlayerIndex + 1) % players.count
        let nextScore = players[activePlayerIndex].score
        currentTurn = Turn(startingScore: nextScore)
    }
}

private struct GameSnapshot {
    let players: [Player]
    let activePlayerIndex: Int
    let currentTurn: Turn
    let winner: Player?
    let statusMessage: String?
    let lastTurnThrowsByPlayerID: [UUID: [Int]]
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
                lastTurnThrowsByPlayerID: lastTurnThrowsByPlayerID
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
}
