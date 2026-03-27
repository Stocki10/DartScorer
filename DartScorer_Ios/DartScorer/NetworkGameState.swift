import Foundation

// MARK: - Session Enums

enum InputMode: String, Codable, CaseIterable, Identifiable {
    case ownOnly
    case othersOnly
    case free

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ownOnly:    return L10n.string("Own Only")
        case .othersOnly: return L10n.string("Others Only (Referee)")
        case .free:       return L10n.string("Free")
        }
    }

    var explanation: String {
        switch self {
        case .ownOnly:    return L10n.string("You can only enter your own scores")
        case .othersOnly: return L10n.string("You enter scores for your opponent")
        case .free:       return L10n.string("Any player can enter any score")
        }
    }
}

enum UndoPermission: String, Codable, CaseIterable, Identifiable {
    case anyPlayer
    case hostOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .anyPlayer: return L10n.string("Any Player")
        case .hostOnly:  return L10n.string("Host Only")
        }
    }
}

// MARK: - Full Game State Snapshot (wire format)

struct NetworkGameState: Codable {
    let players: [Player]
    let activePlayerIndex: Int
    let currentTurn: Turn
    let winner: Player?
    let setWinner: Player?
    let statusMessage: String?
    let gameMode: String
    let practiceMode: String
    let finishRule: String
    let inRule: String
    let startingScore: Int
    let setModeEnabled: Bool
    let legsToWin: Int
    // UUID-keyed dicts serialised as [String: X] for JSON compatibility
    let legsWonByPlayerID: [String: Int]
    let lastTurnThrowsByPlayerID: [String: [Int]]
    let pointsScoredByPlayerID: [String: Int]
    let dartsThrownByPlayerID: [String: Int]
    let hasOpenedLegByPlayerID: [String: Bool]
    let highestTurnScoreByPlayerID: [String: Int]
    let checkoutOpportunitiesByPlayerID: [String: Int]
    let checkoutConversionsByPlayerID: [String: Int]
    let highestCheckoutByPlayerID: [String: Int]
    let cricketMarksByPlayerID: [String: [String: Int]]
    let cricketScoreByPlayerID: [String: Int]
    let practiceTargetValueByPlayerID: [String: Int]
    let practiceProgressByPlayerID: [String: Int]
}

// MARK: - Session Config (broadcast from host to all peers)

struct SessionConfig: Codable {
    let inputMode: InputMode
    let undoPermission: UndoPermission
    let hostDeviceID: String
    var playerAssignments: [String: [String]]  // deviceID -> [playerID.uuidString]
}

// MARK: - Message Payloads

struct ScoreUpdatePayload: Codable {
    let playerID: String
    let segment: DartSegment
    let multiplier: DartMultiplier
    let turnSequence: Int
}

struct QuickScoreUpdatePayload: Codable {
    let playerID: String
    let score: Int
    let turnSequence: Int
}

struct PlayerAssignmentPayload: Codable {
    let deviceID: String
    let playerIDs: [String]
}

struct TurnLockPayload: Codable {
    let deviceID: String
    let turnSequence: Int
}

// MARK: - Multiplayer Message Envelope

enum MultiplayerMessage: Codable {
    case scoreUpdate(ScoreUpdatePayload)
    case quickScoreUpdate(QuickScoreUpdatePayload)
    case undoRequest(deviceID: String)
    case gameState(NetworkGameState)
    case sessionConfig(SessionConfig)
    case playerAssignment(PlayerAssignmentPayload)
    case profileSync([PlayerProfile])
    case statsUpdate([PlayerProfile])
    case turnLock(TurnLockPayload)
    case turnUnlock
    case gameStarted

    private enum CodingKeys: String, CodingKey { case type, payload }

