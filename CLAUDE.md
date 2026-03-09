# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

DartScorer is a darts scoring app with two parallel implementations:
- **iOS**: SwiftUI app in `DartScorer_Ios/`
- **Android**: Jetpack Compose app in `DartScorer_Android/`

Both platforms implement the same game logic and feature set independently (no shared code).

## Build & Run

### iOS
Open `DartScorer_Ios/DartScorer.xcodeproj` in Xcode, select a simulator, and press Run.

Run all tests:
```
xcodebuild test -project DartScorer_Ios/DartScorer.xcodeproj -scheme DartScorer -destination 'platform=iOS Simulator,name=iPhone 16'
```

Run a single test by name:
```
xcodebuild test -project DartScorer_Ios/DartScorer.xcodeproj -scheme DartScorer -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:DartScorerTests/DartScorerTests/scoreSubtractionOnValidThrow
```

### Android
From `DartScorer_Android/`:
```
./gradlew assembleDebug        # build
./gradlew test                 # run unit tests
./gradlew connectedAndroidTest # run instrumented tests (requires device/emulator)
```

Run a single test class:
```
./gradlew test --tests "com.example.dartscorer_android.DartsGameTest"
```

## Architecture

### Game Logic (`DartsGame`)
The central class/observable on both platforms. Manages all game state:
- Player list, active player index, current turn
- Scores, finish/in rules, set mode
- Per-player statistics: `dartsThrownByPlayerID`, `pointsScoredByPlayerID`, `legsWonByPlayerID`
- Undo stack via `GameSnapshot` — every throw records a full snapshot before mutation

Key rules supported: Double Out / Single Out finish; Default / Double In start; Set mode (configurable legs to win); 501 / 301 starting scores; 2–5 players.

**Bust logic**: Score goes negative, lands on 1, or reaches 0 without a double (in Double Out). On bust, the turn's score is rolled back to `currentTurn.startingScore` and the turn ends.

### Checkout Engine (`BestFinishEngine` / `DartsBestFinish`)
Pure, stateless engine that computes the optimal finish route for a given score and darts remaining. iOS version uses a pro lookup table for well-known routes, bogey handling, and a heuristic search fallback. Android version delegates to `DartsBestFinishEngine` with a similar approach. The result is displayed live above the number pad.

### iOS-specific: `CheckoutAssistantStore`
Standalone `ObservableObject` (Combine-based) for a checkout assistant UI — separate from the main game flow. Tracks score, darts remaining, bust state, and calls `BestFinishEngine` after each throw.

### UI Layer
- **iOS**: `ContentView` applies theme/accent color and hosts `DartsGameView`. The game view contains the scoreboard, live finish suggestion, multiplier picker (Single/Double/Triple), and a 1–20 number pad with Bull and "No Score" buttons. Settings (theme, accent color) and new-game setup are presented as sheets/full-screen covers. Game settings are persisted via `@AppStorage`.
- **Android**: `MainActivity` -> `DartsGameScreen` (Jetpack Compose). Equivalent layout.

### iOS File Map
| File | Role |
|------|------|
| `DartsGame.swift` | Core game state (`ObservableObject`) |
| `DartThrow.swift` | `DartSegment`, `DartMultiplier`, `DartThrow` value types |
| `Player.swift` | `Player` model |
| `Turn.swift` | `Turn` model (darts in current turn) |
| `Models.swift` | `DartTarget`, `FinishRoute` (used by checkout engine) |
| `BestFinishEngine.swift` | Checkout suggestion engine |
| `CheckoutAssistantStore.swift` | Standalone reactive checkout store |
| `DartsGameView.swift` | Main game UI + `NewGameSetupView` |
| `ContentView.swift` | Root view (theme/accent applied here) |
| `SettingsPopupView.swift` | Theme and accent color picker |
| `AppThemeMode.swift` | Light/Dark/System enum |
| `AppAccentColor.swift` | Accent color helpers and defaults |

### Android File Map
| File | Role |
|------|------|
| `game/DartsGame.kt` | Core game state |
| `game/DartModels.kt` | All data models and enums |
| `game/DartsBestFinish.kt` | Checkout suggestion engine |
| `ui/DartsGameScreen.kt` | Main Compose UI |
| `MainActivity.kt` | Entry point |

## Testing

- **iOS unit tests**: `DartScorer_Ios/DartScorerTests/` — uses Swift Testing framework (`@Test`, `#expect`). `DartScorerTests.swift` covers `DartsGame`; `BestFinishEngineTests.swift` covers the checkout engine.
- **Android unit tests**: `DartScorer_Android/app/src/test/.../DartsGameTest.kt` — JUnit 4.
- There are also iOS UI tests in `DartScorerUITests/` (currently minimal).


