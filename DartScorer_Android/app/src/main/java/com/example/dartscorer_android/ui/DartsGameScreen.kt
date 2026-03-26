package com.example.dartscorer_android.ui

import android.content.Context.MODE_PRIVATE
import android.content.SharedPreferences
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.example.dartscorer_android.game.DartMultiplier
import com.example.dartscorer_android.game.DartSegment
import com.example.dartscorer_android.game.DartsGame
import com.example.dartscorer_android.game.FinishRule
import com.example.dartscorer_android.game.InRule
import com.example.dartscorer_android.game.StartScoreOption
import com.example.dartscorer_android.ui.theme.AppColorTheme
import com.example.dartscorer_android.ui.theme.AppThemeMode
import kotlin.math.max

internal data class SetupPlayer(val id: Int, val savedId: Int?, var name: String, val defaultName: String, val colorIndex: Int)
internal data class WinnerOverlayState(val winnerName: String, val isSetWin: Boolean, val isSetMode: Boolean)
internal data class SavedPlayer(val id: Int, val name: String, val colorIndex: Int)

private enum class NavTab { PLAY, HISTORY, PLAYERS, SETTINGS }

// ── SavedPlayer persistence helpers ──────────────────────────────────────────

private fun serializeSavedPlayers(players: List<SavedPlayer>): String =
    players.joinToString("|") { "${it.id}\t${it.name}\t${it.colorIndex}" }

private fun deserializeSavedPlayers(raw: String): List<SavedPlayer> {
    if (raw.isBlank()) return emptyList()
    return raw.split("|").mapNotNull { entry ->
        val parts = entry.split("\t")
        if (parts.size < 3) return@mapNotNull null
        SavedPlayer(
            id = parts[0].toIntOrNull() ?: return@mapNotNull null,
            name = parts[1],
            colorIndex = parts[2].toIntOrNull() ?: 0
        )
    }
}

private fun loadSavedPlayers(prefs: SharedPreferences): List<SavedPlayer> =
    deserializeSavedPlayers(prefs.getString(KEY_SAVED_PLAYERS, "") ?: "")

private fun persistSavedPlayers(prefs: SharedPreferences, players: List<SavedPlayer>) {
    prefs.edit().putString(KEY_SAVED_PLAYERS, serializeSavedPlayers(players)).apply()
}

// ─────────────────────────────────────────────────────────────────────────────

