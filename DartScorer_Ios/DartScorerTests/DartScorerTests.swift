import Foundation
import Testing
@testable import DartScorer

@MainActor
struct DartScorerTests {

    private func practiceSnapshot(
        from game: DartsGame,
        practiceMode: PracticeMode,
        playerScore: Int = 0,
        targetValue: Int = 0,
        progress: Int = 0,
        callTarget: PracticeCallTarget? = nil,
        currentStreak: Int = 0,
        competitiveEnabled: Bool = false,
        successesToWin: Int = 5
    ) -> NetworkGameState {
        var players = game.players
        if let firstIndex = players.indices.first {
            players[firstIndex].score = playerScore
        }

        let playerID = players.first?.id.uuidString ?? UUID().uuidString
        let callTargets = callTarget.map { [playerID: $0] } ?? [:]

        return NetworkGameState(
            players: players,
            activePlayerIndex: 0,
            currentTurn: Turn(startingScore: 0),
            winner: nil,
            setWinner: nil,
            statusMessage: nil,
            gameMode: GameMode.practice.rawValue,
            practiceMode: practiceMode.rawValue,
            practiceCompetitiveEnabled: competitiveEnabled,
            practiceSuccessesToWin: successesToWin,
            finishRule: GameMode.practice.rawValue,
            inRule: InRule.default.rawValue,
            startingScore: 0,
            setModeEnabled: false,
            legsToWin: 1,
            legsWonByPlayerID: [:],
            lastTurnThrowsByPlayerID: [:],
            pointsScoredByPlayerID: [:],
            dartsThrownByPlayerID: [:],
            hasOpenedLegByPlayerID: [:],
            highestTurnScoreByPlayerID: [:],
            checkoutOpportunitiesByPlayerID: [:],
            checkoutConversionsByPlayerID: [:],
            highestCheckoutByPlayerID: [:],
            cricketMarksByPlayerID: [:],
            cricketScoreByPlayerID: [:],
            practiceTargetValueByPlayerID: [playerID: targetValue],
            practiceProgressByPlayerID: [playerID: progress],
            practiceCallTargetByPlayerID: callTargets,
            practiceCurrentStreakByPlayerID: [playerID: currentStreak]
        )
    }

    private func trendRecord(
        profileID: UUID,
        date: Date,
        isWinner: Bool,
        average: Double,
        firstNineAverage: Double?,
        checkoutAttempts: Int,
        checkoutHits: Int,
        score180Count: Int = 0,
        score140PlusCount: Int = 0,
        totalDartsThrown: Int,
        totalPointsScored: Int,
        totalFirstNinePoints: Int,
        totalFirstNineDarts: Int,
        practiceMode: PracticeMode? = nil,
        finishRule: String = FinishRule.doubleOut.rawValue
    ) -> GameRecord {
        GameRecord(
            id: UUID(),
            date: date,
            startingScore: practiceMode == nil ? 501 : 0,
            finishRule: practiceMode == nil ? finishRule : GameMode.practice.rawValue,
            practiceMode: practiceMode?.rawValue,
            playerResults: [
                PlayerGameResult(
                    id: UUID(),
                    name: "Alex",
                    average: average,
                    firstNineAverage: firstNineAverage,
                    highestTurnScore: 140,
                    highestScore: 140,
                    checkoutPercentage: checkoutAttempts > 0 ? Double(checkoutHits) / Double(checkoutAttempts) : nil,
                    checkoutAttempts: checkoutAttempts,
                    checkoutHits: checkoutHits,
                    isWinner: isWinner,
                    profileID: profileID,
                    totalDartsThrown: totalDartsThrown,
                    totalPointsScored: totalPointsScored,
                    highestCheckout: 100,
                    score180Count: score180Count,
                    score140PlusCount: score140PlusCount,
                    totalFirstNinePoints: totalFirstNinePoints,
                    totalFirstNineDarts: totalFirstNineDarts
                )
            ],
            legs: []
        )
    }

    private func rivalryResult(
        profileID: UUID?,
        name: String,
        isWinner: Bool,
        average: Double = 60,
        firstNineAverage: Double? = 75,
        highestCheckout: Int = 100,
        totalDartsThrown: Int = 15,
        totalPointsScored: Int = 300,
        totalFirstNinePoints: Int = 90,
        totalFirstNineDarts: Int = 9
    ) -> PlayerGameResult {
        PlayerGameResult(
            id: profileID ?? UUID(),
            name: name,
            average: average,
            firstNineAverage: firstNineAverage,
            highestTurnScore: 140,
            highestScore: 140,
            checkoutPercentage: nil,
            checkoutAttempts: 0,
            checkoutHits: 0,
            isWinner: isWinner,
            profileID: profileID,
            totalDartsThrown: totalDartsThrown,
            totalPointsScored: totalPointsScored,
            highestCheckout: highestCheckout,
            score180Count: 0,
            score140PlusCount: 0,
            totalFirstNinePoints: totalFirstNinePoints,
            totalFirstNineDarts: totalFirstNineDarts
        )
    }

    private func rivalryRecord(
        date: Date,
        playerResults: [PlayerGameResult],
        finishRule: String = FinishRule.doubleOut.rawValue,
        startingScore: Int = 501,
        practiceMode: PracticeMode? = nil
    ) -> GameRecord {
        GameRecord(
            id: UUID(),
            date: date,
            startingScore: practiceMode == nil ? startingScore : 0,
            finishRule: practiceMode == nil ? finishRule : GameMode.practice.rawValue,
            practiceMode: practiceMode?.rawValue,
            playerResults: playerResults,
            legs: []
        )
    }

    private func tournamentParticipant(seed: Int, name: String) -> TournamentParticipant {
        TournamentParticipant(
            profileID: UUID(),
            name: name,
            colorHex: "#\(seed)\(seed)\(seed)\(seed)\(seed)\(seed)",
            seed: seed
        )
    }

    private func tournamentRecord(
        playerA: TournamentParticipant,
        playerB: TournamentParticipant,
        winner: TournamentParticipant,
        playerALegsWon: Int,
        playerBLegsWon: Int,
        date: Date = .init(timeIntervalSince1970: 1)
    ) -> GameRecord {
        let playerAIsWinner = winner.id == playerA.id
        let legs: [LegRecord] = (0..<(playerALegsWon + playerBLegsWon)).map { index in
            let winnerPlayerID = index < playerALegsWon ? playerA.profileID : playerB.profileID
            return LegRecord(
                legNumber: index + 1,
                startingPlayerID: index.isMultiple(of: 2) ? playerA.profileID : playerB.profileID,
                winnerPlayerID: winnerPlayerID,
                checkoutScore: nil,
                winningCheckoutRoute: nil,
                playerVisits: [],
                playerResults: []
            )
        }
        return GameRecord(
            id: UUID(),
            date: date,
            startingScore: 501,
            finishRule: FinishRule.doubleOut.rawValue,
            playerResults: [
                PlayerGameResult(
                    id: playerA.profileID,
                    name: playerA.name,
                    average: 60,
                    firstNineAverage: 75,
                    highestTurnScore: 140,
                    highestScore: 140,
                    checkoutPercentage: nil,
                    checkoutAttempts: 0,
                    checkoutHits: 0,
                    isWinner: playerAIsWinner,
                    profileID: playerA.profileID,
                    totalDartsThrown: 15,
                    totalPointsScored: 300,
                    highestCheckout: 100,
                    score180Count: 0,
                    score140PlusCount: 0,
                    totalFirstNinePoints: 90,
                    totalFirstNineDarts: 9
                ),
                PlayerGameResult(
                    id: playerB.profileID,
                    name: playerB.name,
                    average: 55,
                    firstNineAverage: 70,
                    highestTurnScore: 121,
                    highestScore: 121,
                    checkoutPercentage: nil,
                    checkoutAttempts: 0,
                    checkoutHits: 0,
                    isWinner: !playerAIsWinner,
                    profileID: playerB.profileID,
                    totalDartsThrown: 15,
                    totalPointsScored: 275,
                    highestCheckout: 80,
                    score180Count: 0,
                    score140PlusCount: 0,
                    totalFirstNinePoints: 84,
                    totalFirstNineDarts: 9
                )
            ],
            legs: legs
        )
    }

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

