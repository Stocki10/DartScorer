import Foundation

struct SetupPlayer: Identifiable, Equatable {
    let id: UUID
    var name: String
    var defaultName: String
    var colorHex: String?
    var profileID: UUID?

    init(id: UUID = UUID(), name: String, defaultName: String, colorHex: String? = nil, profileID: UUID? = nil) {
        self.id = id
        self.name = name
        self.defaultName = defaultName
        self.colorHex = colorHex
        self.profileID = profileID
    }
}

struct ProfilePickerTarget: Identifiable {
    let id: UUID
}
