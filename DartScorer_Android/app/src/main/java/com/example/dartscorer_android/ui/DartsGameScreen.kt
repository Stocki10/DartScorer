package com.example.dartscorer_android.ui

import android.content.Context.MODE_PRIVATE
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Divider
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.key
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import com.example.dartscorer_android.game.DartMultiplier
import com.example.dartscorer_android.game.DartSegment
import com.example.dartscorer_android.game.DartsGame
import com.example.dartscorer_android.game.FinishRule
import com.example.dartscorer_android.game.InRule
import com.example.dartscorer_android.game.Player
import com.example.dartscorer_android.game.StartScoreOption
import com.example.dartscorer_android.ui.theme.AppColorTheme
import kotlin.math.max

private data class SetupPlayer(
    val id: Int,
    var name: String,
    val defaultName: String
)

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun DartsGameScreen(
    isDarkTheme: Boolean,
    onThemeChange: (Boolean) -> Unit,
    selectedColorTheme: AppColorTheme,
    onColorThemeChange: (AppColorTheme) -> Unit
) {
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences(APP_PREFS, MODE_PRIVATE) }
    val initialNames = remember {
        val raw = prefs.getString(KEY_SETUP_PLAYER_NAMES, null)
        raw?.split(NAME_DELIMITER)
            ?.map { it.trim() }
            ?.filter { it.isNotEmpty() }
            ?.take(5)
            .orEmpty()
            .ifEmpty { listOf("Player 1", "Player 2") }
    }
    val initialFinishRule = remember {
        prefs.getString(KEY_SETUP_FINISH_RULE, FinishRule.DOUBLE_OUT.name)
            ?.let { runCatching { FinishRule.valueOf(it) }.getOrDefault(FinishRule.DOUBLE_OUT) }
            ?: FinishRule.DOUBLE_OUT
    }
    val initialInRule = remember {
        prefs.getString(KEY_SETUP_IN_RULE, InRule.DEFAULT.name)
            ?.let { runCatching { InRule.valueOf(it) }.getOrDefault(InRule.DEFAULT) }
            ?: InRule.DEFAULT
    }
    val initialStartScore = remember {
        val stored = prefs.getInt(KEY_SETUP_START_SCORE, StartScoreOption.SCORE_501.score)
        if (stored == StartScoreOption.SCORE_301.score) StartScoreOption.SCORE_301 else StartScoreOption.SCORE_501
    }
    val initialSetMode = remember { prefs.getBoolean(KEY_SETUP_SET_MODE, false) }
    val initialLegsToWin = remember { prefs.getInt(KEY_SETUP_LEGS_TO_WIN, 3).coerceAtLeast(1) }

    val game = remember {
        DartsGame(
            playerCount = initialNames.size,
            startingScore = initialStartScore.score,
            finishRule = initialFinishRule,
            inRule = initialInRule,
            setModeEnabled = initialSetMode,
            legsToWin = initialLegsToWin
        ).apply {
            newGame(
                playerNames = initialNames,
                finishRule = initialFinishRule,
                inRule = initialInRule,
                startingScore = initialStartScore.score,
                setModeEnabled = initialSetMode,
                legsToWin = initialLegsToWin
            )
        }
    }
    var renderTick by remember { mutableIntStateOf(0) }
    var selectedMultiplier by remember { mutableStateOf(DartMultiplier.SINGLE) }
    var showNewGameDialog by remember { mutableStateOf(true) }
    var showRestartDialog by remember { mutableStateOf(false) }
    var showSettingsDialog by remember { mutableStateOf(false) }
    val setupPlayers = remember { mutableStateListOf<SetupPlayer>() }
    var setupFinishRule by remember { mutableStateOf(initialFinishRule) }
    var setupInRule by remember { mutableStateOf(initialInRule) }
    var setupStartScore by remember { mutableStateOf(initialStartScore) }
    var setupSetModeEnabled by remember { mutableStateOf(initialSetMode) }
    var setupLegsToWin by remember { mutableIntStateOf(initialLegsToWin) }

    fun syncSetupFromGame() {
        setupPlayers.clear()
        game.players.forEachIndexed { index, player ->
            setupPlayers += SetupPlayer(
                id = player.id,
                name = player.name,
                defaultName = "Player ${index + 1}"
            )
        }
        setupFinishRule = game.finishRule
        setupInRule = game.inRule
        setupStartScore = if (game.startingScore == 301) StartScoreOption.SCORE_301 else StartScoreOption.SCORE_501
        setupSetModeEnabled = game.setModeEnabled
        setupLegsToWin = game.legsToWin
    }

    fun persistSetupToPrefs() {
        prefs.edit()
            .putString(KEY_SETUP_PLAYER_NAMES, setupPlayers.map { it.name }.joinToString(NAME_DELIMITER))
            .putString(KEY_SETUP_FINISH_RULE, setupFinishRule.name)
            .putString(KEY_SETUP_IN_RULE, setupInRule.name)
            .putInt(KEY_SETUP_START_SCORE, setupStartScore.score)
            .putBoolean(KEY_SETUP_SET_MODE, setupSetModeEnabled)
            .putInt(KEY_SETUP_LEGS_TO_WIN, setupLegsToWin)
            .apply()
    }

    if (showNewGameDialog && setupPlayers.isEmpty()) {
        syncSetupFromGame()
    }

    if (showNewGameDialog) {
        NewGameDialog(
            setupPlayers = setupPlayers,
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
            onPlayerCountChange = { count ->
                val clamped = count.coerceIn(1, 5)
                if (clamped > setupPlayers.size) {
                    val start = setupPlayers.size + 1
                    for (index in start..clamped) {
                        setupPlayers += SetupPlayer(
                            id = setupPlayers.maxOfOrNull { it.id }?.plus(1) ?: 1,
                            name = "Player $index",
                            defaultName = "Player $index"
                        )
                    }
                } else if (clamped < setupPlayers.size) {
                    repeat(setupPlayers.size - clamped) { setupPlayers.removeAt(setupPlayers.lastIndex) }
                }
            },
            onCancel = {
                showNewGameDialog = false
                if (game.players.isEmpty()) {
                    syncSetupFromGame()
                }
            },
            onStart = {
                game.newGame(
                    playerNames = setupPlayers.map { it.name },
                    finishRule = setupFinishRule,
                    inRule = setupInRule,
                    startingScore = setupStartScore.score,
                    setModeEnabled = setupSetModeEnabled,
                    legsToWin = setupLegsToWin
                )
                persistSetupToPrefs()
                selectedMultiplier = DartMultiplier.SINGLE
                showNewGameDialog = false
                renderTick++
            }
        )
    }

    if (showRestartDialog) {
        AlertDialog(
            onDismissRequest = { showRestartDialog = false },
            title = { Text("Restart Leg?") },
            text = { Text("You already started this leg. This will discard current progress.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        game.restartLeg()
                        showRestartDialog = false
                        renderTick++
                    }
                ) { Text("Restart Leg") }
            },
            dismissButton = {
                TextButton(onClick = { showRestartDialog = false }) { Text("Cancel") }
            }
        )
    }

    if (showSettingsDialog) {
        SettingsDialog(
            isDarkTheme = isDarkTheme,
            onThemeChange = onThemeChange,
            selectedColorTheme = selectedColorTheme,
            onColorThemeChange = onColorThemeChange,
            onDismiss = { showSettingsDialog = false }
        )
    }

    if (game.winner != null) {
        WinnerDialog(
            game = game,
            onNewLegRandom = {
                game.restartLegRandomSequence()
                selectedMultiplier = DartMultiplier.SINGLE
                renderTick++
            },
            onStartNewGame = {
                syncSetupFromGame()
                showNewGameDialog = true
                renderTick++
            }
        )
    }

    Scaffold(
        topBar = { TopAppBar(title = { Text("DartScorer") }) }
    ) { innerPadding ->
        key(renderTick) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
                    .padding(horizontal = 12.dp)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .navigationBarsPadding(),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(
                        modifier = Modifier.weight(1f),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedButton(onClick = {
                            syncSetupFromGame()
                            showNewGameDialog = true
                        }) { Text("New Game") }

                        OutlinedButton(onClick = {
                            if (game.isLegInProgress) {
                                showRestartDialog = true
                            } else {
                                game.restartLeg()
                                selectedMultiplier = DartMultiplier.SINGLE
                                renderTick++
                            }
                        }) { Text("Restart Leg") }
                    }
                    IconButton(
                        onClick = { showSettingsDialog = true },
                        modifier = Modifier.size(48.dp)
                    ) {
                        Icon(
                            painter = painterResource(id = android.R.drawable.ic_menu_preferences),
                            contentDescription = "Settings",
                            modifier = Modifier.size(24.dp)
                        )
                    }
                    IconButton(
                        onClick = {
                            game.undoLastThrow()
                            renderTick++
                        },
                        enabled = game.canUndo,
                        modifier = Modifier.size(48.dp)
                    ) {
                        Icon(
                            painter = painterResource(id = android.R.drawable.ic_media_previous),
                            contentDescription = "Reverse",
                            modifier = Modifier.size(24.dp)
                        )
                    }
                }

                game.statusMessage?.let { Text(it, color = MaterialTheme.colorScheme.onSurfaceVariant) }

                Scoreboard(
                    game = game,
                    version = renderTick,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 4.dp)
                )

                Spacer(modifier = Modifier.weight(1f))

                ChipText(
                    text = "Best Finish: ${game.bestPossibleFinishLine}",
                    emphasized = game.hasBestPossibleFinish
                )
                Divider()

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    DartMultiplier.entries.forEach { multiplier ->
                        FilterChip(
                            selected = selectedMultiplier == multiplier,
                            onClick = { selectedMultiplier = multiplier },
                            label = { Text(multiplier.label) }
                        )
                    }
                }

                val throwButtons = (1..20).map { it.toString() } + listOf(
                    if (selectedMultiplier == DartMultiplier.SINGLE) "25" else "Bull",
                    "0",
                    "",
                    "",
                    "NO_SCORE"
                )

                LazyVerticalGrid(
                    columns = GridCells.Fixed(5),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.heightIn(max = 252.dp)
                ) {
                        items(throwButtons) { label ->
                            if (label.isEmpty()) {
                                Spacer(modifier = Modifier.fillMaxWidth().height(1.dp))
                                return@items
                            }

                            val enabled = when (label) {
                                "25", "Bull" -> game.winner == null && selectedMultiplier != DartMultiplier.TRIPLE
                                else -> game.winner == null
                            }

                            Button(
                                onClick = {
                                    when (label) {
                                        "25", "Bull" -> game.submitThrow(DartSegment.Bull, selectedMultiplier)
                                        "0" -> game.submitThrow(DartSegment.Number(0), DartMultiplier.SINGLE)
                                        "NO_SCORE" -> {
                                            val used = game.currentTurn.darts.size
                                            repeat(used) {
                                                game.undoLastThrow()
                                            }
                                            repeat(3) {
                                                game.submitThrow(DartSegment.Number(0), DartMultiplier.SINGLE)
                                            }
                                        }
                                        else -> game.submitThrow(DartSegment.Number(label.toInt()), selectedMultiplier)
                                    }
                                    selectedMultiplier = DartMultiplier.SINGLE
                                    renderTick++
                                },
                                enabled = enabled,
                                modifier = if (label == "NO_SCORE") {
                                    Modifier
                                        .fillMaxWidth()
                                        .height(56.dp)
                                } else {
                                    Modifier.fillMaxWidth()
                                },
                                contentPadding = if (label == "NO_SCORE") {
                                    PaddingValues(horizontal = 4.dp, vertical = 4.dp)
                                } else {
                                    ButtonDefaults.ContentPadding
                                }
                            ) {
                                if (label == "NO_SCORE") {
                                    Text(
                                        "No\nScore",
                                        maxLines = 2,
                                        softWrap = true,
                                        overflow = TextOverflow.Clip,
                                        fontSize = 11.sp,
                                        lineHeight = 12.sp
                                    )
                                } else {
                                    Text(label, maxLines = 1, softWrap = false, overflow = TextOverflow.Clip)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun Scoreboard(game: DartsGame, version: Int, modifier: Modifier = Modifier) {
    version
    Column(
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = modifier
    ) {
        game.players.forEachIndexed { index, player ->
            val active = index == game.activePlayerIndex
            val throwsForBadge = if (active) {
                game.currentTurn.darts.map { it.points }
            } else {
                game.lastTurnThrows(player)
            }
            Card(
                colors = CardDefaults.cardColors(
                    containerColor = if (active) {
                        MaterialTheme.colorScheme.primary.copy(alpha = 0.18f)
                    } else {
                        MaterialTheme.colorScheme.surfaceVariant
                    }
                )
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 10.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text(player.name)
                            if (game.setModeEnabled) {
                                Text(
                                    "${game.legsWon(player)}",
                                    color = Color.White,
                                    style = MaterialTheme.typography.labelSmall,
                                    modifier = Modifier
                                        .background(
                                            color = MaterialTheme.colorScheme.primary,
                                            shape = RoundedCornerShape(6.dp)
                                        )
                                        .padding(horizontal = 6.dp, vertical = 2.dp)
                                )
                            }
                            if (throwsForBadge.isNotEmpty()) {
                                Row(
                                    modifier = Modifier.weight(1f),
                                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    throwsForBadge.forEach { value ->
                                        ChipText(value.toString())
                                    }
                                    if (throwsForBadge.count() == 3) {
                                        Box(
                                            modifier = Modifier
                                                .padding(horizontal = 2.dp)
                                                .width(1.dp)
                                                .height(16.dp)
                                                .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.8f))
                                        )
                                        ChipText(
                                            text = "${throwsForBadge.sum()}",
                                            emphasized = true
                                        )
                                    }
                                }
                            }
                        }
                    }
                    Column(horizontalAlignment = Alignment.End) {
                        Text("${player.score}", fontWeight = FontWeight.SemiBold)
                        val average = game.legAverage(player) ?: 0.0
                        Text(
                            text = "⌀ ${"%.1f".format(average)}",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ChipText(text: String, emphasized: Boolean = false, modifier: Modifier = Modifier) {
    val background = if (emphasized) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant
    val foreground = if (emphasized) Color.White else MaterialTheme.colorScheme.onSurface
    Text(
        text = text,
        color = foreground,
        fontWeight = if (emphasized) FontWeight.Bold else FontWeight.Normal,
        modifier = modifier
            .background(background, RoundedCornerShape(6.dp))
            .padding(horizontal = 8.dp, vertical = 4.dp)
    )
}

@Composable
@OptIn(ExperimentalLayoutApi::class)
private fun SettingsDialog(
    isDarkTheme: Boolean,
    onThemeChange: (Boolean) -> Unit,
    selectedColorTheme: AppColorTheme,
    onColorThemeChange: (AppColorTheme) -> Unit,
    onDismiss: () -> Unit
) {
    var pendingDarkTheme by remember(isDarkTheme) { mutableStateOf(isDarkTheme) }
    var pendingColorTheme by remember(selectedColorTheme) { mutableStateOf(selectedColorTheme) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Settings", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Theme", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Medium)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(
                        selected = !pendingDarkTheme,
                        onClick = { pendingDarkTheme = false },
                        label = { Text("Light") }
                    )
                    FilterChip(
                        selected = pendingDarkTheme,
                        onClick = { pendingDarkTheme = true },
                        label = { Text("Dark") }
                    )
                }
                Text("Color Theme", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Medium)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    AppColorTheme.entries.forEach { appTheme ->
                        FilterChip(
                            selected = pendingColorTheme == appTheme,
                            onClick = { pendingColorTheme = appTheme },
                            label = { Text(appTheme.label) }
                        )
                    }
                }
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
        confirmButton = {
            TextButton(
                onClick = {
                    onThemeChange(pendingDarkTheme)
                    onColorThemeChange(pendingColorTheme)
                    onDismiss()
                }
            ) { Text("Save") }
        }
    )
}

@Composable
private fun WinnerDialog(
    game: DartsGame,
    onNewLegRandom: () -> Unit,
    onStartNewGame: () -> Unit
) {
    val winner = game.winner ?: return
    val title = if (game.setWinner == null) "Leg Won" else "Winner"
    val subtitle = if (game.setWinner != null) {
        "Match complete."
    } else {
        val outText = if (game.finishRule == FinishRule.DOUBLE_OUT) "double-out" else "single-out"
        val inText = if (game.inRule == InRule.DOUBLE_IN) "double-in" else "default-in"
        "Played $inText, $outText."
    }

    AlertDialog(
        onDismissRequest = {},
        title = { Text(title) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(winner.name, fontWeight = FontWeight.SemiBold)
                Text(subtitle, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        },
        confirmButton = {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (game.setWinner == null) {
                    TextButton(onClick = onNewLegRandom) { Text("New Leg (Random)") }
                }
                TextButton(onClick = onStartNewGame) {
                    Text(if (game.setWinner == null) "New Game" else "Start New Game")
                }
            }
        }
    )
}

@Composable
@OptIn(ExperimentalLayoutApi::class)
private fun NewGameDialog(
    setupPlayers: MutableList<SetupPlayer>,
    finishRule: FinishRule,
    onFinishRuleChange: (FinishRule) -> Unit,
    inRule: InRule,
    onInRuleChange: (InRule) -> Unit,
    startScore: StartScoreOption,
    onStartScoreChange: (StartScoreOption) -> Unit,
    setModeEnabled: Boolean,
    onSetModeChange: (Boolean) -> Unit,
    legsToWin: Int,
    onLegsToWinChange: (Int) -> Unit,
    onPlayerCountChange: (Int) -> Unit,
    onCancel: () -> Unit,
    onStart: () -> Unit
) {
    var draggedIndex by remember { mutableStateOf<Int?>(null) }
    var draggedOffsetY by remember { mutableStateOf(0f) }
    val rowHeightPx = 76f

    fun movePlayer(from: Int, to: Int) {
        if (from == to || from !in setupPlayers.indices || to !in setupPlayers.indices) return
        val item = setupPlayers.removeAt(from)
        setupPlayers.add(to, item)
    }

    AlertDialog(
        onDismissRequest = {},
        title = { Text("New Game") },
        text = {
            Column(
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 520.dp)
                    .verticalScroll(rememberScrollState())
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text("Players: ${setupPlayers.size}")
                    OutlinedButton(onClick = { onPlayerCountChange(setupPlayers.size - 1) }) { Text("-") }
                    OutlinedButton(onClick = { onPlayerCountChange(setupPlayers.size + 1) }) { Text("+") }
                }
                Text("Game")
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    StartScoreOption.entries.forEach { option ->
                        FilterChip(
                            selected = startScore == option,
                            onClick = { onStartScoreChange(option) },
                            label = { Text(option.label) }
                        )
                    }
                }
                Text("Finish Mode")
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FinishRule.entries.forEach { rule ->
                        FilterChip(
                            selected = finishRule == rule,
                            onClick = { onFinishRuleChange(rule) },
                            label = { Text(rule.label) }
                        )
                    }
                }
                Text("In Mode")
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    InRule.entries.forEach { rule ->
                        FilterChip(
                            selected = inRule == rule,
                            onClick = { onInRuleChange(rule) },
                            label = { Text(rule.label) }
                        )
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    FilterChip(
                        selected = setModeEnabled,
                        onClick = { onSetModeChange(!setModeEnabled) },
                        label = { Text("Set Mode") }
                    )
                    if (setModeEnabled) {
                        Text("Legs: $legsToWin")
                        OutlinedButton(onClick = { onLegsToWinChange(legsToWin - 1) }) { Text("-") }
                        OutlinedButton(onClick = { onLegsToWinChange(legsToWin + 1) }) { Text("+") }
                    }
                }
                Text("Player Order")
                repeat(setupPlayers.size) { index ->
                    val player = setupPlayers[index]
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .graphicsLayer {
                                translationY = if (draggedIndex == index) draggedOffsetY else 0f
                            }
                            .zIndex(if (draggedIndex == index) 1f else 0f)
                            .pointerInput(index) {
                                detectDragGesturesAfterLongPress(
                                    onDragStart = {
                                        draggedIndex = index
                                        draggedOffsetY = 0f
                                    },
                                    onDragCancel = {
                                        draggedIndex = null
                                        draggedOffsetY = 0f
                                    },
                                    onDragEnd = {
                                        draggedIndex = null
                                        draggedOffsetY = 0f
                                    },
                                    onDrag = { _, dragAmount ->
                                        var currentIndex = draggedIndex ?: return@detectDragGesturesAfterLongPress
                                        draggedOffsetY += dragAmount.y

                                        while (draggedOffsetY > rowHeightPx && currentIndex < setupPlayers.lastIndex) {
                                            movePlayer(currentIndex, currentIndex + 1)
                                            currentIndex += 1
                                            draggedOffsetY -= rowHeightPx
                                        }
                                        while (draggedOffsetY < -rowHeightPx && currentIndex > 0) {
                                            movePlayer(currentIndex, currentIndex - 1)
                                            currentIndex -= 1
                                            draggedOffsetY += rowHeightPx
                                        }
                                        draggedIndex = currentIndex
                                    }
                                )
                            }
                    ) {
                        OutlinedTextField(
                            value = player.name,
                            onValueChange = { setupPlayers[index] = player.copy(name = it) },
                            label = { Text(player.defaultName) },
                            singleLine = true,
                            modifier = Modifier.weight(1f)
                        )
                        Icon(
                            painter = painterResource(id = android.R.drawable.ic_menu_sort_by_size),
                            contentDescription = "Drag Handle",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        },
        dismissButton = {
            TextButton(
                onClick = onCancel,
                colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error)
            ) { Text("Cancel") }
        },
        confirmButton = { TextButton(onClick = onStart) { Text("Start") } }
    )
}

private const val APP_PREFS = "dartscorer_android_prefs"
private const val KEY_SETUP_PLAYER_NAMES = "setup_player_names"
private const val KEY_SETUP_FINISH_RULE = "setup_finish_rule"
private const val KEY_SETUP_IN_RULE = "setup_in_rule"
private const val KEY_SETUP_START_SCORE = "setup_start_score"
private const val KEY_SETUP_SET_MODE = "setup_set_mode_enabled"
private const val KEY_SETUP_LEGS_TO_WIN = "setup_legs_to_win"
private const val NAME_DELIMITER = "\u001F"
