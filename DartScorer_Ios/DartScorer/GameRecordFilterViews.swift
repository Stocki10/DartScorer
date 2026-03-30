import SwiftUI

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
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(filter.date == option ? Color.white : Color.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    (filter.date == option ? Color.accentColor : Color(.secondarySystemBackground)),
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
