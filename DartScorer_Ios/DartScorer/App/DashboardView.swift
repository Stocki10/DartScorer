import SwiftUI

private struct DashboardGamePresentation: Identifiable, Hashable {
    let id = UUID()
    let entryIntent: DartsGameLaunchIntent
    let tournamentLaunchContext: TournamentMatchLaunchContext?

    static func == (lhs: DashboardGamePresentation, rhs: DashboardGamePresentation) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct DashboardProfilePresentation: Identifiable, Hashable {
    let id: UUID
}

struct DashboardView: View {
    @ObservedObject var game: DartsGame
    @ObservedObject var session: MultipeerSessionManager
    @ObservedObject var tournamentStore: TournamentStore
    @ObservedObject var historyStore: GameHistoryStore
    @ObservedObject var profileStore: PlayerProfileStore
    @Binding var activeTournamentMatchContext: TournamentMatchLaunchContext?

    @AppStorage("appThemeMode") private var appThemeModeRaw = AppThemeMode.system.rawValue
    @AppStorage("defaultProfileID") private var defaultProfileID = ""
    @AppStorage("newGamePracticeMode") private var storedPracticeModeRaw = PracticeMode.scoringDrill.rawValue
    @AppStorage("appAccentRed") private var appAccentRed = AppAccentColor.defaultRed
    @AppStorage("appAccentGreen") private var appAccentGreen = AppAccentColor.defaultGreen
    @AppStorage("appAccentBlue") private var appAccentBlue = AppAccentColor.defaultBlue
    @AppStorage("hasCreatedFirstProfile") private var hasCreatedFirstProfile = false
    @AppStorage("hasConfirmedInitialAppearance") private var hasConfirmedInitialAppearance = false

    @State private var gamePresentation: DashboardGamePresentation?
    @State private var profilePresentation: DashboardProfilePresentation?
    @State private var deferredGamePresentation: DashboardGamePresentation?
    @State private var isShowingHistory = false
    @State private var isShowingProfiles = false
    @State private var isShowingTournaments = false
    @State private var isShowingSettings = false
    @State private var draftThemeMode: AppThemeMode = .system
    @State private var draftAccentColor: Color = AppAccentColor.makeColor(
        red: AppAccentColor.defaultRed,
        green: AppAccentColor.defaultGreen,
        blue: AppAccentColor.defaultBlue
    )
    @State private var expandedSetupStep: HomeSetupStep?
    @State private var onboardingProfileName = ""
    @State private var onboardingProfileColor = AppAccentColor.currentColor

    private var accentColor: Color {
        AppAccentColor.makeColor(
            red: appAccentRed,
            green: appAccentGreen,
            blue: appAccentBlue
        )
    }

    private var defaultProfile: PlayerProfile? {
        guard let id = UUID(uuidString: defaultProfileID) else { return nil }
        return profileStore.profiles.first(where: { $0.id == id })
    }

    private var featuredProfile: PlayerProfile? {
        defaultProfile ?? profileStore.profiles.first
    }

    private var recentTrend: ProfileTrendSnapshot? {
        guard let featuredProfile else { return nil }
        return ProfileTrends.makeSnapshot(
            for: featuredProfile.id,
            stats: featuredProfile.stats,
            records: historyStore.records,
            filter: GameRecordFilter(date: .last30Days)
        )
    }

    private var ongoingTournaments: [Tournament] {
        tournamentStore.tournaments.filter { $0.status != .completed }
    }

    private var profileSetupComplete: Bool {
        hasCreatedFirstProfile || !profileStore.profiles.isEmpty
    }

    private var appearanceSetupComplete: Bool {
        hasConfirmedInitialAppearance
    }

    private var hasCompletedOnboarding: Bool {
        profileSetupComplete && appearanceSetupComplete
    }

    private var completedSetupStepCount: Int {
        [profileSetupComplete, appearanceSetupComplete].filter { $0 }.count
    }

    private var resumableMatchAvailable: Bool {
        activeTournamentMatchContext != nil || session.isActive || game.hasResumableProgress
    }

