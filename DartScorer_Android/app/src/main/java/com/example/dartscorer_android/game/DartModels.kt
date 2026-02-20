package com.example.dartscorer_android.game

enum class FinishRule(val label: String) {
    DOUBLE_OUT("Double Out"),
    SINGLE_OUT("Single Out")
}

enum class InRule(val label: String) {
    DEFAULT("Default"),
    DOUBLE_IN("Double In")
}

enum class StartScoreOption(val score: Int) {
    SCORE_501(501),
    SCORE_301(301);

    val label: String
        get() = score.toString()
}

enum class DartMultiplier(val value: Int, val label: String) {
    SINGLE(1, "Single"),
    DOUBLE(2, "Double"),
    TRIPLE(3, "Triple")
}

sealed interface DartSegment {
    val baseValue: Int
    val label: String

    data class Number(val value: Int) : DartSegment {
        override val baseValue: Int = value
        override val label: String = value.toString()
    }

    data object Bull : DartSegment {
        override val baseValue: Int = 25
        override val label: String = "Bull"
    }
}

data class DartThrow(
    val segment: DartSegment,
    val multiplier: DartMultiplier
) {
    val points: Int
        get() = segment.baseValue * multiplier.value

    val isDouble: Boolean
        get() = multiplier == DartMultiplier.DOUBLE

    val displayText: String
        get() = "${multiplier.label} ${segment.label} ($points)"

    companion object {
        fun isValid(segment: DartSegment, multiplier: DartMultiplier): Boolean {
            return when (segment) {
                is DartSegment.Number -> segment.value in 0..20
                DartSegment.Bull -> multiplier != DartMultiplier.TRIPLE
            }
        }
    }
}

data class Player(
    val id: Int,
    val name: String,
    val score: Int = 501
)

data class Turn(
    val startingScore: Int,
    val openedAtTurnStart: Boolean = true,
    val darts: List<DartThrow> = emptyList()
) {
    val dartsUsed: Int
        get() = darts.size

    val dartsRemaining: Int
        get() = (3 - dartsUsed).coerceAtLeast(0)
}
