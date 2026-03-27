import Testing
@testable import DartScorer

@MainActor
struct DartScorerTests {

    @Test func scoreSubtractionOnValidThrow() {
        let game = DartsGame(playerCount: 2)

        game.submitThrow(segment: .number(20), multiplier: .triple)

        #expect(game.players[0].score == 441)
        #expect(game.currentTurn.darts.count == 1)
        #expect(game.activePlayerIndex == 0)
    }

    @Test func bustRevertsScoreAndSwitchesPlayer() {
        let game = DartsGame(playerCount: 2)
        game.players[0].score = 40
        game.currentTurn = Turn(startingScore: 40)

        game.submitThrow(segment: .number(20), multiplier: .triple)

        #expect(game.players[0].score == 40)
        #expect(game.activePlayerIndex == 1)
        #expect(game.currentTurn.darts.isEmpty)
    }

    @Test func bustVisitDoesNotCarryThrowBadgesFromPreviousVisit() {
        let game = DartsGame(playerCount: 2)

        game.submitThrow(segment: .number(20), multiplier: .single)
        game.submitThrow(segment: .number(0), multiplier: .single)
        game.submitThrow(segment: .number(0), multiplier: .single)

        game.submitThrow(segment: .number(0), multiplier: .single)
        game.submitThrow(segment: .number(0), multiplier: .single)
        game.submitThrow(segment: .number(0), multiplier: .single)

        game.players[0].score = 66
        game.currentTurn = Turn(startingScore: 66)

        game.submitThrow(segment: .number(20), multiplier: .triple)
        game.submitThrow(segment: .number(20), multiplier: .triple)

        #expect(game.players[0].score == 66)
        #expect(game.activePlayerIndex == 1)
        #expect(game.lastTurnThrows(for: game.players[0]) == [60, 60])
    }

    @Test func doubleOutIsRequired() {
        let game = DartsGame(playerCount: 2)
        game.players[0].score = 20
        game.currentTurn = Turn(startingScore: 20)

        game.submitThrow(segment: .number(20), multiplier: .single)

        #expect(game.players[0].score == 20)
        #expect(game.winner == nil)
        #expect(game.activePlayerIndex == 1)
    }

    @Test func singleOutAllowsWinningOnSingle() {
        let game = DartsGame(playerCount: 2, finishRule: .singleOut)
        game.players[0].score = 20
        game.currentTurn = Turn(startingScore: 20)

        game.submitThrow(segment: .number(20), multiplier: .single)

        #expect(game.players[0].score == 0)
        #expect(game.winner?.name == "Player 1")
    }

    @Test func doubleInRequiresDoubleToStartScoring() {
        let game = DartsGame(playerCount: 2, inRule: .doubleIn)

        game.submitThrow(segment: .number(20), multiplier: .single)
        #expect(game.players[0].score == 501)

        game.submitThrow(segment: .number(20), multiplier: .double)
        #expect(game.players[0].score == 461)
    }

    @Test func playerSwitchesAfterThreeDarts() {
        let game = DartsGame(playerCount: 2)

        game.submitThrow(segment: .number(1), multiplier: .single)
        game.submitThrow(segment: .number(1), multiplier: .single)
        game.submitThrow(segment: .number(1), multiplier: .single)

        #expect(game.activePlayerIndex == 1)
        #expect(game.currentTurn.darts.isEmpty)
    }

    @Test func player2ScoresAfterPlayer1TurnEnds() {
        let game = DartsGame(playerCount: 2)

        // Player 1 completes their turn (3 darts)
        game.submitThrow(segment: .number(1), multiplier: .single)
        game.submitThrow(segment: .number(1), multiplier: .single)
        game.submitThrow(segment: .number(1), multiplier: .single)

        #expect(game.activePlayerIndex == 1)

        // Player 2 throws T20
        game.submitThrow(segment: .number(20), multiplier: .triple)

        #expect(game.players[1].score == 441)
        #expect(game.activePlayerIndex == 1)
    }

    @Test func winningThrowSetsWinnerOnDoubleOut() {
        let game = DartsGame(playerCount: 2)
        game.players[0].score = 40
        game.currentTurn = Turn(startingScore: 40)

        game.submitThrow(segment: .number(20), multiplier: .double)

        #expect(game.players[0].score == 0)
        #expect(game.winner?.name == "Player 1")
        #expect(game.activePlayerIndex == 0)
    }

