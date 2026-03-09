import Foundation
import Combine
import SwiftUI

struct PlayerProfileStats: Codable, Equatable {
    var gamesPlayed: Int = 0
    var gamesWon: Int = 0
    var totalDartsThrown: Int = 0
    var totalPointsScored: Int = 0
    var highestCheckout: Int = 0
    var highestTurnScore: Int = 0

    var legAverage: Double? {
        guard totalDartsThrown > 0 else { return nil }
        return (Double(totalPointsScored) / Double(totalDartsThrown)) * 3.0
    }

    var winRate: Double? {
        guard gamesPlayed > 0 else { return nil }
        return Double(gamesWon) / Double(gamesPlayed)
    }
}

struct PlayerProfile: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var colorHex: String
    var stats: PlayerProfileStats

    init(id: UUID = UUID(), name: String, colorHex: String = "#FF6347") {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.stats = PlayerProfileStats()
    }
}

final class PlayerProfileStore: ObservableObject {
    @Published private(set) var profiles: [PlayerProfile] = []

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("player_profiles.json")
    }()

    init() { load() }

    func add(_ profile: PlayerProfile) {
        profiles.append(profile)
        save()
    }

    func update(_ profile: PlayerProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index] = profile
        save()
    }

    func replaceAll(_ updated: [PlayerProfile]) {
        profiles = updated
        save()
    }

    func delete(at offsets: IndexSet) {
        profiles.remove(atOffsets: offsets)
        save()
    }

    func updateStatsFromGameRecord(_ record: GameRecord) {
        var changed = false
        for result in record.playerResults {
            guard let profileID = result.profileID,
                  let index = profiles.firstIndex(where: { $0.id == profileID }) else { continue }
            profiles[index].stats.gamesPlayed += 1
            if result.isWinner { profiles[index].stats.gamesWon += 1 }
            profiles[index].stats.totalDartsThrown += result.totalDartsThrown
            profiles[index].stats.totalPointsScored += result.totalPointsScored
            profiles[index].stats.highestCheckout = max(profiles[index].stats.highestCheckout, result.highestCheckout)
            profiles[index].stats.highestTurnScore = max(profiles[index].stats.highestTurnScore, result.highestTurnScore)
            changed = true
        }
        if changed { save() }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([PlayerProfile].self, from: data) else { return }
        profiles = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