@Composable
fun DartsGameScreen(
    selectedThemeMode: AppThemeMode,
    onThemeModeChange: (AppThemeMode) -> Unit,
    selectedColorTheme: AppColorTheme,
    onColorThemeChange: (AppColorTheme) -> Unit
) {
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences(APP_PREFS, MODE_PRIVATE) }

    val initialFinishRule = remember {
        prefs.getString(KEY_SETUP_FINISH_RULE, FinishRule.DOUBLE_OUT.name)
            ?.let { runCatching { FinishRule.valueOf(it) }.getOrDefault(FinishRule.DOUBLE_OUT) } ?: FinishRule.DOUBLE_OUT
    }
    val initialInRule = remember {
        prefs.getString(KEY_SETUP_IN_RULE, InRule.DEFAULT.name)
            ?.let { runCatching { InRule.valueOf(it) }.getOrDefault(InRule.DEFAULT) } ?: InRule.DEFAULT
    }
    val initialStartScore = remember {
        val stored = prefs.getInt(KEY_SETUP_START_SCORE, StartScoreOption.SCORE_501.score)
        StartScoreOption.entries.find { it.score == stored } ?: StartScoreOption.SCORE_501
    }
    val initialSetMode = remember { prefs.getBoolean(KEY_SETUP_SET_MODE, false) }
    val initialLegsToWin = remember { prefs.getInt(KEY_SETUP_LEGS_TO_WIN, 3).coerceAtLeast(1) }

    // Saved players (persistent across app launches)
    val savedPlayers = remember { mutableStateListOf<SavedPlayer>().also { it.addAll(loadSavedPlayers(prefs)) } }

    val initialSetupPlayers: List<SetupPlayer> = remember {
        val storedIds = prefs.getString(KEY_SETUP_PLAYER_IDS, null)
            ?.split(",")?.mapNotNull { it.trim().toIntOrNull() }
        if (!storedIds.isNullOrEmpty()) {
            storedIds.mapIndexed { idx, sid ->
                val sp = savedPlayers.firstOrNull { it.id == sid }
                SetupPlayer(id = idx + 1, savedId = sid, name = sp?.name ?: "Player ${idx + 1}", defaultName = "Player ${idx + 1}")
            }.takeIf { it.size >= 2 }
        } else null
    } ?: listOf(
        SetupPlayer(id = 1, savedId = null, name = "Player 1", defaultName = "Player 1"),
        SetupPlayer(id = 2, savedId = null, name = "Player 2", defaultName = "Player 2")
    )

    val game = remember {
        DartsGame(
            playerCount = initialSetupPlayers.size,
            startingScore = initialStartScore.score,
            finishRule = initialFinishRule,
            inRule = initialInRule,
            setModeEnabled = initialSetMode,
            legsToWin = initialLegsToWin
        ).apply {
            newGame(
                playerNames = initialSetupPlayers.map { it.name },
                finishRule = initialFinishRule,
                inRule = initialInRule,
                startingScore = initialStartScore.score,
                setModeEnabled = initialSetMode,
                legsToWin = initialLegsToWin
            )
        }
    }

    var currentTab by remember { mutableStateOf(NavTab.PLAY) }
    var isInSetupMode by remember { mutableStateOf(true) }
    var hasActiveGame by remember { mutableStateOf(false) }
    // gamePlayerId (1-indexed) → colorIndex, rebuilt each time START is pressed
    var playerColorMap by remember { mutableStateOf<Map<Int, Int>>(emptyMap()) }
    var renderTick by remember { mutableIntStateOf(0) }
    var selectedMultiplier by remember { mutableStateOf(DartMultiplier.SINGLE) }
    var winnerOverlay by remember { mutableStateOf<WinnerOverlayState?>(null) }
    val gameHistory = remember { mutableStateListOf<GameResult>() }
    var currentLegNumber by remember { mutableIntStateOf(1) }
    var legStartTime by remember { mutableStateOf(System.currentTimeMillis()) }

    val setupPlayers = remember { mutableStateListOf<SetupPlayer>().also { it.addAll(initialSetupPlayers) } }
    var setupFinishRule by remember { mutableStateOf(initialFinishRule) }
    var setupInRule by remember { mutableStateOf(initialInRule) }
    var setupStartScore by remember { mutableStateOf(initialStartScore) }
    var setupSetModeEnabled by remember { mutableStateOf(initialSetMode) }
    var setupLegsToWin by remember { mutableIntStateOf(initialLegsToWin) }

    val completedRounds = remember { mutableStateListOf<CompletedRound>() }
    var uiActivePlayerIndex by remember { mutableIntStateOf(0) }
    val currentTurnLabels = remember { mutableStateListOf<String>() }
    val currentTurnIsDouble = remember { mutableStateListOf<Boolean>() }
    val currentTurnIsTriple = remember { mutableStateListOf<Boolean>() }
    var globalRoundCounter by remember { mutableIntStateOf(1) }

    fun syncSetupFromGame() {
        setupPlayers.clear()
        game.players.forEachIndexed { index, player ->
            val savedPlayer = savedPlayers.firstOrNull { it.name == player.name }
            setupPlayers += SetupPlayer(id = player.id, savedId = savedPlayer?.id, name = player.name, defaultName = "Player ${index + 1}")
        }
        setupFinishRule = game.finishRule
        setupInRule = game.inRule
        setupStartScore = StartScoreOption.entries.find { it.score == game.startingScore } ?: StartScoreOption.SCORE_501
        setupSetModeEnabled = game.setModeEnabled
        setupLegsToWin = game.legsToWin
    }

    fun persistSetupToPrefs() {
        val ids = setupPlayers.mapNotNull { it.savedId }.joinToString(",")
        prefs.edit()
            .putString(KEY_SETUP_PLAYER_IDS, ids)
            .putString(KEY_SETUP_FINISH_RULE, setupFinishRule.name)
            .putString(KEY_SETUP_IN_RULE, setupInRule.name)
            .putInt(KEY_SETUP_START_SCORE, setupStartScore.score)
            .putBoolean(KEY_SETUP_SET_MODE, setupSetModeEnabled)
            .putInt(KEY_SETUP_LEGS_TO_WIN, setupLegsToWin)
            .apply()
    }

    fun recordTurnIfPlayerChanged(newPlayerIndex: Int, wasCheckout: Boolean = false) {
        if (uiActivePlayerIndex != newPlayerIndex || wasCheckout) {
            if (currentTurnLabels.isNotEmpty()) {
                val total = currentTurnLabels.sumOf { label ->
                    when {
                        label.startsWith("T") -> (label.drop(1).toIntOrNull() ?: 0) * 3
                        label.startsWith("D") -> (label.drop(1).toIntOrNull() ?: 0) * 2
                        label == "Bull" -> 50
                        label == "25" -> 25
                        else -> label.toIntOrNull() ?: 0
                    }
                }
                val playerName = game.players.getOrNull(uiActivePlayerIndex)?.name ?: "Player"
                completedRounds += CompletedRound(
                    roundNumber = globalRoundCounter++,
                    playerName = playerName,
                    throwLabels = currentTurnLabels.toList(),
                    isDoubleList = currentTurnIsDouble.toList(),
                    isTripleList = currentTurnIsTriple.toList(),
                    total = total,
                    wasCheckout = wasCheckout
                )
                currentTurnLabels.clear()
                currentTurnIsDouble.clear()
                currentTurnIsTriple.clear()
            }
            uiActivePlayerIndex = newPlayerIndex
        }
    }

    fun buildGameResult(winnerName: String, isSetWin: Boolean, checkoutLabel: String?): GameResult {
        val duration = (System.currentTimeMillis() - legStartTime) / 1000
        val checkoutScore = completedRounds.lastOrNull { it.wasCheckout }?.total
        return GameResult(
            winnerName = winnerName,
            isSetWin = isSetWin,
            startingScore = game.startingScore,
            checkoutLabel = checkoutLabel,
            checkoutScore = checkoutScore,
            legNumber = currentLegNumber,
            durationSeconds = duration,
            playerStats = game.players.map { player ->
                PlayerMatchStat(
                    name = player.name,
                    averagePPR = game.legAverage(player) ?: 0.0,
                    dartsThrown = game.dartsThrownByPlayerId[player.id] ?: 0,
                    remainingScore = player.score
                )
            },
            roundHistory = completedRounds.toList(),
            timestamp = System.currentTimeMillis()
        )
    }

    fun syncWinnerOverlay() {
        if (winnerOverlay != null) return
        val winner = game.winner ?: game.players.firstOrNull { it.score == 0 } ?: return
        winnerOverlay = WinnerOverlayState(winnerName = winner.name, isSetWin = game.setWinner != null, isSetMode = game.setModeEnabled)
    }

    fun handleThrow(segment: DartSegment, multiplier: DartMultiplier) {
        val prevPlayerIndex = game.activePlayerIndex
        game.submitThrow(segment, multiplier)

        val throwLabel = when {
            segment is DartSegment.Bull && multiplier == DartMultiplier.DOUBLE -> "Bull"
            segment is DartSegment.Bull -> "25"
            segment is DartSegment.Number -> when (multiplier) {
                DartMultiplier.SINGLE -> "${segment.value}"
                DartMultiplier.DOUBLE -> "D${segment.value}"
                DartMultiplier.TRIPLE -> "T${segment.value}"
            }
            else -> "0"
        }
        currentTurnLabels += throwLabel
        currentTurnIsDouble += (multiplier == DartMultiplier.DOUBLE)
        currentTurnIsTriple += (multiplier == DartMultiplier.TRIPLE)

        val isWinner = game.winner != null
        if (isWinner) {
            recordTurnIfPlayerChanged(game.activePlayerIndex, wasCheckout = true)
        } else if (game.activePlayerIndex != prevPlayerIndex) {
            recordTurnIfPlayerChanged(game.activePlayerIndex)
        }

        if (isWinner) {
            val lastLabel = currentTurnLabels.lastOrNull() ?: throwLabel
            val winner = game.winner!!
            val result = buildGameResult(winner.name, game.setWinner != null, lastLabel)
            gameHistory.add(0, result)
            syncWinnerOverlay()
        }

        selectedMultiplier = DartMultiplier.SINGLE
        renderTick++
    }

    fun resetLegState() {
        completedRounds.clear()
        currentTurnLabels.clear()
        currentTurnIsDouble.clear()
        currentTurnIsTriple.clear()
        uiActivePlayerIndex = 0
        legStartTime = System.currentTimeMillis()
    }

    if (isInSetupMode && setupPlayers.isEmpty()) syncSetupFromGame()

    LaunchedEffect(game.winner?.id, game.setWinner?.id) { syncWinnerOverlay() }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        bottomBar = { AppBottomNav(currentTab = currentTab, onTabChange = { currentTab = it }) }
    ) { innerPadding ->
        key(renderTick) {
            when (currentTab) {
                NavTab.PLAY -> {
                    if (isInSetupMode) {
                        NewGameScreen(
                            setupPlayers = setupPlayers,
                            savedPlayers = savedPlayers.toList(),
                            finishRule = setupFinishRule,
                            onFinishRuleChange = { setupFinishRule = it },
                            inRule = setupInRule,
                            onInRuleChange = { setupInRule = it },
                            startScore = setupStartScore,
                            onStartScoreChange = { setupStartScore = it },
                            setModeEnabled = setupSetModeEnabled,
                            onSetModeChange = { setupSetModeEnabled = it },
                            legsToWin = setupLegsToWin,
                            onLegsToWinChange = { setupLegsToWin = max(1, it) },
                            onShuffle = {
                                val shuffled = setupPlayers.toMutableList().shuffled()
                                setupPlayers.clear()
                                setupPlayers.addAll(shuffled)
                            },
                            onCreateAndAddPlayer = { name ->
                                val newId = (savedPlayers.maxOfOrNull { it.id } ?: 0) + 1
                                val colorIdx = savedPlayers.size % playerIndicatorColors.size
                                val newSaved = SavedPlayer(id = newId, name = name, colorIndex = colorIdx)
                                savedPlayers.add(newSaved)
                                persistSavedPlayers(prefs, savedPlayers)
                                val slotId = (setupPlayers.maxOfOrNull { it.id } ?: 0) + 1
                                setupPlayers.add(SetupPlayer(id = slotId, savedId = newId, name = name, defaultName = name))
                            },
                            onAddSavedPlayer = { savedPlayer ->
                                if (setupPlayers.size < 5) {
                                    val slotId = (setupPlayers.maxOfOrNull { it.id } ?: 0) + 1
                                    setupPlayers.add(SetupPlayer(id = slotId, savedId = savedPlayer.id, name = savedPlayer.name, defaultName = savedPlayer.name))
                                }
                            },
                            onRemovePlayer = { slotId ->
                                setupPlayers.removeAll { it.id == slotId }
                            },
                            onBack = if (hasActiveGame) {
                                { isInSetupMode = false; renderTick++ }
                            } else null,
                            onStart = {
                                if (setupPlayers.size < 2) return@NewGameScreen
                                // Map game player ID (1-indexed by position) → saved color index
                                playerColorMap = setupPlayers.mapIndexed { index, sp ->
                                    val colorIndex = sp.savedId
                                        ?.let { sid -> savedPlayers.firstOrNull { it.id == sid }?.colorIndex }
                                        ?: (index % playerIndicatorColors.size)
                                    (index + 1) to colorIndex
                                }.toMap()
                                game.newGame(
                                    playerNames = setupPlayers.map { it.name },
                                    finishRule = setupFinishRule,
                                    inRule = setupInRule,
                                    startingScore = setupStartScore.score,
                                    setModeEnabled = setupSetModeEnabled,
                                    legsToWin = setupLegsToWin
                                )
                                winnerOverlay = null
                                persistSetupToPrefs()
                                selectedMultiplier = DartMultiplier.SINGLE
                                isInSetupMode = false
                                hasActiveGame = true
                                resetLegState()
                                globalRoundCounter = 1
                                renderTick++
                            },
                            modifier = Modifier.padding(innerPadding)
                        )
                    } else {
                        GamePlayScreen(
                            game = game,
                            playerColorMap = playerColorMap,
                            selectedMultiplier = selectedMultiplier,
                            onMultiplierChange = { selectedMultiplier = it },
                            onThrow = ::handleThrow,
                            onUndo = {
                                game.undoLastThrow()
                                if (currentTurnLabels.isNotEmpty()) currentTurnLabels.removeAt(currentTurnLabels.lastIndex)
                                if (currentTurnIsDouble.isNotEmpty()) currentTurnIsDouble.removeAt(currentTurnIsDouble.lastIndex)
                                if (currentTurnIsTriple.isNotEmpty()) currentTurnIsTriple.removeAt(currentTurnIsTriple.lastIndex)
                                renderTick++
                            },
                            onNewGame = {
                                syncSetupFromGame()
                                isInSetupMode = true
                                renderTick++
                            },
                            onRestartLeg = {
                                game.restartLeg()
                                winnerOverlay = null
                                selectedMultiplier = DartMultiplier.SINGLE
                                resetLegState()
                                renderTick++
                            },
                            winnerOverlay = winnerOverlay,
                            onUndoWin = {
                                winnerOverlay = null
                                game.undoLastThrow()
                                renderTick++
                            },
                            onNewLegRandom = {
                                winnerOverlay = null
                                game.restartLegRandomSequence()
                                selectedMultiplier = DartMultiplier.SINGLE
                                resetLegState()
                                currentLegNumber++
                                renderTick++
                            },
                            modifier = Modifier.padding(innerPadding)
                        )
                    }
                }

                NavTab.HISTORY -> {
                    HistoryScreen(
                        results = gameHistory.toList(),
                        onRematch = {
                            game.restartLegRandomSequence()
                            winnerOverlay = null
                            selectedMultiplier = DartMultiplier.SINGLE
                            resetLegState()
                            isInSetupMode = false
                            currentTab = NavTab.PLAY
                            renderTick++
                        },
                        modifier = Modifier.padding(innerPadding)
                    )
                }

                NavTab.PLAYERS -> {
                    PlayersScreen(
                        savedPlayers = savedPlayers.toList(),
                        gameHistory = gameHistory.toList(),
                        onCreatePlayer = { name ->
                            val newId = (savedPlayers.maxOfOrNull { it.id } ?: 0) + 1
                            val colorIdx = savedPlayers.size % playerIndicatorColors.size
                            savedPlayers.add(SavedPlayer(id = newId, name = name, colorIndex = colorIdx))
                            persistSavedPlayers(prefs, savedPlayers)
                        },
                        onDeletePlayer = { id ->
                            savedPlayers.removeAll { it.id == id }
                            persistSavedPlayers(prefs, savedPlayers)
                        },
                        onEditPlayer = { id, name, colorIndex ->
                            val idx = savedPlayers.indexOfFirst { it.id == id }
                            if (idx >= 0) {
                                savedPlayers[idx] = savedPlayers[idx].copy(name = name, colorIndex = colorIndex)
                                persistSavedPlayers(prefs, savedPlayers)
                            }
                        },
                        modifier = Modifier.padding(innerPadding)
                    )
                }

                NavTab.SETTINGS -> {
                    SettingsScreen(
                        selectedThemeMode = selectedThemeMode,
                        onThemeModeChange = onThemeModeChange,
                        selectedColorTheme = selectedColorTheme,
                        onColorThemeChange = onColorThemeChange,
                        modifier = Modifier.padding(innerPadding)
                    )
                }
            }
        }
    }
}

