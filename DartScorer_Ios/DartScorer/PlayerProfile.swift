import Foundation
import Combine
import SwiftUI

struct PlayerProfileStats: Codable, Equatable {
    var gamesPlayed: Int = 0
    var gamesWon: Int = 0
    var totalDartsThrown: Int = 0
    var totalPointsScored: Int = 0
    var totalFirstNinePoints: Int = 0
    var totalFirstNineDarts: Int = 0
    var checkoutAttempts: Int = 0
    var checkoutHits: Int = 0
    var score180Count: Int = 0
    var score140PlusCount: Int = 0
    var highestCheckout: Int = 0
    var highestTurnScore: Int = 0
    var highestScore: Int = 0

    var legAverage: Double? {
        guard totalDartsThrown > 0 else { return nil }
        return (Double(totalPointsScored) / Double(totalDartsThrown)) * 3.0
    }

    var firstNineAverage: Double? {
        guard totalFirstNineDarts > 0 else { return nil }
        return (Double(totalFirstNinePoints) / Double(totalFirstNineDarts)) * 3.0
    }

    var winRate: Double? {
        guard gamesPlayed > 0 else { return nil }
        return Double(gamesWon) / Double(gamesPlayed)
    }

    var checkoutPercentage: Double? {
        guard checkoutAttempts > 0 else { return nil }
        return Double(checkoutHits) / Double(checkoutAttempts)
    }

    enum CodingKeys: String, CodingKey {
        case gamesPlayed, gamesWon, totalDartsThrown, totalPointsScored
        case totalFirstNinePoints, totalFirstNineDarts
        case checkoutAttempts, checkoutHits
        case score180Count, score140PlusCount
        case highestCheckout, highestTurnScore, highestScore
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gamesPlayed = (try? container.decode(Int.self, forKey: .gamesPlayed)) ?? 0
        gamesWon = (try? container.decode(Int.self, forKey: .gamesWon)) ?? 0
        totalDartsThrown = (try? container.decode(Int.self, forKey: .totalDartsThrown)) ?? 0
        totalPointsScored = (try? container.decode(Int.self, forKey: .totalPointsScored)) ?? 0
        totalFirstNinePoints = (try? container.decode(Int.self, forKey: .totalFirstNinePoints)) ?? 0
        totalFirstNineDarts = (try? container.decode(Int.self, forKey: .totalFirstNineDarts)) ?? 0
        checkoutAttempts = (try? container.decode(Int.self, forKey: .checkoutAttempts)) ?? 0
        checkoutHits = (try? container.decode(Int.self, forKey: .checkoutHits)) ?? 0
        score180Count = (try? container.decode(Int.self, forKey: .score180Count)) ?? 0
        score140PlusCount = (try? container.decode(Int.self, forKey: .score140PlusCount)) ?? 0
        highestCheckout = (try? container.decode(Int.self, forKey: .highestCheckout)) ?? 0
        highestTurnScore = (try? container.decode(Int.self, forKey: .highestTurnScore)) ?? 0
        highestScore = (try? container.decode(Int.self, forKey: .highestScore)) ?? highestTurnScore
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
            profiles[index].stats.totalFirstNinePoints += result.totalFirstNinePoints
            profiles[index].stats.totalFirstNineDarts += result.totalFirstNineDarts
            profiles[index].stats.checkoutAttempts += result.checkoutAttempts
            profiles[index].stats.checkoutHits += result.checkoutHits
            profiles[index].stats.score180Count += result.score180Count
            profiles[index].stats.score140PlusCount += result.score140PlusCount
            profiles[index].stats.highestCheckout = max(profiles[index].stats.highestCheckout, result.highestCheckout)
            profiles[index].stats.highestTurnScore = max(profiles[index].stats.highestTurnScore, result.highestTurnScore)
            profiles[index].stats.highestScore = max(profiles[index].stats.highestScore, result.highestScore)
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
