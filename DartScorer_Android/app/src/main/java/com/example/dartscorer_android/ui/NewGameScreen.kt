package com.example.dartscorer_android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DragHandle
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material.icons.filled.Shuffle
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import com.example.dartscorer_android.game.FinishRule
import com.example.dartscorer_android.game.InRule
import com.example.dartscorer_android.game.StartScoreOption

internal val playerIndicatorColors = listOf(
    Color(0xFFFF6B35),
    Color(0xFF9B6DFF),
    Color(0xFF00D4AA),
    Color(0xFFFF69B4),
    Color(0xFF4CAF50),
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun NewGameScreen(
    setupPlayers: MutableList<SetupPlayer>,
    savedPlayers: List<SavedPlayer>,
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
    onShuffle: () -> Unit,
    onCreateAndAddPlayer: (String) -> Unit,
    onAddSavedPlayer: (SavedPlayer) -> Unit,
    onRemovePlayer: (Int) -> Unit,
    onStart: () -> Unit,
    onBack: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    // Track drag by player ID (stable across recompositions caused by reordering)
    var draggedPlayerId by remember { mutableStateOf<Int?>(null) }
    var draggedOffsetY by remember { mutableStateOf(0f) }
    val rowHeightPx = with(LocalDensity.current) { 76.dp.toPx() }

    var showAddPlayerDialog by remember { mutableStateOf(false) }

    fun movePlayer(from: Int, to: Int) {
        if (from == to || from !in setupPlayers.indices || to !in setupPlayers.indices) return
        val item = setupPlayers.removeAt(from)
        setupPlayers.add(to, item)
    }

    Column(modifier = modifier.fillMaxSize()) {
        // Heading
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 4.dp, end = 16.dp, top = 4.dp, bottom = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            if (onBack != null) {
                IconButton(onClick = onBack) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Back to game",
                        tint = MaterialTheme.colorScheme.onBackground
                    )
                }
            } else {
                Spacer(modifier = Modifier.width(16.dp))
            }
            Text(
                "New Game",
                style = MaterialTheme.typography.displaySmall,
                fontWeight = FontWeight.ExtraBold,
                color = MaterialTheme.colorScheme.onBackground
            )
        }

        // Settings section — scrollable, takes flexible remaining height
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp)
        ) {
            // GAME SETTINGS section header
            Text(
                "GAME SETTINGS",
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.ExtraBold,
                color = MaterialTheme.colorScheme.onBackground,
                letterSpacing = 1.sp
            )

            Spacer(modifier = Modifier.height(8.dp))

            // Settings card
            Card(
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    // Game mode dropdown (101, 301, 501, 701, 1001)
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(
                            "GAME MODE",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            letterSpacing = 1.sp
                        )
                        ScoreDropdown(selected = startScore, onSelect = onStartScoreChange)
                    }

                    // Finish + In mode row
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        // Finish mode dropdown
                        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(
                                "FINISH MODE",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                letterSpacing = 1.sp
                            )
                            FinishModeDropdown(
                                selected = finishRule,
                                onSelect = onFinishRuleChange
                            )
                        }
                        // In mode toggle
                        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(
                                "IN MODE",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                letterSpacing = 1.sp
                            )
                            InModeToggle(
                                inRule = inRule,
                                onToggle = {
                                    onInRuleChange(
                                        if (inRule == InRule.DEFAULT) InRule.DOUBLE_IN else InRule.DEFAULT
                                    )
                                }
                            )
                        }
                    }

                    // Set mode toggle
                    HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.3f))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(
                                "Set Mode",
                                style = MaterialTheme.typography.bodyLarge,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Text(
                                "Play a legs match",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        Switch(
                            checked = setModeEnabled,
                            onCheckedChange = { onSetModeChange(it) },
                            colors = SwitchDefaults.colors(
                                checkedThumbColor = MaterialTheme.colorScheme.primary,
                                checkedTrackColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.3f),
                                uncheckedThumbColor = MaterialTheme.colorScheme.onSurfaceVariant,
                                uncheckedTrackColor = MaterialTheme.colorScheme.outline
                            )
                        )
                    }

                    // Set mode legs
                    if (setModeEnabled) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Text("Legs to win:", color = MaterialTheme.colorScheme.onSurfaceVariant)
                            PlayerCountControl(
                                count = legsToWin,
                                onDecrement = { onLegsToWinChange(legsToWin - 1) },
                                onIncrement = { onLegsToWinChange(legsToWin + 1) }
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(4.dp))
        } // end settings scroll column

        // PLAYER ORDER header — outside scroll, no gesture conflict
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 4.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                "PLAYER ORDER",
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.ExtraBold,
                color = MaterialTheme.colorScheme.onBackground,
                letterSpacing = 1.sp
            )
            TextButton(onClick = onShuffle) {
                Icon(Icons.Default.Shuffle, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(14.dp))
                Spacer(modifier = Modifier.width(4.dp))
                Text("SHUFFLE", color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold, letterSpacing = 1.sp)
            }
        }

        // Player cards — outside scroll so drag gestures have no competition
        Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
            setupPlayers.forEachIndexed { idx, player ->
                key(player.id) {
                    val savedPlayer = player.savedId?.let { sid -> savedPlayers.firstOrNull { it.id == sid } }
                    val colorIndex = (savedPlayer?.colorIndex ?: idx) % playerIndicatorColors.size

                    Card(
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                        shape = RoundedCornerShape(14.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(bottom = 8.dp)
                            .graphicsLayer {
                                translationY = if (draggedPlayerId == player.id) draggedOffsetY else 0f
                            }
                            .zIndex(if (draggedPlayerId == player.id) 1f else 0f)
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth().height(68.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            // Color indicator bar
                            Box(
                                modifier = Modifier
                                    .width(4.dp).height(68.dp)
                                    .background(playerIndicatorColors[colorIndex], RoundedCornerShape(topStart = 14.dp, bottomStart = 14.dp))
                            )
                            Spacer(modifier = Modifier.width(12.dp))

                            // Avatar circle
                            Box(
                                modifier = Modifier.size(36.dp).clip(CircleShape)
                                    .background(playerIndicatorColors[colorIndex].copy(alpha = 0.2f)),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(player.name.take(1).uppercase(), style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.ExtraBold, color = playerIndicatorColors[colorIndex])
                            }

                            Spacer(modifier = Modifier.width(12.dp))

                            // Player name
                            Column(modifier = Modifier.weight(1f)) {
                                Text(player.name, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
                                if (player.savedId != null) {
                                    Text("Saved player", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }

                            // Remove button (only if > 2 players)
                            if (setupPlayers.size > 2) {
                                IconButton(onClick = { onRemovePlayer(player.id) }) {
                                    Icon(Icons.Default.Close, contentDescription = "Remove", tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(18.dp))
                                }
                            }

                            // Drag handle — gesture lives here, away from the scroll container
                            Icon(
                                Icons.Default.DragHandle,
                                contentDescription = "Drag to reorder",
                                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier
                                    .size(44.dp)
                                    .padding(end = 12.dp)
                                    .pointerInput(player.id) {
                                        detectVerticalDragGestures(
                                            onDragStart = { draggedPlayerId = player.id; draggedOffsetY = 0f },
                                            onDragCancel = { draggedPlayerId = null; draggedOffsetY = 0f },
                                            onDragEnd = { draggedPlayerId = null; draggedOffsetY = 0f },
                                            onVerticalDrag = { change, dragAmount ->
                                                change.consume()
                                                val pid = draggedPlayerId ?: return@detectVerticalDragGestures
                                                var idx = setupPlayers.indexOfFirst { it.id == pid }
                                                if (idx < 0) return@detectVerticalDragGestures
                                                draggedOffsetY += dragAmount
                                                while (draggedOffsetY > rowHeightPx && idx < setupPlayers.lastIndex) {
                                                    movePlayer(idx, idx + 1); idx++; draggedOffsetY -= rowHeightPx
                                                }
                                                while (draggedOffsetY < -rowHeightPx && idx > 0) {
                                                    movePlayer(idx, idx - 1); idx--; draggedOffsetY += rowHeightPx
                                                }
                                            }
                                        )
                                    }
                            )
                        }
                    }
                } // end key(player.id)
            } // end forEachIndexed

            // Add player button (only if < 5 players)
            if (setupPlayers.size < 5) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth().height(56.dp)
                        .border(1.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(14.dp))
                        .clip(RoundedCornerShape(14.dp))
                        .clickable { showAddPlayerDialog = true },
                    contentAlignment = Alignment.Center
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Icon(Icons.Default.PersonAdd, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(18.dp))
                        Text("Add Player", color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }
        }

        // START button — fixed at bottom
        Button(
            onClick = onStart,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp).height(52.dp),
            shape = RoundedCornerShape(14.dp),
            colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
        ) {
            Text("START", fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, letterSpacing = 2.sp)
        }
    }

    // Add player dialog
    if (showAddPlayerDialog) {
        AddPlayerDialog(
            savedPlayers = savedPlayers,
            alreadyAddedIds = setupPlayers.mapNotNull { it.savedId }.toSet(),
            onSelectSaved = { sp ->
                onAddSavedPlayer(sp)
                showAddPlayerDialog = false
            },
            onCreateNew = { name ->
                onCreateAndAddPlayer(name)
                showAddPlayerDialog = false
            },
            onDismiss = { showAddPlayerDialog = false }
        )
    }
}