@Composable
private fun AppBottomNav(currentTab: NavTab, onTabChange: (NavTab) -> Unit) {
    NavigationBar(
        containerColor = MaterialTheme.colorScheme.surface,
        contentColor = MaterialTheme.colorScheme.onSurface
    ) {
        val tabs = listOf(
            Triple(NavTab.PLAY, Icons.Default.SportsEsports, "PLAY"),
            Triple(NavTab.HISTORY, Icons.Default.History, "HISTORY"),
            Triple(NavTab.PLAYERS, Icons.Default.Person, "PLAYERS"),
            Triple(NavTab.SETTINGS, Icons.Default.Settings, "SETTINGS")
        )
        tabs.forEach { (tab, icon, label) ->
            val selected = currentTab == tab
            NavigationBarItem(
                selected = selected,
                onClick = { onTabChange(tab) },
                icon = { Icon(icon, contentDescription = label) },
                label = {
                    Text(label, fontSize = 9.sp, fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal, letterSpacing = 0.5.sp)
                },
                colors = NavigationBarItemDefaults.colors(
                    selectedIconColor = MaterialTheme.colorScheme.primary,
                    selectedTextColor = MaterialTheme.colorScheme.primary,
                    indicatorColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.15f),
                    unselectedIconColor = MaterialTheme.colorScheme.onSurfaceVariant,
                    unselectedTextColor = MaterialTheme.colorScheme.onSurfaceVariant
                )
            )
        }
    }
}

private const val APP_PREFS = "dartscorer_android_prefs"
private const val KEY_SETUP_PLAYER_IDS = "setup_player_ids"
private const val KEY_SETUP_FINISH_RULE = "setup_finish_rule"
private const val KEY_SETUP_IN_RULE = "setup_in_rule"
private const val KEY_SETUP_START_SCORE = "setup_start_score"
private const val KEY_SETUP_SET_MODE = "setup_set_mode_enabled"
private const val KEY_SETUP_LEGS_TO_WIN = "setup_legs_to_win"
private const val KEY_SAVED_PLAYERS = "saved_players_v2"
