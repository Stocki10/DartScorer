package com.example.dartscorer_android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.example.dartscorer_android.ui.DartsGameScreen
import com.example.dartscorer_android.ui.theme.DartScorer_AndroidTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            DartScorer_AndroidTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    DartsGameScreen()
                }
            }
        }
    }
}