@Composable
private fun AddPlayerDialog(
    savedPlayers: List<SavedPlayer>,
    alreadyAddedIds: Set<Int>,
    onSelectSaved: (SavedPlayer) -> Unit,
    onCreateNew: (String) -> Unit,
    onDismiss: () -> Unit
) {
    var newName by remember { mutableStateOf("") }
    val available = savedPlayers.filter { it.id !in alreadyAddedIds }

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = MaterialTheme.colorScheme.surfaceVariant,
        title = {
            Text(
                "Add Player",
                fontWeight = FontWeight.ExtraBold,
                color = MaterialTheme.colorScheme.onSurface
            )
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                // Saved players list
                if (available.isNotEmpty()) {
                    Text(
                        "SAVED PLAYERS",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        letterSpacing = 1.sp
                    )
                    available.forEach { sp ->
                        val colorIndex = sp.colorIndex % playerIndicatorColors.size
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(10.dp))
                                .clickable { onSelectSaved(sp) }
                                .padding(horizontal = 8.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(32.dp)
                                    .clip(CircleShape)
                                    .background(playerIndicatorColors[colorIndex].copy(alpha = 0.25f)),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    sp.name.take(1).uppercase(),
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.ExtraBold,
                                    color = playerIndicatorColors[colorIndex]
                                )
                            }
                            Text(
                                sp.name,
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                        }
                    }
                    HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.4f))
                }

                // Create new player
                Text(
                    "CREATE NEW PLAYER",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    letterSpacing = 1.sp
                )
                OutlinedTextField(
                    value = newName,
                    onValueChange = { newName = it },
                    placeholder = { Text("Player name") },
                    singleLine = true,
                    shape = RoundedCornerShape(10.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = MaterialTheme.colorScheme.primary,
                        unfocusedBorderColor = MaterialTheme.colorScheme.outline
                    ),
                    modifier = Modifier.fillMaxWidth()
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val trimmed = newName.trim()
                    if (trimmed.isNotEmpty()) onCreateNew(trimmed)
                },
                enabled = newName.trim().isNotEmpty(),
                colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
            ) {
                Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                Spacer(modifier = Modifier.width(4.dp))
                Text("Create & Add")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    )
}

