import Foundation

struct Turn: Equatable {
    let startingScore: Int
    let openedAtTurnStart: Bool
    var darts: [DartThrow]

    init(startingScore: Int, openedAtTurnStart: Bool = true, darts: [DartThrow] = []) {
        self.startingScore = startingScore
        self.openedAtTurnStart = openedAtTurnStart
        self.darts = darts
    }

    var dartsUsed: Int {
        darts.count
    }

    var dartsRemaining: Int {
        max(0, 3 - dartsUsed)
    }
}
