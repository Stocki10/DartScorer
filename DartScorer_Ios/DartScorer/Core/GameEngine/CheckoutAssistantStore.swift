import Foundation
import Combine

/// Reactive MVVM store that recomputes checkout guidance after every throw.
final class CheckoutAssistantStore: ObservableObject {
    @Published private(set) var currentScore: Int = 501
    @Published private(set) var dartsRemaining: Int = 3
    @Published private(set) var suggestion: FinishRoute?
    @Published private(set) var didBustLastThrow: Bool = false

    private let engine = BestFinishEngine()
    private var turnStartScore: Int = 501
    private var history: [Snapshot] = []

    func startLeg(startingAt score: Int = 501) {
        currentScore = score
        turnStartScore = score
        dartsRemaining = 3
        didBustLastThrow = false
        history.removeAll()
        suggestion = engine.getBestFinish(for: score, dartsRemaining: 3)
    }

    /// Records a throw by points only (no segment/multiplier validation).
    func recordThrow(pointsHit: Int) {
        guard dartsRemaining > 0, currentScore > 1 else { return }
        recordSnapshot()
        didBustLastThrow = false

        let proposed = currentScore - pointsHit
        if proposed < 0 || proposed == 1 {
            bustTurn()
            return
        }
        if proposed == 0 {
            currentScore = 0
            dartsRemaining = 0
            suggestion = nil
            return
        }

        currentScore = proposed
        dartsRemaining -= 1
        finishOrAdvanceTurn()
    }

    /// Records a throw using the exact board target (recommended for strict double-out handling).
    func recordThrow(target: DartTarget) {
        guard dartsRemaining > 0, currentScore > 1 else { return }
        recordSnapshot()
        didBustLastThrow = false

        let proposed = currentScore - target.total
        if proposed < 0 || proposed == 1 || (proposed == 0 && !engine.isFinishingTarget(target)) {
            bustTurn()
            return
        }
        if proposed == 0 {
            currentScore = 0
            dartsRemaining = 0
            suggestion = nil
            return
        }

        currentScore = proposed
        dartsRemaining -= 1
        finishOrAdvanceTurn()
    }

    func resetLeg() {
        startLeg()
    }

    func undoLastThrow() {
        guard let previous = history.popLast() else { return }
        currentScore = previous.currentScore
        dartsRemaining = previous.dartsRemaining
        suggestion = previous.suggestion
        didBustLastThrow = previous.didBustLastThrow
        turnStartScore = previous.turnStartScore
    }

    private func finishOrAdvanceTurn() {
        if dartsRemaining == 0 {
            dartsRemaining = 3
            turnStartScore = currentScore
        }
        suggestion = currentScore > 1 ? engine.getBestFinish(for: currentScore, dartsRemaining: dartsRemaining) : nil
    }

    private func bustTurn() {
        currentScore = turnStartScore
        dartsRemaining = 3
        didBustLastThrow = true
        suggestion = engine.getBestFinish(for: currentScore, dartsRemaining: dartsRemaining)
    }

    private func recordSnapshot() {
        history.append(
            Snapshot(
                currentScore: currentScore,
                dartsRemaining: dartsRemaining,
                suggestion: suggestion,
                didBustLastThrow: didBustLastThrow,
                turnStartScore: turnStartScore
            )
        )
    }

    private struct Snapshot {
        let currentScore: Int
        let dartsRemaining: Int
        let suggestion: FinishRoute?
        let didBustLastThrow: Bool
        let turnStartScore: Int
    }
}
