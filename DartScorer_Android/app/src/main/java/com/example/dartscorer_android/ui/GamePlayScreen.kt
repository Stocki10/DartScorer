package com.example.dartscorer_android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Undo
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import com.example.dartscorer_android.game.DartMultiplier
import com.example.dartscorer_android.game.DartSegment
import com.example.dartscorer_android.game.DartsGame
import com.example.dartscorer_android.game.Player

@Composable
internal fun GamePlayScreen(
    game: DartsGame,
    playerColorMap: Map<Int, Int>,
    selectedMultiplier: DartMultiplier,
    onMultiplierChange: (DartMultiplier) -> Unit,
    onThrow: (DartSegment, DartMultiplier) -> Unit,
    onUndo: () -> Unit,
    onNewGame: () -> Unit,
    onRestartLeg: () -> Unit,
    winnerOverlay: WinnerOverlayState?,
    onUndoWin: () -> Unit,
    onNewLegRandom: () -> Unit,
    modifier: Modifier = Modifier
) {
    var showRestartDialog by remember { mutableStateOf(false) }

    if (showRestartDialog) {
        AlertDialog(
            onDismissRequest = { showRestartDialog = false },
            containerColor = MaterialTheme.colorScheme.surfaceVariant,
            title = {
                Text("Restart leg?", fontWeight = FontWeight.ExtraBold, color = MaterialTheme.colorScheme.onSurface)
            },
            text = {
                Text("All throws in this leg will be lost.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            },
            confirmButton = {
                Button(
                    onClick = { showRestartDialog = false; onRestartLeg() },
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
                ) { Text("Restart") }
            },
            dismissButton = {
                TextButton(onClick = { showRestartDialog = false }) {
                    Text("Cancel", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        )
    }

    Box(modifier = modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .navigationBarsPadding()
                .padding(horizontal = 12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // Controls row
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                TextButton(onClick = onNewGame) {
                    Text("New Game", color = MaterialTheme.colorScheme.primary, fontSize = 13.sp)
                }
                TextButton(onClick = { showRestartDialog = true }) {
                    Text("Restart", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 13.sp)
                }
                Spacer(Modifier.weight(1f))
                IconButton(
                    onClick = onUndo,
                    enabled = game.canUndo,
                    modifier = Modifier.size(40.dp)
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.Undo,
                        contentDescription = "Undo",
                        tint = if (game.canUndo) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f)
                    )
                }
            }

            // Status message
            if (winnerOverlay == null) {
                game.statusMessage
                    ?.takeIf { !it.contains("wins", ignoreCase = true) }
                    ?.let {
                        Text(it, color = MaterialTheme.colorScheme.secondary, style = MaterialTheme.typography.bodySmall)
                    }
            }

            // Scoreboard
            GameScoreboard(
                game = game,
                playerColorMap = playerColorMap,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.weight(1f))

            // Best finish suggestion
            val bestFinishText = if (game.hasBestPossibleFinish) {
                "FINISH: ${game.bestPossibleFinishLine}"
            } else null

            if (bestFinishText != null) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            MaterialTheme.colorScheme.primary.copy(alpha = 0.15f),
                            RoundedCornerShape(10.dp)
                        )
                        .border(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.4f), RoundedCornerShape(10.dp))
                        .padding(horizontal = 12.dp, vertical = 6.dp)
                ) {
                    Text(
                        bestFinishText,
                        color = MaterialTheme.colorScheme.primary,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }

            HorizontalDivider(color = MaterialTheme.colorScheme.outline)

            // Multiplier selector
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                DartMultiplier.entries.forEach { multiplier ->
                    val isSelected = selectedMultiplier == multiplier
                    Button(
                        onClick = { onMultiplierChange(multiplier) },
                        modifier = Modifier
                            .weight(1f)
                            .height(38.dp),
                        shape = RoundedCornerShape(10.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant,
                            contentColor = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    ) {
                        Text(multiplier.label, fontSize = 12.sp, fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal)
                    }
                }
            }

            // Number pad
            val throwButtons = (1..20).map { it.toString() } + listOf(
                if (selectedMultiplier == DartMultiplier.SINGLE) "25" else "Bull",
                "0", "", "", "NO_SCORE"
            )

            LazyVerticalGrid(
                columns = GridCells.Fixed(5),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.fillMaxWidth(),
                contentPadding = PaddingValues(bottom = 8.dp)
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
                    val isNoScore = label == "NO_SCORE"
                    Button(
                        onClick = {
                            when (label) {
                                "25", "Bull" -> onThrow(DartSegment.Bull, selectedMultiplier)
                                "0" -> onThrow(DartSegment.Number(0), DartMultiplier.SINGLE)
                                "NO_SCORE" -> onThrow(DartSegment.Number(0), DartMultiplier.SINGLE)
                                else -> onThrow(DartSegment.Number(label.toInt()), selectedMultiplier)
                            }
                        },
                        enabled = enabled,
                        modifier = if (isNoScore) Modifier.fillMaxWidth().height(52.dp) else Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(10.dp),
                        contentPadding = if (isNoScore) PaddingValues(4.dp) else ButtonDefaults.ContentPadding,
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (isNoScore) MaterialTheme.colorScheme.surfaceVariant else MaterialTheme.colorScheme.outline.copy(alpha = 0.5f),
                            contentColor = if (isNoScore) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface
                        )
                    ) {
                        if (isNoScore) {
                            Text("No\nScore", maxLines = 2, softWrap = true, overflow = TextOverflow.Clip, fontSize = 10.sp, lineHeight = 11.sp, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                        } else {
                            Text(label, maxLines = 1, softWrap = false, overflow = TextOverflow.Clip, fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
            }
        }

        // Winner overlay
        winnerOverlay?.let { overlay ->
            WinnerOverlay(
                winnerName = overlay.winnerName,
                isSetWin = overlay.isSetWin,
                isSetMode = overlay.isSetMode,
                legsWon = if (overlay.isSetMode) game.legsWon(game.players.firstOrNull { it.name == overlay.winnerName } ?: game.players.first()) else 0,
                legsToWin = game.legsToWin,
                onUndoWin = onUndoWin,
                onNewLegRandom = onNewLegRandom,
                onStartNewGame = onNewGame
            )
        }
    }
}

@Composable
private fun GameScoreboard(game: DartsGame, playerColorMap: Map<Int, Int>, modifier: Modifier = Modifier) {
    Column(
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = modifier
    ) {
        game.players.forEachIndexed { index, player ->
            val active = index == game.activePlayerIndex
            val throwsForDisplay = if (active) {
                game.currentTurn.darts.map { it.points }
            } else {
                game.lastTurnThrows(player)
            }

            Card(
                colors = CardDefaults.cardColors(
                    containerColor = if (active) MaterialTheme.colorScheme.primary.copy(alpha = 0.15f)
                    else MaterialTheme.colorScheme.surfaceVariant
                ),
                shape = RoundedCornerShape(14.dp)
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 12.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Player color from saved profile (falls back to position-based index)
                    val colorIndex = (playerColorMap[player.id] ?: (player.id - 1)) % playerIndicatorColors.size
                    Box(
                        modifier = Modifier
                            .size(4.dp, 40.dp)
                            .background(
                                playerIndicatorColors[colorIndex],
                                RoundedCornerShape(2.dp)
                            )
                    )
                    Spacer(modifier = Modifier.width(10.dp))

                    Column(modifier = Modifier.weight(1f)) {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                player.name,
                                fontWeight = FontWeight.SemiBold,
                                color = if (active) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            if (game.setModeEnabled) {
                                Box(
                                    modifier = Modifier
                                        .background(MaterialTheme.colorScheme.primary, RoundedCornerShape(6.dp))
                                        .padding(horizontal = 6.dp, vertical = 2.dp)
                                ) {
                                    Text(
                                        "${game.legsWon(player)}",
                                        color = Color.White,
                                        style = MaterialTheme.typography.labelSmall
                                    )
                                }
                            }
                        }
                        if (throwsForDisplay.isNotEmpty()) {
                            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                throwsForDisplay.forEach { pts ->
                                    ScoreBadge(pts.toString(), emphasized = false)
                                }
                                if (throwsForDisplay.size == 3) {
                                    ScoreBadge(throwsForDisplay.sum().toString(), emphasized = true)
                                }
                            }
                        }
                    }

                    Column(horizontalAlignment = Alignment.End) {
                        Text(
                            "${player.score}",
                            fontWeight = FontWeight.ExtraBold,
                            fontSize = 22.sp,
                            color = if (active) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        val avg = game.legAverage(player) ?: 0.0
                        Text(
                            "⌀ ${"%.1f".format(avg)}",
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
private fun ScoreBadge(text: String, emphasized: Boolean) {
    val bg = if (emphasized) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline.copy(alpha = 0.5f)
    val fg = if (emphasized) Color.White else MaterialTheme.colorScheme.onSurface
    Box(
        modifier = Modifier
            .background(bg, RoundedCornerShape(6.dp))
            .padding(horizontal = 6.dp, vertical = 2.dp)
    ) {
        Text(text, color = fg, style = MaterialTheme.typography.labelSmall, fontWeight = if (emphasized) FontWeight.Bold else FontWeight.Normal)
    }
}

@Composable
private fun WinnerOverlay(
    winnerName: String,
    isSetWin: Boolean,
    isSetMode: Boolean,
    legsWon: Int,
    legsToWin: Int,
    onUndoWin: () -> Unit,
    onNewLegRandom: () -> Unit,
    onStartNewGame: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.6f))
            .zIndex(20f),
        contentAlignment = Alignment.Center
    ) {
        Card(
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            shape = RoundedCornerShape(20.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
        ) {
            Column(
                modifier = Modifier.padding(24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                val headerLabel = when {
                    isSetWin -> "SET WON 🏆"
                    isSetMode -> "LEG WON"
                    else -> "GAME WON"
                }
                Text(
                    headerLabel,
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.secondary,
                    fontWeight = FontWeight.ExtraBold,
                    letterSpacing = 2.sp
                )
                Text(
                    winnerName,
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.ExtraBold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                // Leg progress indicator in set mode
                if (isSetMode && !isSetWin) {
                    Text(
                        "Leads $legsWon / $legsToWin legs",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.primary,
                        fontWeight = FontWeight.SemiBold
                    )
                }
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    // In set mode leg win: "Next Leg" is the only main action
                    // In set win or single game: "New Game" is the main action
                    if (isSetMode && !isSetWin) {
                        Button(
                            onClick = onNewLegRandom,
                            modifier = Modifier.fillMaxWidth().height(48.dp),
                            shape = RoundedCornerShape(50),
                            colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
                        ) { Text("Next Leg →", fontWeight = FontWeight.ExtraBold) }
                    } else {
                        Button(
                            onClick = onStartNewGame,
                            modifier = Modifier.fillMaxWidth().height(48.dp),
                            shape = RoundedCornerShape(50),
                            colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
                        ) { Text("New Game", fontWeight = FontWeight.Bold) }
                    }
                    TextButton(onClick = onUndoWin, modifier = Modifier.fillMaxWidth()) {
                        Text("Undo Last Throw", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }
}