    private enum Tag: String, Codable {
        case scoreUpdate, quickScoreUpdate, undoRequest, gameState, sessionConfig
        case playerAssignment, profileSync, statsUpdate, turnLock, turnUnlock, gameStarted
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .scoreUpdate(let p):
            try c.encode(Tag.scoreUpdate, forKey: .type); try c.encode(p, forKey: .payload)
        case .quickScoreUpdate(let p):
            try c.encode(Tag.quickScoreUpdate, forKey: .type); try c.encode(p, forKey: .payload)
        case .undoRequest(let id):
            try c.encode(Tag.undoRequest, forKey: .type); try c.encode(id, forKey: .payload)
        case .gameState(let s):
            try c.encode(Tag.gameState, forKey: .type); try c.encode(s, forKey: .payload)
        case .sessionConfig(let s):
            try c.encode(Tag.sessionConfig, forKey: .type); try c.encode(s, forKey: .payload)
        case .playerAssignment(let p):
            try c.encode(Tag.playerAssignment, forKey: .type); try c.encode(p, forKey: .payload)
        case .profileSync(let ps):
            try c.encode(Tag.profileSync, forKey: .type); try c.encode(ps, forKey: .payload)
        case .statsUpdate(let ps):
            try c.encode(Tag.statsUpdate, forKey: .type); try c.encode(ps, forKey: .payload)
        case .turnLock(let p):
            try c.encode(Tag.turnLock, forKey: .type); try c.encode(p, forKey: .payload)
        case .turnUnlock:
            try c.encode(Tag.turnUnlock, forKey: .type)
        case .gameStarted:
            try c.encode(Tag.gameStarted, forKey: .type)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Tag.self, forKey: .type) {
        case .scoreUpdate:      self = .scoreUpdate(try c.decode(ScoreUpdatePayload.self, forKey: .payload))
        case .quickScoreUpdate: self = .quickScoreUpdate(try c.decode(QuickScoreUpdatePayload.self, forKey: .payload))
        case .undoRequest:      self = .undoRequest(deviceID: try c.decode(String.self, forKey: .payload))
        case .gameState:        self = .gameState(try c.decode(NetworkGameState.self, forKey: .payload))
        case .sessionConfig:    self = .sessionConfig(try c.decode(SessionConfig.self, forKey: .payload))
        case .playerAssignment: self = .playerAssignment(try c.decode(PlayerAssignmentPayload.self, forKey: .payload))
        case .profileSync:      self = .profileSync(try c.decode([PlayerProfile].self, forKey: .payload))
        case .statsUpdate:      self = .statsUpdate(try c.decode([PlayerProfile].self, forKey: .payload))
        case .turnLock:         self = .turnLock(try c.decode(TurnLockPayload.self, forKey: .payload))
        case .turnUnlock:       self = .turnUnlock
        case .gameStarted:      self = .gameStarted
        }
    }
}

// MARK: - QR Pairing Payload

struct QRPayload: Codable {
    let token: String       // "DART-XXXX" – session secret
    let peerName: String    // MCPeerID.displayName of the host
}

// MARK: - Profile Merger

struct ProfileMerger {
    /// Merges incoming remote profiles into the local list.
    /// - Matching profiles (same id): keep local color; update stats if remote has more gamesPlayed
    /// - Unknown profiles: appended as guests
    func merge(local: [PlayerProfile], incoming: [PlayerProfile]) -> [PlayerProfile] {
        var result = local
        for remote in incoming {
            if let idx = result.firstIndex(where: { $0.id == remote.id }) {
                if remote.stats.gamesPlayed > result[idx].stats.gamesPlayed {
                    var merged = remote
                    merged.colorHex = result[idx].colorHex  // preserve local color preference
                    result[idx] = merged
                }
            } else {
                result.append(remote)
            }
        }
        return result
    }
}

// MARK: - Dictionary Helpers

extension Dictionary where Key == UUID {
    var stringKeyed: [String: Value] {
        reduce(into: [:]) { $0[$1.key.uuidString] = $1.value }
    }
}

extension Dictionary where Key == String {
    func uuidKeyed() -> [UUID: Value] {
        reduce(into: [:]) { result, pair in
            if let id = UUID(uuidString: pair.key) { result[id] = pair.value }
        }
    }
}

extension Dictionary where Key == UUID, Value == [CricketTarget: Int] {
    var stringKeyedCricketMarks: [String: [String: Int]] {
        reduce(into: [:]) { result, pair in
            result[pair.key.uuidString] = pair.value.reduce(into: [:]) { targetResult, targetPair in
                targetResult["\(targetPair.key.rawValue)"] = targetPair.value
            }
        }
    }
}

extension Dictionary where Key == String, Value == [String: Int] {
    func uuidKeyedCricketMarks() -> [UUID: [CricketTarget: Int]] {
        reduce(into: [:]) { result, pair in
            guard let playerID = UUID(uuidString: pair.key) else { return }
            result[playerID] = pair.value.reduce(into: [:]) { marksResult, markPair in
                guard let rawValue = Int(markPair.key), let target = CricketTarget(rawValue: rawValue) else { return }
                marksResult[target] = markPair.value
            }
        }
    }
}
