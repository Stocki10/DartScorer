import Foundation

struct Turn: Equatable {
    let startingScore: Int
    var darts: [DartThrow]

    init(startingScore: Int, darts: [DartThrow] = []) {
        self.startingScore = startingScore
        self.darts = darts
    }

    var dartsUsed: Int {
        darts.count
    }

    var dartsRemaining: Int {
        max(0, 3 - dartsUsed)
    }
}