    private var currentPracticeModeLabel: String {
        PracticeMode(rawValue: storedPracticeModeRaw)?.label ?? PracticeMode.scoringDrill.label
    }

    private var recentRecords: [GameRecord] {
        Array(historyStore.records.prefix(3))
    }

    private var matchesThisWeek: Int {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return historyStore.records.filter { $0.date >= weekStart }.count
    }

    private var ongoingTournament: Tournament? {
        ongoingTournaments.first
    }

    private var heroAccessoryItems: [DashboardHeroAccessoryItem] {
        var items: [DashboardHeroAccessoryItem] = []

        if session.isActive {
            items.append(
                DashboardHeroAccessoryItem(
                    title: L10n.string("Local Multiplayer"),
                    value: L10n.format("%@ players connected", "\(session.connectedPeers.count + 1)"),
                    systemImage: "person.2.fill",
                    tint: .green
                )
            )
        }

        if let ongoingTournament, activeTournamentMatchContext == nil {
            items.append(
                DashboardHeroAccessoryItem(
                    title: L10n.string("Tournament"),
                    value: ongoingTournament.name,
                    systemImage: "flag.checkered.2.crossed",
                    tint: .orange
                )
            )
        }

        return items
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !hasCompletedOnboarding {
                        onboardingSetupCard
                    }
                    heroCard
                    quickStartSection
                    motivationSection
                    featureGridSection
                    recentActivitySection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }

