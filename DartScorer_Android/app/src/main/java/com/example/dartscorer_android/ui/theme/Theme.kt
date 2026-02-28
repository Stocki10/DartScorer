package com.example.dartscorer_android.ui.theme

import android.app.Activity
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

enum class AppColorTheme(val label: String) {
    PURPLE("Purple"),
    BLUE("Blue"),
    GREEN("Green"),
    ORANGE("Orange")
}

private val PurpleDarkColorScheme = darkColorScheme(
    primary = Purple80,
    secondary = PurpleGrey80,
    tertiary = Pink80
)

private val PurpleLightColorScheme = lightColorScheme(
    primary = Purple40,
    secondary = PurpleGrey40,
    tertiary = Pink40
)

private val BlueDarkColorScheme = darkColorScheme(
    primary = Color(0xFF9CCAFF),
    secondary = Color(0xFFB5C4FF),
    tertiary = Color(0xFF9ECBE1)
)

private val BlueLightColorScheme = lightColorScheme(
    primary = Color(0xFF2E5FA8),
    secondary = Color(0xFF4E5D92),
    tertiary = Color(0xFF2D6F8A)
)

private val GreenDarkColorScheme = darkColorScheme(
    primary = Color(0xFF9FD49F),
    secondary = Color(0xFFAFCF9A),
    tertiary = Color(0xFF94D1B2)
)

private val GreenLightColorScheme = lightColorScheme(
    primary = Color(0xFF2F7D4F),
    secondary = Color(0xFF5A7159),
    tertiary = Color(0xFF1F8A70)
)

private val OrangeDarkColorScheme = darkColorScheme(
    primary = Color(0xFFFFC38C),
    secondary = Color(0xFFFFB59F),
    tertiary = Color(0xFFFFCC80)
)

private val OrangeLightColorScheme = lightColorScheme(
    primary = Color(0xFFB45A2A),
    secondary = Color(0xFF9A5F4A),
    tertiary = Color(0xFF9A6C00)
)

@Composable
fun DartScorer_AndroidTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    colorTheme: AppColorTheme = AppColorTheme.PURPLE,
    // Dynamic color is available on Android 12+
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }

        darkTheme -> when (colorTheme) {
            AppColorTheme.PURPLE -> PurpleDarkColorScheme
            AppColorTheme.BLUE -> BlueDarkColorScheme
            AppColorTheme.GREEN -> GreenDarkColorScheme
            AppColorTheme.ORANGE -> OrangeDarkColorScheme
        }

        else -> when (colorTheme) {
            AppColorTheme.PURPLE -> PurpleLightColorScheme
            AppColorTheme.BLUE -> BlueLightColorScheme
            AppColorTheme.GREEN -> GreenLightColorScheme
            AppColorTheme.ORANGE -> OrangeLightColorScheme
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
