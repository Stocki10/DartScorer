# DartScorer

A clean, feature-complete darts scoring app available on **iOS** and **Android**. Supports 501 and 301, flexible in/out rules, set mode, live checkout suggestions, full undo, local multiplayer, player profiles, and game history.

---

## Features

### Core Game
- **2–5 players** with drag-to-reorder throw sequence
- **501 / 301** starting scores
- **Double Out / Single Out** finish rules
- **Double In / Default** start rules
- **Set mode** — configurable legs to win
- **Live checkout suggestions** shown above the number pad
- **Full undo** — step back through every throw
- **Per-leg stats** — live average and last-turn scores per player
- **Haptic feedback** on throws, busts, and wins

### Local Multiplayer *(iOS)*
Play on multiple iPhones over a shared local network — no internet required.
- Host generates a **QR code** that joiners scan to connect instantly
- Up to **4 devices** (host + 3 joiners) via Apple MultipeerConnectivity
- Host **assigns each player to a device** before starting; every device then scores for its own player
- If all guests disconnect, the host is notified and the game ends gracefully

### Player Profiles *(iOS)*
- Create reusable profiles with a **custom name and color**
- Stats accumulate automatically across games:
  - Games played & won, win rate
  - 3-dart average, highest turn score
  - Highest checkout
- Profiles are linked to game results so history always shows the right player

### Game History *(iOS)*
- Every completed game is saved automatically
- Browse past games with per-player results: average, highest turn, checkout percentage
- History feeds back into player profile stats

### Appearance
- **Theme support** — Light / Dark / System
- **Custom accent color** via color picker

---

## Platforms

| Platform | Stack | Location |
|----------|-------|----------|
| iOS 17+ | SwiftUI | `DartScorer_Ios/` |
| Android | Jetpack Compose | `DartScorer_Android/` |

Both apps implement the same core game logic independently — there is no shared code between platforms. Multiplayer, Player Profiles, and Game History are currently iOS-only features.

---

## Getting Started

### iOS

Open `DartScorer_Ios/DartScorer.xcodeproj` in Xcode, select a simulator or device, and press **Run**.

Requirements: Xcode 15+, iOS 17+

> **Local Multiplayer** requires physical devices on the same Wi-Fi or Bluetooth range. It does not work in the Simulator.

### Android

```bash
cd DartScorer_Android
./gradlew assembleDebug
```

Requirements: Android Studio, Android SDK 34+

---

## Running Tests

### iOS

```bash
# All tests
xcodebuild test -project DartScorer_Ios/DartScorer.xcodeproj -scheme DartScorer \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Single test
xcodebuild test -project DartScorer_Ios/DartScorer.xcodeproj -scheme DartScorer \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:DartScorerTests/DartScorerTests/scoreSubtractionOnValidThrow
```

### Android

```bash
cd DartScorer_Android
./gradlew test                                              # unit tests
./gradlew connectedAndroidTest                             # instrumented (requires device)
./gradlew test --tests "com.example.dartscorer_android.DartsGameTest"  # single class
```
