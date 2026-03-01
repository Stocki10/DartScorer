package com.example.dartscorer_android.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

enum class AppColorTheme(val label: String) {
    PURPLE("Purple"),
    BLUE("Blue"),
    GREEN("Green"),
    ORANGE("Orange")
}

enum class AppThemeMode(val label: String) {
    SYSTEM("System"),
    LIGHT("Light"),
    DARK("Dark")
}

private val PurpleDarkColorScheme = darkColorScheme(
    primary = Purple80,
    secondary = PurpleGrey80,
    tertiary = Pink80,
    background = Color(0xFF141218),
    surface = Color(0xFF141218)
)

private val PurpleLightColorScheme = lightColorScheme(
    primary = Purple40,
    secondary = PurpleGrey40,
    tertiary = Pink40,
    background = Color(0xFFFFFBFE),
    surface = Color(0xFFFFFBFE)
)

private val BlueDarkColorScheme = darkColorScheme(
    primary = Color(0xFF9FC9FF),
    secondary = Color(0xFFB8C3DC),
    tertiary = Color(0xFFA9C8E8),
    background = Color(0xFF141218),
    surface = Color(0xFF141218)
)

private val BlueLightColorScheme = lightColorScheme(
    primary = Color(0xFF1E5AA8),
    secondary = Color(0xFF4B5F83),
    tertiary = Color(0xFF2E6986),
    background = Color(0xFFFFFBFE),
    surface = Color(0xFFFFFBFE)
)

private val GreenDarkColorScheme = darkColorScheme(
    primary = Color(0xFF9ED7AE),
    secondary = Color(0xFFB8CCB0),
    tertiary = Color(0xFFA5D4C8),
    background = Color(0xFF111411),
    surface = Color(0xFF111411)
)

private val GreenLightColorScheme = lightColorScheme(
    primary = Color(0xFF2D6A3A),
    secondary = Color(0xFF4F6350),
    tertiary = Color(0xFF3B6C62),
    background = Color(0xFFF7FCF5),
    surface = Color(0xFFF7FCF5)
)

private val OrangeDarkColorScheme = darkColorScheme(
    primary = Color(0xFFFFC08A),
    secondary = Color(0xFFE5C2A9),
    tertiary = Color(0xFFFFD58A),
    background = Color(0xFF17120F),
    surface = Color(0xFF17120F)
)

private val OrangeLightColorScheme = lightColorScheme(
    primary = Color(0xFFA24D12),
    secondary = Color(0xFF7A5A43),
    tertiary = Color(0xFF8A6100),
    background = Color(0xFFFFF8F4),
    surface = Color(0xFFFFF8F4)
)

@Composable
fun DartScorer_AndroidTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    colorTheme: AppColorTheme = AppColorTheme.PURPLE,
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit
) {
    val colorScheme = when (colorTheme) {
        AppColorTheme.PURPLE ->
            if (darkTheme) PurpleDarkColorScheme else PurpleLightColorScheme
        AppColorTheme.BLUE ->
            if (darkTheme) BlueDarkColorScheme else BlueLightColorScheme
        AppColorTheme.GREEN ->
            if (darkTheme) GreenDarkColorScheme else GreenLightColorScheme
        AppColorTheme.ORANGE ->
            if (darkTheme) OrangeDarkColorScheme else OrangeLightColorScheme
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