@Composable
private fun PlayerCountControl(count: Int, onDecrement: () -> Unit, onIncrement: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(0.dp)
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .background(MaterialTheme.colorScheme.outline, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            TextButton(onClick = onDecrement, modifier = Modifier.fillMaxSize()) {
                Text("−", color = MaterialTheme.colorScheme.onSurface, fontSize = 18.sp, fontWeight = FontWeight.Light)
            }
        }
        Text(
            "$count",
            modifier = Modifier.width(40.dp),
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface
        )
        Box(
            modifier = Modifier
                .size(36.dp)
                .background(MaterialTheme.colorScheme.outline, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            TextButton(onClick = onIncrement, modifier = Modifier.fillMaxSize()) {
                Text("+", color = MaterialTheme.colorScheme.onSurface, fontSize = 18.sp, fontWeight = FontWeight.Light)
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ScoreDropdown(selected: StartScoreOption, onSelect: (StartScoreOption) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
        OutlinedTextField(
            value = "${selected.score}",
            onValueChange = {},
            readOnly = true,
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
            colors = OutlinedTextFieldDefaults.colors(
                unfocusedBorderColor = MaterialTheme.colorScheme.outline,
                focusedBorderColor = MaterialTheme.colorScheme.primary,
                unfocusedContainerColor = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f),
                focusedContainerColor = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f)
            ),
            shape = RoundedCornerShape(10.dp),
            textStyle = MaterialTheme.typography.bodyMedium,
            modifier = Modifier
                .fillMaxWidth()
                .menuAnchor(MenuAnchorType.PrimaryNotEditable)
                .height(52.dp)
        )
        ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            StartScoreOption.entries.forEach { option ->
                DropdownMenuItem(
                    text = { Text("${option.score}") },
                    onClick = { onSelect(option); expanded = false }
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FinishModeDropdown(selected: FinishRule, onSelect: (FinishRule) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
        OutlinedTextField(
            value = selected.label,
            onValueChange = {},
            readOnly = true,
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
            colors = OutlinedTextFieldDefaults.colors(
                unfocusedBorderColor = MaterialTheme.colorScheme.outline,
                focusedBorderColor = MaterialTheme.colorScheme.primary,
                unfocusedContainerColor = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f),
                focusedContainerColor = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f)
            ),
            shape = RoundedCornerShape(10.dp),
            textStyle = MaterialTheme.typography.bodyMedium,
            modifier = Modifier
                .fillMaxWidth()
                .menuAnchor(MenuAnchorType.PrimaryNotEditable)
                .height(52.dp)
        )
        ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            FinishRule.entries.forEach { rule ->
                DropdownMenuItem(
                    text = { Text(rule.label) },
                    onClick = { onSelect(rule); expanded = false }
                )
            }
        }
    }
}

@Composable
private fun InModeToggle(inRule: InRule, onToggle: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp)
            .background(
                MaterialTheme.colorScheme.outline.copy(alpha = 0.2f),
                RoundedCornerShape(10.dp)
            )
            .border(1.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(10.dp))
            .padding(horizontal = 12.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                "Double In",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface
            )
            Switch(
                checked = inRule == InRule.DOUBLE_IN,
                onCheckedChange = { onToggle() },
                colors = SwitchDefaults.colors(
                    checkedThumbColor = MaterialTheme.colorScheme.primary,
                    checkedTrackColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.3f),
                    uncheckedThumbColor = MaterialTheme.colorScheme.onSurfaceVariant,
                    uncheckedTrackColor = MaterialTheme.colorScheme.outline
                )
            )
        }
    }
}
