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

        #expect(game.bestPossibleFinishLine == "Best Finish: D20")
    }
}
