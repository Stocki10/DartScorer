# DartScorer iOS

`DartScorer` is a SwiftUI darts scoring app for iPhone with support for classic x01 play, Cricket, practice sessions, local multiplayer, player profiles, and match history.

## What The App Does

- Play `301`, `501`, and other x01 formats with configurable `double in`, `double out`, and set mode rules
- Play `Cricket` with mark tracking and scoring
- Run `Practice` sessions for simple scoring drills
- Track checkout suggestions, leg averages, busts, and winner state live during a match
- Save completed matches to history with per-leg detail views
- Store reusable player profiles with persistent stats
- Connect multiple nearby iPhones for local multiplayer using `MultipeerConnectivity`
- Switch between throw-by-throw input and quick-score input

## iOS Features

### Game Modes

- `X01`
  - configurable starting score
  - `default in` / `double in`
  - `single out` / `double out`
  - optional set mode with configurable legs to win
- `Cricket`
  - marks for `20` through `15` and `Bull`
  - scoring after closing numbers against open opponents
- `Practice`
  - simple cumulative scoring without checkout logic

### Match Flow

- `1–5` players depending on mode
- full undo support
- restart leg
- quick-score shortcuts for common x01 totals
- haptic feedback for normal throws, warnings, and wins

### Profiles And Stats

Each player profile persists across launches and updates automatically after recorded matches.

Tracked stats include:

- games played
- wins
- win rate
- average
- first 9 average
- best turn
- best checkout
- checkout percentage
- 180 count
- 140+ count
- highest score

### Match History

- completed matches are saved automatically
- match detail screens show player summaries and leg results
- leg detail screens include finishing info and per-player breakdowns

### Local Multiplayer

- host / join flow over nearby Apple devices
- QR-based session joining
- player assignment per device
- synchronized game state, undo, leg restarts, and profile stat updates

## Project Structure

### Main iOS App

- `DartScorer_Ios/DartScorer.xcodeproj`
- `DartScorer_Ios/DartScorer/`

### Important Files

- [DartsGame.swift](/Users/leonstockmann/git/DartScorer/DartScorer_Ios/DartScorer/DartsGame.swift)
  - core game rules, scoring, snapshots, history record building
- [DartsGameView.swift](/Users/leonstockmann/git/DartScorer/DartScorer_Ios/DartScorer/DartsGameView.swift)
  - main game screen orchestration
- [GameScreenComponents.swift](/Users/leonstockmann/git/DartScorer/DartScorer_Ios/DartScorer/GameScreenComponents.swift)
  - scoreboard, cricket board, input controls
- [NewGameSetupView.swift](/Users/leonstockmann/git/DartScorer/DartScorer_Ios/DartScorer/NewGameSetupView.swift)
  - new game setup flow
- [GameHistory.swift](/Users/leonstockmann/git/DartScorer/DartScorer_Ios/DartScorer/GameHistory.swift)
  - persisted match and leg history models
- [GameHistoryView.swift](/Users/leonstockmann/git/DartScorer/DartScorer_Ios/DartScorer/GameHistoryView.swift)
  - history list and detail screens
- [PlayerProfile.swift](/Users/leonstockmann/git/DartScorer/DartScorer_Ios/DartScorer/PlayerProfile.swift)
  - persistent player profiles and stat aggregation
- [PlayerProfileView.swift](/Users/leonstockmann/git/DartScorer/DartScorer_Ios/DartScorer/PlayerProfileView.swift)
  - profile management UI
- [MultipeerSessionManager.swift](/Users/leonstockmann/git/DartScorer/DartScorer_Ios/DartScorer/MultipeerSessionManager.swift)
  - local multiplayer session handling
- [NetworkGameState.swift](/Users/leonstockmann/git/DartScorer/DartScorer_Ios/DartScorer/NetworkGameState.swift)
  - multiplayer wire models

## Requirements

- macOS with Xcode installed
- Xcode `15+`
- iOS `17+`

## Running The iOS App

Open the project in Xcode:

```bash
open DartScorer_Ios/DartScorer.xcodeproj
```

Or build from the terminal:

```bash
xcodebuild -project DartScorer_Ios/DartScorer.xcodeproj \
  -scheme DartScorer \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/DartScorerDerivedData build
```

## Running Tests

```bash
xcodebuild test -project DartScorer_Ios/DartScorer.xcodeproj \
  -scheme DartScorer \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Run a single test:

```bash
xcodebuild test -project DartScorer_Ios/DartScorer.xcodeproj \
  -scheme DartScorer \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:DartScorerTests/DartScorerTests/scoreSubtractionOnValidThrow
```

## Notes

- local multiplayer requires physical Apple devices; it is not meaningful in the simulator
- history and profile data are stored locally on-device
- the iOS app and Android app live in the same repository, but this README is intentionally focused on the iOS app
