package com.example.dartscorer_android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.LazyColumn
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.example.dartscorer_android.game.DartMultiplier
import com.example.dartscorer_android.game.DartSegment
import com.example.dartscorer_android.game.DartsGame
import com.example.dartscorer_android.game.FinishRule
import com.example.dartscorer_android.game.InRule
import com.example.dartscorer_android.game.Player
import com.example.dartscorer_android.game.StartScoreOption
import kotlin.math.max

private data class SetupPlayer(
    val id: Int,
    var name: String,
    val defaultName: String
)

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun DartsGameScreen() {
    val game = remember { DartsGame(playerCount = 2) }
    var renderTick by remember { mutableIntStateOf(0) }
    var selectedMultiplier by remember { mutableStateOf(DartMultiplier.SINGLE) }
    var showNewGameDialog by remember { mutableStateOf(true) }
    var showRestartDialog by remember { mutableStateOf(false) }
    val setupPlayers = remember { mutableStateListOf<SetupPlayer>() }
    var setupFinishRule by remember { mutableStateOf(FinishRule.DOUBLE_OUT) }
    var setupInRule by remember { mutableStateOf(InRule.DEFAULT) }
    var setupStartScore by remember { mutableStateOf(StartScoreOption.SCORE_501) }
    var setupSetModeEnabled by remember { mutableStateOf(false) }
    var setupLegsToWin by remember { mutableIntStateOf(3) }

    renderTick

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
                val clamped = count.coerceIn(1, 4)
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
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
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

                OutlinedButton(
                    onClick = {
                        game.undoLastThrow()
                        renderTick++
                    },
                    enabled = game.canUndo
                ) { Text("Undo") }
            }

            key(renderTick) {
                Scoreboard(game = game, version = renderTick)
                Divider()

                Text("Active: ${game.activePlayer.name}", fontWeight = FontWeight.Medium)

                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    val throwsInTurn = game.currentTurn.darts
                    if (throwsInTurn.isEmpty()) {
                        ChipText("No throws")
                    } else {
                        throwsInTurn.forEach { ChipText(it.displayText) }
                    }
                }

                ChipText(
                    text = game.bestPossibleFinishLine,
                    emphasized = game.hasBestPossibleFinish
                )

                game.statusMessage?.let { Text(it, color = MaterialTheme.colorScheme.onSurfaceVariant) }
            }

            Text("Multiplier", style = MaterialTheme.typography.titleSmall)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                DartMultiplier.entries.forEach { multiplier ->
                    FilterChip(
                        selected = selectedMultiplier == multiplier,
                        onClick = { selectedMultiplier = multiplier },
                        label = { Text(multiplier.label) }
                    )
                }
            }

            Text("Throw", style = MaterialTheme.typography.titleSmall)
            val throwButtons = (1..20).map { it.toString() } + listOf(
                if (selectedMultiplier == DartMultiplier.SINGLE) "25" else "Bull",
                "0"
            )

            LazyVerticalGrid(
                columns = GridCells.Fixed(5),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.heightIn(max = 280.dp)
            ) {
                items(throwButtons) { label ->
                    val enabled = when (label) {
                        "25", "Bull" -> game.winner == null && selectedMultiplier != DartMultiplier.TRIPLE
                        else -> game.winner == null
                    }

                    Button(
                        onClick = {
                            when (label) {
                                "25", "Bull" -> game.submitThrow(DartSegment.Bull, selectedMultiplier)
                                "0" -> game.submitThrow(DartSegment.Number(0), DartMultiplier.SINGLE)
                                else -> game.submitThrow(DartSegment.Number(label.toInt()), selectedMultiplier)
                            }
                            selectedMultiplier = DartMultiplier.SINGLE
                            renderTick++
                        },
                        enabled = enabled,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(label, maxLines = 1, softWrap = false, overflow = TextOverflow.Clip)
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun Scoreboard(game: DartsGame, version: Int) {
    version
    LazyColumn(
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        items(game.players.size) { index ->
            val player = game.players[index]
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
                        .padding(10.dp),
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
                                FlowRow(
                                    modifier = Modifier.weight(1f),
                                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                                ) {
                                    throwsForBadge.forEach { value ->
                                        ChipText(value.toString())
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
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ChipText(text: String, emphasized: Boolean = false) {
    val background = if (emphasized) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant
    val foreground = if (emphasized) Color.White else MaterialTheme.colorScheme.onSurface
    Text(
        text = text,
        color = foreground,
        fontWeight = if (emphasized) FontWeight.Bold else FontWeight.Normal,
        modifier = Modifier
            .background(background, RoundedCornerShape(6.dp))
            .padding(horizontal = 8.dp, vertical = 4.dp)
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
                        Text("Legs to win: $legsToWin")
                        OutlinedButton(onClick = { onLegsToWinChange(legsToWin - 1) }) { Text("-") }
                        OutlinedButton(onClick = { onLegsToWinChange(legsToWin + 1) }) { Text("+") }
                    }
                }

                Text("Player Order")
                Column(
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(max = 320.dp)
                ) {
                    setupPlayers.forEachIndexed { index, player ->
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
                                        onDrag = { change, dragAmount ->
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
                            Text("Drag", color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
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
