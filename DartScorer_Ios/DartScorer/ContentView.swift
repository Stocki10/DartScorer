import SwiftUI

struct ContentView: View {
    @AppStorage("appThemeMode") private var appThemeModeRaw = AppThemeMode.light.rawValue

    private var appThemeMode: AppThemeMode {
        AppThemeMode(rawValue: appThemeModeRaw) ?? .light
    }

    var body: some View {
        NavigationStack {
            DartsGameView()
                .navigationTitle("DartScorer")
                .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(appThemeMode.colorScheme)
    }
}