    @Test func restartLegResetsX01ScoresAndCurrentVisit() {
        let game = DartsGame(playerCount: 2)

        game.submitThrow(segment: .number(20), multiplier: .triple)
        game.submitThrow(segment: .number(19), multiplier: .triple)

        #expect(game.players[0].score == 384)
        #expect(game.currentTurn.darts.count == 2)

        game.restartLeg()

        #expect(game.players.allSatisfy { $0.score == 501 })
        #expect(game.activePlayerIndex == 0)
        #expect(game.currentTurn.darts.isEmpty)
        #expect(game.lastTurnThrows(for: game.players[0]).isEmpty)
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
            practiceMode: .scoringDrill,
            practiceCompetitiveEnabled: false,
            practiceSuccessesToWin: 5,
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

    @Test func cricketTracksMarksForAllTargetsFrom20To15AndBull() {
        let expectations: [(CricketTarget, DartSegment, DartMultiplier, Int)] = [
            (.twenty, .number(20), .triple, 3),
            (.nineteen, .number(19), .double, 2),
            (.eighteen, .number(18), .single, 1),
            (.seventeen, .number(17), .triple, 3),
            (.sixteen, .number(16), .double, 2),
            (.fifteen, .number(15), .single, 1),
            (.bull, .bull, .double, 2)
        ]

        for (target, segment, multiplier, expectedMarks) in expectations {
            let freshGame = DartsGame(playerCount: 2, gameMode: .cricket)
            freshGame.submitThrow(segment: segment, multiplier: multiplier)
            #expect(freshGame.cricketMarks(for: freshGame.players[0], target: target) == expectedMarks)
        }
    }

    @Test func cricketCountsMarksAndScoresOverflow() {
        let game = DartsGame(playerCount: 2, gameMode: .cricket)

        game.submitThrow(segment: .number(20), multiplier: .triple)
        game.submitThrow(segment: .number(20), multiplier: .triple)

        #expect(game.cricketMarks(for: game.players[0], target: .twenty) == 3)
        #expect(game.cricketScore(for: game.players[0]) == 60)
    }

    @Test func cricketDoesNotScoreWhenAllOpponentsClosedTarget() {
        let game = DartsGame(playerCount: 2, gameMode: .cricket)
        let playerOne = game.players[0]
        let playerTwo = game.players[1]
        let snapshot = NetworkGameState(
            players: game.players,
            activePlayerIndex: 0,
            currentTurn: Turn(startingScore: 0),
            winner: nil,
            setWinner: nil,
            statusMessage: nil,
            gameMode: GameMode.cricket.rawValue,
            practiceMode: PracticeMode.scoringDrill.rawValue,
            practiceCompetitiveEnabled: false,
            practiceSuccessesToWin: 5,
            finishRule: FinishRule.doubleOut.rawValue,
            inRule: InRule.default.rawValue,
            startingScore: 0,
            setModeEnabled: false,
            legsToWin: 1,
            legsWonByPlayerID: [:],
            lastTurnThrowsByPlayerID: [:],
            pointsScoredByPlayerID: [:],
            dartsThrownByPlayerID: [:],
            hasOpenedLegByPlayerID: [:],
            highestTurnScoreByPlayerID: [:],
            checkoutOpportunitiesByPlayerID: [:],
            checkoutConversionsByPlayerID: [:],
            highestCheckoutByPlayerID: [:],
            cricketMarksByPlayerID: [
                playerOne.id.uuidString: ["20": 3],
                playerTwo.id.uuidString: ["20": 3]
            ],
            cricketScoreByPlayerID: [:],
            practiceTargetValueByPlayerID: [:],
            practiceProgressByPlayerID: [:],
            practiceCallTargetByPlayerID: [:],
            practiceCurrentStreakByPlayerID: [:]
        )

        game.applySnapshot(snapshot)
        game.submitThrow(segment: .number(20), multiplier: .triple)

        #expect(game.cricketMarks(for: game.players[0], target: .twenty) == 3)
        #expect(game.cricketScore(for: game.players[0]) == 0)
    }

    @Test func cricketWinnerRequiresClosedTargetsAndLead() {
        let game = DartsGame(playerCount: 1, gameMode: .cricket)

        for target in game.cricketTargets {
            let segment: DartSegment = target == .bull ? .bull : .number(target.rawValue)
            if target == .bull {
                game.submitThrow(segment: segment, multiplier: .double)
                game.submitThrow(segment: segment, multiplier: .single)
                game.submitThrow(segment: .number(0), multiplier: .single)
            } else {
                game.submitThrow(segment: segment, multiplier: .triple)
                game.submitThrow(segment: .number(0), multiplier: .single)
                game.submitThrow(segment: .number(0), multiplier: .single)
            }
        }

        #expect(game.winner?.id == game.players[0].id)
    }

    @Test func cricketDoesNotWinWhenClosingLastTargetWhileStillBehind() {
        let game = DartsGame(playerCount: 2, gameMode: .cricket)
        let playerOne = game.players[0]
        let playerTwo = game.players[1]

        let closedExceptBull: [String: Int] = [
            "20": 3, "19": 3, "18": 3, "17": 3, "16": 3, "15": 3, "25": 2
        ]

        let snapshot = NetworkGameState(
            players: game.players,
            activePlayerIndex: 0,
            currentTurn: Turn(startingScore: 0),
            winner: nil,
            setWinner: nil,
            statusMessage: nil,
            gameMode: GameMode.cricket.rawValue,
            practiceMode: PracticeMode.scoringDrill.rawValue,
            practiceCompetitiveEnabled: false,
            practiceSuccessesToWin: 5,
            finishRule: FinishRule.doubleOut.rawValue,
            inRule: InRule.default.rawValue,
            startingScore: 0,
            setModeEnabled: false,
            legsToWin: 1,
            legsWonByPlayerID: [:],
            lastTurnThrowsByPlayerID: [:],
            pointsScoredByPlayerID: [:],
            dartsThrownByPlayerID: [:],
            hasOpenedLegByPlayerID: [:],
            highestTurnScoreByPlayerID: [:],
            checkoutOpportunitiesByPlayerID: [:],
            checkoutConversionsByPlayerID: [:],
            highestCheckoutByPlayerID: [:],
            cricketMarksByPlayerID: [
                playerOne.id.uuidString: closedExceptBull,
                playerTwo.id.uuidString: [:]
            ],
            cricketScoreByPlayerID: [
                playerOne.id.uuidString: 0,
                playerTwo.id.uuidString: 40
            ],
            practiceTargetValueByPlayerID: [:],
            practiceProgressByPlayerID: [:],
            practiceCallTargetByPlayerID: [:],
            practiceCurrentStreakByPlayerID: [:]
        )

        game.applySnapshot(snapshot)
        game.submitThrow(segment: .bull, multiplier: .single)

        #expect(game.allCricketTargetsClosed(for: game.players[0]) == true)
        #expect(game.cricketScore(for: game.players[0]) == 0)
        #expect(game.winner == nil)
    }

    @Test func cricketWinsWhenClosingLastTargetLevelOrAhead() {
        let game = DartsGame(playerCount: 2, gameMode: .cricket)
        let playerOne = game.players[0]
        let playerTwo = game.players[1]

        let closedExceptBull: [String: Int] = [
            "20": 3, "19": 3, "18": 3, "17": 3, "16": 3, "15": 3, "25": 2
        ]

        let snapshot = NetworkGameState(
            players: game.players,
            activePlayerIndex: 0,
            currentTurn: Turn(startingScore: 0),
            winner: nil,
            setWinner: nil,
            statusMessage: nil,
            gameMode: GameMode.cricket.rawValue,
            practiceMode: PracticeMode.scoringDrill.rawValue,
            practiceCompetitiveEnabled: false,
            practiceSuccessesToWin: 5,
            finishRule: FinishRule.doubleOut.rawValue,
            inRule: InRule.default.rawValue,
            startingScore: 0,
            setModeEnabled: false,
            legsToWin: 1,
            legsWonByPlayerID: [:],
            lastTurnThrowsByPlayerID: [:],
            pointsScoredByPlayerID: [:],
            dartsThrownByPlayerID: [:],
            hasOpenedLegByPlayerID: [:],
            highestTurnScoreByPlayerID: [:],
            checkoutOpportunitiesByPlayerID: [:],
            checkoutConversionsByPlayerID: [:],
            highestCheckoutByPlayerID: [:],
            cricketMarksByPlayerID: [
                playerOne.id.uuidString: closedExceptBull,
                playerTwo.id.uuidString: [:]
            ],
            cricketScoreByPlayerID: [
                playerOne.id.uuidString: 40,
                playerTwo.id.uuidString: 40
            ],
            practiceTargetValueByPlayerID: [:],
            practiceProgressByPlayerID: [:],
            practiceCallTargetByPlayerID: [:],
            practiceCurrentStreakByPlayerID: [:]
        )

        game.applySnapshot(snapshot)
        game.submitThrow(segment: .bull, multiplier: .single)

        #expect(game.allCricketTargetsClosed(for: game.players[0]) == true)
        #expect(game.winner?.id == game.players[0].id)
    }

    @Test func cricketSupportsFivePlayers() {
        let game = DartsGame(playerCount: 5, gameMode: .cricket)

        #expect(game.players.count == 5)
        #expect(game.players.allSatisfy { player in
            game.cricketTargets.allSatisfy { game.cricketMarks(for: player, target: $0) == 0 }
        })
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
        #expect(record.legs.map(\.legNumber) == [1, 2])
    }

    @Test func matchShareSummaryUsesX01Stats() {
        let winnerID = UUID()
        let loserID = UUID()
        let record = GameRecord(
            id: UUID(),
            date: Date(timeIntervalSince1970: 0),
            startingScore: 501,
            finishRule: FinishRule.doubleOut.rawValue,
            playerResults: [
                PlayerGameResult(
                    id: winnerID,
                    name: "Alex",
                    average: 72.4,
                    firstNineAverage: 80.0,
                    highestTurnScore: 140,
                    highestScore: 140,
                    checkoutPercentage: 0.5,
                    checkoutAttempts: 2,
                    checkoutHits: 1,
                    isWinner: true,
                    profileID: nil,
                    totalDartsThrown: 21,
                    totalPointsScored: 501,
                    highestCheckout: 101,
                    score180Count: 0,
                    score140PlusCount: 1,
                    totalFirstNinePoints: 240,
                    totalFirstNineDarts: 9
                ),
                PlayerGameResult(
                    id: loserID,
                    name: "Chris",
                    average: 61.8,
                    firstNineAverage: 65.0,
                    highestTurnScore: 100,
                    highestScore: 100,
                    checkoutPercentage: nil,
                    checkoutAttempts: 0,
                    checkoutHits: 0,
                    isWinner: false,
                    profileID: nil,
                    totalDartsThrown: 24,
                    totalPointsScored: 421,
                    highestCheckout: 0,
                    score180Count: 0,
                    score140PlusCount: 0,
                    totalFirstNinePoints: 195,
                    totalFirstNineDarts: 9
                )
            ],
            legs: []
        )

        let summary = MatchShareSummary(record: record)

        #expect(summary.winnerName == "Alex")
        #expect(summary.format == "501 • \(FinishRule.doubleOut.label)")
        #expect(summary.playerLines.first?.stats.map(\.title) == [
            L10n.string("Average"),
            L10n.string("Best Checkout"),
            L10n.string("Best Turn")
        ])
    }

    @Test func matchShareSummaryUsesCricketStats() {
        let playerID = UUID()
        let record = GameRecord(
            id: UUID(),
            date: Date(timeIntervalSince1970: 0),
            startingScore: 0,
            finishRule: GameMode.cricket.rawValue,
            playerResults: [
                PlayerGameResult(
                    id: playerID,
                    name: "Taylor",
                    average: 18.0,
                    firstNineAverage: nil,
                    highestTurnScore: 60,
                    highestScore: 60,
                    checkoutPercentage: nil,
                    checkoutAttempts: 0,
                    checkoutHits: 0,
                    isWinner: true,
                    profileID: nil,
                    totalDartsThrown: 27,
                    totalPointsScored: 85,
                    highestCheckout: 0,
                    score180Count: 0,
                    score140PlusCount: 0,
                    totalFirstNinePoints: 0,
                    totalFirstNineDarts: 0
                )
            ],
            legs: []
        )

        let summary = MatchShareSummary(record: record)

        #expect(summary.format == GameMode.cricket.label)
        #expect(summary.playerLines.first?.stats.map(\.title) == [
            L10n.string("Score"),
            L10n.string("Darts"),
            L10n.string("Best Turn")
        ])
    }

    @Test func matchShareSummaryTextIncludesLocalizedWinnerLine() {
        let playerID = UUID()
        let record = GameRecord(
            id: UUID(),
            date: Date(timeIntervalSince1970: 0),
            startingScore: 0,
            finishRule: GameMode.practice.rawValue,
            playerResults: [
                PlayerGameResult(
                    id: playerID,
                    name: "Jordan",
                    average: 45.0,
                    firstNineAverage: nil,
                    highestTurnScore: 125,
                    highestScore: 125,
                    checkoutPercentage: nil,
                    checkoutAttempts: 0,
                    checkoutHits: 0,
                    isWinner: true,
                    profileID: nil,
                    totalDartsThrown: 18,
                    totalPointsScored: 270,
                    highestCheckout: 0,
                    score180Count: 0,
                    score140PlusCount: 0,
                    totalFirstNinePoints: 0,
                    totalFirstNineDarts: 0
                )
            ],
            legs: []
        )

        let summary = MatchShareSummary(record: record)

        #expect(summary.textSummary.contains(L10n.format("Winner: %@", "Jordan")))
        #expect(summary.textSummary.contains(L10n.string("Scored with Just a Darts Scorer")))
    }

    @Test func practiceGameRecordStoresPracticeModeForHistory() {
        let game = DartsGame(playerCount: 1, gameMode: .practice, practiceMode: .doublesPractice)

        let record = game.buildGameRecord()

        #expect(record.finishRule == GameMode.practice.rawValue)
        #expect(record.practiceMode == PracticeMode.doublesPractice.rawValue)

        let summary = MatchShareSummary(record: record)
        #expect(summary.format == PracticeMode.doublesPractice.label)
    }

    @Test func scoringDrillQuickScoreAddsPointsAndEndsTurn() {
        let game = DartsGame(playerCount: 2, gameMode: .practice, practiceMode: .scoringDrill)

        game.submitQuickScore(140)

        #expect(game.players[0].score == 140)
        #expect(game.activePlayerIndex == 1)
        #expect(game.lastTurnThrows(for: game.players[0]) == [140])
    }

    @Test func checkoutPracticeCountsWholeVisitTowardsTarget() {
        let game = DartsGame(playerCount: 2, gameMode: .practice, practiceMode: .checkoutPractice)
        game.applySnapshot(
            practiceSnapshot(
                from: game,
                practiceMode: .checkoutPractice,
                targetValue: 41
            )
        )

        game.submitThrow(segment: .number(20), multiplier: .single)
        game.submitThrow(segment: .number(20), multiplier: .single)
        game.submitThrow(segment: .number(1), multiplier: .single)

        #expect(game.players[0].score == 1)
        #expect(game.activePlayerIndex == 1)
    }

    @Test func doublesPracticeScoresOnCalledDouble() {
        let game = DartsGame(playerCount: 2, gameMode: .practice, practiceMode: .doublesPractice)
        game.applySnapshot(
            practiceSnapshot(
                from: game,
                practiceMode: .doublesPractice,
                targetValue: 16
            )
        )

        game.submitThrow(segment: .number(16), multiplier: .double)

        #expect(game.players[0].score == 1)
        #expect(game.activePlayerIndex == 1)
    }

    @Test func aroundTheClockWinsOnFinalBull() {
        let game = DartsGame(playerCount: 2, gameMode: .practice, practiceMode: .aroundTheClock)
        game.applySnapshot(
            practiceSnapshot(
                from: game,
                practiceMode: .aroundTheClock,
                playerScore: 20,
                targetValue: 25,
                progress: 20
            )
        )

        game.submitThrow(segment: .bull, multiplier: .single)

        #expect(game.players[0].score == 21)
        #expect(game.winner?.id == game.players[0].id)
    }

    @Test func firstNineChallengeEndsAfterThreeVisits() {
        let game = DartsGame(playerCount: 1, gameMode: .practice, practiceMode: .first9Challenge)

        for _ in 0..<9 {
            game.submitThrow(segment: .number(20), multiplier: .single)
        }

        #expect(game.winner?.id == game.players[0].id)
        #expect(game.players[0].score == 180)
        #expect(game.practiceProgressByPlayerID[game.players[0].id] == 3)
    }

    @Test func firstNineChallengeUsesExtraRoundToBreakTie() {
        let game = DartsGame(playerCount: 2, gameMode: .practice, practiceMode: .first9Challenge)

        for _ in 0..<3 {
            game.submitThrow(segment: .number(20), multiplier: .single)
            game.submitThrow(segment: .number(0), multiplier: .single)
            game.submitThrow(segment: .number(0), multiplier: .single)

            game.submitThrow(segment: .number(20), multiplier: .single)
            game.submitThrow(segment: .number(0), multiplier: .single)
            game.submitThrow(segment: .number(0), multiplier: .single)
        }

        #expect(game.winner == nil)
        #expect(game.statusMessage == L10n.format("Tiebreak Round %@", "1"))

        game.submitThrow(segment: .number(20), multiplier: .single)
        game.submitThrow(segment: .number(0), multiplier: .single)
        game.submitThrow(segment: .number(0), multiplier: .single)

        #expect(game.winner == nil)

        game.submitThrow(segment: .number(5), multiplier: .single)
        game.submitThrow(segment: .number(0), multiplier: .single)
        game.submitThrow(segment: .number(0), multiplier: .single)

        #expect(game.winner?.id == game.players[0].id)
        #expect(game.players[0].score == 80)
        #expect(game.players[1].score == 65)
    }

    @Test func pressureFinishesResetsSuccessCountOnFailedVisit() {
        let game = DartsGame(playerCount: 1, gameMode: .practice, practiceMode: .pressureFinishes)
        game.applySnapshot(
            practiceSnapshot(
                from: game,
                practiceMode: .pressureFinishes,
                playerScore: 1,
                targetValue: 41
            )
        )

        game.submitThrow(segment: .number(20), multiplier: .single)
        game.submitThrow(segment: .number(20), multiplier: .single)
        game.submitThrow(segment: .number(0), multiplier: .single)

        #expect(game.players[0].score == 0)
        #expect(game.winner == nil)
    }

    @Test func randomTargetScoresWhenCalledTargetIsHit() {
        let game = DartsGame(playerCount: 1, gameMode: .practice, practiceMode: .randomTarget)
        game.applySnapshot(
            practiceSnapshot(
                from: game,
                practiceMode: .randomTarget,
                callTarget: .number(20, .triple)
            )
        )

        game.submitThrow(segment: .number(20), multiplier: .triple)

        #expect(game.players[0].score == 1)
        #expect(game.winner == nil)
    }

    @Test func randomTargetCanWinInCompetitiveMode() {
        let game = DartsGame(playerCount: 2, gameMode: .practice, practiceMode: .randomTarget)
        game.applySnapshot(
            practiceSnapshot(
                from: game,
                practiceMode: .randomTarget,
                playerScore: 1,
                callTarget: .number(20, .triple),
                competitiveEnabled: true,
                successesToWin: 2
            )
        )

        game.submitThrow(segment: .number(20), multiplier: .triple)

        #expect(game.winner?.id == game.players[0].id)
        #expect(game.players[0].score == 2)
    }

    @Test func streakModeKeepsLongestStreakAndResetsCurrentStreakOnMiss() {
        let game = DartsGame(playerCount: 1, gameMode: .practice, practiceMode: .streakMode)
        game.applySnapshot(
            practiceSnapshot(
                from: game,
                practiceMode: .streakMode,
                callTarget: .number(20, .triple)
            )
        )

        game.submitThrow(segment: .number(20), multiplier: .triple)
        game.submitThrow(segment: .number(20), multiplier: .triple)
        game.submitThrow(segment: .number(1), multiplier: .single)

        #expect(game.players[0].score == 2)
        #expect(game.practiceCurrentStreakByPlayerID[game.players[0].id] == 0)
    }

    @Test func pressureFinishesCanWinInCompetitiveMode() {
        let game = DartsGame(playerCount: 2, gameMode: .practice, practiceMode: .pressureFinishes)
        game.applySnapshot(
            practiceSnapshot(
                from: game,
                practiceMode: .pressureFinishes,
                playerScore: 1,
                targetValue: 40,
                competitiveEnabled: true,
                successesToWin: 2
            )
        )

        game.submitThrow(segment: .number(20), multiplier: .double)

        #expect(game.winner?.id == game.players[0].id)
    }

    @Test func streakModeCanWinInCompetitiveMode() {
        let game = DartsGame(playerCount: 2, gameMode: .practice, practiceMode: .streakMode)
        game.applySnapshot(
            practiceSnapshot(
                from: game,
                practiceMode: .streakMode,
                playerScore: 1,
                callTarget: .number(20, .triple),
                currentStreak: 1,
                competitiveEnabled: true,
                successesToWin: 2
            )
        )

        game.submitThrow(segment: .number(20), multiplier: .triple)

        #expect(game.winner?.id == game.players[0].id)
        #expect(game.players[0].score == 2)
    }

    @Test func profileTrendsUseLastFiveQualifyingRecordsForAverage() {
        let profileID = UUID()
        var stats = PlayerProfileStats()
        stats.gamesPlayed = 6
        stats.gamesWon = 3
        stats.totalDartsThrown = 60
        stats.totalPointsScored = 1200
        stats.totalFirstNinePoints = 270
        stats.totalFirstNineDarts = 18
        stats.checkoutAttempts = 10
        stats.checkoutHits = 4
        stats.score180Count = 1
        stats.score140PlusCount = 3
        stats.highestCheckout = 100
        stats.highestTurnScore = 140
        stats.highestScore = 140
        let records = [
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 6), isWinner: true, average: 60, firstNineAverage: 70, checkoutAttempts: 2, checkoutHits: 1, totalDartsThrown: 20, totalPointsScored: 400, totalFirstNinePoints: 90, totalFirstNineDarts: 9),
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 5), isWinner: false, average: 45, firstNineAverage: 50, checkoutAttempts: 1, checkoutHits: 0, totalDartsThrown: 10, totalPointsScored: 150, totalFirstNinePoints: 60, totalFirstNineDarts: 9),
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 4), isWinner: true, average: 30, firstNineAverage: 35, checkoutAttempts: 0, checkoutHits: 0, totalDartsThrown: 10, totalPointsScored: 100, totalFirstNinePoints: 30, totalFirstNineDarts: 6),
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 3), isWinner: false, average: 30, firstNineAverage: 30, checkoutAttempts: 0, checkoutHits: 0, totalDartsThrown: 10, totalPointsScored: 100, totalFirstNinePoints: 30, totalFirstNineDarts: 6),
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 2), isWinner: true, average: 30, firstNineAverage: 40, checkoutAttempts: 1, checkoutHits: 1, totalDartsThrown: 10, totalPointsScored: 100, totalFirstNinePoints: 60, totalFirstNineDarts: 9),
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 1), isWinner: true, average: 90, firstNineAverage: 90, checkoutAttempts: 1, checkoutHits: 1, totalDartsThrown: 5, totalPointsScored: 150, totalFirstNinePoints: 90, totalFirstNineDarts: 3)
        ]

        let snapshot = ProfileTrends.makeSnapshot(
            for: profileID,
            stats: stats,
            records: records,
            filter: GameRecordFilter()
        )

        #expect(snapshot.sampleSize == 5)
        #expect(snapshot.average.recentValue != nil)
        #expect(abs((snapshot.average.recentValue ?? 0) - 42.5) < 0.001)
    }

    @Test func gameRecordFilterX01ExcludesCricketAndPractice() {
        let profileID = UUID()
        let records = [
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 3), isWinner: true, average: 50, firstNineAverage: 55, checkoutAttempts: 1, checkoutHits: 1, totalDartsThrown: 10, totalPointsScored: 170, totalFirstNinePoints: 90, totalFirstNineDarts: 9, practiceMode: .scoringDrill),
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 2), isWinner: false, average: 60, firstNineAverage: 60, checkoutAttempts: 2, checkoutHits: 1, totalDartsThrown: 20, totalPointsScored: 400, totalFirstNinePoints: 180, totalFirstNineDarts: 9),
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 1), isWinner: true, average: 45, firstNineAverage: 50, checkoutAttempts: 1, checkoutHits: 0, totalDartsThrown: 12, totalPointsScored: 180, totalFirstNinePoints: 90, totalFirstNineDarts: 6, finishRule: GameMode.cricket.rawValue)
        ]

        let filter = GameRecordFilter(mode: .x01)
        let filtered = filter.filteredRecords(from: records)

        #expect(filtered.count == 1)
        #expect(filtered.allSatisfy(\.isX01Record))
    }

    @Test func gameRecordFilterCricketIncludesOnlyCricketRecords() {
        let profileID = UUID()
        let records = [
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 3), isWinner: true, average: 50, firstNineAverage: 55, checkoutAttempts: 1, checkoutHits: 1, totalDartsThrown: 10, totalPointsScored: 170, totalFirstNinePoints: 90, totalFirstNineDarts: 9, practiceMode: .scoringDrill),
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 2), isWinner: false, average: 60, firstNineAverage: 60, checkoutAttempts: 2, checkoutHits: 1, totalDartsThrown: 20, totalPointsScored: 400, totalFirstNinePoints: 180, totalFirstNineDarts: 9),
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 1), isWinner: true, average: 45, firstNineAverage: 50, checkoutAttempts: 1, checkoutHits: 0, totalDartsThrown: 12, totalPointsScored: 180, totalFirstNinePoints: 90, totalFirstNineDarts: 6, practiceMode: .doublesPractice)
        ]

        let cricketRecord = trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 4), isWinner: true, average: 42, firstNineAverage: nil, checkoutAttempts: 0, checkoutHits: 0, totalDartsThrown: 18, totalPointsScored: 80, totalFirstNinePoints: 0, totalFirstNineDarts: 0, finishRule: GameMode.cricket.rawValue)
        let filtered = GameRecordFilter(mode: .cricket).filteredRecords(from: records + [cricketRecord])

        #expect(filtered.count == 1)
        #expect(filtered.allSatisfy(\.isCricketRecord))
    }

    @Test func gameRecordFilterPracticeIncludesAllPracticeVariants() {
        let profileID = UUID()
        let records = [
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 3), isWinner: true, average: 50, firstNineAverage: 55, checkoutAttempts: 1, checkoutHits: 1, totalDartsThrown: 10, totalPointsScored: 170, totalFirstNinePoints: 90, totalFirstNineDarts: 9, practiceMode: .scoringDrill),
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 2), isWinner: true, average: 50, firstNineAverage: 55, checkoutAttempts: 1, checkoutHits: 1, totalDartsThrown: 10, totalPointsScored: 170, totalFirstNinePoints: 90, totalFirstNineDarts: 9, practiceMode: .doublesPractice),
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 1), isWinner: false, average: 60, firstNineAverage: 60, checkoutAttempts: 2, checkoutHits: 1, totalDartsThrown: 20, totalPointsScored: 400, totalFirstNinePoints: 180, totalFirstNineDarts: 9)
        ]

        let filtered = GameRecordFilter(mode: .practice).filteredRecords(from: records)

        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy(\.isPracticeRecord))
    }

    @Test func gameRecordFilterLastSevenDaysIncludesBoundary() {
        let profileID = UUID()
        let now = Date(timeIntervalSince1970: 10 * 24 * 60 * 60)
        let inside = trendRecord(profileID: profileID, date: now.addingTimeInterval(-6 * 24 * 60 * 60), isWinner: true, average: 50, firstNineAverage: nil, checkoutAttempts: 0, checkoutHits: 0, totalDartsThrown: 10, totalPointsScored: 150, totalFirstNinePoints: 0, totalFirstNineDarts: 0)
        let outside = trendRecord(profileID: profileID, date: now.addingTimeInterval(-7 * 24 * 60 * 60).addingTimeInterval(-60), isWinner: true, average: 50, firstNineAverage: nil, checkoutAttempts: 0, checkoutHits: 0, totalDartsThrown: 10, totalPointsScored: 150, totalFirstNinePoints: 0, totalFirstNineDarts: 0)

        let filtered = GameRecordFilter(date: .last7Days).filteredRecords(from: [inside, outside], now: now)

        #expect(filtered.count == 1)
        #expect(filtered.first?.id == inside.id)
    }

    @Test func gameRecordFilterCustomRangeIncludesBothBoundaries() {
        let profileID = UUID()
        let start = Date(timeIntervalSince1970: 1_000_000)
        let end = Date(timeIntervalSince1970: 1_100_000)
        let lowerBoundary = trendRecord(profileID: profileID, date: start, isWinner: true, average: 50, firstNineAverage: nil, checkoutAttempts: 0, checkoutHits: 0, totalDartsThrown: 10, totalPointsScored: 150, totalFirstNinePoints: 0, totalFirstNineDarts: 0)
        let upperBoundary = trendRecord(profileID: profileID, date: end, isWinner: true, average: 50, firstNineAverage: nil, checkoutAttempts: 0, checkoutHits: 0, totalDartsThrown: 10, totalPointsScored: 150, totalFirstNinePoints: 0, totalFirstNineDarts: 0)
        let outside = trendRecord(profileID: profileID, date: end.addingTimeInterval(24 * 60 * 60), isWinner: true, average: 50, firstNineAverage: nil, checkoutAttempts: 0, checkoutHits: 0, totalDartsThrown: 10, totalPointsScored: 150, totalFirstNinePoints: 0, totalFirstNineDarts: 0)

        let filter = GameRecordFilter(mode: .all, date: .custom, customStartDate: start, customEndDate: end)
        let filtered = filter.filteredRecords(from: [lowerBoundary, upperBoundary, outside], now: end)

        #expect(filtered.count == 2)
    }

    @Test func combinedModeAndDateFilterWorksTogether() {
        let profileID = UUID()
        let now = Date(timeIntervalSince1970: 100 * 24 * 60 * 60)
        let recentPractice = trendRecord(profileID: profileID, date: now.addingTimeInterval(-2 * 24 * 60 * 60), isWinner: true, average: 50, firstNineAverage: nil, checkoutAttempts: 0, checkoutHits: 0, totalDartsThrown: 10, totalPointsScored: 150, totalFirstNinePoints: 0, totalFirstNineDarts: 0, practiceMode: .scoringDrill)
        let oldPractice = trendRecord(profileID: profileID, date: now.addingTimeInterval(-40 * 24 * 60 * 60), isWinner: true, average: 50, firstNineAverage: nil, checkoutAttempts: 0, checkoutHits: 0, totalDartsThrown: 10, totalPointsScored: 150, totalFirstNinePoints: 0, totalFirstNineDarts: 0, practiceMode: .doublesPractice)
        let recentX01 = trendRecord(profileID: profileID, date: now.addingTimeInterval(-2 * 24 * 60 * 60), isWinner: true, average: 50, firstNineAverage: nil, checkoutAttempts: 0, checkoutHits: 0, totalDartsThrown: 10, totalPointsScored: 150, totalFirstNinePoints: 0, totalFirstNineDarts: 0)

        let filtered = GameRecordFilter(mode: .practice, date: .last30Days).filteredRecords(from: [recentPractice, oldPractice, recentX01], now: now)

        #expect(filtered.count == 1)
        #expect(filtered.first?.id == recentPractice.id)
    }

    @Test func filteredProfileStatsUseMatchingRecordsOnly() {
        let profileID = UUID()
        let records = [
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 3), isWinner: true, average: 50, firstNineAverage: 55, checkoutAttempts: 1, checkoutHits: 1, totalDartsThrown: 10, totalPointsScored: 170, totalFirstNinePoints: 90, totalFirstNineDarts: 9, practiceMode: .scoringDrill),
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 2), isWinner: false, average: 60, firstNineAverage: 60, checkoutAttempts: 2, checkoutHits: 1, totalDartsThrown: 20, totalPointsScored: 400, totalFirstNinePoints: 180, totalFirstNineDarts: 9),
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 1), isWinner: true, average: 45, firstNineAverage: 50, checkoutAttempts: 1, checkoutHits: 0, totalDartsThrown: 12, totalPointsScored: 180, totalFirstNinePoints: 90, totalFirstNineDarts: 6, finishRule: GameMode.cricket.rawValue)
        ]

        let snapshot = FilteredProfileStatsBuilder.makeSnapshot(
            for: profileID,
            stats: PlayerProfileStats(),
            records: records,
            filter: GameRecordFilter(mode: .practice)
        )

        #expect(snapshot.recordCount == 1)
        #expect(snapshot.gamesPlayed == 1)
        #expect(snapshot.gamesWon == 1)
    }

    @Test func allTimeUnfilteredProfileStatsUseLifetimeStats() {
        let profileID = UUID()
        var stats = PlayerProfileStats()
        stats.gamesPlayed = 12
        stats.gamesWon = 8
        stats.totalDartsThrown = 120
        stats.totalPointsScored = 3600
        stats.totalFirstNinePoints = 900
        stats.totalFirstNineDarts = 45
        stats.checkoutAttempts = 20
        stats.checkoutHits = 10
        stats.highestCheckout = 121
        stats.highestTurnScore = 180
        stats.highestScore = 180
        stats.score180Count = 4
        stats.score140PlusCount = 9

        let snapshot = FilteredProfileStatsBuilder.makeSnapshot(
            for: profileID,
            stats: stats,
            records: [],
            filter: GameRecordFilter()
        )

        #expect(snapshot.gamesPlayed == 12)
        #expect(snapshot.gamesWon == 8)
        #expect(snapshot.average == stats.legAverage)
        #expect(snapshot.score180Count == 4)
    }

    @Test func filteredProfileStatsCheckoutPercentageIsNilWithoutAttempts() {
        let profileID = UUID()
        let records = [
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 1), isWinner: true, average: 50, firstNineAverage: nil, checkoutAttempts: 0, checkoutHits: 0, totalDartsThrown: 10, totalPointsScored: 150, totalFirstNinePoints: 0, totalFirstNineDarts: 0)
        ]

        let snapshot = FilteredProfileStatsBuilder.makeSnapshot(
            for: profileID,
            stats: PlayerProfileStats(),
            records: records,
            filter: GameRecordFilter(mode: .x01)
        )

        #expect(snapshot.checkoutPercentage == nil)
    }

    @Test func filteredProfileStatsFirstNineAverageUsesSummedPointsAndDarts() {
        let profileID = UUID()
        let records = [
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 2), isWinner: true, average: 50, firstNineAverage: 80, checkoutAttempts: 0, checkoutHits: 0, totalDartsThrown: 10, totalPointsScored: 150, totalFirstNinePoints: 160, totalFirstNineDarts: 6),
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 1), isWinner: true, average: 50, firstNineAverage: 20, checkoutAttempts: 0, checkoutHits: 0, totalDartsThrown: 10, totalPointsScored: 150, totalFirstNinePoints: 60, totalFirstNineDarts: 9)
        ]

        let snapshot = FilteredProfileStatsBuilder.makeSnapshot(
            for: profileID,
            stats: PlayerProfileStats(),
            records: records,
            filter: GameRecordFilter(mode: .x01)
        )

        #expect(snapshot.firstNineAverage != nil)
        #expect(abs((snapshot.firstNineAverage ?? 0) - 44.0) < 0.001)
    }

    @Test func filteredProfileStatsEmptyResultProducesEmptySnapshot() {
        let snapshot = FilteredProfileStatsBuilder.makeSnapshot(
            for: UUID(),
            stats: PlayerProfileStats(),
            records: [],
            filter: GameRecordFilter(mode: .practice)
        )

        #expect(snapshot.hasRecords == false)
        #expect(snapshot.gamesPlayed == nil)
        #expect(snapshot.average == nil)
    }

    @Test func profileTrendsWinStreaksHandleCurrentAndBestStreaks() {
        let profileID = UUID()
        let records = [
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 5), isWinner: true, average: 50, firstNineAverage: nil, checkoutAttempts: 0, checkoutHits: 0, totalDartsThrown: 10, totalPointsScored: 150, totalFirstNinePoints: 0, totalFirstNineDarts: 0),
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 4), isWinner: true, average: 50, firstNineAverage: nil, checkoutAttempts: 0, checkoutHits: 0, totalDartsThrown: 10, totalPointsScored: 150, totalFirstNinePoints: 0, totalFirstNineDarts: 0),
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 3), isWinner: false, average: 50, firstNineAverage: nil, checkoutAttempts: 0, checkoutHits: 0, totalDartsThrown: 10, totalPointsScored: 150, totalFirstNinePoints: 0, totalFirstNineDarts: 0),
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 2), isWinner: true, average: 50, firstNineAverage: nil, checkoutAttempts: 0, checkoutHits: 0, totalDartsThrown: 10, totalPointsScored: 150, totalFirstNinePoints: 0, totalFirstNineDarts: 0),
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 1), isWinner: true, average: 50, firstNineAverage: nil, checkoutAttempts: 0, checkoutHits: 0, totalDartsThrown: 10, totalPointsScored: 150, totalFirstNinePoints: 0, totalFirstNineDarts: 0)
        ]

        let snapshot = ProfileTrends.makeSnapshot(for: profileID, stats: PlayerProfileStats(), records: records, filter: GameRecordFilter())

        #expect(snapshot.currentWinStreak == 2)
        #expect(snapshot.bestRecentWinStreak == 2)
    }

    @Test func profileTrendsCheckoutPercentageIsNilWithoutAttempts() {
        let profileID = UUID()
        let records = [
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 1), isWinner: true, average: 50, firstNineAverage: nil, checkoutAttempts: 0, checkoutHits: 0, totalDartsThrown: 10, totalPointsScored: 150, totalFirstNinePoints: 0, totalFirstNineDarts: 0)
        ]

        let snapshot = ProfileTrends.makeSnapshot(for: profileID, stats: PlayerProfileStats(), records: records, filter: GameRecordFilter())

        #expect(snapshot.checkoutPercentage.recentValue == nil)
    }

    @Test func profileTrendsFirstNineAverageUsesSummedPointsAndDarts() {
        let profileID = UUID()
        let records = [
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 2), isWinner: true, average: 50, firstNineAverage: 80, checkoutAttempts: 0, checkoutHits: 0, totalDartsThrown: 10, totalPointsScored: 150, totalFirstNinePoints: 160, totalFirstNineDarts: 6),
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 1), isWinner: true, average: 50, firstNineAverage: 20, checkoutAttempts: 0, checkoutHits: 0, totalDartsThrown: 10, totalPointsScored: 150, totalFirstNinePoints: 60, totalFirstNineDarts: 9)
        ]

        let snapshot = ProfileTrends.makeSnapshot(for: profileID, stats: PlayerProfileStats(), records: records, filter: GameRecordFilter())

        #expect(snapshot.firstNineAverage.recentValue != nil)
        #expect(abs((snapshot.firstNineAverage.recentValue ?? 0) - 44.0) < 0.001)
    }

    @Test func profileTrendsFewerThanFiveRecordsStillProduceSnapshot() {
        let profileID = UUID()
        let records = [
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 2), isWinner: true, average: 50, firstNineAverage: 60, checkoutAttempts: 1, checkoutHits: 1, totalDartsThrown: 10, totalPointsScored: 150, totalFirstNinePoints: 90, totalFirstNineDarts: 6),
            trendRecord(profileID: profileID, date: .init(timeIntervalSince1970: 1), isWinner: false, average: 40, firstNineAverage: 45, checkoutAttempts: 0, checkoutHits: 0, totalDartsThrown: 12, totalPointsScored: 160, totalFirstNinePoints: 90, totalFirstNineDarts: 9)
        ]

        let snapshot = ProfileTrends.makeSnapshot(for: profileID, stats: PlayerProfileStats(), records: records, filter: GameRecordFilter())

        #expect(snapshot.sampleSize == 2)
        #expect(snapshot.hasRecords == true)
    }

    @Test func profileTrendsEmptyHistoryProducesEmptySnapshot() {
        let snapshot = ProfileTrends.makeSnapshot(for: UUID(), stats: PlayerProfileStats(), records: [], filter: GameRecordFilter())

        #expect(snapshot.sampleSize == 0)
        #expect(snapshot.hasRecords == false)
        #expect(snapshot.average.recentValue == nil)
        #expect(snapshot.checkoutPercentage.recentValue == nil)
    }

    @Test func headToHeadExcludesPracticeRecords() {
        let alex = PlayerProfile(id: UUID(), name: "Alex", colorHex: "#111111")
        let blake = PlayerProfile(id: UUID(), name: "Blake", colorHex: "#222222")

        let records = [
            rivalryRecord(
                date: .init(timeIntervalSince1970: 2),
                playerResults: [
                    rivalryResult(profileID: alex.id, name: "Alex", isWinner: true),
                    rivalryResult(profileID: blake.id, name: "Blake", isWinner: false)
                ]
            ),
            rivalryRecord(
                date: .init(timeIntervalSince1970: 1),
                playerResults: [
                    rivalryResult(profileID: alex.id, name: "Alex", isWinner: true),
                    rivalryResult(profileID: blake.id, name: "Blake", isWinner: false)
                ],
                practiceMode: .scoringDrill
            )
        ]

        let snapshot = HeadToHeadBuilder.makeSnapshot(for: alex, profiles: [alex, blake], records: records, filter: GameRecordFilter())

        #expect(snapshot.opponents.count == 1)
        #expect(snapshot.opponents[0].matchesPlayed == 1)
    }

    @Test func headToHeadIncludesX01AndCricket() {
        let alex = PlayerProfile(id: UUID(), name: "Alex", colorHex: "#111111")
        let blake = PlayerProfile(id: UUID(), name: "Blake", colorHex: "#222222")

        let records = [
            rivalryRecord(
                date: .init(timeIntervalSince1970: 2),
                playerResults: [
                    rivalryResult(profileID: alex.id, name: "Alex", isWinner: true),
                    rivalryResult(profileID: blake.id, name: "Blake", isWinner: false)
                ]
            ),
            rivalryRecord(
                date: .init(timeIntervalSince1970: 1),
                playerResults: [
                    rivalryResult(profileID: alex.id, name: "Alex", isWinner: false),
                    rivalryResult(profileID: blake.id, name: "Blake", isWinner: true)
                ],
                finishRule: GameMode.cricket.rawValue,
                startingScore: 0
            )
        ]

        let snapshot = HeadToHeadBuilder.makeSnapshot(for: alex, profiles: [alex, blake], records: records, filter: GameRecordFilter())

        #expect(snapshot.opponents.first?.matchesPlayed == 2)
    }

    @Test func headToHeadGroupsByOpponentProfileID() {
        let alex = PlayerProfile(id: UUID(), name: "Alex", colorHex: "#111111")
        let blake = PlayerProfile(id: UUID(), name: "Blake", colorHex: "#222222")
        let casey = PlayerProfile(id: UUID(), name: "Casey", colorHex: "#333333")

        let records = [
            rivalryRecord(
                date: .init(timeIntervalSince1970: 2),
                playerResults: [
                    rivalryResult(profileID: alex.id, name: "Alex", isWinner: true),
                    rivalryResult(profileID: blake.id, name: "Blake", isWinner: false)
                ]
            ),
            rivalryRecord(
                date: .init(timeIntervalSince1970: 1),
                playerResults: [
                    rivalryResult(profileID: alex.id, name: "Alex", isWinner: true),
                    rivalryResult(profileID: casey.id, name: "Casey", isWinner: false)
                ]
            )
        ]

        let snapshot = HeadToHeadBuilder.makeSnapshot(for: alex, profiles: [alex, blake, casey], records: records, filter: GameRecordFilter())

        #expect(snapshot.opponents.count == 2)
        #expect(Set(snapshot.opponents.map(\.opponentProfileID)) == Set([blake.id, casey.id]))
    }

    @Test func headToHeadIgnoresMatchesWithoutSelectedProfile() {
        let alex = PlayerProfile(id: UUID(), name: "Alex", colorHex: "#111111")
        let blake = PlayerProfile(id: UUID(), name: "Blake", colorHex: "#222222")
        let casey = PlayerProfile(id: UUID(), name: "Casey", colorHex: "#333333")

        let record = rivalryRecord(
            date: .init(timeIntervalSince1970: 1),
            playerResults: [
                rivalryResult(profileID: blake.id, name: "Blake", isWinner: true),
                rivalryResult(profileID: casey.id, name: "Casey", isWinner: false)
            ]
        )

        let snapshot = HeadToHeadBuilder.makeSnapshot(for: alex, profiles: [alex, blake, casey], records: [record], filter: GameRecordFilter())

        #expect(snapshot.opponents.isEmpty)
    }

    @Test func headToHeadIgnoresUnprofiledOpponents() {
        let alex = PlayerProfile(id: UUID(), name: "Alex", colorHex: "#111111")

        let record = rivalryRecord(
            date: .init(timeIntervalSince1970: 1),
            playerResults: [
                rivalryResult(profileID: alex.id, name: "Alex", isWinner: true),
                rivalryResult(profileID: nil, name: "Guest", isWinner: false)
            ]
        )

        let snapshot = HeadToHeadBuilder.makeSnapshot(for: alex, profiles: [alex], records: [record], filter: GameRecordFilter())

        #expect(snapshot.opponents.isEmpty)
        #expect(snapshot.hasCompetitiveHistory == false)
    }

    @Test func headToHeadComputesWinsLossesAndWinRate() {
        let alex = PlayerProfile(id: UUID(), name: "Alex", colorHex: "#111111")
        let blake = PlayerProfile(id: UUID(), name: "Blake", colorHex: "#222222")

        let records = [
            rivalryRecord(date: .init(timeIntervalSince1970: 3), playerResults: [rivalryResult(profileID: alex.id, name: "Alex", isWinner: true), rivalryResult(profileID: blake.id, name: "Blake", isWinner: false)]),
            rivalryRecord(date: .init(timeIntervalSince1970: 2), playerResults: [rivalryResult(profileID: alex.id, name: "Alex", isWinner: true), rivalryResult(profileID: blake.id, name: "Blake", isWinner: false)]),
            rivalryRecord(date: .init(timeIntervalSince1970: 1), playerResults: [rivalryResult(profileID: alex.id, name: "Alex", isWinner: false), rivalryResult(profileID: blake.id, name: "Blake", isWinner: true)])
        ]

        let snapshot = HeadToHeadBuilder.makeSnapshot(for: alex, profiles: [alex, blake], records: records, filter: GameRecordFilter())
        let summary = try #require(snapshot.opponents.first)

        #expect(summary.wins == 2)
        #expect(summary.losses == 1)
        #expect(abs(summary.winRate - (2.0 / 3.0)) < 0.001)
    }

    @Test func headToHeadComputesCurrentStreak() {
        let alex = PlayerProfile(id: UUID(), name: "Alex", colorHex: "#111111")
        let blake = PlayerProfile(id: UUID(), name: "Blake", colorHex: "#222222")

        let records = [
            rivalryRecord(date: .init(timeIntervalSince1970: 4), playerResults: [rivalryResult(profileID: alex.id, name: "Alex", isWinner: true), rivalryResult(profileID: blake.id, name: "Blake", isWinner: false)]),
            rivalryRecord(date: .init(timeIntervalSince1970: 3), playerResults: [rivalryResult(profileID: alex.id, name: "Alex", isWinner: true), rivalryResult(profileID: blake.id, name: "Blake", isWinner: false)]),
            rivalryRecord(date: .init(timeIntervalSince1970: 2), playerResults: [rivalryResult(profileID: alex.id, name: "Alex", isWinner: false), rivalryResult(profileID: blake.id, name: "Blake", isWinner: true)]),
            rivalryRecord(date: .init(timeIntervalSince1970: 1), playerResults: [rivalryResult(profileID: alex.id, name: "Alex", isWinner: false), rivalryResult(profileID: blake.id, name: "Blake", isWinner: true)])
        ]

        let snapshot = HeadToHeadBuilder.makeSnapshot(for: alex, profiles: [alex, blake], records: records, filter: GameRecordFilter())

        #expect(snapshot.opponents.first?.currentStreak == -2)
    }

    @Test func headToHeadRespectsActiveDateFilter() {
        let alex = PlayerProfile(id: UUID(), name: "Alex", colorHex: "#111111")
        let blake = PlayerProfile(id: UUID(), name: "Blake", colorHex: "#222222")
        let now = Date()

        let recentRecord = rivalryRecord(
            date: now.addingTimeInterval(-2 * 24 * 60 * 60),
            playerResults: [rivalryResult(profileID: alex.id, name: "Alex", isWinner: true), rivalryResult(profileID: blake.id, name: "Blake", isWinner: false)]
        )
        let oldRecord = rivalryRecord(
            date: now.addingTimeInterval(-50 * 24 * 60 * 60),
            playerResults: [rivalryResult(profileID: alex.id, name: "Alex", isWinner: true), rivalryResult(profileID: blake.id, name: "Blake", isWinner: false)]
        )

        let snapshot = HeadToHeadBuilder.makeSnapshot(
            for: alex,
            profiles: [alex, blake],
            records: [recentRecord, oldRecord],
            filter: GameRecordFilter(date: .last30Days),
            now: now
        )

        #expect(snapshot.opponents.first?.matchesPlayed == 1)
    }

    @Test func headToHeadSortsByMatchesPlayedThenMostRecent() {
        let alex = PlayerProfile(id: UUID(), name: "Alex", colorHex: "#111111")
        let blake = PlayerProfile(id: UUID(), name: "Blake", colorHex: "#222222")
        let casey = PlayerProfile(id: UUID(), name: "Casey", colorHex: "#333333")
        let drew = PlayerProfile(id: UUID(), name: "Drew", colorHex: "#444444")

        let records = [
            rivalryRecord(date: .init(timeIntervalSince1970: 5), playerResults: [rivalryResult(profileID: alex.id, name: "Alex", isWinner: true), rivalryResult(profileID: blake.id, name: "Blake", isWinner: false)]),
            rivalryRecord(date: .init(timeIntervalSince1970: 4), playerResults: [rivalryResult(profileID: alex.id, name: "Alex", isWinner: true), rivalryResult(profileID: blake.id, name: "Blake", isWinner: false)]),
            rivalryRecord(date: .init(timeIntervalSince1970: 3), playerResults: [rivalryResult(profileID: alex.id, name: "Alex", isWinner: true), rivalryResult(profileID: casey.id, name: "Casey", isWinner: false)]),
            rivalryRecord(date: .init(timeIntervalSince1970: 2), playerResults: [rivalryResult(profileID: alex.id, name: "Alex", isWinner: true), rivalryResult(profileID: casey.id, name: "Casey", isWinner: false)]),
            rivalryRecord(date: .init(timeIntervalSince1970: 1), playerResults: [rivalryResult(profileID: alex.id, name: "Alex", isWinner: true), rivalryResult(profileID: drew.id, name: "Drew", isWinner: false)])
        ]

        let snapshot = HeadToHeadBuilder.makeSnapshot(for: alex, profiles: [alex, blake, casey, drew], records: records, filter: GameRecordFilter())

        #expect(snapshot.opponents.map(\.opponentProfileID) == [blake.id, casey.id, drew.id])
    }

    @Test func headToHeadProducesEmptySnapshotWhenNoCompetitiveRivalryExists() {
        let alex = PlayerProfile(id: UUID(), name: "Alex", colorHex: "#111111")
        let blake = PlayerProfile(id: UUID(), name: "Blake", colorHex: "#222222")

        let records = [
            rivalryRecord(
                date: .init(timeIntervalSince1970: 1),
                playerResults: [rivalryResult(profileID: alex.id, name: "Alex", isWinner: true), rivalryResult(profileID: blake.id, name: "Blake", isWinner: false)],
                practiceMode: .scoringDrill
            )
        ]

        let snapshot = HeadToHeadBuilder.makeSnapshot(for: alex, profiles: [alex, blake], records: records, filter: GameRecordFilter())

        #expect(snapshot.opponents.isEmpty)
        #expect(snapshot.hasCompetitiveHistory == false)
    }

    @Test func singleEliminationGeneratesBracketAndCompletesTournament() {
        let store = TournamentStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let participants = [
            tournamentParticipant(seed: 1, name: "Alex"),
            tournamentParticipant(seed: 2, name: "Blake"),
            tournamentParticipant(seed: 3, name: "Casey"),
            tournamentParticipant(seed: 4, name: "Drew")
        ]

        let tournament = store.createTournament(
            name: "Spring Cup",
            format: .singleElimination,
            participants: participants,
            rules: TournamentMatchRules()
        )

        #expect(tournament.rounds.count == 2)
        #expect(tournament.matches.count == 3)

        let semifinalMatches = tournament.matches.filter { $0.roundIndex == 0 }.sorted { $0.slotIndex < $1.slotIndex }
        let semifinalOne = semifinalMatches[0]
        let semifinalTwo = semifinalMatches[1]

        store.completeMatch(
            tournamentID: tournament.id,
            matchID: semifinalOne.id,
            record: tournamentRecord(
                playerA: participants[0],
                playerB: participants[3],
                winner: participants[0],
                playerALegsWon: 2,
                playerBLegsWon: 0
            )
        )
        store.completeMatch(
            tournamentID: tournament.id,
            matchID: semifinalTwo.id,
            record: tournamentRecord(
                playerA: participants[1],
                playerB: participants[2],
                winner: participants[2],
                playerALegsWon: 0,
                playerBLegsWon: 2,
                date: .init(timeIntervalSince1970: 2)
            )
        )

        let updated = try #require(store.tournament(id: tournament.id))
        let finalMatch = try #require(updated.matches.first(where: { $0.roundIndex == 1 }))
        #expect(finalMatch.status == .ready)

        store.completeMatch(
            tournamentID: tournament.id,
            matchID: finalMatch.id,
            record: tournamentRecord(
                playerA: participants[0],
                playerB: participants[2],
                winner: participants[2],
                playerALegsWon: 1,
                playerBLegsWon: 2,
                date: .init(timeIntervalSince1970: 3)
            )
        )

        let completed = try #require(store.tournament(id: tournament.id))
        #expect(completed.status == .completed)
        #expect(completed.winnerParticipantID == participants[2].id)
    }

    @Test func singleEliminationRespectsSelectedPlayerOrderForSeeding() {
        let store = TournamentStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let participants = [
            tournamentParticipant(seed: 1, name: "Blake"),
            tournamentParticipant(seed: 2, name: "Alex"),
            tournamentParticipant(seed: 3, name: "Casey"),
            tournamentParticipant(seed: 4, name: "Drew")
        ]

        let tournament = store.createTournament(
            name: "Seeded Cup",
            format: .singleElimination,
            participants: participants,
            rules: TournamentMatchRules()
        )

        let firstRoundMatches = tournament.matches
            .filter { $0.roundIndex == 0 }
            .sorted { $0.slotIndex < $1.slotIndex }

        let firstMatch = try #require(firstRoundMatches.first)
        let secondMatch = try #require(firstRoundMatches.last)

        #expect(firstMatch.playerAParticipantID == participants[0].id)
        #expect(firstMatch.playerBParticipantID == participants[3].id)
        #expect(secondMatch.playerAParticipantID == participants[1].id)
        #expect(secondMatch.playerBParticipantID == participants[2].id)
    }

    @Test func singleEliminationAutoAdvancesBye() {
        let store = TournamentStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let participants = [
            tournamentParticipant(seed: 1, name: "Alex"),
            tournamentParticipant(seed: 2, name: "Blake"),
            tournamentParticipant(seed: 3, name: "Casey")
        ]

        let tournament = store.createTournament(
            name: "Mini Cup",
            format: .singleElimination,
            participants: participants,
            rules: TournamentMatchRules()
        )

        let byeMatches = tournament.matches.filter { $0.status == .bye }
        #expect(byeMatches.count == 1)
        #expect(byeMatches.first?.winnerParticipantID != nil)
    }

    @Test func roundRobinGeneratesUniquePairingsAndUpdatesStandings() {
        let store = TournamentStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let participants = [
            tournamentParticipant(seed: 1, name: "Alex"),
            tournamentParticipant(seed: 2, name: "Blake"),
            tournamentParticipant(seed: 3, name: "Casey")
        ]

        let tournament = store.createTournament(
            name: "League Night",
            format: .roundRobin,
            participants: participants,
            rules: TournamentMatchRules()
        )

        #expect(tournament.matches.count == 3)

        let pairings = Set(tournament.matches.compactMap { match -> Set<UUID>? in
            guard let playerA = match.playerAParticipantID, let playerB = match.playerBParticipantID else { return nil }
            return Set([playerA, playerB])
        })
        #expect(pairings.count == 3)

        for match in tournament.matches.reversed() {
            guard let playerAID = match.playerAParticipantID,
                  let playerBID = match.playerBParticipantID,
                  let playerA = participants.first(where: { $0.id == playerAID }),
                  let playerB = participants.first(where: { $0.id == playerBID }) else {
                Issue.record("Round robin match missing participants")
                continue
            }
            store.completeMatch(
                tournamentID: tournament.id,
                matchID: match.id,
                record: tournamentRecord(
                    playerA: playerA,
                    playerB: playerB,
                    winner: playerA.name == "Alex" ? playerA : playerB,
                    playerALegsWon: playerA.name == "Alex" ? 2 : 0,
                    playerBLegsWon: playerA.name == "Alex" ? 0 : 2,
                    date: .init(timeIntervalSince1970: Double(match.slotIndex + 1))
                )
            )
        }

        let updated = try #require(store.tournament(id: tournament.id))
        let standings = store.standings(for: updated)
        #expect(updated.status == .completed)
        #expect(standings.first?.participant.name == "Alex")
        #expect(standings.first?.wins == 2)
    }

    @Test func doubleRoundRobinGeneratesEveryPairingTwice() {
        let store = TournamentStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let participants = [
            tournamentParticipant(seed: 1, name: "Alex"),
            tournamentParticipant(seed: 2, name: "Blake"),
            tournamentParticipant(seed: 3, name: "Casey")
        ]

        let tournament = store.createTournament(
            name: "Home and Away",
            format: .roundRobin,
            participants: participants,
            rules: TournamentMatchRules(),
            roundRobinMode: .double
        )

        #expect(tournament.roundRobinMode == .double)
        #expect(tournament.matches.count == 6)

        let pairingCounts = tournament.matches.reduce(into: [Set<UUID>: Int]()) { counts, match in
            guard let playerA = match.playerAParticipantID,
                  let playerB = match.playerBParticipantID else { return }
            counts[Set([playerA, playerB]), default: 0] += 1
        }

        #expect(pairingCounts.count == 3)
        #expect(pairingCounts.values.allSatisfy { $0 == 2 })
        #expect(tournament.matches.allSatisfy { $0.status == .ready })
    }

    @Test func tournamentDecodingDefaultsMissingRoundRobinModeToSingle() throws {
        let participants = [
            tournamentParticipant(seed: 1, name: "Alex"),
            tournamentParticipant(seed: 2, name: "Blake")
        ]

        let tournament = Tournament(
            name: "Legacy League",
            format: .roundRobin,
            roundRobinMode: .double,
            status: .inProgress,
            participants: participants,
            rules: TournamentMatchRules(),
            rounds: [],
            matches: []
        )

        let encoded = try JSONEncoder().encode(tournament)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "roundRobinMode")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(Tournament.self, from: legacyData)

        #expect(decoded.roundRobinMode == .single)
    }
}
