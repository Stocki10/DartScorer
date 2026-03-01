package com.example.dartscorer_android.ui.theme

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
    MATERIAL_YOU("Material You"),
    TONAL_SPOT("Tonal Spot"),
    NEUTRAL("Neutral"),
    VIBRANT("Vibrant")
}

enum class AppThemeMode(val label: String) {
    SYSTEM("System"),
    LIGHT("Light"),
    DARK("Dark")
}

private val TonalSpotDarkColorScheme = darkColorScheme(
    primary = Purple80,
    secondary = PurpleGrey80,
    tertiary = Pink80
)

private val TonalSpotLightColorScheme = lightColorScheme(
    primary = Purple40,
    secondary = PurpleGrey40,
    tertiary = Pink40
)

private val NeutralDarkColorScheme = darkColorScheme(
    primary = Color(0xFFCAC4D0),
    secondary = Color(0xFFCCC2DC),
    tertiary = Color(0xFFEFB8C8),
    background = Color(0xFF141218),
    surface = Color(0xFF141218)
)

private val NeutralLightColorScheme = lightColorScheme(
    primary = Color(0xFF625B71),
    secondary = Color(0xFF625B71),
    tertiary = Color(0xFF7D5260),
    background = Color(0xFFFFFBFE),
    surface = Color(0xFFFFFBFE)
)

private val VibrantDarkColorScheme = darkColorScheme(
    primary = Color(0xFFFFB4A8),
    secondary = Color(0xFFE7BDB6),
    tertiary = Color(0xFFD0C58A),
    background = Color(0xFF201A19),
    surface = Color(0xFF201A19)
)

private val VibrantLightColorScheme = lightColorScheme(
    primary = Color(0xFFBA1A1A),
    secondary = Color(0xFF775651),
    tertiary = Color(0xFF6F5D2F),
    background = Color(0xFFFFF8F6),
    surface = Color(0xFFFFF8F6)
)

@Composable
fun DartScorer_AndroidTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    colorTheme: AppColorTheme = AppColorTheme.PURPLE,
    // Dynamic color is available on Android 12+
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit
) {
    val context = LocalContext.current
    val supportsDynamic = dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
    val colorScheme = when (colorTheme) {
        AppColorTheme.MATERIAL_YOU ->
            if (supportsDynamic) {
                if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
            } else {
                if (darkTheme) TonalSpotDarkColorScheme else TonalSpotLightColorScheme
            }

        AppColorTheme.TONAL_SPOT ->
            if (darkTheme) TonalSpotDarkColorScheme else TonalSpotLightColorScheme

        AppColorTheme.NEUTRAL ->
            if (darkTheme) NeutralDarkColorScheme else NeutralLightColorScheme

        AppColorTheme.VIBRANT ->
            if (darkTheme) VibrantDarkColorScheme else VibrantLightColorScheme
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
