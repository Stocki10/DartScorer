package com.example.dartscorer_android

import android.content.Context.MODE_PRIVATE
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.getValue
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.example.dartscorer_android.ui.DartsGameScreen
import com.example.dartscorer_android.ui.theme.AppColorTheme
import com.example.dartscorer_android.ui.theme.AppThemeMode
import com.example.dartscorer_android.ui.theme.DartScorer_AndroidTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val prefs = remember { getSharedPreferences(APP_PREFS, MODE_PRIVATE) }
            var appThemeMode by remember {
                mutableStateOf(
                    prefs.getString(KEY_THEME_MODE, AppThemeMode.SYSTEM.name)
                        ?.let { runCatching { AppThemeMode.valueOf(it) }.getOrDefault(AppThemeMode.SYSTEM) }
                        ?: AppThemeMode.SYSTEM
                )
            }
            var appColorTheme by remember {
                mutableStateOf(
                    prefs.getString(KEY_COLOR_THEME, AppColorTheme.MATERIAL_YOU.name)
                        ?.let { runCatching { AppColorTheme.valueOf(it) }.getOrDefault(AppColorTheme.MATERIAL_YOU) }
                        ?: AppColorTheme.MATERIAL_YOU
                )
            }
            val systemDark = isSystemInDarkTheme()
            val darkTheme = when (appThemeMode) {
                AppThemeMode.SYSTEM -> systemDark
                AppThemeMode.LIGHT -> false
                AppThemeMode.DARK -> true
            }

            DartScorer_AndroidTheme(
                darkTheme = darkTheme,
                colorTheme = appColorTheme,
                dynamicColor = false
            ) {
                Surface(modifier = Modifier.fillMaxSize()) {
                    DartsGameScreen(
                        selectedThemeMode = appThemeMode,
                        onThemeModeChange = { mode ->
                            appThemeMode = mode
                            prefs.edit().putString(KEY_THEME_MODE, mode.name).apply()
                        },
                        selectedColorTheme = appColorTheme,
                        onColorThemeChange = { theme ->
                            appColorTheme = theme
                            prefs.edit().putString(KEY_COLOR_THEME, theme.name).apply()
                        },
                    )
                }
            }
        }
    }

    companion object {
        private const val APP_PREFS = "dartscorer_android_prefs"
        private const val KEY_THEME_MODE = "theme_mode"
        private const val KEY_COLOR_THEME = "color_theme"
    }
}
