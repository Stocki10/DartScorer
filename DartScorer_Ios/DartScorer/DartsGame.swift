import Foundation
import Combine

enum GameMode: String, CaseIterable, Identifiable, Codable {
    case x01 = "X01"
    case practice = "Practice"
    case cricket = "Cricket"

    nonisolated var id: String { rawValue }

    nonisolated var label: String {
        switch self {
        case .x01:
            return "X01"
        case .practice:
            return L10n.string("Practice")
        case .cricket:
            return L10n.string("Cricket")
        }
    }
}

enum PracticeMode: String, CaseIterable, Identifiable, Codable {
    case scoringDrill = "Scoring Drill"
    case checkoutPractice = "Checkout Practice"
    case doublesPractice = "Doubles Practice"
    case aroundTheClock = "Around the Clock"
    case first9Challenge = "First 9 Challenge"
    case pressureFinishes = "Pressure Finishes"
    case streakMode = "Streak Mode"
    case randomTarget = "Random Target"

    nonisolated var id: String { rawValue }

    nonisolated var label: String { L10n.string(rawValue) }

    nonisolated var supportsCompetitiveGoal: Bool {
        switch self {
        case .checkoutPractice, .doublesPractice, .pressureFinishes, .streakMode, .randomTarget:
            return true
        case .scoringDrill, .aroundTheClock, .first9Challenge:
            return false
        }
    }
}

enum PracticeCallTarget: Codable, Equatable {
    case number(Int, DartMultiplier)
    case bull(DartMultiplier)

    nonisolated var label: String {
        switch self {
        case .number(let value, let multiplier):
            switch multiplier {
            case .single: return "\(value)"
            case .double: return "D\(value)"
            case .triple: return "T\(value)"
            }
        case .bull(let multiplier):
            return multiplier == .double ? L10n.string("Bull") : "25"
        }
    }

    func matches(segment: DartSegment, multiplier: DartMultiplier) -> Bool {
        switch self {
        case .number(let value, let expectedMultiplier):
            return segment == .number(value) && multiplier == expectedMultiplier
        case .bull(let expectedMultiplier):
            return segment == .bull && multiplier == expectedMultiplier
        }
    }
}

enum CricketTarget: Int, CaseIterable, Identifiable, Codable {
    case twenty = 20
    case nineteen = 19
    case eighteen = 18
    case seventeen = 17
    case sixteen = 16
    case fifteen = 15
    case bull = 25

    nonisolated var id: Int { rawValue }

    nonisolated var label: String {
        self == .bull ? L10n.string("Bull") : "\(rawValue)"
    }
}

enum FinishRule: String, CaseIterable, Identifiable, Codable {
    case doubleOut = "Double Out"
    case singleOut = "Single Out"

    nonisolated var id: String { rawValue }

    nonisolated var label: String {
        switch self {
        case .doubleOut:
            return L10n.string("Double Out")
        case .singleOut:
            return L10n.string("Single Out")
        }
    }
}

enum StartScoreOption: Int, CaseIterable, Identifiable {
    case score101 = 101
    case score301 = 301
    case score501 = 501
    case score701 = 701
    case score1001 = 1001

    nonisolated var id: Int { rawValue }

    nonisolated var label: String { "\(rawValue)" }
}

enum InRule: String, CaseIterable, Identifiable, Codable {
    case `default` = "Default"
    case doubleIn = "Double In"

    nonisolated var id: String { rawValue }

    nonisolated var label: String {
        switch self {
        case .default:
            return L10n.string("Default")
        case .doubleIn:
            return L10n.string("Double In")
        }
    }
}

final class DartsGame: ObservableObject {
    @Published var players: [Player]
    @Published private(set) var activePlayerIndex: Int = 0
    @Published var currentTurn: Turn
    @Published private(set) var winner: Player?
    @Published private(set) var statusMessage: String?
    @Published private(set) var gameMode: GameMode
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
    @Published private(set) var cricketMarksByPlayerID: [UUID: [CricketTarget: Int]] = [:]
    @Published private(set) var cricketScoreByPlayerID: [UUID: Int] = [:]
    @Published private(set) var practiceMode: PracticeMode
    @Published private(set) var practiceCompetitiveEnabled: Bool
    @Published private(set) var practiceSuccessesToWin: Int
    @Published private(set) var practiceTargetValueByPlayerID: [UUID: Int] = [:]
    @Published private(set) var practiceProgressByPlayerID: [UUID: Int] = [:]
    @Published private(set) var practiceCallTargetByPlayerID: [UUID: PracticeCallTarget] = [:]
    @Published private(set) var practiceCurrentStreakByPlayerID: [UUID: Int] = [:]

    private var history: [GameSnapshot] = []
    private var completedLegs: [LegRecord] = []
    private var currentLegStartingPlayerID: UUID?
    private var scoredDartPointsHistoryByPlayerID: [UUID: [Int]] = [:]
    private var bustCountByPlayerID: [UUID: Int] = [:]
    private var currentLegVisitsByPlayerID: [UUID: [LegPlayerVisit]] = [:]

    init(
        playerCount: Int = 2,
        gameMode: GameMode = .x01,
        practiceMode: PracticeMode = .scoringDrill,
        practiceCompetitiveEnabled: Bool = false,
        practiceSuccessesToWin: Int = 5,
        startingScore: Int = 501,
        finishRule: FinishRule = .doubleOut,
        inRule: InRule = .default,
        setModeEnabled: Bool = false,
        legsToWin: Int = 3
    ) {
        let minimumPlayers = gameMode == .x01 ? 2 : 1
        let clampedCount = min(max(minimumPlayers, playerCount), 5)
        let initialScore = gameMode == .x01 ? startingScore : 0
        self.gameMode = gameMode
        self.practiceMode = practiceMode
        self.practiceCompetitiveEnabled = gameMode == .practice ? practiceCompetitiveEnabled : false
        self.practiceSuccessesToWin = max(1, practiceSuccessesToWin)
        self.startingScore = initialScore
        self.finishRule = finishRule
        self.inRule = inRule
        self.setModeEnabled = gameMode == .x01 ? setModeEnabled : false
        self.legsToWin = max(1, legsToWin)
        self.players = (1...clampedCount).map { Player(name: "Player \($0)", score: initialScore) }
        self.currentTurn = Turn(startingScore: initialScore, openedAtTurnStart: inRule == .default)
        resetSetState()
        resetOpenState()
        resetLegStats()
        currentLegStartingPlayerID = players.first?.id
        recordCheckoutOpportunityForCurrentPlayer()
        updatePracticeStatusMessage()
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
        guard gameMode == .x01 else { return [] }
        guard winner == nil, remainingDarts > 0 else { return [] }
        let score = activePlayer.score
        guard !Self.bogeyScores.contains(score) else { return [] }
        return findTopRoutes(for: score, dartsRemaining: remainingDarts, maxRoutes: 3)
    }

    var isCurrentScoreBogey: Bool {
        guard gameMode == .x01 else { return false }
        guard winner == nil else { return false }
        return Self.bogeyScores.contains(activePlayer.score)
    }

    private static let bogeyScores: Set<Int> = [169, 168, 166, 165, 163, 162, 159]

    var isLegInProgress: Bool {
        guard winner == nil else { return false }
        if gameMode == .cricket {
            return cricketMarksByPlayerID.values.contains { marks in
                marks.values.contains { $0 > 0 }
            }
        }
        return dartsThrownByPlayerID.values.contains { $0 > 0 }
    }

    var cricketTargets: [CricketTarget] {
        CricketTarget.allCases
    }

    func cricketMarks(for player: Player, target: CricketTarget) -> Int {
        cricketMarksByPlayerID[player.id]?[target] ?? 0
    }

    func cricketScore(for player: Player) -> Int {
        cricketScoreByPlayerID[player.id] ?? 0
    }

    func allCricketTargetsClosed(for player: Player) -> Bool {
        cricketTargets.allSatisfy { cricketMarks(for: player, target: $0) >= 3 }
    }

