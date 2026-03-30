import SwiftUI

struct GameHistoryView: View {
    @ObservedObject var store: GameHistoryStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRecord: GameRecord?
    @State private var isShowingClearConfirmation = false
    @State private var isShowingFilters = false
    @State private var recordFilter = GameRecordFilter()

    private var filteredRecords: [GameRecord] {
        recordFilter.filteredRecords(from: store.records)
    }

    private var availablePlayers: [HistoryFilterPlayerOption] {
        var playersByID: [UUID: String] = [:]

        for record in store.records {
            for result in record.playerResults {
                guard let profileID = result.profileID else { continue }
                playersByID[profileID] = result.name
            }
        }

        return playersByID
            .map { HistoryFilterPlayerOption(id: $0.key, name: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !store.records.isEmpty {
                    HistoryPrimaryFilterBar(
                        filter: $recordFilter,
                        showsActiveIndicator: recordFilter.hasSupplementaryFilters,
                        onOpenFilters: { isShowingFilters = true }
                    )
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    Divider()
                }

                Group {
                    if store.records.isEmpty {
                        ContentUnavailableView(
                            "No Games Yet",
                            systemImage: "clock",
                            description: Text("Completed games will appear here.")
                        )
                    } else if filteredRecords.isEmpty {
                        ContentUnavailableView(
                            "No Matching Games",
                            systemImage: "line.3.horizontal.decrease.circle",
                            description: Text("No games match the current filters.")
                        )
                    } else {
                        List(filteredRecords) { record in
                            Button {
                                selectedRecord = record
                            } label: {
                                GameRecordRow(record: record)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarBackButton { dismiss() }
                }
                if !store.records.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Clear", role: .destructive) {
                            isShowingClearConfirmation = true
                        }
                    }
                }
            }
            .alert("Clear History?", isPresented: $isShowingClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) { store.clearAll() }
            } message: {
                Text("This will permanently delete all saved game history.")
            }
            .sheet(item: $selectedRecord) { record in
                GameRecordDetailView(record: record)
            }
            .sheet(isPresented: $isShowingFilters) {
                HistoryFilterSheet(
                    initialFilter: recordFilter,
                    availablePlayers: availablePlayers
                ) { appliedFilter in
                    recordFilter = appliedFilter
                }
            }
        }
    }
}

@MainActor
struct GameRecordRow: View {
    let record: GameRecord

    private var winner: PlayerGameResult? {
        record.playerResults.first { $0.isWinner }
    }