            if isShowingSettings {
                SettingsPopupView(
                    themeMode: $draftThemeMode,
                    accentColor: $draftAccentColor
                ) {
                    applySettings()
                } onClose: {
                    isShowingSettings = false
                }
                .transition(.opacity)
                .zIndex(20)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(L10n.string("Home"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingHistory) {
            GameHistoryView(store: historyStore)
        }
        .sheet(isPresented: $isShowingProfiles) {
            PlayerProfileView(store: profileStore, historyStore: historyStore)
        }
        .sheet(isPresented: $isShowingTournaments) {
            TournamentListView(
                store: tournamentStore,
                profileStore: profileStore,
                historyStore: historyStore,
                onPlayMatch: { context in
                    deferredGamePresentation = DashboardGamePresentation(
                        entryIntent: .resume,
                        tournamentLaunchContext: context
                    )
                    isShowingTournaments = false
                }
            )
        }
        .navigationDestination(item: $gamePresentation) { presentation in
            DartsGameView(
                game: game,
                session: session,
                tournamentStore: tournamentStore,
                historyStore: historyStore,
                profileStore: profileStore,
                activeTournamentMatchContext: $activeTournamentMatchContext,
                initialEntryIntent: presentation.entryIntent,
                initialTournamentMatchContext: presentation.tournamentLaunchContext
            )
            .navigationTitle(L10n.string("Just a Darts Scorer"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationDestination(item: $profilePresentation) { presentation in
            ProfileDetailView(
                store: profileStore,
                historyStore: historyStore,
                profileID: presentation.id
            )
        }
        .onAppear {
            if profileSetupComplete && !hasCreatedFirstProfile {
                hasCreatedFirstProfile = true
            }
        }
        .onChange(of: isShowingTournaments) { _, isShowing in
            guard !isShowing, let deferredGamePresentation else { return }
            gamePresentation = deferredGamePresentation
            self.deferredGamePresentation = nil
        }
        .onChange(of: profileStore.profiles.count) { _, count in
            guard count > 0 else { return }
            hasCreatedFirstProfile = true
            if defaultProfileID.isEmpty, let firstProfile = profileStore.profiles.first {
                defaultProfileID = firstProfile.id.uuidString
            }
        }
    }

    private var onboardingSetupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.string("Finish setup"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(L10n.string("Create your first profile and confirm your theme before you get started."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(L10n.format("%@ of 2 completed", "\(completedSetupStepCount)"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemBackground), in: Capsule())
            }

            VStack(spacing: 0) {
                setupStepRow(
                    step: .profile,
                    title: L10n.string("Create your first profile"),
                    subtitle: profileSetupComplete ? (featuredProfile?.name ?? L10n.string("Done")) : L10n.string("Name your first player and choose a color"),
                    isComplete: profileSetupComplete,
                    action: {
                        expandedSetupStep = expandedSetupStep == .profile ? nil : .profile
                    }
                )

                if expandedSetupStep == .profile && !profileSetupComplete {
                    Divider()
                        .padding(.leading, 56)

                    onboardingProfileForm
                }

                Divider()
                    .padding(.leading, 56)

                setupStepRow(
                    step: .appearance,
                    title: L10n.string("Choose your theme and color"),
                    subtitle: appearanceSetupComplete ? L10n.string("Done") : L10n.string("Confirm your app appearance once"),
                    isComplete: appearanceSetupComplete,
                    action: {
                        expandedSetupStep = expandedSetupStep == .appearance ? nil : .appearance
                        prepareOnboardingAppearanceDrafts()
                    }
                )

                if expandedSetupStep == .appearance && !appearanceSetupComplete {
                    Divider()
                        .padding(.leading, 56)

                    onboardingAppearanceForm
                }
            }
            .background(Color(.systemBackground).opacity(0.76))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    accentColor.opacity(0.16),
                    accentColor.opacity(0.06),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        }
    }

    private var onboardingProfileForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("Your name"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("Name", text: $onboardingProfileName)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("Color"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 14) {
                    ColorPicker(L10n.string("Choose Color"), selection: $onboardingProfileColor, supportsOpacity: false)
                        .tint(onboardingProfileColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Button {
                createOnboardingProfile()
            } label: {
                Text(L10n.string("Create Profile"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DashboardPrimaryButtonStyle(tint: accentColor))
            .disabled(onboardingTrimmedName.isEmpty)
        }
        .padding(16)
    }

    private var onboardingAppearanceForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("Theme"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("Theme", selection: $draftThemeMode) {
                    ForEach(AppThemeMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("Color"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ColorPicker(L10n.string("Choose Color"), selection: $draftAccentColor, supportsOpacity: false)
                    .tint(draftAccentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Button {
                applyOnboardingAppearance()
            } label: {
                Text(L10n.string("Save Appearance"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DashboardPrimaryButtonStyle(tint: draftAccentColor))
        }
        .padding(16)
    }

    private func setupStepRow(
        step: HomeSetupStep,
        title: String,
        subtitle: String,
        isComplete: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill((isComplete ? Color.green : accentColor).opacity(0.12))
                        .frame(width: 30, height: 30)

                    Image(systemName: iconName(for: step, isComplete: isComplete))
                        .font(.subheadline.weight(.bold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(isComplete ? Color.green : accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: isComplete ? "checkmark.circle.fill" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isComplete ? Color.green : Color(.tertiaryLabel))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var heroCard: some View {
        let gradient = LinearGradient(
            colors: [
                accentColor.opacity(0.22),
                accentColor.opacity(0.08),
                Color(.secondarySystemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        return VStack(alignment: .leading, spacing: 16) {
            heroHeader

            if resumableMatchAvailable {
                VStack(spacing: 10) {
                    ForEach(Array(game.players.enumerated()), id: \.element.id) { _, player in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(player.colorHex.flatMap { Color(hex: $0) } ?? accentColor)
                                .frame(width: 10, height: 10)

                            Text(player.name)
                                .font(.subheadline.weight(heroHighlightsWinner(player) ? .bold : .semibold))
                                .foregroundStyle(heroHighlightsWinner(player) ? .primary : .secondary)

                            Spacer(minLength: 8)

                            Text(activeValueText(for: player))
                                .font(.headline.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(14)
                .background(Color(.systemBackground).opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else if let heroSnapshotSummary {
                HStack(spacing: 10) {
                    Image(systemName: heroSnapshotSummary.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accentColor)

                    Text(heroSnapshotSummary.value)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.systemBackground).opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            if !heroAccessoryItems.isEmpty {
                HStack(spacing: 10) {
                    ForEach(heroAccessoryItems) { item in
                        DashboardHeroAccessoryView(item: item)
                    }
                }
            }

            if let heroPrimaryAction {
                Button(action: heroPrimaryAction.action) {
                    Label(heroPrimaryAction.title, systemImage: heroPrimaryAction.systemImage)
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DashboardPrimaryButtonStyle(tint: accentColor))
            }
        }
        .padding(20)
        .background(gradient)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        }
    }

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionHeader(title: L10n.string("Quick Start"))

            HStack(alignment: .top, spacing: 10) {
                DashboardQuickActionButton(
                    title: L10n.string("New Match"),
                    systemImage: "plus.circle.fill",
                    tint: accentColor
                ) {
                    openGame(entryIntent: .newMatch)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                DashboardQuickActionButton(
                    title: L10n.string("Practice"),
                    systemImage: "scope",
                    tint: accentColor
                ) {
                    openGame(entryIntent: .practice)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                DashboardQuickActionButton(
                    title: L10n.string("Tournaments"),
                    systemImage: "flag.checkered.2.crossed",
                    tint: accentColor
                ) {
                    isShowingTournaments = true
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    private var motivationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionHeader(title: L10n.string("Recent Performance"))

            Group {
                if let featuredProfile {
                    Button {
                        profilePresentation = DashboardProfilePresentation(id: featuredProfile.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(featuredProfile.name)
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(.primary)

                                    Text(L10n.string("Recent performance"))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    Text(L10n.string("Last 30 days"))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 8)

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 2)
                            }

                            VStack(alignment: .leading, spacing: 14) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(L10n.string("Average"))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)

                                    Text(displayDecimal(recentTrend?.average.recentValue ?? featuredProfile.stats.legAverage))
                                        .font(.system(size: 34, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(.primary)
                                }

                                Divider()
                                    .overlay(Color.primary.opacity(0.06))

                                HStack(spacing: 18) {
                                    DashboardMiniStat(
                                        title: L10n.string("Win Rate"),
                                        value: displayPercent(recentTrend?.winRate.recentValue ?? featuredProfile.stats.winRate),
                                        subtitle: L10n.string("Last 30d")
                                    )

                                    DashboardMiniStat(
                                        title: L10n.string("Best Checkout"),
                                        value: featuredProfile.stats.highestCheckout > 0 ? "\(featuredProfile.stats.highestCheckout)" : "—",
                                        subtitle: L10n.string("Personal best")
                                    )

                                    DashboardMiniStat(
                                        title: L10n.string("Matches"),
                                        value: "\(matchesThisWeek)",
                                        subtitle: L10n.string("This week")
                                    )
                                }
                            }
                            .padding(16)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .padding(18)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.string("Build your profile"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(L10n.string("Create a profile and finish a few matches to unlock recent form, streaks, and personal bests here."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
            }
        }
    }

    private var featureGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionHeader(title: L10n.string("Explore"))

            VStack(spacing: 0) {
                DashboardExploreRow(
                    title: L10n.string("Profiles"),
                    systemImage: "person.crop.circle.fill",
                    tint: accentColor
                ) {
                    isShowingProfiles = true
                }

                Divider()
                    .padding(.leading, 56)

                DashboardExploreRow(
                    title: L10n.string("History"),
                    systemImage: "clock.fill",
                    tint: accentColor
                ) {
                    isShowingHistory = true
                }

                Divider()
                    .padding(.leading, 56)

                DashboardExploreRow(
                    title: L10n.string("Settings"),
                    systemImage: "gearshape.fill",
                    tint: accentColor
                ) {
                    showSettings()
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardSectionHeader(title: L10n.string("Recent Activity"), actionTitle: historyStore.records.isEmpty ? nil : L10n.string("See All")) {
                isShowingHistory = true
            }

            VStack(spacing: 0) {
                if recentRecords.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.string("No matches yet"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(L10n.string("Your latest matches will show up here once you finish a game."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                } else {
                    ForEach(Array(recentRecords.enumerated()), id: \.element.id) { index, record in
                        Button {
                            isShowingHistory = true
                        } label: {
                            DashboardRecentMatchRow(record: record)
                        }
                        .buttonStyle(.plain)

                        if index < recentRecords.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private var activeMatchSummaryText: String {
        if let activeTournamentMatchContext {
            let names = activeTournamentMatchContext.participants.map(\.name).joined(separator: " vs ")
            return "\(activeTournamentMatchContext.roundTitle) • \(names)"
        }
        if game.gameMode == .practice {
            return game.practiceMode.label
        }
        return gameModeSummaryText
    }

    private var gameModeSummaryText: String {
        switch game.gameMode {
        case .x01:
            return "\(game.startingScore) • \(game.finishRule.label)"
        case .practice:
            return game.practiceMode.label
        case .cricket:
            return GameMode.cricket.label
        }
    }

    private func activeValueText(for player: Player) -> String {
        switch game.gameMode {
        case .x01:
            return "\(player.score)"
        case .cricket:
            return "\(game.cricketScore(for: player))"
        case .practice:
            return "\(game.practiceProgressByPlayerID[player.id] ?? 0)"
        }
    }

    private var heroSnapshotSummary: (systemImage: String, value: String)? {
        if activeTournamentMatchContext != nil {
            return ("flag.checkered.2.crossed", activeMatchSummaryText)
        }
        if game.hasResumableProgress {
            return ("play.fill", activeMatchSummaryText)
        }
        if let ongoingTournament {
            return ("flag.checkered.2.crossed", ongoingTournament.name)
        }
        return nil
    }

    @ViewBuilder
    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(heroTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            Text(heroSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let heroMetaLine {
                Text(heroMetaLine)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var heroTitle: String {
        if activeTournamentMatchContext != nil {
            return L10n.string("Continue Tournament")
        }
        if game.gameMode == .practice && game.winner == nil && game.isLegInProgress {
            return L10n.string("Resume Practice")
        }
        if game.hasResumableProgress || session.isActive {
            return L10n.string("Resume Match")
        }
        if ongoingTournament != nil {
            return L10n.string("Continue Tournament")
        }
        return L10n.string("Ready for your next game?")
    }

    private var heroSubtitle: String {
        if activeTournamentMatchContext != nil {
            return activeMatchSummaryText
        }
        if game.gameMode == .practice && game.winner == nil && game.isLegInProgress {
            return L10n.format("%@ in progress", game.practiceMode.label)
        }
        if game.hasResumableProgress || session.isActive {
            return activeMatchSummaryText
        }
        if let ongoingTournament {
            return L10n.format("%@ in progress", ongoingTournament.format.label)
        }
        return L10n.string("Start a match right away, or jump into practice and tournaments below.")
    }

    private var heroMetaLine: String? {
        if session.isActive {
            return L10n.format("%@ players connected", "\(session.connectedPeers.count + 1)")
        }
        if let ongoingTournament, activeTournamentMatchContext == nil {
            return L10n.format("%@ is in progress", ongoingTournament.name)
        }
        return nil
    }

    private var heroPrimaryAction: (title: String, systemImage: String, action: () -> Void)? {
        if activeTournamentMatchContext != nil {
            return (L10n.string("Open Match"), "play.fill", { openGame(entryIntent: .resume) })
        }
        if game.gameMode == .practice && game.winner == nil && game.isLegInProgress {
            return (L10n.string("Resume Practice"), "play.fill", { openGame(entryIntent: .resume) })
        }
        if game.hasResumableProgress || session.isActive {
            return (L10n.string("Resume Match"), "play.fill", { openGame(entryIntent: .resume) })
        }
        if ongoingTournament != nil {
            return (L10n.string("Open Tournament"), "flag.checkered.2.crossed", { isShowingTournaments = true })
        }
        return (L10n.string("Start Match"), "plus.circle.fill", { openGame(entryIntent: .newMatch) })
    }

    private func heroHighlightsWinner(_ player: Player) -> Bool {
        guard let winner = game.winner else { return false }
        return winner.id == player.id
    }

    private func openGame(entryIntent: DartsGameLaunchIntent) {
        gamePresentation = DashboardGamePresentation(entryIntent: entryIntent, tournamentLaunchContext: nil)
    }

    private func showSettings() {
        draftThemeMode = AppThemeMode(rawValue: appThemeModeRaw) ?? .system
        draftAccentColor = AppAccentColor.makeColor(
            red: appAccentRed,
            green: appAccentGreen,
            blue: appAccentBlue
        )
        isShowingSettings = true
    }

    private func prepareOnboardingAppearanceDrafts() {
        draftThemeMode = AppThemeMode(rawValue: appThemeModeRaw) ?? .system
        draftAccentColor = AppAccentColor.makeColor(
            red: appAccentRed,
            green: appAccentGreen,
            blue: appAccentBlue
        )
    }

    private func applySettings() {
        appThemeModeRaw = draftThemeMode.rawValue

        let accent = UIColor(draftAccentColor)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0

        guard accent.getRed(&red, green: &green, blue: &blue, alpha: nil) else { return }

        appAccentRed = Double(red)
        appAccentGreen = Double(green)
        appAccentBlue = Double(blue)
        hasConfirmedInitialAppearance = true
    }

    private func applyOnboardingAppearance() {
        applySettings()
        expandedSetupStep = nil
    }

    private var onboardingTrimmedName: String {
        onboardingProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func createOnboardingProfile() {
        guard !onboardingTrimmedName.isEmpty else { return }

        let profile = profileStore.createProfile(name: onboardingTrimmedName, colorHex: onboardingProfileColor.hexString)
        defaultProfileID = profile.id.uuidString
        hasCreatedFirstProfile = true
        onboardingProfileName = ""
        onboardingProfileColor = accentColor
        expandedSetupStep = nil
    }

    private func displayPercent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int((value * 100).rounded()))%"
    }

    private func displayDecimal(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f", value)
    }

    private func iconName(for step: HomeSetupStep, isComplete: Bool) -> String {
        if isComplete {
            return "checkmark"
        }

        switch step {
        case .profile:
            return "person.crop.circle.fill"
        case .appearance:
            return "paintpalette.fill"
        }
    }
}

private enum HomeSetupStep {
    case profile
    case appearance
}

private struct DashboardHeroAccessoryItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let systemImage: String
    let tint: Color
}

private struct DashboardSectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }
}

private struct DashboardHeroAccessoryView: View {
    let item: DashboardHeroAccessoryItem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(item.tint)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(item.value)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct DashboardQuickActionButton: View {
    private enum Layout {
        static let iconSpacing: CGFloat = 10
        static let cardMinHeight: CGFloat = 72
        static let titleHeight: CGFloat = 44
    }

    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Layout.iconSpacing) {
                DashboardCardIcon(systemImage: systemImage, tint: tint)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: Layout.titleHeight, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, minHeight: Layout.cardMinHeight, alignment: .topLeading)
            .modifier(DashboardCardChrome())
        }
        .buttonStyle(.plain)
    }
}

private struct DashboardExploreRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                DashboardCardIcon(systemImage: systemImage, tint: tint)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

private struct DashboardCardIcon: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: 30, height: 30)

            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(tint)
        }
    }
}

private struct DashboardCardChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct DashboardPrimaryMetricRow: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }

            Spacer()

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct DashboardMiniStat: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DashboardRecentMatchRow: View {
    let record: GameRecord

    private var winnerName: String {
        record.playerResults.first(where: \.isWinner)?.name ?? "Match complete"
    }

    private var playersLabel: String {
        record.playerResults.map(\.name).joined(separator: " • ")
    }

    private var formatLabel: String {
        if let practiceMode = record.practiceMode {
            return practiceMode
        }
        if record.finishRule == GameMode.cricket.rawValue {
            return GameMode.cricket.label
        }
        return "\(record.startingScore) • \(record.finishRule)"
    }

    private var detailLine: String {
        "\(playersLabel) • \(formatLabel)"
    }

    var body: some View {
        HStack(spacing: 12) {
            DashboardCardIcon(systemImage: "clock.fill", tint: AppAccentColor.currentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(winnerName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(detailLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(record.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct DashboardPrimaryButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(tint.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct DashboardSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 14)
            .foregroundStyle(.primary)
            .background(Color(.systemBackground).opacity(configuration.isPressed ? 0.78 : 0.92))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