    func submitThrow(segment: DartSegment, multiplier: DartMultiplier) {
        if gameMode == .practice {
            submitPracticeThrow(segment: segment, multiplier: multiplier)
            return
        } else if gameMode == .cricket {
            submitCricketThrow(segment: segment, multiplier: multiplier)
            return
        }
        guard winner == nil else { return }
        guard remainingDarts > 0 else { return }

        guard let throwValue = DartThrow(segment: segment, multiplier: multiplier) else {
            statusMessage = L10n.string("Invalid throw.")
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
            appendScoredDartPoints(0, for: player.id)
            rollbackTurnScoringForBust(playerID: player.id)
            rollbackFirstNineScoringForBust(playerID: player.id)
            hasOpenedLegByPlayerID[player.id] = currentTurn.openedAtTurnStart
            handleBust(for: player)
            return
        }

        appendScoredDartPoints(effectivePoints, for: player.id)
        addScoredPoints(effectivePoints, for: player.id)
        var updatedPlayers = players
        updatedPlayers[activePlayerIndex].score = proposedScore
        players = updatedPlayers
        currentTurn.darts.append(throwValue)

        if proposedScore == 0 {
            let winningPlayer = players[activePlayerIndex]
            let checkoutScore = currentTurn.startingScore
            updateHighestTurnScore(for: winningPlayer.id, score: checkoutScore)
            highestCheckoutByPlayerID[winningPlayer.id] = max(highestCheckoutByPlayerID[winningPlayer.id] ?? 0, checkoutScore)
            checkoutConversionsByPlayerID[winningPlayer.id, default: 0] += 1
            recordVisit(for: winningPlayer.id, score: checkoutScore, isBust: false)
            recordCompletedLeg(
                winner: winningPlayer,
                checkoutScore: checkoutScore,
                checkoutRoute: currentTurn.darts.map(throwNotation).joined(separator: " ")
            )
            if setModeEnabled {
                legsWonByPlayerID[winningPlayer.id, default: 0] += 1
                if (legsWonByPlayerID[winningPlayer.id] ?? 0) >= legsToWin {
                    winner = winningPlayer
                    setWinner = winningPlayer
                    statusMessage = L10n.format("%@ wins the set.", winningPlayer.name)
                } else {
                    startNewLeg(randomSequence: false, invertedSequence: true)
                }
            } else {
                winner = winningPlayer
                statusMessage = L10n.format("%@ wins the leg.", winningPlayer.name)
            }
            return
        }

        if currentTurn.dartsUsed == 3 {
            let turnScore = currentTurn.startingScore - players[activePlayerIndex].score
            updateHighestTurnScore(
                for: players[activePlayerIndex].id,
                score: turnScore
            )
            recordVisit(for: players[activePlayerIndex].id, score: turnScore, isBust: false)
            endTurn()
        }
    }

