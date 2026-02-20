package com.example.dartscorer_android

import com.example.dartscorer_android.game.DartMultiplier
import com.example.dartscorer_android.game.DartSegment
import com.example.dartscorer_android.game.DartsGame
import com.example.dartscorer_android.game.FinishRule
import com.example.dartscorer_android.game.InRule
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class DartsGameTest {
    @Test
    fun scoreSubtraction_singleThrow() {
        val game = DartsGame(playerCount = 1)
        game.submitThrow(DartSegment.Number(20), DartMultiplier.SINGLE)
        assertEquals(481, game.players.first().score)
    }

    @Test
    fun bustRevertsToTurnStartAndSwitchesPlayer() {
        val game = DartsGame(playerCount = 2)
        game.newGame(
            playerNames = listOf("A", "B"),
            finishRule = FinishRule.DOUBLE_OUT,
            inRule = InRule.DEFAULT,
            startingScore = 40,
            setModeEnabled = false,
            legsToWin = 3
        )

        game.submitThrow(DartSegment.Number(20), DartMultiplier.TRIPLE)

        assertEquals(40, game.players[0].score)
        assertEquals(1, game.activePlayerIndex)
    }

    @Test
    fun doubleOutRequiredToWin() {
        val game = DartsGame(playerCount = 1)
        game.newGame(
            playerNames = listOf("A"),
            finishRule = FinishRule.DOUBLE_OUT,
            inRule = InRule.DEFAULT,
            startingScore = 20,
            setModeEnabled = false,
            legsToWin = 3
        )

        game.submitThrow(DartSegment.Number(20), DartMultiplier.SINGLE)

        assertNull(game.winner)
        assertEquals(20, game.players.first().score)
    }

    @Test
    fun turnSwitchesAfterThreeDarts() {
        val game = DartsGame(playerCount = 2)
        repeat(3) {
            game.submitThrow(DartSegment.Number(1), DartMultiplier.SINGLE)
        }
        assertEquals(1, game.activePlayerIndex)
    }

    @Test
    fun winDetection_singleOut() {
        val game = DartsGame(playerCount = 1)
        game.newGame(
            playerNames = listOf("A"),
            finishRule = FinishRule.SINGLE_OUT,
            inRule = InRule.DEFAULT,
            startingScore = 20,
            setModeEnabled = false,
            legsToWin = 3
        )

        game.submitThrow(DartSegment.Number(20), DartMultiplier.SINGLE)

        assertNotNull(game.winner)
        assertEquals("A", game.winner?.name)
    }

    @Test
    fun setModeAdvancesLegCountAndDelaysWinnerUntilTargetReached() {
        val game = DartsGame(playerCount = 1)
        game.newGame(
            playerNames = listOf("A"),
            finishRule = FinishRule.SINGLE_OUT,
            inRule = InRule.DEFAULT,
            startingScore = 10,
            setModeEnabled = true,
            legsToWin = 2
        )

        game.submitThrow(DartSegment.Number(10), DartMultiplier.SINGLE)
        assertNull(game.winner)
        assertEquals(1, game.legsWon(game.players.first()))
        assertEquals(10, game.players.first().score)

        game.submitThrow(DartSegment.Number(10), DartMultiplier.SINGLE)
        assertNotNull(game.winner)
        assertEquals(2, game.legsWon(game.players.first()))
    }
}
