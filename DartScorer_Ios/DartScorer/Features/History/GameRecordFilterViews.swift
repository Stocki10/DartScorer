import SwiftUI

struct HistoryFilterPlayerOption: Identifiable, Equatable {
    let id: UUID
    let name: String
}

struct GameRecordFilterControls: View {
    @Binding var filter: GameRecordFilter
    var title: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Picker("Mode Filter", selection: $filter.mode) {
                ForEach(GameModeHistoryFilter.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(GameDateFilter.allCases) { option in
                        Button {
                            filter.date = option
                        } label: {
                            Text(option.label)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(filter.date == option ? Color.accentColor : Color.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    (
                                        filter.date == option
                                        ? Color.accentColor.opacity(0.14)
                                        : Color(.secondarySystemBackground)
                                    ),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }

            if filter.date == .custom {
                HStack(spacing: 12) {
                    DatePicker(
                        L10n.string("From"),
                        selection: Binding(
                            get: { min(filter.customStartDate, filter.customEndDate) },
                            set: { newValue in
                                filter.customStartDate = newValue
                                if filter.customEndDate < newValue {
                                    filter.customEndDate = newValue
                                }
                            }
                        ),
                        displayedComponents: .date
                    )

                    DatePicker(
                        L10n.string("To"),
                        selection: Binding(
                            get: { max(filter.customStartDate, filter.customEndDate) },
                            set: { newValue in
                                filter.customEndDate = newValue
                                if filter.customStartDate > newValue {
                                    filter.customStartDate = newValue
                                }
                            }
                        ),
                        displayedComponents: .date
                    )
                }
                .font(.subheadline)
            }
        }
    }
}

struct HistoryPrimaryFilterBar: View {
    @Binding var filter: GameRecordFilter
    let showsActiveIndicator: Bool
    let onOpenFilters: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Picker("Mode Filter", selection: $filter.mode) {
                ForEach(GameModeHistoryFilter.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Button(action: onOpenFilters) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: showsActiveIndicator ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.title3)
                        .foregroundStyle(showsActiveIndicator ? Color.accentColor : Color.primary)

                    if showsActiveIndicator {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }
                .frame(width: 36, height: 36)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string("Filters"))
        }
    }
}

struct HistoryFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draftFilter: GameRecordFilter
    let availablePlayers: [HistoryFilterPlayerOption]
    let onApply: (GameRecordFilter) -> Void

    init(
        initialFilter: GameRecordFilter,
        availablePlayers: [HistoryFilterPlayerOption],
        onApply: @escaping (GameRecordFilter) -> Void
    ) {
        _draftFilter = State(initialValue: initialFilter)
        self.availablePlayers = availablePlayers
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.string("Time Range")) {
                    ForEach(sheetDateOptions) { option in
                        filterChoiceRow(
                            title: option.sheetLabel,
                            isSelected: draftFilter.date == option
                        ) {
                            draftFilter.date = option
                        }
                    }

                    if draftFilter.date == .custom {
                        DatePicker(
                            L10n.string("From"),
                            selection: Binding(
                                get: { min(draftFilter.customStartDate, draftFilter.customEndDate) },
                                set: { newValue in
                                    draftFilter.customStartDate = newValue
                                    if draftFilter.customEndDate < newValue {
                                        draftFilter.customEndDate = newValue
                                    }
                                }
                            ),
                            displayedComponents: .date
                        )

                        DatePicker(
                            L10n.string("To"),
                            selection: Binding(
                                get: { max(draftFilter.customStartDate, draftFilter.customEndDate) },
                                set: { newValue in
                                    draftFilter.customEndDate = newValue
                                    if draftFilter.customStartDate > newValue {
                                        draftFilter.customStartDate = newValue
                                    }
                                }
                            ),
                            displayedComponents: .date
                        )
                    }
                }

                Section(L10n.string("Player")) {
                    filterChoiceRow(
                        title: L10n.string("All Players"),
                        isSelected: draftFilter.participantProfileID == nil
                    ) {
                        draftFilter.participantProfileID = nil
                    }

                    ForEach(availablePlayers) { player in
                        filterChoiceRow(
                            title: player.name,
                            isSelected: draftFilter.participantProfileID == player.id
                        ) {
                            draftFilter.participantProfileID = player.id
                        }
                    }
                }

                Section {
                    Button(L10n.string("Reset")) {
                        draftFilter.date = .allTime
                        draftFilter.participantProfileID = nil
                        draftFilter.customStartDate = Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date()
                        draftFilter.customEndDate = Date()
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle(L10n.string("Filters"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string("Apply")) {
                        onApply(draftFilter)
                        dismiss()
                    }
                }
            }
        }
    }

    private func filterChoiceRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var sheetDateOptions: [GameDateFilter] {
        [.allTime, .last7Days, .last30Days, .last90Days, .custom]
    }
}

private extension GameDateFilter {
    var sheetLabel: String {
        switch self {
        case .last7Days:
            return L10n.string("7 days")
        case .last30Days:
            return L10n.string("30 days")
        case .last90Days:
            return L10n.string("90 days")
        case .allTime:
            return L10n.string("All")
        case .custom:
            return L10n.string("Custom")
        }
    }
}
