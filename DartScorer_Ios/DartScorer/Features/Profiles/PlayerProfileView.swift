import SwiftUI

struct PlayerProfileView: View {
    @ObservedObject var store: PlayerProfileStore
    @ObservedObject var historyStore: GameHistoryStore
    @Environment(\.dismiss) private var dismiss
    @State private var isAddingProfile = false

    var body: some View {
        NavigationStack {
            Group {
                if store.profiles.isEmpty {
                    ContentUnavailableView(
                        "No Profiles",
                        systemImage: "person.crop.circle",
                        description: Text("Add a profile to track your stats across games.")
                    )
                } else {
                    List {
                        ForEach(store.profiles) { profile in
                            NavigationLink {
                                ProfileDetailView(
                                    store: store,
                                    historyStore: historyStore,
                                    profileID: profile.id
                                )
                            } label: {
                                ProfileRow(profile: profile)
                            }
                        }
                        .onDelete(perform: store.delete)
                    }
                }
            }
            .navigationTitle("Profiles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarBackButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isAddingProfile = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingProfile) {
                ProfileFormView(store: store, profile: nil)
            }
        }
    }
}

private struct ProfileRow: View {
    let profile: PlayerProfile

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: profile.colorHex) ?? Color.accentColor)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .fontWeight(.semibold)
                if let avg = profile.stats.legAverage {
                    Text(L10n.format("Avg %@  ·  %@ games", L10n.decimal(avg), "\(profile.stats.gamesPlayed)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(L10n.format("%@ games", "\(profile.stats.gamesPlayed)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

struct ProfileDetailView: View {
    @ObservedObject var store: PlayerProfileStore
    @ObservedObject var historyStore: GameHistoryStore
    let profileID: UUID
    @State private var recordFilter = GameRecordFilter()
    @State private var editingProfile: PlayerProfile?

    private let statsColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var profile: PlayerProfile? {
        store.profiles.first(where: { $0.id == profileID })
    }

    private var filteredStatsSnapshot: FilteredProfileStatsSnapshot? {
        guard let profile else { return nil }
        return FilteredProfileStatsBuilder.makeSnapshot(
            for: profile.id,
            stats: profile.stats,
            records: historyStore.records,
            filter: recordFilter
        )
    }

    private var trendSnapshot: ProfileTrendSnapshot? {
        guard let profile else { return nil }
        return ProfileTrends.makeSnapshot(
            for: profile.id,
            stats: profile.stats,
            records: historyStore.records,
            filter: recordFilter
        )
    }

    private var headToHeadSnapshot: HeadToHeadSnapshot? {
        guard let profile else { return nil }
        return HeadToHeadBuilder.makeSnapshot(
            for: profile,
            profiles: store.profiles,
            records: historyStore.records,
            filter: recordFilter
        )
    }

    private var emptyFilterMessage: String {
        recordFilter.isUnfiltered
            ? L10n.string("Play more games to see trends.")
            : L10n.string("No games match the current filters.")
    }

    private var hasFilteredScoringStats: Bool {
        guard let filteredStatsSnapshot else { return false }
        return filteredStatsSnapshot.firstNineAverage != nil
            || filteredStatsSnapshot.bestTurn != nil
            || filteredStatsSnapshot.highestScore != nil
            || ((filteredStatsSnapshot.score180Count ?? 0) > 0)
            || ((filteredStatsSnapshot.score140PlusCount ?? 0) > 0)
    }

    private var hasFilteredFinishingStats: Bool {
        guard let filteredStatsSnapshot else { return false }
        return filteredStatsSnapshot.checkoutPercentage != nil
            || filteredStatsSnapshot.bestCheckout != nil
    }

    var body: some View {
        Form {
            if let profile,
               let filteredStatsSnapshot,
               let trendSnapshot,
               let headToHeadSnapshot {
                Section("Profile") {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: profile.colorHex) ?? Color.accentColor)
                            .frame(width: 28, height: 28)

                        Text(profile.name)
                            .font(.headline)
                    }
                    .padding(.vertical, 4)
                }

                Section("Stats") {
                    GameRecordFilterControls(filter: $recordFilter)
                        .padding(.vertical, 4)

                    if filteredStatsSnapshot.hasRecords {
                        statGroup(title: L10n.string("Overview")) {
                            statCard(label: L10n.string("Games"), value: filteredStatsSnapshot.gamesPlayed.map(String.init))
                            statCard(label: L10n.string("Wins"), value: filteredStatsSnapshot.gamesWon.map(String.init))
                            statCard(label: L10n.string("Win Rate"), value: filteredStatsSnapshot.winRate.map(L10n.percent))
                            statCard(label: L10n.string("Average"), value: filteredStatsSnapshot.average.map { L10n.decimal($0) })
                        }

                        if hasFilteredScoringStats {
                            statGroup(title: L10n.string("Scoring")) {
                                if let firstNineAverage = filteredStatsSnapshot.firstNineAverage {
                                    statCard(label: L10n.string("First 9 Avg"), value: L10n.decimal(firstNineAverage))
                                }
                                if let bestTurn = filteredStatsSnapshot.bestTurn {
                                    statCard(label: L10n.string("Best Turn"), value: "\(bestTurn)")
                                }
                                if let highestScore = filteredStatsSnapshot.highestScore {
                                    statCard(label: L10n.string("Highest Score"), value: "\(highestScore)")
                                }
                                if let count180 = filteredStatsSnapshot.score180Count, count180 > 0 {
                                    statCard(label: L10n.string("180 Count"), value: "\(count180)")
                                }
                                if let count140Plus = filteredStatsSnapshot.score140PlusCount, count140Plus > 0 {
                                    statCard(label: L10n.string("140+ Count"), value: "\(count140Plus)")
                                }
                            }
                        }

                        if hasFilteredFinishingStats {
                            statGroup(title: L10n.string("Finishing")) {
                                if let checkoutPercentage = filteredStatsSnapshot.checkoutPercentage {
                                    statCard(label: L10n.string("Checkout %"), value: L10n.percent(checkoutPercentage))
                                }
                                if let bestCheckout = filteredStatsSnapshot.bestCheckout {
                                    statCard(label: L10n.string("Best Checkout"), value: "\(bestCheckout)")
                                }
                            }
                        }
                    } else {
                        Text(emptyFilterMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                    }
                }

                Section(L10n.string("Recent Form")) {
                    if trendSnapshot.hasRecords {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(trendSnapshot.sampleLabel)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }

                            LazyVGrid(columns: statsColumns, spacing: 12) {
                                trendCard(label: L10n.string("Average"), metric: trendSnapshot.average)
                                trendCard(label: L10n.string("First 9 Avg"), metric: trendSnapshot.firstNineAverage)
                                trendCard(label: L10n.string("Checkout %"), metric: trendSnapshot.checkoutPercentage)
                                trendCard(label: L10n.string("Win Rate"), metric: trendSnapshot.winRate)
                            }

                            LazyVGrid(columns: statsColumns, spacing: 12) {
                                summaryCard(label: L10n.string("Current Streak"), value: "\(trendSnapshot.currentWinStreak)")
                                summaryCard(label: L10n.string("Best Recent Streak"), value: "\(trendSnapshot.bestRecentWinStreak)")
                                summaryCard(label: L10n.string("Recent 180s"), value: "\(trendSnapshot.recent180Count)")
                                summaryCard(label: L10n.string("Recent 140+"), value: "\(trendSnapshot.recent140PlusCount)")
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        Text(emptyFilterMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                    }
                }

                if headToHeadSnapshot.hasCompetitiveHistory {
                    Section(L10n.string("Head-to-Head")) {
                        if headToHeadSnapshot.hasOpponents {
                            ForEach(headToHeadSnapshot.opponents) { opponentSummary in
                                NavigationLink {
                                    HeadToHeadDetailView(
                                        profile: profile,
                                        snapshot: HeadToHeadBuilder.makeDetailSnapshot(
                                            for: profile,
                                            opponentSummary: opponentSummary,
                                            profiles: store.profiles,
                                            records: historyStore.records,
                                            filter: recordFilter
                                        )
                                    )
                                } label: {
                                    HeadToHeadRow(summary: opponentSummary)
                                }
                            }
                        } else {
                            Text(L10n.string("Play competitive matches against other profiles to build rivalries."))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 6)
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Profile",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("This profile is no longer available.")
                )
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let profile {
                    Button("Edit") {
                        editingProfile = profile
                    }
                }
            }
        }
        .sheet(item: $editingProfile) { profile in
            ProfileFormView(store: store, profile: profile)
        }
    }

    private func statCard(label: String, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value ?? L10n.string("—"))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func trendCard(label: String, metric: ProfileTrendMetric) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(metric.formattedRecentValue)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Group {
                if let deltaText = metric.formattedDeltaText,
                   let direction = metric.direction {
                    TrendDeltaChip(direction: direction, text: deltaText)
                } else {
                    Color.clear
                        .frame(height: 26)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func summaryCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func statGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: statsColumns, spacing: 12) {
                content()
            }
        }
        .padding(.vertical, 4)
    }
}

struct ProfileFormView: View {
    @ObservedObject var store: PlayerProfileStore
    let profile: PlayerProfile?
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var color: Color

    init(store: PlayerProfileStore, profile: PlayerProfile?) {
        self.store = store
        self.profile = profile
        _name = State(initialValue: profile?.name ?? "")
        _color = State(initialValue: profile.flatMap { Color(hex: $0.colorHex) } ?? .accentColor)
    }

    private var isEditing: Bool { profile != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)

                    ColorPicker("Color", selection: $color, supportsOpacity: false)
                }
            }
            .navigationTitle(isEditing ? "Edit Profile" : "New Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if var existing = profile {
            existing.name = trimmed
            existing.colorHex = color.hexString
            store.update(existing)
        } else {
            store.add(PlayerProfile(name: trimmed, colorHex: color.hexString))
        }
        dismiss()
    }
}

