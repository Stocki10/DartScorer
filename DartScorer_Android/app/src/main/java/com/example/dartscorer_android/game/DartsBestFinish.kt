package com.example.dartscorer_android.game

data class DartTarget(val value: Int, val multiplier: Int) {
    val total: Int
        get() = if (value == 25 && multiplier == 2) 50 else value * multiplier

    val isBull: Boolean
        get() = value == 25 && multiplier == 2

    val isOuterBull: Boolean
        get() = value == 25 && multiplier == 1

    val label: String
        get() = when {
            isBull -> "Bull"
            isOuterBull -> "25"
            multiplier == 1 -> "S$value"
            multiplier == 2 -> "D$value"
            else -> "T$value"
        }

    companion object {
        val outerBull = DartTarget(value = 25, multiplier = 1)
        val bull = DartTarget(value = 25, multiplier = 2)
    }
}

data class FinishRoute(
    val darts: List<DartTarget>,
    val label: String,
    val rationale: String
)

class DartsBestFinishEngine {
    private val proRoutes: Map<Int, List<String>> = mapOf(
        170 to listOf("T20", "T20", "Bull"),
        167 to listOf("T20", "T19", "Bull"),
        164 to listOf("T20", "T18", "Bull"),
        161 to listOf("T20", "T17", "Bull"),
        160 to listOf("T20", "T20", "D20"),
        158 to listOf("T20", "T20", "D19"),
        152 to listOf("T20", "T20", "D16"),
        141 to listOf("T20", "T19", "D12"),
        132 to listOf("Bull", "Bull", "D16"),
        121 to listOf("T20", "T11", "D14"),
        110 to listOf("T20", "T10", "D10"),
        107 to listOf("T19", "T10", "D10"),
        101 to listOf("T20", "S1", "D20"),
        100 to listOf("T20", "D20"),
        92 to listOf("T20", "D16"),
        90 to listOf("T18", "D18"),
        85 to listOf("T15", "D20"),
        82 to listOf("Bull", "D16"),
        81 to listOf("T19", "D12"),
        70 to listOf("T18", "D8"),
        69 to listOf("T19", "D6"),
        68 to listOf("T20", "D4"),
        67 to listOf("T17", "D8"),
        66 to listOf("T10", "D18"),
        65 to listOf("T19", "D4"),
        64 to listOf("T16", "D8"),
        63 to listOf("T13", "D12"),
        62 to listOf("T10", "D16"),
        61 to listOf("T15", "D8"),
        60 to listOf("S20", "D20"),
        56 to listOf("S16", "D20"),
        52 to listOf("S12", "D20"),
        48 to listOf("S16", "D16"),
        44 to listOf("S12", "D16"),
        40 to listOf("D20"),
        38 to listOf("D19"),
        36 to listOf("D18"),
        34 to listOf("D17"),
        32 to listOf("D16"),
        30 to listOf("D15"),
        28 to listOf("D14"),
        26 to listOf("D13"),
        24 to listOf("D12"),
        22 to listOf("D11"),
        20 to listOf("D10"),
        18 to listOf("D9"),
        16 to listOf("D8"),
        14 to listOf("D7"),
        12 to listOf("D6"),
        10 to listOf("D5"),
        8 to listOf("D4"),
        6 to listOf("D3"),
        4 to listOf("D2"),
        2 to listOf("D1")
    )

    private val bogeys = setOf(169, 168, 166, 165, 163, 162, 159)

    private val allTargets: List<DartTarget> by lazy {
        buildList {
            for (value in 1..20) {
                add(DartTarget(value, 1))
                add(DartTarget(value, 2))
                add(DartTarget(value, 3))
            }
            add(DartTarget.outerBull)
            add(DartTarget.bull)
        }
    }

    private val finishingTargets: List<DartTarget> by lazy {
        allTargets.filter { isFinishingTarget(it) }
    }

    fun getBestFinish(score: Int, dartsRemaining: Int): FinishRoute {
        if (score <= 1) {
            return FinishRoute(emptyList(), "Invalid", "Cannot check out 1")
        }
        if (dartsRemaining !in 1..3) {
            return FinishRoute(emptyList(), "Invalid", "Darts remaining must be 1...3")
        }
        if (score > 170) {
            return setupForHighScore(score)
        }
        if (bogeys.contains(score)) {
            return setupForBogey(score)
        }
        proRoute(score, dartsRemaining)?.let { return it }
        bestFallbackCheckout(score, dartsRemaining)?.let {
            return FinishRoute(
                darts = it,
                label = "Fallback",
                rationale = "Heuristic route with double-out and preferred doubles."
            )
        }
        bestSetupTarget(score)?.let {
            return FinishRoute(
                darts = listOf(it),
                label = "Setup",
                rationale = "No direct finish in $dartsRemaining darts. Safe leave selected."
            )
        }
        return FinishRoute(emptyList(), "Invalid", "No valid route found.")
    }

