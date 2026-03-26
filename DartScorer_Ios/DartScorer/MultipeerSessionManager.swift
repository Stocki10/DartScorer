import Combine
import Foundation
import MultipeerConnectivity
import UIKit

enum SessionRole { case none, host, joiner }

final class MultipeerSessionManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published private(set) var role: SessionRole = .none
    @Published private(set) var connectedPeers: [MCPeerID] = []
    @Published private(set) var inputMode: InputMode = .free
    @Published private(set) var undoPermission: UndoPermission = .anyPlayer
    @Published private(set) var assignedPlayerIDs: Set<UUID> = []
    @Published private(set) var isReconnecting = false
    @Published private(set) var sessionToken = ""       // "DART-XXXX" for display
    @Published private(set) var gameHasStarted = false
    @Published private(set) var playerAssignments: [String: [String]] = [:]   // deviceID -> [playerID strings]
    @Published private(set) var peerDisplayNames: [String: String] = [:]      // deviceID -> display name
    @Published private(set) var lastDisconnectedPeerName: String? = nil

    // MARK: - Private State

    private(set) var deviceID = UUID().uuidString       // stable for this session
    private weak var game: DartsGame?
    private weak var profileStore: PlayerProfileStore?

    private var mcSession: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var localPeerID = MCPeerID(displayName: UIDevice.current.name)

    private var expectedToken: String?                  // joiner uses this to validate host
    private var expectedHostName: String?               // joiner uses this to find the right peer
    private var cachedGameState: NetworkGameState?      // for reconnect re-send (host only)
    private var lockDeviceID: String?                   // free-mode first-write lock
    private var currentTurnSequence = 0                 // monotonically increasing per turn
    private var peerDeviceIDs: [MCPeerID: String] = [:]       // MCPeerID -> deviceID

    private static let serviceType = "dartscore"

    // MARK: - Configuration

    func configure(game: DartsGame, profileStore: PlayerProfileStore) {
        self.game = game
        self.profileStore = profileStore
    }

    // MARK: - Host API

    func hostSession(inputMode: InputMode, undoPermission: UndoPermission) {
        self.inputMode = inputMode
        self.undoPermission = undoPermission
        lockDeviceID = nil
        currentTurnSequence = 0
        playerAssignments = [:]
        peerDeviceIDs = [:]

        let suffix = String(format: "%04X", Int.random(in: 0..<65536))
        sessionToken = "DART-\(suffix)"

        let session = MCSession(peer: localPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        mcSession = session

        let adv = MCNearbyServiceAdvertiser(peer: localPeerID, discoveryInfo: nil, serviceType: Self.serviceType)
        adv.delegate = self
        adv.startAdvertisingPeer()
        advertiser = adv

        role = .host
    }

    // MARK: - Join API

    func joinSession(qrPayload: String) {
        guard let data = qrPayload.data(using: .utf8),
              let info = try? JSONDecoder().decode(QRPayload.self, from: data) else { return }
        expectedToken = info.token
        expectedHostName = info.peerName
        sessionToken = info.token

        let session = MCSession(peer: localPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        mcSession = session

        let b = MCNearbyServiceBrowser(peer: localPeerID, serviceType: Self.serviceType)
        b.delegate = self
        b.startBrowsingForPeers()
        browser = b

        role = .joiner
    }

    // MARK: - Game Actions (called from DartsGameView)

    func handleThrow(segment: DartSegment, multiplier: DartMultiplier) {
        guard let game = game else { return }
        guard !isInputLocked else { return }

        if role == .none {
            game.submitThrow(segment: segment, multiplier: multiplier)
            return
        }
        if role == .host {
            let prevIdx = game.activePlayerIndex
            game.submitThrow(segment: segment, multiplier: multiplier)
            let turnEnded = game.activePlayerIndex != prevIdx || game.winner != nil
            broadcastAfterHostMutation(turnEnded: turnEnded)
        } else {
            let payload = ScoreUpdatePayload(
                playerID: game.activePlayer.id.uuidString,
                segment: segment,
                multiplier: multiplier,
                turnSequence: currentTurnSequence
            )
            sendToHost(.scoreUpdate(payload))
        }
    }

    func handleUndo() {
        guard let game = game else { return }
        if role == .none {
            game.undoLastThrow(); return
        }
        if role == .host {
            guard canUndoLocally else { return }
            game.undoLastThrow()
            broadcastAfterHostMutation(turnEnded: false)
        } else {
            if canUndoLocally { sendToHost(.undoRequest(deviceID: deviceID)) }
        }
    }

    func handleRestartLeg() {
        guard let game = game else { return }
        if role == .none {
            game.restartLeg()
            return
        }
        guard role == .host else { return }
        game.restartLeg()
        broadcastAfterHostMutation(turnEnded: true)
    }

    func updateSessionConfig(inputMode: InputMode, undoPermission: UndoPermission) {
        guard role == .host else { return }
        self.inputMode = inputMode
        self.undoPermission = undoPermission
        broadcastSessionConfig()
    }

    func setPlayerAssignment(playerID: UUID, toDeviceID: String) {
        guard role == .host else { return }
        let pidStr = playerID.uuidString
        for key in playerAssignments.keys {
            playerAssignments[key] = playerAssignments[key]?.filter { $0 != pidStr }
        }
        if !toDeviceID.isEmpty {
            if playerAssignments[toDeviceID] == nil { playerAssignments[toDeviceID] = [] }
            playerAssignments[toDeviceID]?.append(pidStr)
        }
        assignedPlayerIDs = Set((playerAssignments[deviceID] ?? []).compactMap { UUID(uuidString: $0) })
        broadcastSessionConfig()
    }

    func endSession() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        mcSession?.disconnect()
        advertiser = nil; browser = nil; mcSession = nil
        role = .none
        connectedPeers = []
        lockDeviceID = nil
        currentTurnSequence = 0
        isReconnecting = false
        cachedGameState = nil
        playerAssignments = [:]
        peerDeviceIDs = [:]
        peerDisplayNames = [:]
        lastDisconnectedPeerName = nil
        sessionToken = ""
        gameHasStarted = false
    }

    // MARK: - Post-Game

    func broadcastStatsUpdate() {
        guard role == .host, let profiles = profileStore?.profiles else { return }
        broadcastMessage(.statsUpdate(profiles))
    }

    func handleNewLeg() {
        guard role == .host else { return }
        broadcastAfterHostMutation(turnEnded: true)
    }

    func broadcastGameStarted() {
        guard role == .host else { return }
        gameHasStarted = true
        broadcastMessage(.gameStarted)
    }

    // MARK: - Computed

    var isActive: Bool { role != .none }

    var canUndoLocally: Bool {
        undoPermission == .anyPlayer || role == .host
    }

    var isInputLocked: Bool {
        guard let game = game, role != .none else { return false }
        let activeID = game.activePlayer.id
        let isMyPlayer = assignedPlayerIDs.contains(activeID)
        switch inputMode {
        case .ownOnly:
            guard !assignedPlayerIDs.isEmpty else { return false }
            return !isMyPlayer
        case .othersOnly:
            guard !assignedPlayerIDs.isEmpty else { return false }
            return isMyPlayer
        case .free:
            if let holder = lockDeviceID { return holder != deviceID }
            return false
        }
    }

    var qrPayload: String? {
        guard role == .host else { return nil }
        let info = QRPayload(token: sessionToken, peerName: localPeerID.displayName)
        guard let data = try? JSONEncoder().encode(info),
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    // MARK: - Private Helpers

    private func broadcastAfterHostMutation(turnEnded: Bool) {
        guard let snapshot = game?.buildNetworkSnapshot() else { return }
        cachedGameState = snapshot
        if turnEnded && inputMode == .free {
            lockDeviceID = nil
            currentTurnSequence += 1
            broadcastMessage(.turnUnlock)
        }
        broadcastMessage(.gameState(snapshot))
    }

    private func broadcastSessionConfig() {
        guard role == .host else { return }
        let config = SessionConfig(
            inputMode: inputMode,
            undoPermission: undoPermission,
            hostDeviceID: deviceID,
            playerAssignments: playerAssignments
        )
        broadcastMessage(.sessionConfig(config))
    }

    private func broadcastMessage(_ msg: MultiplayerMessage) {
        guard let s = mcSession, !s.connectedPeers.isEmpty else { return }
        send(msg, to: s.connectedPeers)
    }

    private func sendToHost(_ msg: MultiplayerMessage) {
        guard role == .joiner, let s = mcSession, let host = s.connectedPeers.first else { return }
        send(msg, to: [host])
    }

    private func send(_ msg: MultiplayerMessage, to peers: [MCPeerID]) {
        guard let s = mcSession, let data = try? JSONEncoder().encode(msg) else { return }
        do { try s.send(data, toPeers: peers, with: .reliable) }
        catch { print("[Multiplayer] Send error: \(error)") }
    }

    private func handleReceived(_ msg: MultiplayerMessage, from peer: MCPeerID) {
        switch msg {

        case .scoreUpdate(let payload):
            guard role == .host, let game = game else { return }
            guard payload.turnSequence == currentTurnSequence else { return }
            let peerDID = peerDeviceIDs[peer] ?? peer.displayName
            let peerPlayers = Set((playerAssignments[peerDID] ?? []).compactMap { UUID(uuidString: $0) })
            let activeID = game.activePlayer.id
            switch inputMode {
            case .ownOnly:    guard peerPlayers.contains(activeID) else { return }
            case .othersOnly: guard !peerPlayers.contains(activeID) else { return }
            case .free:
                if let holder = lockDeviceID, holder != peerDID { return }
                if lockDeviceID == nil {
                    lockDeviceID = peerDID
                    broadcastMessage(.turnLock(TurnLockPayload(deviceID: peerDID, turnSequence: currentTurnSequence)))
                }
            }
            let prevIdx = game.activePlayerIndex
            game.submitThrow(segment: payload.segment, multiplier: payload.multiplier)
            let turnEnded = game.activePlayerIndex != prevIdx || game.winner != nil
            broadcastAfterHostMutation(turnEnded: turnEnded)

        case .undoRequest:
            guard role == .host, let game = game else { return }
            guard undoPermission == .anyPlayer else { return }
            game.undoLastThrow()
            broadcastAfterHostMutation(turnEnded: false)

        case .gameState(let state):
            guard role == .joiner else { return }
            DispatchQueue.main.async { [weak self] in
                self?.game?.applySnapshot(state)
                self?.cachedGameState = state
                self?.isReconnecting = false
            }

        case .sessionConfig(let config):
            guard role == .joiner else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.inputMode = config.inputMode
                self.undoPermission = config.undoPermission
                let myIDs = config.playerAssignments[self.deviceID] ?? []
                self.assignedPlayerIDs = Set(myIDs.compactMap { UUID(uuidString: $0) })
            }

        case .playerAssignment(let payload):
            guard role == .host else { return }
            peerDeviceIDs[peer] = payload.deviceID
            peerDisplayNames[payload.deviceID] = peer.displayName
            // Only overwrite assignments when payload has content; empty = device registration only
            if !payload.playerIDs.isEmpty || playerAssignments[payload.deviceID] == nil {
                playerAssignments[payload.deviceID] = payload.playerIDs
            }
            broadcastSessionConfig()

        case .profileSync:
            break  // profile sync disabled; guests manage profiles locally

        case .statsUpdate(let profiles):
            guard role == .joiner else { return }
            DispatchQueue.main.async { [weak self] in
                guard let store = self?.profileStore else { return }
                store.replaceAll(ProfileMerger().merge(local: store.profiles, incoming: profiles))
            }

        case .turnLock(let payload):
            guard role == .joiner else { return }
            guard payload.turnSequence == currentTurnSequence else { return }
            DispatchQueue.main.async { [weak self] in self?.lockDeviceID = payload.deviceID }

        case .turnUnlock:
            DispatchQueue.main.async { [weak self] in
                self?.lockDeviceID = nil
                self?.currentTurnSequence += 1
            }

        case .gameStarted:
            guard role == .joiner else { return }
            DispatchQueue.main.async { [weak self] in self?.gameHasStarted = true }
        }
    }
}