    @Test func undoRevertsRegularThrow() {
        let game = DartsGame(playerCount: 2)

        game.submitThrow(segment: .number(20), multiplier: .triple)
        game.undoLastThrow()

        #expect(game.players[0].score == 501)
        #expect(game.currentTurn.darts.isEmpty)
        #expect(game.activePlayerIndex == 0)
        #expect(game.canUndo == false)
    }

    @Test func undoRevertsBustState() {
        let game = DartsGame(playerCount: 2)
        game.players[0].score = 40
        game.currentTurn = Turn(startingScore: 40)

        game.submitThrow(segment: .number(20), multiplier: .triple)
        #expect(game.activePlayerIndex == 1)

        game.undoLastThrow()

        #expect(game.activePlayerIndex == 0)
        #expect(game.players[0].score == 40)
        #expect(game.currentTurn.startingScore == 40)
        #expect(game.currentTurn.darts.isEmpty)
    }

    @Test func playerNameCanBeUpdatedAndTrimmed() {
        let game = DartsGame(playerCount: 2)

        game.updatePlayerName(index: 0, name: "  Alex  ")
        #expect(game.players[0].name == "Alex")

        game.updatePlayerName(index: 0, name: "   ")
        #expect(game.players[0].name == "Player 1")
    }

    @Test func newGameUsesConfiguredOrderAndMode() {
        let game = DartsGame(playerCount: 2)

        game.newGame(playerNames: ["Chris", "Taylor", "Morgan"], finishRule: .singleOut)

        #expect(game.players.map(\.name) == ["Chris", "Taylor", "Morgan"])
        #expect(game.finishRule == .singleOut)
        #expect(game.activePlayerIndex == 0)
        #expect(game.players.allSatisfy { $0.score == 501 })
    }

    @Test func newGameCanUse301() {
        let game = DartsGame(playerCount: 2)

        game.newGame(playerNames: ["A", "B"], finishRule: .doubleOut, startingScore: 301)

        #expect(game.startingScore == 301)
        #expect(game.players.allSatisfy { $0.score == 301 })
    }

    @Test func randomNewLegResetsScoresAndKeepsPlayers() {
        let game = DartsGame(playerCount: 3)
        let namesBefore = Set(game.players.map(\.name))
        game.players[0].score = 250

        game.restartLegRandomSequence()

        #expect(Set(game.players.map(\.name)) == namesBefore)
        #expect(game.players.allSatisfy { $0.score == 501 })
        #expect(game.activePlayerIndex == 0)
    }

    @Test func setModeTracksLegWins() {
        let game = DartsGame(playerCount: 2, setModeEnabled: true, legsToWin: 2)
        let orderBefore = game.players.map(\.id)
        game.players[0].score = 40
        game.currentTurn = Turn(startingScore: 40)

        game.submitThrow(segment: .number(20), multiplier: .double)

        #expect(game.legsWonByPlayerID.values.reduce(0, +) == 1)
        #expect(game.setWinner == nil)
        #expect(game.winner == nil)
        #expect(game.players.map(\.id) == Array(orderBefore.reversed()))
    }

    @Test func legAverageUsesScoredPointsPerThreeDarts() {
        let game = DartsGame(playerCount: 2)

        game.submitThrow(segment: .number(20), multiplier: .single)
        game.submitThrow(segment: .number(20), multiplier: .single)

        let average = game.legAverage(for: game.players[0])
        #expect(average != nil)
        #expect(abs((average ?? 0) - 60.0) < 0.001)
    }

    @Test func bestPossibleFinishShowsCheckoutRoute() {
        let game = DartsGame(playerCount: 2)
        game.players[0].score = 40
        game.currentTurn = Turn(startingScore: 40)

        #expect(game.bestPossibleFinishLine == "D20")
    }

    @Test func bestPossibleFinish170() {
        let game = DartsGame(playerCount: 2)
        game.players[0].score = 170
        game.currentTurn = Turn(startingScore: 170)

        #expect(game.bestPossibleFinishLine == "T20 T20 Bull")
    }

    @Test func bestPossibleFinishNoFinishAvailable() {
        let game = DartsGame(playerCount: 2)
        game.players[0].score = 1
        game.currentTurn = Turn(startingScore: 1)

        #expect(game.bestPossibleFinishLine == nil)
    }

    @Test func practiceModeAccumulatesScoreInsteadOfSubtracting() {
        let game = DartsGame(playerCount: 1, gameMode: .practice)

        game.submitThrow(segment: .number(20), multiplier: .triple)

        #expect(game.players[0].score == 60)
        #expect(game.winner == nil)
        #expect(game.bestPossibleFinishLine == nil)
    }

