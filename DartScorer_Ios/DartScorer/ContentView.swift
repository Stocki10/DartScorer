import SwiftUI

struct ContentView: View {
    @AppStorage("appThemeMode") private var appThemeModeRaw = AppThemeMode.light.rawValue
    @AppStorage("appAccentRed") private var appAccentRed = AppAccentColor.defaultRed
    @AppStorage("appAccentGreen") private var appAccentGreen = AppAccentColor.defaultGreen
    @AppStorage("appAccentBlue") private var appAccentBlue = AppAccentColor.defaultBlue

    private var appThemeMode: AppThemeMode {
        AppThemeMode(rawValue: appThemeModeRaw) ?? .light
    }

    private var appAccentColor: Color {
        AppAccentColor.makeColor(
            red: appAccentRed,
            green: appAccentGreen,
            blue: appAccentBlue
        )
    }

    var body: some View {
        NavigationStack {
            DartsGameView()
                .navigationTitle("DartScorer")
                .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(appThemeMode.colorScheme)
        .tint(appAccentColor)
    }
}