    func submitQuickScore(_ score: Int) {
        if gameMode == .practice {
            submitPracticeQuickScore(score)
            return
        }

        guard gameMode == .x01 else {
            statusMessage = L10n.string("Quick score is unavailable in Cricket.")
            return
        }
        guard winner == nil else { return }
        guard currentTurn.dartsUsed == 0 else {
            statusMessage = L10n.string("Finish the current visit in Throws mode.")
            return
        }
        guard (1...180).contains(score) else {
            statusMessage = L10n.string("Quick scores must be between 1 and 180.")
            return
        }
        guard !(inRule == .doubleIn && currentTurn.openedAtTurnStart == false) else {
            statusMessage = L10n.string("Finish the opening double in Throws mode.")
            return
        }

        recordSnapshot()
        statusMessage = nil

        let player = activePlayer
        let proposedScore = player.score - score
        let checkoutRoute = proposedScore == 0 ? bestPossibleFinishLine : nil
        let checkoutDartsUsed = checkoutRoute.map(Self.dartCountForCheckoutRoute)
        let dartsUsed = checkoutDartsUsed ?? 3

        lastTurnThrowsByPlayerID[player.id] = [score]

        if proposedScore < 0 || (finishRule == .doubleOut && proposedScore == 1) || (proposedScore == 0 && checkoutRoute == nil) {
            recordDartsThrown(count: 3, for: player.id)
            appendQuickScoredDartPoints(0, dartsUsed: 3, for: player.id)
            handleBust(for: player)
            return
        }

        recordDartsThrown(count: dartsUsed, for: player.id)
        appendQuickScoredDartPoints(score, dartsUsed: dartsUsed, for: player.id)
        addScoredPoints(score, for: player.id)

        var updatedPlayers = players
        updatedPlayers[activePlayerIndex].score = proposedScore
        players = updatedPlayers

        if proposedScore == 0 {
            let winningPlayer = players[activePlayerIndex]
            let checkoutScore = currentTurn.startingScore
            updateHighestTurnScore(for: winningPlayer.id, score: checkoutScore)
            highestCheckoutByPlayerID[winningPlayer.id] = max(highestCheckoutByPlayerID[winningPlayer.id] ?? 0, checkoutScore)
            checkoutConversionsByPlayerID[winningPlayer.id, default: 0] += 1
            recordVisit(for: winningPlayer.id, score: checkoutScore, isBust: false)
            recordCompletedLeg(
                winner: winningPlayer,
                checkoutScore: checkoutScore,
                checkoutRoute: checkoutRoute
            )
            if setModeEnabled {
                legsWonByPlayerID[winningPlayer.id, default: 0] += 1
                if (legsWonByPlayerID[winningPlayer.id] ?? 0) >= legsToWin {
                    winner = winningPlayer
                    setWinner = winningPlayer
                    statusMessage = L10n.format("%@ wins the set.", winningPlayer.name)
                } else {
                    startNewLeg(randomSequence: false, invertedSequence: true)
                }
            } else {
                winner = winningPlayer
                statusMessage = L10n.format("%@ wins the leg.", winningPlayer.name)
            }
            return
        }

        updateHighestTurnScore(for: player.id, score: score)
        recordVisit(for: player.id, score: score, isBust: false)
        endTurn()
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
            gameMode: gameMode,
            practiceMode: practiceMode,
            practiceCompetitiveEnabled: practiceCompetitiveEnabled,
            practiceSuccessesToWin: practiceSuccessesToWin,
            finishRule: finishRule,
            inRule: inRule,
            startingScore: startingScore,
            setModeEnabled: setModeEnabled,
            legsToWin: legsToWin
        )
    }

    func newGame(
        playerNames: [String],
        gameMode: GameMode,
        practiceMode: PracticeMode,
        practiceCompetitiveEnabled: Bool,
        practiceSuccessesToWin: Int,
        finishRule: FinishRule,
        inRule: InRule,
        startingScore: Int,
        setModeEnabled: Bool,
        legsToWin: Int
    ) {
        history.removeAll()
        completedLegs.removeAll()
        currentLegStartingPlayerID = nil
        lastTurnThrowsByPlayerID.removeAll()
        let preparedNames = sanitizeAndClampNames(playerNames, for: gameMode)
        self.gameMode = gameMode
        self.practiceMode = practiceMode
        self.practiceCompetitiveEnabled = gameMode == .practice ? practiceCompetitiveEnabled : false
        self.practiceSuccessesToWin = max(1, practiceSuccessesToWin)
        self.startingScore = gameMode == .x01 ? startingScore : 0
        self.finishRule = finishRule
        self.inRule = inRule
        self.setModeEnabled = gameMode == .x01 ? setModeEnabled : false
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
        currentLegStartingPlayerID = players.first?.id
        recordCheckoutOpportunityForCurrentPlayer()
        initializePracticeState()
        updatePracticeStatusMessage()
    }

    func newGame(playerNames: [String], finishRule: FinishRule) {
        newGame(
            playerNames: playerNames,
            gameMode: gameMode,
            practiceMode: practiceMode,
            practiceCompetitiveEnabled: practiceCompetitiveEnabled,
            practiceSuccessesToWin: practiceSuccessesToWin,
            finishRule: finishRule,
            inRule: inRule,
            startingScore: startingScore,
            setModeEnabled: setModeEnabled,
            legsToWin: legsToWin
        )
    }

    func newGame(
        players inputPlayers: [Player],
        gameMode: GameMode,
        practiceMode: PracticeMode,
        practiceCompetitiveEnabled: Bool,
        practiceSuccessesToWin: Int,
        finishRule: FinishRule,
        inRule: InRule,
        startingScore: Int,
        setModeEnabled: Bool,
        legsToWin: Int
    ) {
        history.removeAll()
        completedLegs.removeAll()
        currentLegStartingPlayerID = nil
        lastTurnThrowsByPlayerID.removeAll()
        self.gameMode = gameMode
        self.practiceMode = practiceMode
        self.practiceCompetitiveEnabled = gameMode == .practice ? practiceCompetitiveEnabled : false
        self.practiceSuccessesToWin = max(1, practiceSuccessesToWin)
        self.startingScore = gameMode == .x01 ? startingScore : 0
        self.finishRule = finishRule
        self.inRule = inRule
        self.setModeEnabled = gameMode == .x01 ? setModeEnabled : false
        self.legsToWin = max(1, legsToWin)
        players = inputPlayers.map { p in
            var player = p
            player.score = self.startingScore
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
        currentLegStartingPlayerID = players.first?.id
        recordCheckoutOpportunityForCurrentPlayer()
        initializePracticeState()
        updatePracticeStatusMessage()
    }

    func newGame(playerCount: Int) {
        let minimumPlayers = gameMode == .x01 ? 2 : 1
        let clampedCount = min(max(minimumPlayers, playerCount), 5)
        let names = (1...clampedCount).map { index in
            players.indices.contains(index - 1) ? players[index - 1].name : "Player \(index)"
        }
        newGame(
            playerNames: names,
            gameMode: gameMode,
            practiceMode: practiceMode,
            practiceCompetitiveEnabled: practiceCompetitiveEnabled,
            practiceSuccessesToWin: practiceSuccessesToWin,
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
        var updatedPlayers = players
        updatedPlayers[index].name = trimmed.isEmpty ? "Player \(index + 1)" : trimmed
        players = updatedPlayers
    }

    func undoLastThrow() {
        guard let previous = history.popLast() else { return }
        players = previous.players
        activePlayerIndex = previous.activePlayerIndex
        currentTurn = previous.currentTurn
        winner = previous.winner
        statusMessage = previous.statusMessage
        inRule = previous.inRule
        gameMode = previous.gameMode
        practiceMode = previous.practiceMode
        practiceCompetitiveEnabled = previous.practiceCompetitiveEnabled
        practiceSuccessesToWin = previous.practiceSuccessesToWin
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
        cricketMarksByPlayerID = previous.cricketMarksByPlayerID
        cricketScoreByPlayerID = previous.cricketScoreByPlayerID
        practiceTargetValueByPlayerID = previous.practiceTargetValueByPlayerID
        practiceProgressByPlayerID = previous.practiceProgressByPlayerID
        practiceCallTargetByPlayerID = previous.practiceCallTargetByPlayerID
        practiceCurrentStreakByPlayerID = previous.practiceCurrentStreakByPlayerID
        completedLegs = previous.completedLegs
        currentLegStartingPlayerID = previous.currentLegStartingPlayerID
        scoredDartPointsHistoryByPlayerID = previous.scoredDartPointsHistoryByPlayerID
        bustCountByPlayerID = previous.bustCountByPlayerID
        currentLegVisitsByPlayerID = previous.currentLegVisitsByPlayerID
    }

    func lastTurnThrows(for player: Player) -> [Int] {
        lastTurnThrowsByPlayerID[player.id] ?? []
    }

    func legAverage(for player: Player) -> Double? {
        let darts = dartsThrownByPlayerID[player.id] ?? 0
        guard darts > 0 else { return nil }
        let points = gameMode == .cricket
            ? (cricketScoreByPlayerID[player.id] ?? 0)
            : (pointsScoredByPlayerID[player.id] ?? 0)
        return (Double(points) / Double(darts)) * 3.0
    }

    func legsWon(for player: Player) -> Int {
        legsWonByPlayerID[player.id] ?? 0
    }

    func buildGameRecord() -> GameRecord {
        let results = players.map { player in
            let legResults = completedLegs.compactMap { leg in
                leg.playerResults.first { $0.playerID == player.id }
            }
            let legVisits = completedLegs.flatMap { leg in
                leg.playerVisits.filter { $0.playerID == player.id }
            }

            let darts = legResults.isEmpty
                ? (dartsThrownByPlayerID[player.id] ?? 0)
                : legResults.reduce(0) { $0 + $1.dartsThrown }
            let points = legResults.isEmpty
                ? (gameMode == .cricket
                    ? (cricketScoreByPlayerID[player.id] ?? 0)
                    : (pointsScoredByPlayerID[player.id] ?? 0))
                : legResults.reduce(0) { $0 + $1.pointsScored }
            let avg = darts > 0 ? (Double(points) / Double(darts)) * 3.0 : 0.0
            let highest = legResults.isEmpty
                ? (highestTurnScoreByPlayerID[player.id] ?? 0)
                : legResults.reduce(0) { max($0, $1.highestTurnScore) }
            let highestScore = legVisits.isEmpty
                ? highest
                : legVisits.reduce(0) { max($0, $1.score) }
            let opportunities = legResults.isEmpty
                ? (checkoutOpportunitiesByPlayerID[player.id] ?? 0)
                : legResults.reduce(0) { $0 + $1.checkoutAttempts }
            let conversions = legResults.isEmpty
                ? (checkoutConversionsByPlayerID[player.id] ?? 0)
                : legResults.reduce(0) { $0 + $1.checkoutHits }
            let checkoutPct: Double? = opportunities > 0 ? Double(conversions) / Double(opportunities) : nil
            let highestCheckout = legResults.isEmpty
                ? (highestCheckoutByPlayerID[player.id] ?? 0)
                : legResults.reduce(0) { max($0, $1.highestFinish) }
            let totalFirstNinePoints = legResults.reduce(0) { $0 + $1.firstNinePoints }
            let totalFirstNineDarts = legResults.reduce(0) { $0 + $1.firstNineDarts }
            let firstNineAverage = totalFirstNineDarts > 0
                ? (Double(totalFirstNinePoints) / Double(totalFirstNineDarts)) * 3.0
                : nil
            let score180Count = legVisits.filter { !$0.isBust && $0.score == 180 }.count
            let score140PlusCount = legVisits.filter { !$0.isBust && $0.score >= 140 && $0.score < 180 }.count
            return PlayerGameResult(
                id: player.id,
                name: player.name,
                average: avg,
                firstNineAverage: firstNineAverage,
                highestTurnScore: highest,
                highestScore: highestScore,
                checkoutPercentage: checkoutPct,
                checkoutAttempts: opportunities,
                checkoutHits: conversions,
                isWinner: winner?.id == player.id,
                profileID: player.profileID,
                totalDartsThrown: darts,
                totalPointsScored: points,
                highestCheckout: highestCheckout,
                score180Count: score180Count,
                score140PlusCount: score140PlusCount,
                totalFirstNinePoints: totalFirstNinePoints,
                totalFirstNineDarts: totalFirstNineDarts
            )
        }
        return GameRecord(
            id: UUID(),
            date: Date(),
            startingScore: startingScore,
            finishRule: gameMode == .x01 ? finishRule.rawValue : gameMode.rawValue,
            practiceMode: gameMode == .practice ? practiceMode.rawValue : nil,
            playerResults: results,
            legs: completedLegs
        )
    }

    private func isBust(proposedScore: Int, throwValue: DartThrow, effectivePoints: Int) -> Bool {
        guard gameMode == .x01 else { return false }
        if effectivePoints == 0 { return false }
        if proposedScore < 0 { return true }
        if finishRule == .doubleOut {
            if proposedScore == 1 { return true }
            if proposedScore == 0 && !throwValue.isDouble { return true }
        }
        return false
    }

    private func handleBust(for player: Player) {
        bustCountByPlayerID[player.id, default: 0] += 1
        recordVisit(for: player.id, score: 0, isBust: true)
        var updatedPlayers = players
        updatedPlayers[activePlayerIndex].score = currentTurn.startingScore
        players = updatedPlayers
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
        updatePracticeStatusMessage()
    }

    private func startNewLeg(randomSequence: Bool, invertedSequence: Bool) {
        history.removeAll()
        lastTurnThrowsByPlayerID.removeAll()
        if !(setModeEnabled && winner == nil && setWinner == nil) {
            completedLegs.removeAll()
        }
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
        players = players.map { p in var q = p; q.score = startingScore; return q }
        initializePracticeState()
        currentLegStartingPlayerID = players.first?.id
        currentTurn = Turn(
            startingScore: startingScore,
            openedAtTurnStart: hasOpenedLegByPlayerID[players[activePlayerIndex].id] ?? (inRule == .default)
        )
        recordCheckoutOpportunityForCurrentPlayer()
        updatePracticeStatusMessage()
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
        guard gameMode == .x01 else { return false }
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

    private static let practiceCheckoutCandidates = [41, 50, 60, 70, 81, 90, 95, 100, 101, 110, 121]
    private static let aroundTheClockTargets = Array(1...20) + [25]
    private static let practiceCallTargets: [PracticeCallTarget] = {
        let highSingles = [16, 17, 18, 19, 20].map { PracticeCallTarget.number($0, .single) }
        let commonDoubles = [8, 10, 12, 16, 18, 20].map { PracticeCallTarget.number($0, .double) }
        let triples = [17, 18, 19, 20].map { PracticeCallTarget.number($0, .triple) }
        return highSingles + commonDoubles + triples + [.bull(.double)]
    }()

    private static func randomCheckoutTarget() -> Int {
        practiceCheckoutCandidates.randomElement() ?? 101
    }

    private static func randomDoubleTarget() -> Int {
        ([25] + Array(1...20)).randomElement() ?? 20
    }

    private static func randomCalledTarget() -> PracticeCallTarget {
        practiceCallTargets.randomElement() ?? .number(20, .triple)
    }

    private static func matchesAroundTheClockTarget(_ target: Int, segment: DartSegment) -> Bool {
        if target == 25 { return segment == .bull }
        if case .number(let value) = segment {
            return value == target
        }
        return false
    }

    private func effectivePointsForThrow(_ throwValue: DartThrow, playerID: UUID) -> Int {
        guard gameMode == .x01 else { return throwValue.points }
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

// MARK: - Network Snapshot

extension DartsGame {
    func buildNetworkSnapshot() -> NetworkGameState {
        NetworkGameState(
            players: players,
            activePlayerIndex: activePlayerIndex,
            currentTurn: currentTurn,
            winner: winner,
            setWinner: setWinner,
            statusMessage: statusMessage,
            gameMode: gameMode.rawValue,
            practiceMode: practiceMode.rawValue,
            practiceCompetitiveEnabled: practiceCompetitiveEnabled,
            practiceSuccessesToWin: practiceSuccessesToWin,
            finishRule: finishRule.rawValue,
            inRule: inRule.rawValue,
            startingScore: startingScore,
            setModeEnabled: setModeEnabled,
            legsToWin: legsToWin,
            legsWonByPlayerID: legsWonByPlayerID.stringKeyed,
            lastTurnThrowsByPlayerID: lastTurnThrowsByPlayerID.stringKeyed,
            pointsScoredByPlayerID: pointsScoredByPlayerID.stringKeyed,
            dartsThrownByPlayerID: dartsThrownByPlayerID.stringKeyed,
            hasOpenedLegByPlayerID: hasOpenedLegByPlayerID.stringKeyed,
            highestTurnScoreByPlayerID: highestTurnScoreByPlayerID.stringKeyed,
            checkoutOpportunitiesByPlayerID: checkoutOpportunitiesByPlayerID.stringKeyed,
            checkoutConversionsByPlayerID: checkoutConversionsByPlayerID.stringKeyed,
            highestCheckoutByPlayerID: highestCheckoutByPlayerID.stringKeyed,
            cricketMarksByPlayerID: cricketMarksByPlayerID.stringKeyedCricketMarks,
            cricketScoreByPlayerID: cricketScoreByPlayerID.stringKeyed,
            practiceTargetValueByPlayerID: practiceTargetValueByPlayerID.stringKeyed,
            practiceProgressByPlayerID: practiceProgressByPlayerID.stringKeyed,
            practiceCallTargetByPlayerID: practiceCallTargetByPlayerID.stringKeyed,
            practiceCurrentStreakByPlayerID: practiceCurrentStreakByPlayerID.stringKeyed
        )
    }

    func applySnapshot(_ state: NetworkGameState) {
        history.removeAll()
        players = state.players
        activePlayerIndex = state.activePlayerIndex
        currentTurn = state.currentTurn
        winner = state.winner
        setWinner = state.setWinner
        statusMessage = state.statusMessage
        gameMode = GameMode(rawValue: state.gameMode) ?? .x01
        practiceMode = PracticeMode(rawValue: state.practiceMode) ?? .scoringDrill
        practiceCompetitiveEnabled = state.practiceCompetitiveEnabled
        practiceSuccessesToWin = max(1, state.practiceSuccessesToWin)
        finishRule = FinishRule(rawValue: state.finishRule) ?? .doubleOut
        inRule = InRule(rawValue: state.inRule) ?? .default
        startingScore = state.startingScore
        setModeEnabled = state.setModeEnabled
        legsToWin = state.legsToWin
        legsWonByPlayerID = state.legsWonByPlayerID.uuidKeyed()
        lastTurnThrowsByPlayerID = state.lastTurnThrowsByPlayerID.uuidKeyed()
        pointsScoredByPlayerID = state.pointsScoredByPlayerID.uuidKeyed()
        dartsThrownByPlayerID = state.dartsThrownByPlayerID.uuidKeyed()
        hasOpenedLegByPlayerID = state.hasOpenedLegByPlayerID.uuidKeyed()
        highestTurnScoreByPlayerID = state.highestTurnScoreByPlayerID.uuidKeyed()
        checkoutOpportunitiesByPlayerID = state.checkoutOpportunitiesByPlayerID.uuidKeyed()
        checkoutConversionsByPlayerID = state.checkoutConversionsByPlayerID.uuidKeyed()
        highestCheckoutByPlayerID = state.highestCheckoutByPlayerID.uuidKeyed()
        cricketMarksByPlayerID = state.cricketMarksByPlayerID.uuidKeyedCricketMarks()
        cricketScoreByPlayerID = state.cricketScoreByPlayerID.uuidKeyed()
        practiceTargetValueByPlayerID = state.practiceTargetValueByPlayerID.uuidKeyed()
        practiceProgressByPlayerID = state.practiceProgressByPlayerID.uuidKeyed()
        practiceCallTargetByPlayerID = state.practiceCallTargetByPlayerID.uuidKeyed()
        practiceCurrentStreakByPlayerID = state.practiceCurrentStreakByPlayerID.uuidKeyed()
        completedLegs = []
        currentLegStartingPlayerID = players.first?.id
        scoredDartPointsHistoryByPlayerID = [:]
        bustCountByPlayerID = [:]
        currentLegVisitsByPlayerID = [:]
    }
}

private struct GameSnapshot {
    let players: [Player]
    let activePlayerIndex: Int
    let currentTurn: Turn
    let winner: Player?
    let statusMessage: String?
    let gameMode: GameMode
    let practiceMode: PracticeMode
    let practiceCompetitiveEnabled: Bool
    let practiceSuccessesToWin: Int
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
    let cricketMarksByPlayerID: [UUID: [CricketTarget: Int]]
    let cricketScoreByPlayerID: [UUID: Int]
    let practiceTargetValueByPlayerID: [UUID: Int]
    let practiceProgressByPlayerID: [UUID: Int]
    let practiceCallTargetByPlayerID: [UUID: PracticeCallTarget]
    let practiceCurrentStreakByPlayerID: [UUID: Int]
    let completedLegs: [LegRecord]
    let currentLegStartingPlayerID: UUID?
    let scoredDartPointsHistoryByPlayerID: [UUID: [Int]]
    let bustCountByPlayerID: [UUID: Int]
    let currentLegVisitsByPlayerID: [UUID: [LegPlayerVisit]]
}

private extension DartsGame {
    func sanitizeAndClampNames(_ names: [String], for gameMode: GameMode) -> [String] {
        let clamped = Array(names.prefix(5))
        let withFallbacks = clamped.enumerated().map { index, name in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Player \(index + 1)" : trimmed
        }
        if withFallbacks.isEmpty {
            return gameMode == .x01 ? ["Player 1", "Player 2"] : ["Player 1"]
        }
        if withFallbacks.count == 1, gameMode == .x01 {
            return withFallbacks + ["Player 2"]
        }
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
                gameMode: gameMode,
                practiceMode: practiceMode,
                practiceCompetitiveEnabled: practiceCompetitiveEnabled,
                practiceSuccessesToWin: practiceSuccessesToWin,
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
                highestCheckoutByPlayerID: highestCheckoutByPlayerID,
                cricketMarksByPlayerID: cricketMarksByPlayerID,
                cricketScoreByPlayerID: cricketScoreByPlayerID,
                practiceTargetValueByPlayerID: practiceTargetValueByPlayerID,
                practiceProgressByPlayerID: practiceProgressByPlayerID,
                practiceCallTargetByPlayerID: practiceCallTargetByPlayerID,
                practiceCurrentStreakByPlayerID: practiceCurrentStreakByPlayerID,
                completedLegs: completedLegs,
                currentLegStartingPlayerID: currentLegStartingPlayerID,
                scoredDartPointsHistoryByPlayerID: scoredDartPointsHistoryByPlayerID,
                bustCountByPlayerID: bustCountByPlayerID,
                currentLegVisitsByPlayerID: currentLegVisitsByPlayerID
            )
        )
    }

    func appendThrowToHistory(playerID: UUID, points: Int) {
        var values: [Int] = currentTurn.dartsUsed == 0 ? [] : (lastTurnThrowsByPlayerID[playerID] ?? [])
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
        scoredDartPointsHistoryByPlayerID = [:]
        bustCountByPlayerID = [:]
        currentLegVisitsByPlayerID = [:]
        cricketMarksByPlayerID = [:]
        cricketScoreByPlayerID = [:]
        for player in players {
            pointsScoredByPlayerID[player.id] = 0
            dartsThrownByPlayerID[player.id] = 0
            highestTurnScoreByPlayerID[player.id] = 0
            checkoutOpportunitiesByPlayerID[player.id] = 0
            checkoutConversionsByPlayerID[player.id] = 0
            highestCheckoutByPlayerID[player.id] = 0
            scoredDartPointsHistoryByPlayerID[player.id] = []
            bustCountByPlayerID[player.id] = 0
            currentLegVisitsByPlayerID[player.id] = []
            cricketMarksByPlayerID[player.id] = Dictionary(uniqueKeysWithValues: cricketTargets.map { ($0, 0) })
            cricketScoreByPlayerID[player.id] = 0
        }
    }

    func recordDartThrown(for playerID: UUID) {
        dartsThrownByPlayerID[playerID, default: 0] += 1
    }

    func recordDartsThrown(count: Int, for playerID: UUID) {
        guard count > 0 else { return }
        dartsThrownByPlayerID[playerID, default: 0] += count
    }

    func addScoredPoints(_ points: Int, for playerID: UUID) {
        pointsScoredByPlayerID[playerID, default: 0] += points
    }

    func rollbackTurnScoringForBust(playerID: UUID) {
        let turnPoints = currentTurn.darts.reduce(0) { $0 + $1.points }
        pointsScoredByPlayerID[playerID, default: 0] -= turnPoints
    }

    func rollbackFirstNineScoringForBust(playerID: UUID) {
        guard var history = scoredDartPointsHistoryByPlayerID[playerID] else { return }
        let revertCount = currentTurn.darts.count
        guard revertCount > 0, history.count > 1 else { return }
        let bustIndex = history.count - 1
        let lowerBound = max(0, bustIndex - revertCount)
        if lowerBound < bustIndex {
            for index in lowerBound..<bustIndex {
                history[index] = 0
            }
            scoredDartPointsHistoryByPlayerID[playerID] = history
        }
    }

    func appendScoredDartPoints(_ points: Int, for playerID: UUID) {
        scoredDartPointsHistoryByPlayerID[playerID, default: []].append(points)
    }

    func appendQuickScoredDartPoints(_ score: Int, dartsUsed: Int, for playerID: UUID) {
        guard dartsUsed > 0 else { return }
        appendScoredDartPoints(score, for: playerID)
        if dartsUsed > 1 {
            for _ in 1..<dartsUsed {
                appendScoredDartPoints(0, for: playerID)
            }
        }
    }

    func recordVisit(for playerID: UUID, score: Int, isBust: Bool) {
        var visits = currentLegVisitsByPlayerID[playerID] ?? []
        visits.append(
            LegPlayerVisit(
                playerID: playerID,
                visitNumber: visits.count + 1,
                score: score,
                isBust: isBust
            )
        )
        currentLegVisitsByPlayerID[playerID] = visits
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
        guard gameMode == .x01 else { return }
        let score = players[activePlayerIndex].score
        guard score > 1, score <= 170 else { return }
        checkoutOpportunitiesByPlayerID[players[activePlayerIndex].id, default: 0] += 1
    }

    func recordCompletedLeg(winner: Player, checkoutScore: Int?, checkoutRoute: String?) {
        guard let startingPlayerID = currentLegStartingPlayerID else { return }
        let playerVisits = players.flatMap { player in currentLegVisitsByPlayerID[player.id] ?? [] }
        let playerResults = players.map { player in
            let darts = dartsThrownByPlayerID[player.id] ?? 0
            let points = pointsScoredByPlayerID[player.id] ?? 0
            let average = darts > 0 ? (Double(points) / Double(darts)) * 3.0 : 0.0
            let firstNineHistory = scoredDartPointsHistoryByPlayerID[player.id] ?? []
            let firstNineDarts = min(firstNineHistory.count, 9)
            let firstNinePoints = firstNineHistory.prefix(firstNineDarts).reduce(0, +)
            let firstNineAverage: Double?
            if firstNineDarts > 0 {
                firstNineAverage = (Double(firstNinePoints) / Double(firstNineDarts)) * 3.0
            } else {
                firstNineAverage = nil
            }

            return LegPlayerResult(
                playerID: player.id,
                name: player.name,
                dartsThrown: darts,
                pointsScored: points,
                average: average,
                firstNineAverage: firstNineAverage,
                firstNinePoints: firstNinePoints,
                firstNineDarts: firstNineDarts,
                highestFinish: highestCheckoutByPlayerID[player.id] ?? 0,
                highestTurnScore: highestTurnScoreByPlayerID[player.id] ?? 0,
                bustCount: bustCountByPlayerID[player.id] ?? 0,
                checkoutAttempts: checkoutOpportunitiesByPlayerID[player.id] ?? 0,
                checkoutHits: checkoutConversionsByPlayerID[player.id] ?? 0
            )
        }

        completedLegs.append(
            LegRecord(
                legNumber: completedLegs.count + 1,
                startingPlayerID: startingPlayerID,
                winnerPlayerID: winner.id,
                checkoutScore: checkoutScore,
                winningCheckoutRoute: checkoutRoute?.isEmpty == true ? nil : checkoutRoute,
                playerVisits: playerVisits,
                playerResults: playerResults
            )
        )
    }

    func initializePracticeState() {
        practiceTargetValueByPlayerID = [:]
        practiceProgressByPlayerID = [:]
        practiceCallTargetByPlayerID = [:]
        practiceCurrentStreakByPlayerID = [:]
        guard gameMode == .practice else { return }
        for player in players {
            switch practiceMode {
            case .scoringDrill:
                practiceTargetValueByPlayerID[player.id] = 0
                practiceProgressByPlayerID[player.id] = 0
            case .checkoutPractice:
                practiceTargetValueByPlayerID[player.id] = Self.randomCheckoutTarget()
                practiceProgressByPlayerID[player.id] = 0
            case .doublesPractice:
                practiceTargetValueByPlayerID[player.id] = Self.randomDoubleTarget()
                practiceProgressByPlayerID[player.id] = 0
            case .aroundTheClock:
                practiceTargetValueByPlayerID[player.id] = Self.aroundTheClockTargets.first ?? 1
                practiceProgressByPlayerID[player.id] = 0
            case .first9Challenge:
                practiceTargetValueByPlayerID[player.id] = 3
                practiceProgressByPlayerID[player.id] = 0
            case .pressureFinishes:
                practiceTargetValueByPlayerID[player.id] = Self.randomCheckoutTarget()
                practiceProgressByPlayerID[player.id] = 0
            case .streakMode:
                practiceTargetValueByPlayerID[player.id] = 0
                practiceProgressByPlayerID[player.id] = 0
                practiceCallTargetByPlayerID[player.id] = Self.randomCalledTarget()
                practiceCurrentStreakByPlayerID[player.id] = 0
            case .randomTarget:
                practiceTargetValueByPlayerID[player.id] = 0
                practiceProgressByPlayerID[player.id] = 0
                practiceCallTargetByPlayerID[player.id] = Self.randomCalledTarget()
                practiceCurrentStreakByPlayerID[player.id] = 0
            }
        }
    }

    func updatePracticeStatusMessage() {
        guard gameMode == .practice, winner == nil, players.indices.contains(activePlayerIndex) else { return }
        let player = players[activePlayerIndex]
        statusMessage = practiceObjectiveMessage(for: player)
    }

    private func maybeFinishCompetitivePracticeTurn(for player: Player) -> Bool {
        let updatedPlayer = players[activePlayerIndex]
        guard gameMode == .practice,
              practiceCompetitiveEnabled,
              practiceMode.supportsCompetitiveGoal,
              players.count > 1,
              updatedPlayer.score >= practiceSuccessesToWin else { return false }

        winner = updatedPlayer
        setWinner = updatedPlayer
        statusMessage = L10n.format("%@ wins %@.", updatedPlayer.name, practiceMode.label)
        return true
    }

    func submitPracticeThrow(segment: DartSegment, multiplier: DartMultiplier) {
        switch practiceMode {
        case .scoringDrill:
            submitScoringDrillThrow(segment: segment, multiplier: multiplier)
        case .checkoutPractice:
            submitCheckoutPracticeThrow(segment: segment, multiplier: multiplier)
        case .doublesPractice:
            submitDoublesPracticeThrow(segment: segment, multiplier: multiplier)
        case .aroundTheClock:
            submitAroundTheClockThrow(segment: segment, multiplier: multiplier)
        case .first9Challenge:
            submitFirstNineChallengeThrow(segment: segment, multiplier: multiplier)
        case .pressureFinishes:
            submitPressureFinishesThrow(segment: segment, multiplier: multiplier)
        case .streakMode:
            submitStreakModeThrow(segment: segment, multiplier: multiplier)
        case .randomTarget:
            submitRandomTargetThrow(segment: segment, multiplier: multiplier)
        }
    }

    func submitPracticeQuickScore(_ score: Int) {
        guard practiceMode == .scoringDrill else {
            statusMessage = L10n.string("Quick score is only available in Scoring Drill.")
            return
        }
        submitScoringDrillQuickScore(score)
    }

    private func submitScoringDrillThrow(segment: DartSegment, multiplier: DartMultiplier) {
        guard winner == nil else { return }
        guard remainingDarts > 0 else { return }

        guard let throwValue = DartThrow(segment: segment, multiplier: multiplier) else {
            statusMessage = L10n.string("Invalid throw.")
            return
        }

        recordSnapshot()
        statusMessage = L10n.string("Scoring Drill")

        let player = activePlayer
        appendThrowToHistory(playerID: player.id, points: throwValue.points)
        recordDartThrown(for: player.id)
        appendScoredDartPoints(throwValue.points, for: player.id)
        addScoredPoints(throwValue.points, for: player.id)

        var updatedPlayers = players
        updatedPlayers[activePlayerIndex].score += throwValue.points
        players = updatedPlayers
        currentTurn.darts.append(throwValue)

        if currentTurn.dartsUsed == 3 {
            let turnScore = currentTurn.darts.reduce(0) { $0 + $1.points }
            updateHighestTurnScore(for: player.id, score: turnScore)
            recordVisit(for: player.id, score: turnScore, isBust: false)
            endTurn()
        }
    }

    private func submitScoringDrillQuickScore(_ score: Int) {
        guard winner == nil else { return }
        guard currentTurn.dartsUsed == 0 else {
            statusMessage = L10n.string("Finish the current visit in Throws mode.")
            return
        }
        guard (1...180).contains(score) else {
            statusMessage = L10n.string("Quick scores must be between 1 and 180.")
            return
        }

        recordSnapshot()
        statusMessage = L10n.string("Scoring Drill")

        let player = activePlayer
        lastTurnThrowsByPlayerID[player.id] = [score]
        recordDartsThrown(count: 3, for: player.id)
        appendQuickScoredDartPoints(score, dartsUsed: 3, for: player.id)
        addScoredPoints(score, for: player.id)

        var updatedPlayers = players
        updatedPlayers[activePlayerIndex].score += score
        players = updatedPlayers

        updateHighestTurnScore(for: player.id, score: score)
        recordVisit(for: player.id, score: score, isBust: false)
        endTurn()
    }

    private func submitCheckoutPracticeThrow(segment: DartSegment, multiplier: DartMultiplier) {
        guard winner == nil, remainingDarts > 0 else { return }
        guard let throwValue = DartThrow(segment: segment, multiplier: multiplier) else {
            statusMessage = L10n.string("Invalid throw.")
            return
        }

        recordSnapshot()
        let player = activePlayer
        let currentTarget = practiceTargetValueByPlayerID[player.id] ?? Self.randomCheckoutTarget()
        let newRemaining = currentTarget - (currentTurn.darts.reduce(0) { $0 + $1.points } + throwValue.points)

        appendThrowToHistory(playerID: player.id, points: throwValue.points)
        recordDartThrown(for: player.id)
        appendScoredDartPoints(max(throwValue.points, 0), for: player.id)
        addScoredPoints(throwValue.points, for: player.id)
        currentTurn.darts.append(throwValue)

        if newRemaining == 0 {
            var updatedPlayers = players
            updatedPlayers[activePlayerIndex].score += 1
            players = updatedPlayers
            let turnScore = currentTurn.darts.reduce(0) { $0 + $1.points }
            updateHighestTurnScore(for: player.id, score: turnScore)
            recordVisit(for: player.id, score: turnScore, isBust: false)
            if maybeFinishCompetitivePracticeTurn(for: player) {
                return
            }
            practiceTargetValueByPlayerID[player.id] = Self.randomCheckoutTarget()
            endTurn()
            updatePracticeStatusMessage()
            return
        }

        if newRemaining < 0 || currentTurn.dartsUsed == 3 {
            let turnScore = currentTurn.darts.reduce(0) { $0 + $1.points }
            updateHighestTurnScore(for: player.id, score: turnScore)
            recordVisit(for: player.id, score: turnScore, isBust: newRemaining < 0)
            practiceTargetValueByPlayerID[player.id] = Self.randomCheckoutTarget()
            endTurn()
            updatePracticeStatusMessage()
            return
        }

        statusMessage = L10n.format("Checkout: %@", "\(newRemaining)")
    }

    private func submitDoublesPracticeThrow(segment: DartSegment, multiplier: DartMultiplier) {
        guard winner == nil, remainingDarts > 0 else { return }
        guard let throwValue = DartThrow(segment: segment, multiplier: multiplier) else {
            statusMessage = L10n.string("Invalid throw.")
            return
        }

        recordSnapshot()
        let player = activePlayer
        let target = practiceTargetValueByPlayerID[player.id] ?? Self.randomDoubleTarget()
        let hitTarget = (target == 25 && segment == .bull && multiplier == .double)
            || (target != 25 && segment == .number(target) && multiplier == .double)

        appendThrowToHistory(playerID: player.id, points: throwValue.points)
        recordDartThrown(for: player.id)
        appendScoredDartPoints(throwValue.points, for: player.id)
        addScoredPoints(throwValue.points, for: player.id)
        currentTurn.darts.append(throwValue)

        if hitTarget {
            var updatedPlayers = players
            updatedPlayers[activePlayerIndex].score += 1
            players = updatedPlayers
            if maybeFinishCompetitivePracticeTurn(for: player) {
                return
            }
        }

        if hitTarget || currentTurn.dartsUsed == 3 {
            let turnScore = currentTurn.darts.reduce(0) { $0 + $1.points }
            updateHighestTurnScore(for: player.id, score: turnScore)
            recordVisit(for: player.id, score: turnScore, isBust: false)
            practiceTargetValueByPlayerID[player.id] = Self.randomDoubleTarget()
            endTurn()
            updatePracticeStatusMessage()
            return
        }

        statusMessage = target == 25 ? L10n.string("Hit Bull") : L10n.format("Hit D%@", "\(target)")
    }

    private func submitAroundTheClockThrow(segment: DartSegment, multiplier: DartMultiplier) {
        guard winner == nil, remainingDarts > 0 else { return }
        guard let throwValue = DartThrow(segment: segment, multiplier: multiplier) else {
            statusMessage = L10n.string("Invalid throw.")
            return
        }

        recordSnapshot()
        let player = activePlayer
        let progress = practiceProgressByPlayerID[player.id] ?? 0
        let target = Self.aroundTheClockTargets[min(progress, Self.aroundTheClockTargets.count - 1)]
        let hitTarget = Self.matchesAroundTheClockTarget(target, segment: segment)

        appendThrowToHistory(playerID: player.id, points: throwValue.points)
        recordDartThrown(for: player.id)
        appendScoredDartPoints(throwValue.points, for: player.id)
        addScoredPoints(throwValue.points, for: player.id)
        currentTurn.darts.append(throwValue)

        if hitTarget {
            let newProgress = progress + 1
            practiceProgressByPlayerID[player.id] = newProgress
            practiceTargetValueByPlayerID[player.id] = Self.aroundTheClockTargets[min(newProgress, Self.aroundTheClockTargets.count - 1)]
            var updatedPlayers = players
            updatedPlayers[activePlayerIndex].score = newProgress
            players = updatedPlayers
            if newProgress >= Self.aroundTheClockTargets.count {
                let turnScore = currentTurn.darts.reduce(0) { $0 + $1.points }
                updateHighestTurnScore(for: player.id, score: turnScore)
                recordVisit(for: player.id, score: turnScore, isBust: false)
                winner = player
                setWinner = player
                statusMessage = L10n.format("%@ wins Around the Clock.", player.name)
                return
            }
        }

        if currentTurn.dartsUsed == 3 {
            let turnScore = currentTurn.darts.reduce(0) { $0 + $1.points }
            updateHighestTurnScore(for: player.id, score: turnScore)
            recordVisit(for: player.id, score: turnScore, isBust: false)
            endTurn()
            updatePracticeStatusMessage()
            return
        }

        let nextProgress = practiceProgressByPlayerID[player.id] ?? progress
        let nextTarget = Self.aroundTheClockTargets[min(nextProgress, Self.aroundTheClockTargets.count - 1)]
        statusMessage = nextTarget == 25 ? L10n.string("Hit Bull") : L10n.format("Hit %@", "\(nextTarget)")
    }

    private func submitFirstNineChallengeThrow(segment: DartSegment, multiplier: DartMultiplier) {
        guard winner == nil, remainingDarts > 0 else { return }
        guard let throwValue = DartThrow(segment: segment, multiplier: multiplier) else {
            statusMessage = L10n.string("Invalid throw.")
            return
        }

        recordSnapshot()

        let player = activePlayer
        appendThrowToHistory(playerID: player.id, points: throwValue.points)
        recordDartThrown(for: player.id)
        appendScoredDartPoints(throwValue.points, for: player.id)
        addScoredPoints(throwValue.points, for: player.id)

        var updatedPlayers = players
        updatedPlayers[activePlayerIndex].score += throwValue.points
        players = updatedPlayers
        currentTurn.darts.append(throwValue)

        if currentTurn.dartsUsed == 3 {
            let turnScore = currentTurn.darts.reduce(0) { $0 + $1.points }
            updateHighestTurnScore(for: player.id, score: turnScore)
            recordVisit(for: player.id, score: turnScore, isBust: false)
            practiceProgressByPlayerID[player.id, default: 0] += 1

            advanceFirstNineChallenge(after: activePlayerIndex)
        } else {
            statusMessage = practiceObjectiveMessage(for: player)
        }
    }

    private func submitPressureFinishesThrow(segment: DartSegment, multiplier: DartMultiplier) {
        guard winner == nil, remainingDarts > 0 else { return }
        guard let throwValue = DartThrow(segment: segment, multiplier: multiplier) else {
            statusMessage = L10n.string("Invalid throw.")
            return
        }

        recordSnapshot()
        let player = activePlayer
        let currentTarget = practiceTargetValueByPlayerID[player.id] ?? Self.randomCheckoutTarget()
        let newRemaining = currentTarget - (currentTurn.darts.reduce(0) { $0 + $1.points } + throwValue.points)

        appendThrowToHistory(playerID: player.id, points: throwValue.points)
        recordDartThrown(for: player.id)
        appendScoredDartPoints(throwValue.points, for: player.id)
        addScoredPoints(throwValue.points, for: player.id)
        currentTurn.darts.append(throwValue)

        if newRemaining == 0 {
            var updatedPlayers = players
            updatedPlayers[activePlayerIndex].score += 1
            players = updatedPlayers
            let turnScore = currentTurn.darts.reduce(0) { $0 + $1.points }
            updateHighestTurnScore(for: player.id, score: turnScore)
            recordVisit(for: player.id, score: turnScore, isBust: false)
            if maybeFinishCompetitivePracticeTurn(for: player) {
                return
            }
            practiceTargetValueByPlayerID[player.id] = Self.randomCheckoutTarget()
            endTurn()
            return
        }

        if newRemaining < 0 || currentTurn.dartsUsed == 3 {
            var updatedPlayers = players
            updatedPlayers[activePlayerIndex].score = 0
            players = updatedPlayers
            let turnScore = currentTurn.darts.reduce(0) { $0 + $1.points }
            updateHighestTurnScore(for: player.id, score: turnScore)
            recordVisit(for: player.id, score: turnScore, isBust: newRemaining < 0)
            practiceTargetValueByPlayerID[player.id] = Self.randomCheckoutTarget()
            endTurn()
            return
        }

        statusMessage = L10n.format("Checkout: %@", "\(newRemaining)")
    }

    private func submitStreakModeThrow(segment: DartSegment, multiplier: DartMultiplier) {
        guard winner == nil, remainingDarts > 0 else { return }
        guard let throwValue = DartThrow(segment: segment, multiplier: multiplier) else {
            statusMessage = L10n.string("Invalid throw.")
            return
        }

        recordSnapshot()
        let player = activePlayer
        let target = practiceCallTargetByPlayerID[player.id] ?? Self.randomCalledTarget()
        let hitTarget = target.matches(segment: segment, multiplier: multiplier)

        appendThrowToHistory(playerID: player.id, points: throwValue.points)
        recordDartThrown(for: player.id)
        appendScoredDartPoints(throwValue.points, for: player.id)
        addScoredPoints(throwValue.points, for: player.id)
        currentTurn.darts.append(throwValue)

        if hitTarget {
            let updatedStreak = (practiceCurrentStreakByPlayerID[player.id] ?? 0) + 1
            practiceCurrentStreakByPlayerID[player.id] = updatedStreak

            var updatedPlayers = players
            updatedPlayers[activePlayerIndex].score = max(updatedPlayers[activePlayerIndex].score, updatedStreak)
            players = updatedPlayers
            if maybeFinishCompetitivePracticeTurn(for: player) {
                return
            }

            if currentTurn.dartsUsed == 3 {
                let turnScore = currentTurn.darts.reduce(0) { $0 + $1.points }
                updateHighestTurnScore(for: player.id, score: turnScore)
                recordVisit(for: player.id, score: turnScore, isBust: false)
                endTurn()
            } else {
                statusMessage = practiceObjectiveMessage(for: player)
            }
            return
        }

        practiceCurrentStreakByPlayerID[player.id] = 0
        practiceCallTargetByPlayerID[player.id] = Self.randomCalledTarget()

        let turnScore = currentTurn.darts.reduce(0) { $0 + $1.points }
        updateHighestTurnScore(for: player.id, score: turnScore)
        recordVisit(for: player.id, score: turnScore, isBust: false)
        endTurn()
    }

    private func submitRandomTargetThrow(segment: DartSegment, multiplier: DartMultiplier) {
        guard winner == nil, remainingDarts > 0 else { return }
        guard let throwValue = DartThrow(segment: segment, multiplier: multiplier) else {
            statusMessage = L10n.string("Invalid throw.")
            return
        }

        recordSnapshot()
        let player = activePlayer
        let target = practiceCallTargetByPlayerID[player.id] ?? Self.randomCalledTarget()
        let hitTarget = target.matches(segment: segment, multiplier: multiplier)

        appendThrowToHistory(playerID: player.id, points: throwValue.points)
        recordDartThrown(for: player.id)
        appendScoredDartPoints(throwValue.points, for: player.id)
        addScoredPoints(throwValue.points, for: player.id)
        currentTurn.darts.append(throwValue)

        if hitTarget {
            var updatedPlayers = players
            updatedPlayers[activePlayerIndex].score += 1
            players = updatedPlayers
            if maybeFinishCompetitivePracticeTurn(for: player) {
                return
            }

            let turnScore = currentTurn.darts.reduce(0) { $0 + $1.points }
            updateHighestTurnScore(for: player.id, score: turnScore)
            recordVisit(for: player.id, score: turnScore, isBust: false)
            practiceCallTargetByPlayerID[player.id] = Self.randomCalledTarget()
            endTurn()
            return
        }

        if currentTurn.dartsUsed == 3 {
            let turnScore = currentTurn.darts.reduce(0) { $0 + $1.points }
            updateHighestTurnScore(for: player.id, score: turnScore)
            recordVisit(for: player.id, score: turnScore, isBust: false)
            practiceCallTargetByPlayerID[player.id] = Self.randomCalledTarget()
            endTurn()
            return
        }

        statusMessage = practiceObjectiveMessage(for: player)
    }

    private func practiceObjectiveMessage(for player: Player) -> String {
        let competitiveSuffix = practiceCompetitiveEnabled && practiceMode.supportsCompetitiveGoal && players.count > 1
            ? "  •  " + L10n.format("First to %@", "\(practiceSuccessesToWin)")
            : ""

        switch practiceMode {
        case .scoringDrill:
            return L10n.string("Scoring Drill")
        case .checkoutPractice:
            let target = practiceTargetValueByPlayerID[player.id] ?? Self.randomCheckoutTarget()
            return L10n.format("Checkout: %@", "\(target)") + competitiveSuffix
        case .doublesPractice:
            let target = practiceTargetValueByPlayerID[player.id] ?? Self.randomDoubleTarget()
            return (target == 25 ? L10n.string("Hit Bull") : L10n.format("Hit D%@", "\(target)")) + competitiveSuffix
        case .aroundTheClock:
            let progress = practiceProgressByPlayerID[player.id] ?? 0
            let target = Self.aroundTheClockTargets[min(progress, Self.aroundTheClockTargets.count - 1)]
            return target == 25 ? L10n.string("Hit Bull") : L10n.format("Hit %@", "\(target)")
        case .first9Challenge:
            let turnNumber = (practiceProgressByPlayerID[player.id] ?? 0) + 1
            let requiredVisits = practiceTargetValueByPlayerID[player.id] ?? 3
            if requiredVisits > 3 {
                return L10n.format("Tiebreak Round %@", "\(requiredVisits - 3)")
            }
            return L10n.format("Turn %@ of 3", "\(turnNumber)")
        case .pressureFinishes:
            let target = practiceTargetValueByPlayerID[player.id] ?? Self.randomCheckoutTarget()
            return L10n.format("Checkout: %@", "\(target)")
        case .streakMode:
            let target = practiceCallTargetByPlayerID[player.id] ?? Self.randomCalledTarget()
            let streak = practiceCurrentStreakByPlayerID[player.id] ?? 0
            return L10n.format("Hit %@ • Streak %@", target.label, "\(streak)")
        case .randomTarget:
            let target = practiceCallTargetByPlayerID[player.id] ?? Self.randomCalledTarget()
            return L10n.format("Hit %@", target.label)
        }
    }

    private func finishPracticeSession(with player: Player) {
        winner = player
        setWinner = player
        statusMessage = L10n.format("%@ wins %@.", player.name, practiceMode.label)
    }

    private func advanceFirstNineChallenge(after completedIndex: Int) {
        if let nextIndex = nextFirstNineActivePlayerIndex(after: completedIndex) {
            startPracticeTurn(at: nextIndex)
            return
        }

        let currentTarget = practiceTargetValueByPlayerID.values.max() ?? 3
        let contestants = players.filter { (practiceTargetValueByPlayerID[$0.id] ?? 3) == currentTarget }
        let bestScore = contestants.map(\.score).max() ?? 0
        let leaders = contestants.filter { $0.score == bestScore }

        if leaders.count == 1, let winner = leaders.first {
            finishPracticeSession(with: winner)
            return
        }

        let leaderIDs = Set(leaders.map(\.id))
        for player in players {
            let progress = practiceProgressByPlayerID[player.id] ?? 0
            practiceTargetValueByPlayerID[player.id] = leaderIDs.contains(player.id) ? progress + 1 : progress
        }

        if let nextIndex = nextFirstNineActivePlayerIndex(after: completedIndex) {
            startPracticeTurn(at: nextIndex)
        }
    }

    private func nextFirstNineActivePlayerIndex(after currentIndex: Int) -> Int? {
        guard !players.isEmpty else { return nil }
        for offset in 1...players.count {
            let index = (currentIndex + offset) % players.count
            let player = players[index]
            let progress = practiceProgressByPlayerID[player.id] ?? 0
            let target = practiceTargetValueByPlayerID[player.id] ?? 3
            if progress < target {
                return index
            }
        }
        return nil
    }

    private func startPracticeTurn(at index: Int) {
        activePlayerIndex = index
        let player = players[index]
        currentTurn = Turn(startingScore: player.score, openedAtTurnStart: true)
        updatePracticeStatusMessage()
    }

    func submitCricketThrow(segment: DartSegment, multiplier: DartMultiplier) {
        guard winner == nil else { return }
        guard remainingDarts > 0 else { return }

        guard let throwValue = DartThrow(segment: segment, multiplier: multiplier) else {
            statusMessage = L10n.string("Invalid throw.")
            return
        }

        recordSnapshot()
        statusMessage = L10n.string("Close all numbers and finish level or ahead.")

        let player = activePlayer
        appendThrowToHistory(playerID: player.id, points: throwValue.points)
        recordDartThrown(for: player.id)
        currentTurn.darts.append(throwValue)

        let scoredPoints = applyCricketThrow(throwValue, for: player.id)
        appendScoredDartPoints(scoredPoints, for: player.id)
        addScoredPoints(scoredPoints, for: player.id)

        if currentTurn.dartsUsed == 3 {
            let turnScore = currentTurn.darts.reduce(0) { $0 + $1.points }
            updateHighestTurnScore(for: player.id, score: turnScore)
            recordVisit(for: player.id, score: turnScore, isBust: false)
            endTurn()
        }

        if let winningPlayer = cricketWinningPlayer() {
            recordCompletedLeg(winner: winningPlayer, checkoutScore: nil, checkoutRoute: nil)
            winner = winningPlayer
            setWinner = winningPlayer
            statusMessage = L10n.format("%@ wins Cricket.", winningPlayer.name)
        }
    }

    func applyCricketThrow(_ throwValue: DartThrow, for playerID: UUID) -> Int {
        guard let target = cricketTarget(for: throwValue.segment) else { return 0 }
        let marks = cricketMarksEarned(for: throwValue)
        let currentMarks = cricketMarksByPlayerID[playerID]?[target] ?? 0
        let scoredPoints = cricketScoringValue(for: throwValue, playerID: playerID)
        cricketMarksByPlayerID[playerID]?[target] = min(3, currentMarks + marks)
        cricketScoreByPlayerID[playerID, default: 0] += scoredPoints
        return scoredPoints
    }

    func cricketScoringValue(for throwValue: DartThrow, playerID: UUID) -> Int {
        guard let target = cricketTarget(for: throwValue.segment) else { return 0 }
        let marks = cricketMarksEarned(for: throwValue)
        let currentMarks = cricketMarksByPlayerID[playerID]?[target] ?? 0
        let overflow = max(0, currentMarks + marks - 3)
        let opponentsOpen = players
            .filter { $0.id != playerID }
            .contains { (cricketMarksByPlayerID[$0.id]?[target] ?? 0) < 3 }
        return opponentsOpen ? overflow * target.rawValue : 0
    }

    func cricketMarksEarned(for throwValue: DartThrow) -> Int {
        switch throwValue.segment {
        case .bull:
            return throwValue.multiplier.rawValue
        case .number:
            return throwValue.multiplier.rawValue
        }
    }

    func cricketTarget(for segment: DartSegment) -> CricketTarget? {
        switch segment {
        case .bull:
            return .bull
        case .number(let value):
            return CricketTarget(rawValue: value)
        }
    }

    func cricketWinningPlayer() -> Player? {
        players.first { player in
            allCricketTargetsClosed(for: player) &&
            players.allSatisfy { cricketScore(for: player) >= cricketScore(for: $0) }
        }
    }

    nonisolated private static func dartCountForCheckoutRoute(_ route: String) -> Int {
        route.split(separator: " ").count
    }
}