    @Test func practiceModeSwitchesAfterThreeDarts() {
        let game = DartsGame(playerCount: 2, gameMode: .practice)

        game.submitThrow(segment: .number(20), multiplier: .single)
        game.submitThrow(segment: .number(20), multiplier: .single)
        game.submitThrow(segment: .number(20), multiplier: .single)

        #expect(game.players[0].score == 60)
        #expect(game.activePlayerIndex == 1)
        #expect(game.currentTurn.darts.isEmpty)
    }

    @Test func practiceModeAllowsSinglePlayerSetup() {
        let game = DartsGame(playerCount: 2)

        game.newGame(
            playerNames: ["Solo"],
            gameMode: .practice,
            finishRule: .doubleOut,
            inRule: .default,
            startingScore: 0,
            setModeEnabled: false,
            legsToWin: 1
        )

        #expect(game.gameMode == .practice)
        #expect(game.players.count == 1)
        #expect(game.players[0].score == 0)
    }

    @Test func quickScoreSubtractsAndEndsTurnInX01() {
        let game = DartsGame(playerCount: 2)

        game.submitQuickScore(100)

        #expect(game.players[0].score == 401)
        #expect(game.activePlayerIndex == 1)
        #expect(game.currentTurn.darts.isEmpty)
        #expect(game.lastTurnThrows(for: game.players[0]) == [100])
    }

    @Test func quickScoreAccumulatesInPractice() {
        let game = DartsGame(playerCount: 1, gameMode: .practice)

        game.submitQuickScore(140)

        #expect(game.players[0].score == 140)
        #expect(game.activePlayerIndex == 0)
        #expect(game.lastTurnThrows(for: game.players[0]) == [140])
    }

    @Test func cricketDoubleBullCountsAsTwoMarks() {
        let game = DartsGame(playerCount: 2, gameMode: .cricket)

        game.submitThrow(segment: .bull, multiplier: .double)

        #expect(game.cricketMarks(for: game.players[0], target: .bull) == 2)
        #expect(game.lastTurnThrows(for: game.players[0]) == [50])
    }

    @Test func cricketCountsMarksAndScoresOverflow() {
        let game = DartsGame(playerCount: 2, gameMode: .cricket)

        game.submitThrow(segment: .number(20), multiplier: .triple)
        game.submitThrow(segment: .number(20), multiplier: .triple)

        #expect(game.cricketMarks(for: game.players[0], target: .twenty) == 3)
        #expect(game.cricketScore(for: game.players[0]) == 60)
    }

    @Test func cricketWinnerRequiresClosedTargetsAndLead() {
        let game = DartsGame(playerCount: 1, gameMode: .cricket)

        for target in game.cricketTargets {
            let segment: DartSegment = target == .bull ? .bull : .number(target.rawValue)
            let multiplier: DartMultiplier = target == .bull ? .double : .triple
            game.submitThrow(segment: segment, multiplier: multiplier)
            game.submitThrow(segment: .number(0), multiplier: .single)
            game.submitThrow(segment: .number(0), multiplier: .single)
        }

        #expect(game.winner?.id == game.players[0].id)
    }

    @Test func bestPossibleFinishCacheInvalidatesOnUndo() {
        let game = DartsGame(playerCount: 2)
        
        let initial = game.bestPossibleFinishLine
        
        game.submitThrow(segment: .number(20), multiplier: .triple)
        
        #expect(game.canUndo == true)
        
        game.undoLastThrow()
        
        #expect(game.bestPossibleFinishLine == initial)
    }

    @Test func bustOnScore1InDoubleOut() {
        let game = DartsGame(playerCount: 2)
        game.players[0].score = 2
        game.currentTurn = Turn(startingScore: 2)

        game.submitThrow(segment: .number(1), multiplier: .single)

        #expect(game.players[0].score == 2)
        #expect(game.activePlayerIndex == 1)
    }

    @Test func doubleInOpensWithDouble() {
        let game = DartsGame(playerCount: 2, inRule: .doubleIn)
        
        #expect(game.hasOpenedLegByPlayerID[game.players[0].id] == false)
        
        game.submitThrow(segment: .number(20), multiplier: .double)
        
        #expect(game.hasOpenedLegByPlayerID[game.players[0].id] == true)
    }

