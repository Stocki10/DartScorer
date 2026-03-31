import SwiftUI
import Combine

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var game = DartsGame(playerCount: 2)
    @StateObject private var profileStore = PlayerProfileStore()
    @StateObject private var tournamentStore = TournamentStore()
    @StateObject private var historyStore = GameHistoryStore()
    @StateObject private var session = MultipeerSessionManager()
    @State private var activeTournamentMatchContext: TournamentMatchLaunchContext?
    @State private var hasRestoredOngoingGame = false
    @AppStorage("appThemeMode") private var appThemeModeRaw = AppThemeMode.system.rawValue
    @AppStorage("appAccentRed") private var appAccentRed = AppAccentColor.defaultRed
    @AppStorage("appAccentGreen") private var appAccentGreen = AppAccentColor.defaultGreen
    @AppStorage("appAccentBlue") private var appAccentBlue = AppAccentColor.defaultBlue
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboardingLegacy = false
    @AppStorage("hasCreatedFirstProfile") private var hasCreatedFirstProfile = false
    @AppStorage("hasConfirmedInitialAppearance") private var hasConfirmedInitialAppearance = false
    @AppStorage("defaultProfileID") private var defaultProfileID = ""
    private let ongoingGameStore = OngoingGameStore()

    private var appThemeMode: AppThemeMode {
        AppThemeMode(rawValue: appThemeModeRaw) ?? .system
    }

    private var appAccentColor: Color {
        AppAccentColor.makeColor(
            red: appAccentRed,
            green: appAccentGreen,
            blue: appAccentBlue
        )
    }

    private var hasCompletedOnboarding: Bool {
        hasCreatedFirstProfile && hasConfirmedInitialAppearance
    }

    var body: some View {
        NavigationStack {
            DashboardView(
                game: game,
                session: session,
                tournamentStore: tournamentStore,
                historyStore: historyStore,
                profileStore: profileStore,
                activeTournamentMatchContext: $activeTournamentMatchContext
            )
        }
        .preferredColorScheme(appThemeMode.colorScheme)
        .tint(appAccentColor)
        .onAppear {
            migrateLegacyOnboardingIfNeeded()
            session.configure(game: game, profileStore: profileStore)
            restoreOngoingGameIfNeeded()
        }
        .onReceive(game.objectWillChange) { _ in
            DispatchQueue.main.async {
                persistOngoingGameIfNeeded()
            }
        }
        .onChange(of: activeTournamentMatchContext?.id) { _, _ in
            persistOngoingGameIfNeeded()
        }
        .onChange(of: session.role) { _, _ in
            persistOngoingGameIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            persistOngoingGameIfNeeded()
        }
    }

    private func migrateLegacyOnboardingIfNeeded() {
        if hasCompletedOnboardingLegacy {
            if !hasCreatedFirstProfile {
                hasCreatedFirstProfile = true
            }
            if !hasConfirmedInitialAppearance {
                hasConfirmedInitialAppearance = true
            }
        }

        if !profileStore.profiles.isEmpty && !hasCreatedFirstProfile {
            hasCreatedFirstProfile = true
        }
    }

    private func restoreOngoingGameIfNeeded() {
        guard !hasRestoredOngoingGame else { return }
        hasRestoredOngoingGame = true

        guard let persisted = ongoingGameStore.load() else { return }

        if let context = persisted.tournamentContext,
           let refreshedContext = tournamentStore.launchContext(tournamentID: context.tournamentID, matchID: context.matchID) {
            activeTournamentMatchContext = refreshedContext
        } else {
            activeTournamentMatchContext = nil
        }

        game.applyPersistedSnapshot(persisted.snapshot)
    }

    private func persistOngoingGameIfNeeded() {
        if session.isActive {
            ongoingGameStore.clear()
            return
        }

        guard game.hasResumableProgress || activeTournamentMatchContext != nil else {
            ongoingGameStore.clear()
            return
        }

        ongoingGameStore.save(
            PersistedOngoingGameSession(
                snapshot: game.buildPersistedSnapshot(),
                tournamentContext: activeTournamentMatchContext,
                savedAt: Date()
            )
        )
    }
}