    fun routeTokens(route: FinishRoute): List<String> = route.darts.map { tokenFor(it) }

    private fun proRoute(score: Int, dartsRemaining: Int): FinishRoute? {
        val tokens = proRoutes[score] ?: return null
        if (tokens.size > dartsRemaining) return null
        val darts = tokens.mapNotNull { parseTarget(it) }
        if (darts.size != tokens.size) return null

        val rationale = when {
            score in 61..70 -> "Treble-to-double route; if first dart lands single, recover via bull path."
            score == 132 -> "Champagne shot: Bull, Bull, D16."
            score in setOf(170, 167, 164, 161) -> "Big Fish finish profile."
            else -> "Professional preferred route from lookup table."
        }
        return FinishRoute(darts, "Pro Route", rationale)
    }

    private fun setupForHighScore(score: Int): FinishRoute {
        if (score == 195) {
            return FinishRoute(listOf(DartTarget.outerBull), "Setup", "Leave 170 with 25.")
        }
        if (score == 186) {
            return FinishRoute(listOf(DartTarget(19, 1)), "Setup", "Leave 167 and avoid 166 bogey.")
        }
        val setup = bestSetupTarget(score)
            ?: return FinishRoute(emptyList(), "Setup", "No setup available.")
        val leave = score - setup.total
        return FinishRoute(listOf(setup), "Setup", "Leave $leave (<=170, non-bogey).")
    }

    private fun setupForBogey(score: Int): FinishRoute {
        if (score == 169) {
            return FinishRoute(listOf(DartTarget(9, 1)), "Setup", "169 is a bogey. S9 leaves 160.")
        }
        if (score == 159) {
            return FinishRoute(listOf(DartTarget(19, 1)), "Setup", "159 is a bogey. S19 leaves 140.")
        }
        val setup = bestSetupTarget(score)
            ?: return FinishRoute(emptyList(), "Setup", "No safe bogey setup available.")
        return FinishRoute(listOf(setup), "Setup", "Bogey avoidance setup.")
    }

    private fun bestSetupTarget(score: Int): DartTarget? {
        return allTargets
            .filter {
                val leave = score - it.total
                leave > 1 && leave <= 170 && !bogeys.contains(leave)
            }
            .minByOrNull { setupCost(it, score) }
    }

    private fun setupCost(target: DartTarget, score: Int): Int {
        val leave = score - target.total
        var cost = kotlin.math.abs(leave - 100)
        if (leave > 170) cost += 3_000
        if (leave <= 1) cost += 4_000
        if (bogeys.contains(leave)) cost += 4_000
        if (leave == 170) cost -= 600
        if (leave == 167) cost -= 300
        if (target == DartTarget.outerBull) cost -= 30
        if (target == DartTarget(19, 1)) cost -= 20
        return cost
    }

    private fun bestFallbackCheckout(score: Int, dartsRemaining: Int): List<DartTarget>? {
        var bestRoute: List<DartTarget>? = null
        var bestCost = Int.MAX_VALUE
        var bestLength = Int.MAX_VALUE

        for (length in 1..dartsRemaining) {
            search(score, length, mutableListOf(), score, ::updateBest, bestCost, bestLength, bestRoute).also {
                bestRoute = it.route
                bestCost = it.cost
                bestLength = it.length
            }
        }
        return bestRoute
    }

    private data class SearchState(
        val route: List<DartTarget>?,
        val cost: Int,
        val length: Int
    )

    private fun search(
        score: Int,
        dartsLeft: Int,
        route: MutableList<DartTarget>,
        startScore: Int,
        updater: (List<DartTarget>, Int, Int, List<DartTarget>?, Int, Int) -> SearchState,
        bestCost: Int,
        bestLength: Int,
        bestRoute: List<DartTarget>?
    ): SearchState {
        if (dartsLeft <= 0 || score <= 1) return SearchState(bestRoute, bestCost, bestLength)
        var localRoute = bestRoute
        var localCost = bestCost
        var localLength = bestLength

        if (dartsLeft == 1) {
            for (finish in finishingTargets) {
                if (finish.total != score) continue
                val candidate = route + finish
                val cost = routeCost(candidate, startScore)
                val updated = updater(candidate, cost, candidate.size, localRoute, localCost, localLength)
                localRoute = updated.route
                localCost = updated.cost
                localLength = updated.length
            }
            return SearchState(localRoute, localCost, localLength)
        }

        for (target in allTargets) {
            val remaining = score - target.total
            if (remaining <= 1) continue
            route.add(target)
            val state = search(
                score = remaining,
                dartsLeft = dartsLeft - 1,
                route = route,
                startScore = startScore,
                updater = updater,
                bestCost = localCost,
                bestLength = localLength,
                bestRoute = localRoute
            )
            localRoute = state.route
            localCost = state.cost
            localLength = state.length
            route.removeAt(route.lastIndex)
        }
        return SearchState(localRoute, localCost, localLength)
    }