    private var formatLabel: String {
        if record.finishRule == GameMode.practice.rawValue {
            return record.practiceMode.map(L10n.localizedStoredRule) ?? L10n.localizedStoredRule(record.finishRule)
        }
        let localizedRule = L10n.localizedStoredRule(record.finishRule)
        return record.startingScore > 0 ? "\(record.startingScore) • \(localizedRule)" : localizedRule
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(formatLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(record.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let winner {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    Text(winner.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.black.opacity(0.04), lineWidth: 1)
        )
    }
}

@MainActor
struct GameRecordDetailView: View {
    let record: GameRecord
    let showsToolbarBackButton: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var shareItems: [Any] = []
    @State private var isShowingShareSheet = false

    init(record: GameRecord, showsToolbarBackButton: Bool = true) {
        self.record = record
        self.showsToolbarBackButton = showsToolbarBackButton
    }

    private var isCricket: Bool {
        record.finishRule == "Cricket"
    }

    private var winner: PlayerGameResult? {
        record.playerResults.first { $0.isWinner }
    }

    private var totalLegs: Int {
        max(record.legs.count, 1)
    }

    private func legWins(for playerID: UUID) -> Int {
        record.legs.filter { $0.winnerPlayerID == playerID }.count
    }

    private var formatLabel: String {
        if record.finishRule == GameMode.practice.rawValue {
            return record.practiceMode.map(L10n.localizedStoredRule) ?? L10n.localizedStoredRule(record.finishRule)
        }
        let localizedRule = L10n.localizedStoredRule(record.finishRule)
        return record.startingScore > 0 ? "\(record.startingScore) • \(localizedRule)" : localizedRule
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Match Summary") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(formatLabel)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if let winner {
                                    HStack(spacing: 8) {
                                        Image(systemName: "trophy.fill")
                                            .foregroundStyle(.yellow)
                                        Text(winner.name)
                                            .font(.title2.weight(.bold))
                                            .foregroundStyle(.primary)
                                    }
                                } else {
                                    Text(L10n.string("No data"))
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Button {
                                shareItems = MatchShareRenderer.shareItems(for: record)
                                isShowingShareSheet = true
                            } label: {
                                Label(L10n.string("Share"), systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HistoryMetricRow(
                                title: L10n.string("Date"),
                                value: record.date.formatted(date: .abbreviated, time: .omitted),
                                emphasis: .secondary
                            )
                            HistoryMetricRow(
                                title: L10n.string("Format"),
                                value: formatLabel,
                                emphasis: .secondary
                            )
                            if record.legs.count > 1 {
                                HistoryMetricRow(
                                    title: L10n.string("Total Legs"),
                                    value: "\(record.legs.count)",
                                    emphasis: .secondary
                                )
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                if !record.legs.isEmpty {
                    Section("Legs") {
                        ForEach(record.legs) { leg in
                            NavigationLink {
                                LegRecordDetailView(leg: leg, totalLegs: totalLegs)
                            } label: {
                                LegRecordRow(leg: leg, totalLegs: totalLegs)
                            }
                        }
                    }
                }

                Section("Player Summary") {
                    ForEach(record.playerResults) { result in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                if result.isWinner {
                                    Image(systemName: "trophy.fill")
                                        .foregroundStyle(.yellow)
                                        .font(.subheadline)
                                }
                                Text(result.name)
                                    .fontWeight(result.isWinner ? .semibold : .regular)
                                Spacer()
                                if record.legs.count > 1 {
                                    HistoryInlineBadge(text: L10n.format("Legs won: %@", displayCount(legWins(for: result.id), usesDashForZero: false)))
                                }
                            }

                            HStack(spacing: 20) {
                                if isCricket {
                                    HistoryStatBlock(title: "Score", value: displayCount(result.totalPointsScored, emptyText: L10n.string("No data")))
                                    HistoryStatBlock(title: "Average", value: displayDecimal(result.average, emptyText: L10n.string("No data")))
                                } else {
                                    HistoryStatBlock(title: "Average", value: displayDecimal(result.average, emptyText: L10n.string("No data")))
                                    HistoryStatBlock(title: "Best Turn", value: displayCount(result.highestTurnScore, emptyText: L10n.string("No data")))
                                }
                                HistoryStatBlock(title: "Darts", value: displayCount(result.totalDartsThrown, emptyText: L10n.string("No data")))
                            }
                        }
                        .padding(.vertical, 4)
                        .opacity(hasMeaningfulSummaryData(result) ? 1 : 0.72)
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .navigationTitle(L10n.string("Match"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsToolbarBackButton {
                    ToolbarItem(placement: .cancellationAction) {
                        ToolbarBackButton { dismiss() }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingShareSheet) {
            ShareSheet(items: shareItems)
        }
    }
}

private struct LegRecordRow: View {
    let leg: LegRecord
    let totalLegs: Int

    private var winner: LegPlayerResult? {
        leg.playerResults.first { $0.playerID == leg.winnerPlayerID }
    }

    private var legTitle: String {
        totalLegs == 1 ? L10n.string("Leg") : L10n.format("Leg %@", "\(leg.legNumber)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(legTitle)
                    .fontWeight(.semibold)
                Spacer()
                if let winner {
                    Text(winner.name)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
            }

            if let highlightedPrimaryLine {
                highlightedPrimaryLine
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var highlightedPrimaryLine: Text? {
        guard let winner else { return nil }
        let finishPart: String
        if let route = leg.winningCheckoutRoute, !route.isEmpty {
            finishPart = route
        } else if let checkoutScore = leg.checkoutScore {
            finishPart = L10n.format("Checkout %@", "\(checkoutScore)")
        } else {
            finishPart = ""
        }

        var trailingParts: [String] = []
        if winner.dartsThrown > 0 {
            trailingParts.append(L10n.format("%@ darts", "\(winner.dartsThrown)"))
        }
        if let firstNineAverage = winner.firstNineAverage, firstNineAverage > 0 {
            trailingParts.append(L10n.decimal(firstNineAverage))
        }

        if finishPart.isEmpty, trailingParts.isEmpty {
            return nil
        }

        let suffix = trailingParts.isEmpty ? "" : " • " + trailingParts.joined(separator: " • ")
        return Text(finishPart)
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
        + Text(suffix)
            .foregroundStyle(.secondary)
    }
}

private struct LegRecordDetailView: View {
    let leg: LegRecord
    let totalLegs: Int

    private var winner: LegPlayerResult? {
        leg.playerResults.first { $0.playerID == leg.winnerPlayerID }
    }

    private var legTitle: String {
        totalLegs == 1 ? L10n.string("Leg") : L10n.format("Leg %@", "\(leg.legNumber)")
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    if let winner {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Winner")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                Image(systemName: "trophy.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.yellow)
                                Text(winner.name)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                        }
                    }

                    if leg.checkoutScore != nil || leg.winningCheckoutRoute != nil {
                        HStack(spacing: 12) {
                            if let checkoutScore = leg.checkoutScore {
                                HistoryDetailTile(title: "Checkout", value: "\(checkoutScore)")
                            }
                            if let route = leg.winningCheckoutRoute {
                                HistoryDetailTile(title: "Finish", value: route)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Per-Player Breakdown") {
                ForEach(leg.playerResults) { result in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            HStack(spacing: 6) {
                                if result.playerID == leg.winnerPlayerID {
                                    Image(systemName: "trophy.fill")
                                        .foregroundStyle(.yellow)
                                        .font(.subheadline)
                                }
                                Text(result.name)
                                    .fontWeight(result.playerID == leg.winnerPlayerID ? .semibold : .regular)
                            }
                            Spacer()
                            if result.playerID == leg.startingPlayerID {
                                Text("Started")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.secondary.opacity(0.12), in: Capsule())
                            }
                        }

                        HStack(spacing: 18) {
                            HistoryStatBlock(title: "Darts", value: displayCount(result.dartsThrown))
                            HistoryStatBlock(title: "Average", value: displayDecimal(result.average))
                            HistoryStatBlock(
                                title: "First 9",
                                value: displayDecimal(result.firstNineAverage)
                            )
                        }

                        HStack(spacing: 18) {
                            HistoryStatBlock(title: "Best Finish", value: displayCount(result.highestFinish))
                            HistoryStatBlock(title: "Best Turn", value: displayCount(result.highestTurnScore))
                            HistoryStatBlock(title: "Busts", value: displayCount(result.bustCount))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(legTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HistoryMetricRow: View {
    enum Emphasis {
        case primary
        case secondary
    }

    let title: String
    let value: String
    var emphasis: Emphasis = .primary

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(emphasis == .primary ? .primary : .secondary)
        }
    }
}

private struct HistoryStatBlock: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle((value == L10n.string("—") || value == L10n.string("No data")) ? .secondary : .primary)
        }
    }
}

private struct HistoryInlineBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(.black.opacity(0.04), lineWidth: 1)
            )
    }
}

private struct HistoryDetailTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
        )
    }
}

private func displayDecimal(_ value: Double?, emptyText: String? = nil) -> String {
    guard let value, value > 0 else { return emptyText ?? L10n.string("—") }
    return L10n.decimal(value)
}

private func displayCount(_ value: Int, usesDashForZero: Bool = true, emptyText: String? = nil) -> String {
    guard usesDashForZero, value == 0 else { return "\(value)" }
    return emptyText ?? L10n.string("—")
}

private func hasMeaningfulSummaryData(_ result: PlayerGameResult) -> Bool {
    result.totalPointsScored > 0
        || result.totalDartsThrown > 0
        || result.average > 0
        || result.highestTurnScore > 0
}
