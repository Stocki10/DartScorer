package com.example.dartscorer_android

import android.content.Context.MODE_PRIVATE
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.example.dartscorer_android.ui.DartsGameScreen
import com.example.dartscorer_android.ui.theme.AppColorTheme
import com.example.dartscorer_android.ui.theme.DartScorer_AndroidTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val prefs = remember { getSharedPreferences(APP_PREFS, MODE_PRIVATE) }
            var isDarkTheme by remember {
                mutableStateOf(prefs.getBoolean(KEY_DARK_THEME, false))
            }
            var appColorTheme by remember {
                mutableStateOf(
                    prefs.getString(KEY_COLOR_THEME, AppColorTheme.PURPLE.name)
                        ?.let { runCatching { AppColorTheme.valueOf(it) }.getOrDefault(AppColorTheme.PURPLE) }
                        ?: AppColorTheme.PURPLE
                )
            }

            DartScorer_AndroidTheme(
                darkTheme = isDarkTheme,
                colorTheme = appColorTheme,
                dynamicColor = false
            ) {
                Surface(modifier = Modifier.fillMaxSize()) {
                    DartsGameScreen(
                        isDarkTheme = isDarkTheme,
                        onThemeChange = { dark ->
                            isDarkTheme = dark
                            prefs.edit().putBoolean(KEY_DARK_THEME, dark).apply()
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
        private const val KEY_DARK_THEME = "theme_dark"
        private const val KEY_COLOR_THEME = "color_theme"
    }
}
