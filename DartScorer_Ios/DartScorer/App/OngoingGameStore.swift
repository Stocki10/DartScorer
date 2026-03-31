import Foundation

struct PersistedOngoingGameSession: Codable {
    let snapshot: PersistedDartsGameSnapshot
    let tournamentContext: TournamentMatchLaunchContext?
    let savedAt: Date
}

final class OngoingGameStore {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.fileURL = docs.appendingPathComponent("ongoing-game.json")
        }
    }

    func load() -> PersistedOngoingGameSession? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(PersistedOngoingGameSession.self, from: data)
    }

    func save(_ session: PersistedOngoingGameSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