    private fun updateBest(
        candidate: List<DartTarget>,
        cost: Int,
        length: Int,
        bestRoute: List<DartTarget>?,
        bestCost: Int,
        bestLength: Int
    ): SearchState {
        return if (cost < bestCost || (cost == bestCost && length < bestLength)) {
            SearchState(candidate, cost, length)
        } else {
            SearchState(bestRoute, bestCost, bestLength)
        }
    }

    private fun routeCost(route: List<DartTarget>, startScore: Int): Int {
        var cost = 0
        var remaining = startScore
        route.forEachIndexed { index, dart ->
            remaining -= dart.total
            if (index < route.lastIndex) {
                if (remaining <= 1) cost += 5_000
                if (bogeys.contains(remaining)) cost += 1_200
                if (remaining > 170) cost += 900
            }
            if (index == 0 && startScore in 82..95) {
                cost += if (dart.isBull || dart.isOuterBull) -120 else 40
            }
            if (index == 0 && dart.multiplier == 3) {
                val missSingleLeave = startScore - dart.value
                if (bogeys.contains(missSingleLeave) || missSingleLeave == 1) {
                    cost += 200
                }
            }
        }

        val last = route.lastOrNull() ?: return Int.MAX_VALUE
        if (!(last.isBull || last.multiplier == 2)) cost += 10_000
        if (isSingleIntoDouble(route, startScore)) cost -= 180
        cost += routeScore(route, startScore) * 40
        cost += route.size * 4
        return cost
    }

    private fun routeScore(route: List<DartTarget>, startScore: Int): Int {
        val final = route.lastOrNull() ?: return Int.MAX_VALUE / 8
        var score = 0
        if (final.multiplier == 2) {
            when {
                final.value == 16 -> score -= 5
                final.value == 8 || final.value == 4 -> score -= 4
                final.value == 20 -> score -= 3
                final.value in setOf(12, 10, 18) -> score -= 2
                final.value in setOf(1, 2, 3, 5, 6, 7, 9, 13, 15, 17, 19) -> score += 4
            }
        }
        if (route.size == 2 && route[0].multiplier == 3) score += 2
        if (route.size >= 2) {
            likelyMissLeave(startScore, route[0])?.let { miss ->
                if (bogeys.contains(miss) || miss in 0..9) score += 3
            }
        }
        if (startScore in 82..95 && (route.firstOrNull()?.isBull == true || route.firstOrNull()?.isOuterBull == true)) {
            score -= 1
        }
        return score
    }

    private fun likelyMissLeave(startScore: Int, aimed: DartTarget): Int? {
        return when (aimed.multiplier) {
            1 -> null
            2, 3 -> startScore - aimed.value
            else -> null
        }
    }

    private fun isSingleIntoDouble(route: List<DartTarget>, startScore: Int): Boolean {
        if (route.size != 2) return false
        if (route[0].multiplier != 1 || route[1].multiplier != 2) return false
        return route.sumOf { it.total } == startScore
    }

    private fun parseTarget(token: String): DartTarget? {
        val normalized = token.trim().uppercase()
        if (normalized == "BULL") return DartTarget.bull
        if (normalized == "25") return DartTarget.outerBull
        if (normalized.isEmpty()) return null

        val first = normalized.first()
        val rest = normalized.drop(1)
        return when (first) {
            'S' -> rest.toIntOrNull()?.takeIf { isValidValue(it, 1) }?.let { DartTarget(it, 1) }
            'D' -> rest.toIntOrNull()?.takeIf { isValidValue(it, 2) }?.let {
                if (it == 25) DartTarget.bull else DartTarget(it, 2)
            }
            'T' -> rest.toIntOrNull()?.takeIf { isValidValue(it, 3) }?.let { DartTarget(it, 3) }
            else -> normalized.toIntOrNull()?.takeIf { isValidValue(it, 1) }?.let { DartTarget(it, 1) }
        }
    }

    private fun isValidValue(value: Int, multiplier: Int): Boolean {
        if (value == 25) return multiplier != 3
        return value in 1..20
    }

    private fun isFinishingTarget(target: DartTarget): Boolean {
        return target.isBull || (target.multiplier == 2 && target.value in 1..20)
    }

    private fun tokenFor(target: DartTarget): String {
        return when {
            target.isBull -> "Bull"
            target.isOuterBull -> "25"
            target.multiplier == 1 -> "S${target.value}"
            target.multiplier == 2 -> "D${target.value}"
            else -> "T${target.value}"
        }
    }
}
