# DartScorer

A clean, feature-complete darts scoring app available on **iOS** and **Android**. Supports 501 and 301, flexible in/out rules, set mode, live checkout suggestions, and full undo.

---

## Features

- **2–5 players** with drag-to-reorder throw sequence
- **501 / 301** starting scores
- **Double Out / Single Out** finish rules
- **Double In / Default** start rules
- **Set mode** — configurable legs to win
- **Live checkout suggestions** shown above the number pad
- **Full undo** — step back through every throw
- **Per-leg stats** — live average and last-turn scores per player
- **Haptic feedback** on throws, busts, and wins
- **Theme support** — Light / Dark / System
- **Custom accent color** via color picker

---

## Platforms

| Platform | Stack | Location |
|----------|-------|----------|
| iOS 17+ | SwiftUI | `DartScorer_Ios/` |
| Android | Jetpack Compose | `DartScorer_Android/` |

Both apps implement the same game logic and feature set independently — there is no shared code between platforms.

---

## Getting Started

### iOS

Open `DartScorer_Ios/DartScorer.xcodeproj` in Xcode, select a simulator or device, and press **Run**.

Requirements: Xcode 15+, iOS 17+

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
  -destination 'platform=iOS Simulator,name=iPhone 17'

# Single test
xcodebuild test -project DartScorer_Ios/DartScorer.xcodeproj -scheme DartScorer \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DartScorerTests/DartScorerTests/scoreSubtractionOnValidThrow
```

### Android

```bash
cd DartScorer_Android
./gradlew test                                              # unit tests
./gradlew connectedAndroidTest                             # instrumented (requires device)
./gradlew test --tests "com.example.dartscorer_android.DartsGameTest"  # single class
```
