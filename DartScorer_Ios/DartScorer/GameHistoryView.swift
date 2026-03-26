import SwiftUI

struct GameHistoryView: View {
    @ObservedObject var store: GameHistoryStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRecord: GameRecord?
    @State private var isShowingClearConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if store.records.isEmpty {
                    ContentUnavailableView(
                        "No Games Yet",
                        systemImage: "clock",
                        description: Text("Completed games will appear here.")
                    )
                } else {
                    List(store.records) { record in
                        GameRecordRow(record: record)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedRecord = record }
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
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
        }
    }
}

private struct GameRecordRow: View {
    let record: GameRecord

    private var winner: PlayerGameResult? {
        record.playerResults.first { $0.isWinner }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(record.startingScore) • \(record.finishRule)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let winner {
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                        Text(winner.name)
                            .fontWeight(.semibold)
                    }
                }
            }
            Spacer()
            Text(record.date, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct GameRecordDetailView: View {
    let record: GameRecord
    @Environment(\.dismiss) private var dismiss

    private var winner: PlayerGameResult? {
        record.playerResults.first { $0.isWinner }
    }

    private var totalLegs: Int {
        max(record.legs.count, 1)
    }

    private func legWins(for playerID: UUID) -> Int {
        record.legs.filter { $0.winnerPlayerID == playerID }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Match Summary") {
                    HistoryMetricRow(title: "Date", value: record.date.formatted(date: .abbreviated, time: .omitted))
                    HistoryMetricRow(title: "Format", value: "\(record.startingScore) • \(record.finishRule)")
                    HistoryMetricRow(title: "Winner", value: winner?.name ?? "—")
                    if record.legs.count > 1 {
                        HistoryMetricRow(title: "Total Legs", value: "\(record.legs.count)")
                    }
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
                                    HistoryInlineBadge(text: "Legs won: \(legWins(for: result.id))")
                                }
                            }

                            HStack(spacing: 20) {
                                HistoryStatBlock(title: "Average", value: String(format: "%.1f", result.average))
                                HistoryStatBlock(title: "Darts", value: "\(result.totalDartsThrown)")
                                HistoryStatBlock(title: "Best Finish", value: "\(result.highestCheckout)")
                                HistoryStatBlock(title: "Best Turn", value: "\(result.highestTurnScore)")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("\(record.startingScore) • \(record.finishRule)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
            }
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
        totalLegs == 1 ? "Leg" : "Leg \(leg.legNumber)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(legTitle)
                    .fontWeight(.semibold)
                Spacer()
                if let winner {
                    Text(winner.name)
                        .foregroundStyle(.secondary)
                }
            }

            if let route = leg.winningCheckoutRoute {
                Text("Finish: \(route)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let winner {
                HStack(spacing: 16) {
                    Text("Darts \(winner.dartsThrown)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let firstNineAverage = winner.firstNineAverage {
                        Text("First 9 \(String(format: "%.1f", firstNineAverage))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct LegRecordDetailView: View {
    let leg: LegRecord
    let totalLegs: Int

    private var winner: LegPlayerResult? {
        leg.playerResults.first { $0.playerID == leg.winnerPlayerID }
    }

    private var legTitle: String {
        totalLegs == 1 ? "Leg" : "Leg \(leg.legNumber)"
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
                            HistoryStatBlock(title: "Darts", value: "\(result.dartsThrown)")
                            HistoryStatBlock(title: "Average", value: String(format: "%.1f", result.average))
                            HistoryStatBlock(
                                title: "First 9",
                                value: result.firstNineAverage.map { String(format: "%.1f", $0) } ?? "—"
                            )
                        }

                        HStack(spacing: 18) {
                            HistoryStatBlock(title: "Best Finish", value: "\(result.highestFinish)")
                            HistoryStatBlock(title: "Best Turn", value: "\(result.highestTurnScore)")
                            HistoryStatBlock(title: "Busts", value: "\(result.bustCount)")
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
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
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
        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.black.opacity(0.04), lineWidth: 1)
        )
    }
}