// MARK: - MCSessionDelegate

extension MultipeerSessionManager: MCSessionDelegate {
    func session(_ session: MCSession, peer: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch state {
            case .connected:
                if !self.connectedPeers.contains(peer) { self.connectedPeers.append(peer) }
                self.isReconnecting = false
                if self.role == .host {
                    // Send session config + current game state to newly connected peer
                    self.broadcastSessionConfig()
                    if let snapshot = self.cachedGameState ?? self.game?.buildNetworkSnapshot() {
                        self.send(.gameState(snapshot), to: [peer])
                    }
                } else if self.role == .joiner {
                    // Auto-register this device with the host so it appears in player assignment UI
                    let reg = PlayerAssignmentPayload(deviceID: self.deviceID, playerIDs: [])
                    self.sendToHost(.playerAssignment(reg))
                }
            case .notConnected:
                self.connectedPeers.removeAll { $0 == peer }
                if self.role == .host && self.connectedPeers.isEmpty && self.gameHasStarted {
                    // All guests left — end the session but keep the peer name for the alert
                    let leavingName = peer.displayName
                    self.endSession()
                    self.lastDisconnectedPeerName = leavingName
                } else {
                    self.lastDisconnectedPeerName = peer.displayName
                    if !self.connectedPeers.isEmpty || self.role == .joiner {
                        self.isReconnecting = true
                    }
                }
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peer: MCPeerID) {
        guard let msg = try? JSONDecoder().decode(MultiplayerMessage.self, from: data) else {
            print("[Multiplayer] Failed to decode message from \(peer.displayName)")
            return
        }
        DispatchQueue.main.async { [weak self] in self?.handleReceived(msg, from: peer) }
    }

    func session(_ session: MCSession, didReceive stream: InputStream,
                 withName streamName: String, fromPeer peer: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                 fromPeer peer: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peer: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerSessionManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peer: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Validate that the joiner knows the session token
        let theirToken = context.flatMap { String(data: $0, encoding: .utf8) }
        let valid = theirToken == sessionToken
        invitationHandler(valid, valid ? mcSession : nil)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerSessionManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peer: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        guard peer.displayName == expectedHostName else { return }
        let context = expectedToken?.data(using: .utf8)
        browser.invitePeer(peer, to: mcSession!, withContext: context, timeout: 30)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peer: MCPeerID) {}
}
