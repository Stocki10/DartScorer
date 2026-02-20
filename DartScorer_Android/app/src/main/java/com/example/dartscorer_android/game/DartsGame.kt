package com.example.dartscorer_android.game

import kotlin.random.Random

class DartsGame(
    playerCount: Int = 2,
    startingScore: Int = 501,
    finishRule: FinishRule = FinishRule.DOUBLE_OUT,
    inRule: InRule = InRule.DEFAULT,
    setModeEnabled: Boolean = false,
    legsToWin: Int = 3
) {
    var players: List<Player> = emptyList()
        private set
    var activePlayerIndex: Int = 0
        private set
    var currentTurn: Turn = Turn(startingScore = startingScore)
        private set
    var winner: Player? = null
        private set
    var statusMessage: String? = null
        private set
    var finishRule: FinishRule = finishRule
        private set
    var inRule: InRule = inRule
        private set
    var startingScore: Int = startingScore
        private set
    var setModeEnabled: Boolean = setModeEnabled
        private set
    var legsToWin: Int = legsToWin.coerceAtLeast(1)
        private set
    var legsWonByPlayerId: Map<Int, Int> = emptyMap()
        private set
    var setWinner: Player? = null
        private set
    var lastTurnThrowsByPlayerId: Map<Int, List<Int>> = emptyMap()
        private set
    var pointsScoredByPlayerId: Map<Int, Int> = emptyMap()
        private set
    var dartsThrownByPlayerId: Map<Int, Int> = emptyMap()
        private set
    var hasOpenedLegByPlayerId: Map<Int, Boolean> = emptyMap()
        private set

    private val history = mutableListOf<GameSnapshot>()

    init {
        val clampedCount = playerCount.coerceIn(1, 4)
        players = (1..clampedCount).map { Player(id = it, name = "Player $it", score = startingScore) }
        currentTurn = Turn(startingScore = startingScore, openedAtTurnStart = inRule == InRule.DEFAULT)
        resetSetState()
        resetOpenState()
        resetLegStats()
    }

    val activePlayer: Player
        get() = players[activePlayerIndex]

    val remainingDarts: Int
        get() = currentTurn.dartsRemaining

    val canUndo: Boolean
        get() = history.isNotEmpty()

    val bestPossibleFinishLine: String
        get() {
            if (winner != null) return ""
            val score = activePlayer.score
            val darts = remainingDarts
            if (darts <= 0) return "No finish available"
            val route = bestFinishRoute(score, darts) ?: return "No finish available"
            return route.joinToString(" ") { throwNotation(it) }
        }

    val hasBestPossibleFinish: Boolean
        get() = bestPossibleFinishLine != "No finish available"

    val isLegInProgress: Boolean
        get() = winner == null && dartsThrownByPlayerId.values.any { it > 0 }

    fun submitThrow(segment: DartSegment, multiplier: DartMultiplier) {
        if (winner != null) return
        if (remainingDarts <= 0) return
        if (!DartThrow.isValid(segment, multiplier)) {
            statusMessage = "Invalid throw."
            return
        }

        val throwValue = DartThrow(segment = segment, multiplier = multiplier)
        recordSnapshot()
        statusMessage = null

        val player = activePlayer
        val effectivePoints = effectivePointsForThrow(throwValue, player.id)
        val proposedScore = player.score - effectivePoints

        appendThrowToHistory(player.id, throwValue.points)
        recordDartThrown(player.id)

        if (isBust(proposedScore, throwValue, effectivePoints)) {
            rollbackTurnScoringForBust(player.id)
            hasOpenedLegByPlayerId = hasOpenedLegByPlayerId.toMutableMap().also {
                it[player.id] = currentTurn.openedAtTurnStart
            }
            handleBust()
            return
        }

        addScoredPoints(effectivePoints, player.id)
        players = players.toMutableList().also { list ->
            list[activePlayerIndex] = list[activePlayerIndex].copy(score = proposedScore)
        }
        currentTurn = currentTurn.copy(darts = currentTurn.darts + throwValue)

        if (proposedScore == 0) {
            val winningPlayer = players[activePlayerIndex]
            if (setModeEnabled) {
                val newLegs = legsWonByPlayerId.toMutableMap()
                newLegs[winningPlayer.id] = (newLegs[winningPlayer.id] ?: 0) + 1
                legsWonByPlayerId = newLegs

                if ((legsWonByPlayerId[winningPlayer.id] ?: 0) >= legsToWin) {
                    winner = winningPlayer
                    setWinner = winningPlayer
                    statusMessage = "${winningPlayer.name} wins the set."
                } else {
                    startNewLeg(randomSequence = false, invertedSequence = true)
                }
            } else {
                winner = winningPlayer
                statusMessage = "${winningPlayer.name} wins the leg."
            }
            return
        }

        if (currentTurn.dartsUsed == 3) {
            endTurn()
        }
    }

    fun restartLeg() {
        startNewLeg(randomSequence = false, invertedSequence = false)
    }

    fun restartLegRandomSequence() {
        startNewLeg(randomSequence = true, invertedSequence = false)
    }

    fun restartLegInvertedSequence() {
        startNewLeg(randomSequence = false, invertedSequence = true)
    }

    fun newGame(
        playerNames: List<String>,
        finishRule: FinishRule,
        inRule: InRule,
        startingScore: Int,
        setModeEnabled: Boolean,
        legsToWin: Int
    ) {
        history.clear()
        lastTurnThrowsByPlayerId = emptyMap()
        val preparedNames = sanitizeAndClampNames(playerNames)
        this.startingScore = startingScore
        this.finishRule = finishRule
        this.inRule = inRule
        this.setModeEnabled = setModeEnabled
        this.legsToWin = legsToWin.coerceAtLeast(1)
        players = preparedNames.mapIndexed { index, name ->
            Player(id = index + 1, name = name, score = this.startingScore)
        }
        resetSetState()
        resetOpenState()
        resetLegStats()
        winner = null
        setWinner = null
        statusMessage = null
        activePlayerIndex = 0
        currentTurn = Turn(
            startingScore = this.startingScore,
            openedAtTurnStart = hasOpenedLegByPlayerId[players[activePlayerIndex].id] ?: (inRule == InRule.DEFAULT)
        )
    }

    fun undoLastThrow() {
        val previous = history.removeLastOrNull() ?: return
        players = previous.players
        activePlayerIndex = previous.activePlayerIndex
        currentTurn = previous.currentTurn
        winner = previous.winner
        statusMessage = previous.statusMessage
        inRule = previous.inRule
        setModeEnabled = previous.setModeEnabled
        legsToWin = previous.legsToWin
        legsWonByPlayerId = previous.legsWonByPlayerId
        setWinner = previous.setWinner
        lastTurnThrowsByPlayerId = previous.lastTurnThrowsByPlayerId
        pointsScoredByPlayerId = previous.pointsScoredByPlayerId
        dartsThrownByPlayerId = previous.dartsThrownByPlayerId
        hasOpenedLegByPlayerId = previous.hasOpenedLegByPlayerId
    }

    fun lastTurnThrows(player: Player): List<Int> = lastTurnThrowsByPlayerId[player.id] ?: emptyList()

    fun legAverage(player: Player): Double? {
        val darts = dartsThrownByPlayerId[player.id] ?: 0
        if (darts <= 0) return null
        val points = pointsScoredByPlayerId[player.id] ?: 0
        return (points.toDouble() / darts.toDouble()) * 3.0
    }

    fun legsWon(player: Player): Int = legsWonByPlayerId[player.id] ?: 0

    private fun isBust(proposedScore: Int, throwValue: DartThrow, effectivePoints: Int): Boolean {
        if (effectivePoints == 0) return false
        if (proposedScore < 0) return true
        if (finishRule == FinishRule.DOUBLE_OUT) {
            if (proposedScore == 1) return true
            if (proposedScore == 0 && !throwValue.isDouble) return true
        }
        return false
    }

    private fun handleBust() {
        val restored = currentTurn.startingScore
        players = players.toMutableList().also { list ->
            list[activePlayerIndex] = list[activePlayerIndex].copy(score = restored)
        }
        endTurn()
    }

    private fun endTurn() {
        activePlayerIndex = (activePlayerIndex + 1) % players.size
        val nextPlayer = players[activePlayerIndex]
        currentTurn = Turn(
            startingScore = nextPlayer.score,
            openedAtTurnStart = hasOpenedLegByPlayerId[nextPlayer.id] ?: (inRule == InRule.DEFAULT)
        )
    }

    private fun startNewLeg(randomSequence: Boolean, invertedSequence: Boolean) {
        history.clear()
        lastTurnThrowsByPlayerId = emptyMap()
        resetLegStats()
        winner = null
        statusMessage = null

        var reordered = players
        if (invertedSequence) {
            reordered = reordered.reversed()
        } else if (randomSequence) {
            val previousStarterId = reordered.firstOrNull()?.id
            reordered = reordered.shuffled()
            if (reordered.size > 1 && previousStarterId != null && reordered.first().id == previousStarterId) {
                val swapIndex = Random.nextInt(1, reordered.size)
                val mutable = reordered.toMutableList()
                val first = mutable[0]
                mutable[0] = mutable[swapIndex]
                mutable[swapIndex] = first
                reordered = mutable
            }
        }

        players = reordered.map { it.copy(score = startingScore) }
        activePlayerIndex = 0
        resetOpenState()
        currentTurn = Turn(
            startingScore = startingScore,
            openedAtTurnStart = hasOpenedLegByPlayerId[players[activePlayerIndex].id] ?: (inRule == InRule.DEFAULT)
        )
    }

    private fun bestFinishRoute(score: Int, dartsRemaining: Int): List<DartThrow>? {
        if (score <= 0) return null
        val candidates = checkoutCandidates
        for (dartCount in 1..dartsRemaining) {
            val route = findRoute(score, dartCount, candidates, emptyList())
            if (route != null) return route
        }
        return null
    }

    private fun findRoute(
        target: Int,
        dartsLeft: Int,
        candidates: List<DartThrow>,
        current: List<DartThrow>
    ): List<DartThrow>? {
        if (target < 0) return null
        if (dartsLeft <= 0) return null

        for (dart in candidates) {
            val remaining = target - dart.points
            if (remaining < 0) continue

            if (dartsLeft == 1) {
                if (remaining == 0 && canFinish(dart)) {
                    return current + dart
                }
                continue
            }

            val route = findRoute(remaining, dartsLeft - 1, candidates, current + dart)
            if (route != null) return route
        }
        return null
    }

    private fun canFinish(dart: DartThrow): Boolean {
        return when (finishRule) {
            FinishRule.SINGLE_OUT -> true
            FinishRule.DOUBLE_OUT -> dart.isDouble
        }
    }

    private fun throwNotation(dart: DartThrow): String {
        return when (val segment = dart.segment) {
            is DartSegment.Number -> {
                when (dart.multiplier) {
                    DartMultiplier.SINGLE -> "${segment.value}"
                    DartMultiplier.DOUBLE -> "D${segment.value}"
                    DartMultiplier.TRIPLE -> "T${segment.value}"
                }
            }

            DartSegment.Bull -> if (dart.multiplier == DartMultiplier.DOUBLE) "Bull" else "25"
        }
    }

    private val checkoutCandidates: List<DartThrow> by lazy {
        buildList {
            for (value in 20 downTo 1) add(DartThrow(DartSegment.Number(value), DartMultiplier.TRIPLE))
            for (value in 20 downTo 1) add(DartThrow(DartSegment.Number(value), DartMultiplier.DOUBLE))
            for (value in 20 downTo 1) add(DartThrow(DartSegment.Number(value), DartMultiplier.SINGLE))
            add(DartThrow(DartSegment.Bull, DartMultiplier.DOUBLE))
            add(DartThrow(DartSegment.Bull, DartMultiplier.SINGLE))
        }
    }

    private fun effectivePointsForThrow(throwValue: DartThrow, playerId: Int): Int {
        if (inRule == InRule.DOUBLE_IN) {
            if (hasOpenedLegByPlayerId[playerId] == true) return throwValue.points
            if (throwValue.isDouble) {
                hasOpenedLegByPlayerId = hasOpenedLegByPlayerId.toMutableMap().also { it[playerId] = true }
                return throwValue.points
            }
            return 0
        }
        return throwValue.points
    }

    private fun sanitizeAndClampNames(names: List<String>): List<String> {
        val clamped = names.take(4)
        val withFallbacks = clamped.mapIndexed { index, name ->
            val trimmed = name.trim()
            if (trimmed.isEmpty()) "Player ${index + 1}" else trimmed
        }
        return if (withFallbacks.isEmpty()) listOf("Player 1") else withFallbacks
    }

    private fun recordSnapshot() {
        history += GameSnapshot(
            players = players,
            activePlayerIndex = activePlayerIndex,
            currentTurn = currentTurn,
            winner = winner,
            statusMessage = statusMessage,
            inRule = inRule,
            setModeEnabled = setModeEnabled,
            legsToWin = legsToWin,
            legsWonByPlayerId = legsWonByPlayerId,
            setWinner = setWinner,
            lastTurnThrowsByPlayerId = lastTurnThrowsByPlayerId,
            pointsScoredByPlayerId = pointsScoredByPlayerId,
            dartsThrownByPlayerId = dartsThrownByPlayerId,
            hasOpenedLegByPlayerId = hasOpenedLegByPlayerId
        )
    }

    private fun appendThrowToHistory(playerId: Int, points: Int) {
        val values = (lastTurnThrowsByPlayerId[playerId] ?: emptyList()) + points
        lastTurnThrowsByPlayerId = lastTurnThrowsByPlayerId.toMutableMap().also {
            it[playerId] = values.takeLast(3)
        }
    }

    private fun resetLegStats() {
        pointsScoredByPlayerId = players.associate { it.id to 0 }
        dartsThrownByPlayerId = players.associate { it.id to 0 }
    }

    private fun recordDartThrown(playerId: Int) {
        dartsThrownByPlayerId = dartsThrownByPlayerId.toMutableMap().also {
            it[playerId] = (it[playerId] ?: 0) + 1
        }
    }

    private fun addScoredPoints(points: Int, playerId: Int) {
        pointsScoredByPlayerId = pointsScoredByPlayerId.toMutableMap().also {
            it[playerId] = (it[playerId] ?: 0) + points
        }
    }

    private fun rollbackTurnScoringForBust(playerId: Int) {
        val turnPoints = currentTurn.darts.sumOf { it.points }
        pointsScoredByPlayerId = pointsScoredByPlayerId.toMutableMap().also {
            it[playerId] = (it[playerId] ?: 0) - turnPoints
        }
    }

    private fun resetSetState() {
        legsWonByPlayerId = players.associate { it.id to 0 }
        setWinner = null
    }

    private fun resetOpenState() {
        hasOpenedLegByPlayerId = players.associate { it.id to (inRule == InRule.DEFAULT) }
    }
}

private data class GameSnapshot(
    val players: List<Player>,
    val activePlayerIndex: Int,
    val currentTurn: Turn,
    val winner: Player?,
    val statusMessage: String?,
    val inRule: InRule,
    val setModeEnabled: Boolean,
    val legsToWin: Int,
    val legsWonByPlayerId: Map<Int, Int>,
    val setWinner: Player?,
    val lastTurnThrowsByPlayerId: Map<Int, List<Int>>,
    val pointsScoredByPlayerId: Map<Int, Int>,
    val dartsThrownByPlayerId: Map<Int, Int>,
    val hasOpenedLegByPlayerId: Map<Int, Boolean>
)
