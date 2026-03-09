import SwiftUI

struct PlayerProfileView: View {
    @ObservedObject var store: PlayerProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var isAddingProfile = false
    @State private var editingProfile: PlayerProfile?

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
                            ProfileRow(profile: profile)
                                .contentShape(Rectangle())
                                .onTapGesture { editingProfile = profile }
                        }
                        .onDelete(perform: store.delete)
                    }
                }
            }
            .navigationTitle("Profiles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
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
                ProfileEditView(store: store, profile: nil)
            }
            .sheet(item: $editingProfile) { profile in
                ProfileEditView(store: store, profile: profile)
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
                    Text("Avg \(String(format: "%.1f", avg))  ·  \(profile.stats.gamesPlayed) games")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(profile.stats.gamesPlayed) games")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

struct ProfileEditView: View {
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

                if isEditing, let stats = profile?.stats, stats.gamesPlayed > 0 {
                    Section("Stats") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 24) {
                                statCell(label: "Games", value: "\(stats.gamesPlayed)")
                                statCell(label: "Wins", value: "\(stats.gamesWon)")
                                if let rate = stats.winRate {
                                    statCell(label: "Win Rate", value: "\(Int(rate * 100))%")
                                }
                                if let avg = stats.legAverage {
                                    statCell(label: "Average", value: String(format: "%.1f", avg))
                                }
                                if stats.highestTurnScore > 0 {
                                    statCell(label: "Best Turn", value: "\(stats.highestTurnScore)")
                                }
                                if stats.highestCheckout > 0 {
                                    statCell(label: "Best Checkout", value: "\(stats.highestCheckout)")
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
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

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
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
