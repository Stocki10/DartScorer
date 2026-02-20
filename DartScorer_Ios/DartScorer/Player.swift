import Foundation

struct Player: Identifiable, Equatable {
    let id: UUID
    var name: String
    var score: Int

    init(id: UUID = UUID(), name: String, score: Int = 501) {
        self.id = id
        self.name = name
        self.score = score
    }
}