private struct TrendDeltaChip: View {
    let direction: ProfileTrendDirection
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            if direction != .flat {
                Image(systemName: direction.symbolName)
                    .font(.caption2.weight(.semibold))
            }
            Text(text)
                .font(.caption2.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.tertiarySystemBackground))
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HeadToHeadRow: View {
    let summary: HeadToHeadOpponentSummary

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: summary.opponentColorHex) ?? Color.accentColor)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(summary.opponentName)
                        .fontWeight(.semibold)
                    if let streakLabel = summary.streakLabel {
                        Text(streakLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    Text(summary.recordText)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    Text(L10n.percent(summary.winRate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(L10n.format("Last played %@", summary.lastPlayedDate.formatted(date: .abbreviated, time: .omitted)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

private struct HeadToHeadDetailView: View {
    let profile: PlayerProfile
    let snapshot: HeadToHeadDetailSnapshot

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(hex: profile.colorHex) ?? Color.accentColor)
                            .frame(width: 14, height: 14)
                        Text(L10n.format("%@ vs %@", profile.name, snapshot.opponent.opponentName))
                            .font(.headline)
                        Circle()
                            .fill(Color(hex: snapshot.opponent.opponentColorHex) ?? Color.accentColor)
                            .frame(width: 14, height: 14)
                    }

                    HStack(spacing: 20) {
                        matchupHeaderStat(title: L10n.string("Record"), value: snapshot.opponent.recordText)
                        matchupHeaderStat(title: L10n.string("Win Rate"), value: L10n.percent(snapshot.opponent.winRate))
                        matchupHeaderStat(
                            title: L10n.string("Last Played"),
                            value: snapshot.opponent.lastPlayedDate.formatted(date: .abbreviated, time: .omitted)
                        )
                    }
                }
                .padding(.vertical, 4)
            }

            Section(L10n.string("Comparison")) {
                LazyVGrid(columns: columns, spacing: 12) {
                    headToHeadComparisonCard(
                        label: L10n.string("Average"),
                        playerName: profile.name,
                        playerValue: snapshot.opponent.playerAverage.map { L10n.decimal($0) },
                        opponentName: snapshot.opponent.opponentName,
                        opponentValue: snapshot.opponent.opponentAverage.map { L10n.decimal($0) }
                    )
                    headToHeadComparisonCard(
                        label: L10n.string("First 9 Avg"),
                        playerName: profile.name,
                        playerValue: snapshot.opponent.playerFirstNineAverage.map { L10n.decimal($0) },
                        opponentName: snapshot.opponent.opponentName,
                        opponentValue: snapshot.opponent.opponentFirstNineAverage.map { L10n.decimal($0) }
                    )
                    headToHeadComparisonCard(
                        label: L10n.string("Best Checkout"),
                        playerName: profile.name,
                        playerValue: snapshot.opponent.playerBestCheckout.map(String.init),
                        opponentName: snapshot.opponent.opponentName,
                        opponentValue: snapshot.opponent.opponentBestCheckout.map(String.init)
                    )
                }
                .padding(.vertical, 4)
            }

            Section(L10n.string("Match History")) {
                ForEach(snapshot.recentMeetings) { meeting in
                    NavigationLink {
                        GameRecordDetailView(record: meeting.record, showsToolbarBackButton: false)
                    } label: {
                        GameRecordRow(record: meeting.record)
                    }
                }
            }
        }
        .navigationTitle(snapshot.opponent.opponentName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func matchupHeaderStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .monospacedDigit()
        }
    }

    private func headToHeadComparisonCard(
        label: String,
        playerName: String,
        playerValue: String?,
        opponentName: String,
        opponentValue: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                comparisonRow(name: playerName, value: playerValue)
                comparisonRow(name: opponentName, value: opponentValue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func comparisonRow(name: String, value: String?) -> some View {
        HStack {
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Text(value ?? L10n.string("—"))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
    }
}

struct ProfilePickerView: View {
    let profiles: [PlayerProfile]
    let excludedProfileIDs: Set<UUID>
    let onSelect: (PlayerProfile?) -> Void
    @Environment(\.dismiss) private var dismiss

    init(profiles: [PlayerProfile], excludedProfileIDs: Set<UUID> = [], onSelect: @escaping (PlayerProfile?) -> Void) {
        self.profiles = profiles
        self.excludedProfileIDs = excludedProfileIDs
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            List {
                Button {
                    onSelect(nil)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .strokeBorder(Color.secondary, lineWidth: 1.5)
                            .frame(width: 24, height: 24)
                        Text("No Profile")
                            .foregroundStyle(.primary)
                    }
                }

                ForEach(profiles) { profile in
                    let isExcluded = excludedProfileIDs.contains(profile.id)
                    Button {
                        guard !isExcluded else { return }
                        onSelect(profile)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: profile.colorHex) ?? Color.accentColor)
                                .frame(width: 24, height: 24)
                            Text(profile.name)
                                .foregroundStyle(isExcluded ? Color.secondary : Color.primary)
                            if isExcluded {
                                Spacer()
                                Text("In use")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(isExcluded)
                }
            }
            .navigationTitle("Select Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