    @Test func gameRecordDecodesWithoutLegs() throws {
        struct LegacyGameRecord: Codable {
            let id: UUID
            let date: Date
            let startingScore: Int
            let finishRule: String
            let playerResults: [PlayerGameResult]
        }

        let legacy = LegacyGameRecord(
            id: UUID(),
            date: Date(timeIntervalSince1970: 1234),
            startingScore: 501,
            finishRule: FinishRule.doubleOut.rawValue,
            playerResults: [
                PlayerGameResult(
                    id: UUID(),
                    name: "A",
                    average: 60,
                    firstNineAverage: nil,
                    highestTurnScore: 100,
                    highestScore: 100,
                    checkoutPercentage: 0.5,
                    checkoutAttempts: 2,
                    checkoutHits: 1,
                    isWinner: true,
                    profileID: nil,
                    totalDartsThrown: 18,
                    totalPointsScored: 360,
                    highestCheckout: 40,
                    score180Count: 0,
                    score140PlusCount: 1,
                    totalFirstNinePoints: 180,
                    totalFirstNineDarts: 9
                )
            ]
        )

        let data = try JSONEncoder().encode(legacy)
        let decoded = try JSONDecoder().decode(GameRecord.self, from: data)

        #expect(decoded.legs.isEmpty)
    }

    @Test func legRecordDecodesWithoutAnalyticsFields() throws {
        struct LegacyLegPlayerResult: Codable {
            let playerID: UUID
            let name: String
            let dartsThrown: Int
            let pointsScored: Int
            let average: Double
            let firstNineAverage: Double?
            let highestFinish: Int
            let highestTurnScore: Int
        }

        struct LegacyLegRecord: Codable {
            let legNumber: Int
            let startingPlayerID: UUID
            let winnerPlayerID: UUID
            let winningCheckoutRoute: String?
            let playerResults: [LegacyLegPlayerResult]
        }

        let playerID = UUID()
        let legacy = LegacyLegRecord(
            legNumber: 1,
            startingPlayerID: playerID,
            winnerPlayerID: playerID,
            winningCheckoutRoute: "D20",
            playerResults: [
                LegacyLegPlayerResult(
                    playerID: playerID,
                    name: "A",
                    dartsThrown: 12,
                    pointsScored: 301,
                    average: 75.25,
                    firstNineAverage: 90,
                    highestFinish: 40,
                    highestTurnScore: 100
                )
            ]
        )

        let data = try JSONEncoder().encode(legacy)
        let decoded = try JSONDecoder().decode(LegRecord.self, from: data)

        #expect(decoded.checkoutScore == nil)
        #expect(decoded.playerVisits.isEmpty)
        #expect(decoded.playerResults.first?.bustCount == 0)
    }

    @Test func singleLegMatchProducesOneLegRecord() {
        let game = DartsGame(playerCount: 2)
        game.players[0].score = 40
        game.currentTurn = Turn(startingScore: 40)

        game.submitThrow(segment: .number(20), multiplier: .double)

        let record = game.buildGameRecord()
        #expect(record.legs.count == 1)
        #expect(record.legs[0].winnerPlayerID == game.players[0].id)
        #expect(record.legs[0].checkoutScore == 40)
        #expect(record.legs[0].winningCheckoutRoute == "D20")
        #expect(record.legs[0].playerVisits.count == 1)
    }

    @Test func setModeMatchProducesLegRecordPerCompletedLeg() {
        let game = DartsGame(playerCount: 2, setModeEnabled: true, legsToWin: 2)

        game.players[0].score = 40
        game.currentTurn = Turn(startingScore: 40)
        game.submitThrow(segment: .number(20), multiplier: .double)

        game.players[0].score = 40
        game.currentTurn = Turn(startingScore: 40)
        game.submitThrow(segment: .number(20), multiplier: .double)

        let record = game.buildGameRecord()
        #expect(record.legs.count == 2)
        #expect(record.legs.map(\.legNumber) == [1, 2])
    }

    @Test func winningCheckoutRouteIsRecorded() {
        let game = DartsGame(playerCount: 2)
        game.players[0].score = 170
        game.currentTurn = Turn(startingScore: 170)

        game.submitThrow(segment: .number(20), multiplier: .triple)
        game.submitThrow(segment: .number(20), multiplier: .triple)
        game.submitThrow(segment: .bull, multiplier: .double)

        let record = game.buildGameRecord()
        #expect(record.legs.first?.checkoutScore == 170)
        #expect(record.legs.first?.winningCheckoutRoute == "T20 T20 Bull")
    }

