package com.example.dartscorer_android.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

enum class AppColorTheme(val label: String) {
    PURPLE("Electric Violet"),
    BLUE("Neon Blue"),
    GREEN("Neon Green"),
    ORANGE("Solar Orange")
}

enum class AppThemeMode(val label: String) {
    SYSTEM("System"),
    LIGHT("Light"),
    DARK("Dark")
}

// Electric Violet (Kinetic Pulse default)
private val PurpleDarkColorScheme = darkColorScheme(
    primary = Color(0xFF9B6DFF),
    onPrimary = Color(0xFFFFFFFF),
    primaryContainer = Color(0xFF3B2F7A),
    onPrimaryContainer = Color(0xFFDDD0FF),
    secondary = Color(0xFF00D4AA),
    onSecondary = Color(0xFF000000),
    secondaryContainer = Color(0xFF00453A),
    onSecondaryContainer = Color(0xFFB0FFF0),
    tertiary = Color(0xFFFF6B35),
    onTertiary = Color(0xFFFFFFFF),
    background = Color(0xFF16151E),
    onBackground = Color(0xFFFFFFFF),
    surface = Color(0xFF1E1D28),
    onSurface = Color(0xFFFFFFFF),
    surfaceVariant = Color(0xFF252238),
    onSurfaceVariant = Color(0xFFA09BB8),
    outline = Color(0xFF3A3554),
    outlineVariant = Color(0xFF302D45),
)

private val PurpleLightColorScheme = lightColorScheme(
    primary = Color(0xFF6B3FD4),
    onPrimary = Color(0xFFFFFFFF),
    primaryContainer = Color(0xFFECDFFF),
    onPrimaryContainer = Color(0xFF2D0080),
    secondary = Color(0xFF008C73),
    onSecondary = Color(0xFFFFFFFF),
    background = Color(0xFFF5F2FF),
    onBackground = Color(0xFF1A1630),
    surface = Color(0xFFFFFFFF),
    onSurface = Color(0xFF1A1630),
    surfaceVariant = Color(0xFFEDE8F5),
    onSurfaceVariant = Color(0xFF49445A),
)

// Neon Blue
private val BlueDarkColorScheme = darkColorScheme(
    primary = Color(0xFF4FC3FF),
    onPrimary = Color(0xFF000000),
    primaryContainer = Color(0xFF004A6B),
    secondary = Color(0xFF00D4AA),
    background = Color(0xFF131820),
    onBackground = Color(0xFFFFFFFF),
    surface = Color(0xFF1A2030),
    onSurface = Color(0xFFFFFFFF),
    surfaceVariant = Color(0xFF222A3A),
    onSurfaceVariant = Color(0xFFA0B0C8),
    outline = Color(0xFF2A3545),
)

private val BlueLightColorScheme = lightColorScheme(
    primary = Color(0xFF1E5AA8),
    secondary = Color(0xFF008C73),
    background = Color(0xFFF2F6FF),
    onBackground = Color(0xFF101830),
    surface = Color(0xFFFFFFFF),
    onSurface = Color(0xFF101830),
)

// Neon Green
private val GreenDarkColorScheme = darkColorScheme(
    primary = Color(0xFF00E676),
    onPrimary = Color(0xFF000000),
    primaryContainer = Color(0xFF004D26),
    secondary = Color(0xFF4FC3FF),
    background = Color(0xFF131A15),
    onBackground = Color(0xFFFFFFFF),
    surface = Color(0xFF1A2218),
    onSurface = Color(0xFFFFFFFF),
    surfaceVariant = Color(0xFF222C20),
    onSurfaceVariant = Color(0xFFA0B8A0),
    outline = Color(0xFF2A3A28),
)

private val GreenLightColorScheme = lightColorScheme(
    primary = Color(0xFF2D6A3A),
    secondary = Color(0xFF1E5AA8),
    background = Color(0xFFF2FFF5),
    surface = Color(0xFFFFFFFF),
)

// Solar Orange
private val OrangeDarkColorScheme = darkColorScheme(
    primary = Color(0xFFFF6B35),
    onPrimary = Color(0xFFFFFFFF),
    primaryContainer = Color(0xFF6B2800),
    secondary = Color(0xFFFFD54F),
    background = Color(0xFF1C1510),
    onBackground = Color(0xFFFFFFFF),
    surface = Color(0xFF251C15),
    onSurface = Color(0xFFFFFFFF),
    surfaceVariant = Color(0xFF322418),
    onSurfaceVariant = Color(0xFFB8A898),
    outline = Color(0xFF453020),
)

private val OrangeLightColorScheme = lightColorScheme(
    primary = Color(0xFFA24D12),
    secondary = Color(0xFF8A6100),
    background = Color(0xFFFFF8F4),
    surface = Color(0xFFFFFFFF),
)

@Composable
fun DartScorer_AndroidTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    colorTheme: AppColorTheme = AppColorTheme.PURPLE,
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit
) {
    val colorScheme = when (colorTheme) {
        AppColorTheme.PURPLE -> if (darkTheme) PurpleDarkColorScheme else PurpleLightColorScheme
        AppColorTheme.BLUE -> if (darkTheme) BlueDarkColorScheme else BlueLightColorScheme
        AppColorTheme.GREEN -> if (darkTheme) GreenDarkColorScheme else GreenLightColorScheme
        AppColorTheme.ORANGE -> if (darkTheme) OrangeDarkColorScheme else OrangeLightColorScheme
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
