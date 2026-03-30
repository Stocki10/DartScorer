import Foundation

struct Player: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var score: Int
    var colorHex: String?
    var profileID: UUID?

    init(id: UUID = UUID(), name: String, score: Int = 501, colorHex: String? = nil, profileID: UUID? = nil) {
        self.id = id
        self.name = name
        self.score = score
        self.colorHex = colorHex
        self.profileID = profileID
    }
}
