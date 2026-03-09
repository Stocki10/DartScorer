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

    var body: some View {
        NavigationStack {
            List(record.playerResults) { result in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        if result.isWinner {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(.yellow)
                                .font(.subheadline)
                        }
                        Text(result.name)
                            .fontWeight(result.isWinner ? .semibold : .regular)
                    }

                    HStack(spacing: 20) {
                        VStack(spacing: 2) {
                            Text("Average")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f", result.average))
                                .fontWeight(.semibold)
                        }
                        VStack(spacing: 2) {
                            Text("Best Turn")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(result.highestTurnScore)")
                                .fontWeight(.semibold)
                        }
                        if let pct = result.checkoutPercentage {
                            VStack(spacing: 2) {
                                Text("Checkout")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(Int(pct * 100))%")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
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