    @Test func bustCountAndVisitTimelineAreRecorded() {
        let game = DartsGame(playerCount: 2)
        let firstPlayerID = game.players[0].id
        let secondPlayerID = game.players[1].id

        game.players[0].score = 40
        game.currentTurn = Turn(startingScore: 40)
        game.submitThrow(segment: .number(20), multiplier: .triple)

        game.players[1].score = 40
        game.currentTurn = Turn(startingScore: 40)
        game.submitThrow(segment: .number(20), multiplier: .double)

        let leg = game.buildGameRecord().legs[0]
        let firstPlayerResult = leg.playerResults.first { $0.playerID == firstPlayerID }
        let secondPlayerVisits = leg.playerVisits.filter { $0.playerID == secondPlayerID }
        let firstPlayerVisits = leg.playerVisits.filter { $0.playerID == firstPlayerID }

        #expect(firstPlayerResult?.bustCount == 1)
        #expect(firstPlayerVisits.count == 1)
        #expect(firstPlayerVisits.first?.isBust == true)
        #expect(secondPlayerVisits.map(\.score) == [40])
    }

    @Test func firstNineAverageUsesAllScoredDartsWhenUnderNine() {
        let game = DartsGame(playerCount: 2)

        for _ in 0..<3 { game.submitThrow(segment: .number(20), multiplier: .single) }
        for _ in 0..<3 { game.submitThrow(segment: .number(0), multiplier: .single) }
        for _ in 0..<3 { game.submitThrow(segment: .number(20), multiplier: .single) }
        for _ in 0..<3 { game.submitThrow(segment: .number(0), multiplier: .single) }

        game.players[0].score = 40
        game.currentTurn = Turn(startingScore: 40)
        game.submitThrow(segment: .number(20), multiplier: .double)

        let firstNineAverage = game.buildGameRecord().legs[0].playerResults[0].firstNineAverage
        #expect(firstNineAverage != nil)
        #expect(abs((firstNineAverage ?? 0) - (160.0 / 7.0 * 3.0)) < 0.001)
    }

    @Test func firstNineAverageUsesExactlyNineDarts() {
        let game = DartsGame(playerCount: 2)

        for _ in 0..<3 { game.submitThrow(segment: .number(20), multiplier: .single) }
        for _ in 0..<3 { game.submitThrow(segment: .number(0), multiplier: .single) }
        for _ in 0..<3 { game.submitThrow(segment: .number(20), multiplier: .single) }
        for _ in 0..<3 { game.submitThrow(segment: .number(0), multiplier: .single) }
        for _ in 0..<3 { game.submitThrow(segment: .number(20), multiplier: .single) }
        for _ in 0..<3 { game.submitThrow(segment: .number(0), multiplier: .single) }

        game.players[0].score = 40
        game.currentTurn = Turn(startingScore: 40)
        game.submitThrow(segment: .number(20), multiplier: .double)

        let firstNineAverage = game.buildGameRecord().legs[0].playerResults[0].firstNineAverage
        #expect(firstNineAverage != nil)
        #expect(abs((firstNineAverage ?? 0) - 60.0) < 0.001)
    }

    @Test func firstNineAverageIgnoresDartsAfterNine() {
        let game = DartsGame(playerCount: 2)

        for _ in 0..<3 { game.submitThrow(segment: .number(20), multiplier: .single) }
        for _ in 0..<3 { game.submitThrow(segment: .number(0), multiplier: .single) }
        for _ in 0..<3 { game.submitThrow(segment: .number(20), multiplier: .single) }
        for _ in 0..<3 { game.submitThrow(segment: .number(0), multiplier: .single) }
        for _ in 0..<3 { game.submitThrow(segment: .number(20), multiplier: .single) }
        for _ in 0..<3 { game.submitThrow(segment: .number(0), multiplier: .single) }

        game.submitThrow(segment: .number(20), multiplier: .single)
        game.players[0].score = 40
        game.currentTurn = Turn(startingScore: 40)
        game.submitThrow(segment: .number(20), multiplier: .double)

        let firstNineAverage = game.buildGameRecord().legs[0].playerResults[0].firstNineAverage
        #expect(firstNineAverage != nil)
        #expect(abs((firstNineAverage ?? 0) - 60.0) < 0.001)
    }

    @Test func buildGameRecordIncludesCompletedPriorLegsAndFinalLeg() {
        let game = DartsGame(playerCount: 2, setModeEnabled: true, legsToWin: 2)

        game.players[0].score = 40
        game.currentTurn = Turn(startingScore: 40)
        game.submitThrow(segment: .number(20), multiplier: .double)

        game.players[0].score = 40
        game.currentTurn = Turn(startingScore: 40)
        game.submitThrow(segment: .number(20), multiplier: .double)

        let record = game.buildGameRecord()
        #expect(record.legs.count == 2)
        #expect(record.legs[0].winnerPlayerID == record.legs[1].winnerPlayerID)
    }
}
