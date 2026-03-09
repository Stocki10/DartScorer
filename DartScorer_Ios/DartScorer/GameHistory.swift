import Foundation
import Combine

struct PlayerGameResult: Identifiable {
    let id: UUID
    let name: String
    let average: Double
    let highestTurnScore: Int
    let checkoutPercentage: Double?
    let isWinner: Bool
    let profileID: UUID?
    let totalDartsThrown: Int
    let totalPointsScored: Int
    let highestCheckout: Int
}

extension PlayerGameResult: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, average, highestTurnScore, checkoutPercentage, isWinner
        case profileID, totalDartsThrown, totalPointsScored, highestCheckout
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        average = try c.decode(Double.self, forKey: .average)
        highestTurnScore = try c.decode(Int.self, forKey: .highestTurnScore)
        checkoutPercentage = try? c.decode(Double.self, forKey: .checkoutPercentage)
        isWinner = try c.decode(Bool.self, forKey: .isWinner)
        profileID = try? c.decode(UUID.self, forKey: .profileID)
        totalDartsThrown = (try? c.decode(Int.self, forKey: .totalDartsThrown)) ?? 0
        totalPointsScored = (try? c.decode(Int.self, forKey: .totalPointsScored)) ?? 0
        highestCheckout = (try? c.decode(Int.self, forKey: .highestCheckout)) ?? 0
    }
}

struct GameRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let startingScore: Int
    let finishRule: String
    let playerResults: [PlayerGameResult]
}

final class GameHistoryStore: ObservableObject {
    @Published private(set) var records: [GameRecord] = []

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("game_history.json")
    }()

    init() { load() }

    func record(_ game: GameRecord) {
        records.insert(game, at: 0)
        save()
    }

    func clearAll() {
        records = []
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([GameRecord].self, from: data) else { return }
        records = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
