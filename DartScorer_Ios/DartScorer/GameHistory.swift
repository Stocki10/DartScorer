import Foundation
import Combine

struct PlayerGameResult: Codable, Identifiable {
    let id: UUID
    let name: String
    let average: Double
    let highestTurnScore: Int
    let checkoutPercentage: Double?
    let isWinner: Bool
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
