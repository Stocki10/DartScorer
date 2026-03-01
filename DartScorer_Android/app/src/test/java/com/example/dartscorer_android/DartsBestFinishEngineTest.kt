package com.example.dartscorer_android

import com.example.dartscorer_android.game.DartsBestFinishEngine
import org.junit.Assert.assertEquals
import org.junit.Test

class DartsBestFinishEngineTest {
    @Test
    fun score50SuggestsBull() {
        val engine = DartsBestFinishEngine()
        val route = engine.getBestFinish(score = 50, dartsRemaining = 3)
        val tokens = engine.routeTokens(route)
        assertEquals(listOf("Bull"), tokens)
    }
}

