import Foundation
import Combine

struct LegPlayerVisit: Identifiable, Codable {
    let id: String
    let playerID: UUID
    let visitNumber: Int
    let score: Int
    let isBust: Bool

    enum CodingKeys: String, CodingKey {
        case playerID, visitNumber, score, isBust
    }

    init(playerID: UUID, visitNumber: Int, score: Int, isBust: Bool) {
        self.playerID = playerID
        self.visitNumber = visitNumber
        self.score = score
        self.isBust = isBust
        self.id = "\(playerID.uuidString)-\(visitNumber)"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let decodedPlayerID = try c.decode(UUID.self, forKey: .playerID)
        let decodedVisitNumber = (try? c.decode(Int.self, forKey: .visitNumber)) ?? 0
        playerID = decodedPlayerID
        visitNumber = decodedVisitNumber
        score = (try? c.decode(Int.self, forKey: .score)) ?? 0
        isBust = (try? c.decode(Bool.self, forKey: .isBust)) ?? false
        id = "\(decodedPlayerID.uuidString)-\(decodedVisitNumber)"
    }
}

struct LegPlayerResult: Identifiable, Codable {
    let id: UUID
    let playerID: UUID
    let name: String
    let dartsThrown: Int
    let pointsScored: Int
    let average: Double
    let firstNineAverage: Double?
    let highestFinish: Int
    let highestTurnScore: Int
    let bustCount: Int

    enum CodingKeys: String, CodingKey {
        case playerID, name, dartsThrown, pointsScored, average
        case firstNineAverage, highestFinish, highestTurnScore, bustCount
    }

    init(
        playerID: UUID,
        name: String,
        dartsThrown: Int,
        pointsScored: Int,
        average: Double,
        firstNineAverage: Double?,
        highestFinish: Int,
        highestTurnScore: Int,
        bustCount: Int
    ) {
        self.id = playerID
        self.playerID = playerID
        self.name = name
        self.dartsThrown = dartsThrown
        self.pointsScored = pointsScored
        self.average = average
        self.firstNineAverage = firstNineAverage
        self.highestFinish = highestFinish
        self.highestTurnScore = highestTurnScore
        self.bustCount = bustCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let decodedPlayerID = try c.decode(UUID.self, forKey: .playerID)
        playerID = decodedPlayerID
        id = decodedPlayerID
        name = try c.decode(String.self, forKey: .name)
        dartsThrown = (try? c.decode(Int.self, forKey: .dartsThrown)) ?? 0
        pointsScored = (try? c.decode(Int.self, forKey: .pointsScored)) ?? 0
        average = (try? c.decode(Double.self, forKey: .average)) ?? 0.0
        firstNineAverage = try? c.decode(Double.self, forKey: .firstNineAverage)
        highestFinish = (try? c.decode(Int.self, forKey: .highestFinish)) ?? 0
        highestTurnScore = (try? c.decode(Int.self, forKey: .highestTurnScore)) ?? 0
        bustCount = (try? c.decode(Int.self, forKey: .bustCount)) ?? 0
    }
}

struct LegRecord: Identifiable, Codable {
    let id: Int
    let legNumber: Int
    let startingPlayerID: UUID
    let winnerPlayerID: UUID
    let checkoutScore: Int?
    let winningCheckoutRoute: String?
    let playerVisits: [LegPlayerVisit]
    let playerResults: [LegPlayerResult]

    enum CodingKeys: String, CodingKey {
        case legNumber, startingPlayerID, winnerPlayerID, checkoutScore
        case winningCheckoutRoute, playerVisits, playerResults
    }

    init(
        legNumber: Int,
        startingPlayerID: UUID,
        winnerPlayerID: UUID,
        checkoutScore: Int?,
        winningCheckoutRoute: String?,
        playerVisits: [LegPlayerVisit],
        playerResults: [LegPlayerResult]
    ) {
        self.id = legNumber
        self.legNumber = legNumber
        self.startingPlayerID = startingPlayerID
        self.winnerPlayerID = winnerPlayerID
        self.checkoutScore = checkoutScore
        self.winningCheckoutRoute = winningCheckoutRoute
        self.playerVisits = playerVisits
        self.playerResults = playerResults
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        legNumber = (try? c.decode(Int.self, forKey: .legNumber)) ?? 0
        id = legNumber
        startingPlayerID = try c.decode(UUID.self, forKey: .startingPlayerID)
        winnerPlayerID = try c.decode(UUID.self, forKey: .winnerPlayerID)
        checkoutScore = try? c.decode(Int.self, forKey: .checkoutScore)
        winningCheckoutRoute = try? c.decode(String.self, forKey: .winningCheckoutRoute)
        playerVisits = (try? c.decode([LegPlayerVisit].self, forKey: .playerVisits)) ?? []
        playerResults = (try? c.decode([LegPlayerResult].self, forKey: .playerResults)) ?? []
    }
}

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
    let legs: [LegRecord]

    enum CodingKeys: String, CodingKey {
        case id, date, startingScore, finishRule, playerResults, legs
    }

    init(
        id: UUID,
        date: Date,
        startingScore: Int,
        finishRule: String,
        playerResults: [PlayerGameResult],
        legs: [LegRecord]
    ) {
        self.id = id
        self.date = date
        self.startingScore = startingScore
        self.finishRule = finishRule
        self.playerResults = playerResults
        self.legs = legs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        startingScore = try c.decode(Int.self, forKey: .startingScore)
        finishRule = try c.decode(String.self, forKey: .finishRule)
        playerResults = try c.decode([PlayerGameResult].self, forKey: .playerResults)
        legs = (try? c.decode([LegRecord].self, forKey: .legs)) ?? []
    }
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
