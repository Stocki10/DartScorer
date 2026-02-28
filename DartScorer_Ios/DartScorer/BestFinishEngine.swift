import Foundation

/// Pure checkout engine using pro lookup routes first and heuristic fallback second.
final class BestFinishEngine {
    private let proRoutes: [Int: [String]] = [
        170: ["T20", "T20", "Bull"],
        167: ["T20", "T19", "Bull"],
        164: ["T20", "T18", "Bull"],
        161: ["T20", "T17", "Bull"],
        132: ["Bull", "Bull", "D16"],
        121: ["T20", "T11", "D14"],
        110: ["T20", "T10", "D10"],
        101: ["T20", "S9", "D16"],
        90: ["T18", "D18"],
        85: ["T15", "D20"],
        82: ["Bull", "D16"],
        81: ["T19", "D12"],
        70: ["T18", "D8"],
        69: ["T19", "D6"],
        68: ["T20", "D4"],
        67: ["T17", "D8"],
        66: ["T10", "D18"],
        65: ["T19", "D4"],
        64: ["T16", "D8"],
        63: ["T13", "D12"],
        62: ["T10", "D16"],
        61: ["T15", "D8"],
        56: ["S16", "D20"],
        52: ["S12", "D20"],
        48: ["S16", "D16"],
        44: ["S12", "D16"],
        40: ["D20"],
        38: ["D19"],
        36: ["D18"],
        34: ["D17"],
        32: ["D16"],
        30: ["D15"],
        28: ["D14"],
        26: ["D13"],
        24: ["D12"],
        22: ["D11"],
        20: ["D10"],
        18: ["D9"],
        16: ["D8"],
        14: ["D7"],
        12: ["D6"],
        10: ["D5"],
        8: ["D4"],
        6: ["D3"],
        4: ["D2"],
        2: ["D1"]
    ]

    private let bogeys: Set<Int> = [169, 168, 166, 165, 163, 162, 159]
    private lazy var allTargets: [DartTarget] = {
        var targets: [DartTarget] = []
        for value in 1...20 {
            targets.append(DartTarget(value: value, multiplier: .single))
            targets.append(DartTarget(value: value, multiplier: .double))
            targets.append(DartTarget(value: value, multiplier: .triple))
        }
        targets.append(.outerBull)
        targets.append(.bull)
        return targets
    }()

    private lazy var finishingTargets: [DartTarget] = {
        allTargets.filter(isFinishingTarget(_:))
    }()

    /// Returns the best suggestion for the given score and darts left in hand.
    func getBestFinish(for score: Int, dartsRemaining: Int) -> FinishRoute {
        guard score > 1 else {
            return FinishRoute(darts: [], label: "Invalid", rationale: "Cannot check out 1")
        }
        guard (1...3).contains(dartsRemaining) else {
            return FinishRoute(darts: [], label: "Invalid", rationale: "Darts remaining must be 1...3")
        }

        if score > 170 {
            return setupForHighScore(score: score)
        }

        if bogeys.contains(score) {
            return setupForBogey(score: score)
        }

        if let pro = proRoute(for: score, dartsRemaining: dartsRemaining) {
            return pro
        }

        if let fallback = bestFallbackCheckout(score: score, dartsRemaining: dartsRemaining) {
            return FinishRoute(
                darts: fallback,
                label: "Fallback",
                rationale: "Heuristic route with double-out and preferred doubles."
            )
        }

        if let setup = bestSetupTarget(for: score) {
            return FinishRoute(
                darts: [setup],
                label: "Setup",
                rationale: "No direct finish in \(dartsRemaining) darts. Safe leave selected."
            )
        }

        return FinishRoute(darts: [], label: "Invalid", rationale: "No valid route found.")
    }

    /// Parses a route token such as "T20", "D16", "S9", "25", or "Bull".
    func parseTarget(_ token: String) -> DartTarget? {
        let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if normalized == "BULL" { return .bull }
        if normalized == "25" { return .outerBull }

        if let first = normalized.first {
            let rest = String(normalized.dropFirst())
            switch first {
            case "S":
                guard let value = Int(rest), isValidValue(value, for: .single) else { return nil }
                return DartTarget(value: value, multiplier: .single)
            case "D":
                guard let value = Int(rest), isValidValue(value, for: .double) else { return nil }
                if value == 25 { return .bull }
                return DartTarget(value: value, multiplier: .double)
            case "T":
                guard let value = Int(rest), isValidValue(value, for: .triple) else { return nil }
                return DartTarget(value: value, multiplier: .triple)
            default:
                break
            }
        }

        if let number = Int(normalized), isValidValue(number, for: .single) {
            return DartTarget(value: number, multiplier: .single)
        }

        return nil
    }

    /// Converts route darts to compact scoring tokens for display/testing.
    func routeTokens(_ route: FinishRoute) -> [String] {
        route.darts.map(token(for:))
    }

    /// True when target can legally finish a leg under double-out.
    func isFinishingTarget(_ target: DartTarget) -> Bool {
        target.isBull || (target.multiplier == .double && (1...20).contains(target.value))
    }

    // MARK: - Pro Routes

    private func proRoute(for score: Int, dartsRemaining: Int) -> FinishRoute? {
        guard let tokens = proRoutes[score], tokens.count <= dartsRemaining else { return nil }
        let darts = tokens.compactMap(parseTarget(_:))
        guard darts.count == tokens.count else { return nil }

        var rationale = "Professional preferred route from lookup table."
        if (61...70).contains(score) {
            rationale = "Treble-to-double route; if first dart lands single, recover via bull path."
        } else if score == 132 {
            rationale = "Champagne shot: Bull, Bull, D16."
        } else if [170, 167, 164, 161].contains(score) {
            rationale = "Big Fish finish profile."
        }

        return FinishRoute(darts: darts, label: "Pro Route", rationale: rationale)
    }

    // MARK: - Setup

    private func setupForHighScore(score: Int) -> FinishRoute {
        if score == 195 {
            return FinishRoute(darts: [.outerBull], label: "Setup", rationale: "Leave 170 with 25.")
        }
        if score == 186 {
            return FinishRoute(darts: [DartTarget(value: 19, multiplier: .single)], label: "Setup", rationale: "Leave 167 and avoid 166 bogey.")
        }

        guard let setup = bestSetupTarget(for: score) else {
            return FinishRoute(darts: [], label: "Setup", rationale: "No setup available.")
        }
        let leave = score - setup.total
        return FinishRoute(darts: [setup], label: "Setup", rationale: "Leave \(leave) (<=170, non-bogey).")
    }

    private func setupForBogey(score: Int) -> FinishRoute {
        if score == 169 {
            return FinishRoute(darts: [DartTarget(value: 9, multiplier: .single)], label: "Setup", rationale: "169 is a bogey. S9 leaves 160.")
        }
        if score == 159 {
            return FinishRoute(darts: [DartTarget(value: 19, multiplier: .single)], label: "Setup", rationale: "159 is a bogey. S19 leaves 140.")
        }
        guard let setup = bestSetupTarget(for: score) else {
            return FinishRoute(darts: [], label: "Setup", rationale: "No safe bogey setup available.")
        }
        return FinishRoute(darts: [setup], label: "Setup", rationale: "Bogey avoidance setup.")
    }

    private func bestSetupTarget(for score: Int) -> DartTarget? {
        let candidates = allTargets.filter { target in
            let leave = score - target.total
            return leave > 1 && leave <= 170 && !bogeys.contains(leave)
        }

        return candidates.min { lhs, rhs in
            setupCost(target: lhs, score: score) < setupCost(target: rhs, score: score)
        }
    }

    private func setupCost(target: DartTarget, score: Int) -> Int {
        let leave = score - target.total
        var cost = 0
        cost += abs(leave - 100)
        if leave > 170 { cost += 3_000 }
        if leave <= 1 { cost += 4_000 }
        if bogeys.contains(leave) { cost += 4_000 }
        if leave == 170 { cost -= 600 }
        if leave == 167 { cost -= 300 }
        if target == .outerBull { cost -= 30 }
        if target == DartTarget(value: 19, multiplier: .single) { cost -= 20 }
        return cost
    }

    // MARK: - Fallback search

    private func bestFallbackCheckout(score: Int, dartsRemaining: Int) -> [DartTarget]? {
        var bestRoute: [DartTarget]?
        var bestCost = Int.max
        var bestLength = Int.max

        for length in 1...dartsRemaining {
            var route: [DartTarget] = []
            search(
                score: score,
                dartsLeft: length,
                route: &route,
                bestRoute: &bestRoute,
                bestCost: &bestCost,
                bestLength: &bestLength
            )
        }

        return bestRoute
    }

    private func search(
        score: Int,
        dartsLeft: Int,
        route: inout [DartTarget],
        bestRoute: inout [DartTarget]?,
        bestCost: inout Int,
        bestLength: inout Int
    ) {
        guard dartsLeft > 0, score > 1 else { return }

        if dartsLeft == 1 {
            for finish in finishingTargets where finish.total == score {
                var candidate = route
                candidate.append(finish)
                let cost = routeCost(candidate, startScore: score + route.reduce(0) { $0 + $1.total })
                if cost < bestCost || (cost == bestCost && candidate.count < bestLength) {
                    bestRoute = candidate
                    bestCost = cost
                    bestLength = candidate.count
                }
            }
            return
        }

        for target in allTargets {
            let remaining = score - target.total
            if remaining <= 1 { continue }
            route.append(target)
            search(
                score: remaining,
                dartsLeft: dartsLeft - 1,
                route: &route,
                bestRoute: &bestRoute,
                bestCost: &bestCost,
                bestLength: &bestLength
            )
            route.removeLast()
        }
    }

    private func routeCost(_ route: [DartTarget], startScore: Int) -> Int {
        var cost = 0
        var remaining = startScore

        for (index, dart) in route.enumerated() {
            remaining -= dart.total

            if index < route.count - 1 {
                if remaining <= 1 { cost += 5_000 }
                if bogeys.contains(remaining) { cost += 1_200 }
                if remaining > 170 { cost += 900 }
            }

            if index == 0, (82...95).contains(startScore) {
                if dart.isBull || dart.isOuterBull {
                    cost -= 120
                } else {
                    cost += 40
                }
            }

            if index == 0, dart.multiplier == .triple {
                let missSingleLeave = startScore - dart.value
                if bogeys.contains(missSingleLeave) || missSingleLeave == 1 {
                    cost += 200
                }
            }
        }

        guard let last = route.last else { return Int.max }
        if !(last.isBull || last.multiplier == .double) {
            cost += 10_000
        }

        if isSingleIntoDouble(route: route, startScore: startScore) {
            cost -= 180
        }

        // Professional ranking pass: lower score means better practical route.
        cost += routeScore(route, startScore: startScore) * 40
        cost += route.count * 4
        return cost
    }

    private func routeScore(_ route: [DartTarget], startScore: Int) -> Int {
        guard let final = route.last else { return Int.max / 8 }
        var score = 0

        // Preferred doubles.
        if final.multiplier == .double {
            if final.value == 16 {
                score -= 5
            } else if [8, 4].contains(final.value) {
                score -= 4
            } else if final.value == 20 {
                score -= 3
            } else if [12, 10, 18].contains(final.value) {
                score -= 2
            } else if [1, 2, 3, 5, 6, 7, 9, 13, 15, 17, 19].contains(final.value) {
                score += 4
            }
        }

        // Penalize unnecessary trebles in two-dart finishes.
        if route.count == 2, route[0].multiplier == .triple {
            score += 2
        }

        // Penalize risky misses on dart 1.
        if route.count >= 2, let missLeave = likelyMissLeave(startScore: startScore, aimed: route[0]) {
            if bogeys.contains(missLeave) || (0..<10).contains(missLeave) {
                score += 3
            }
        }

        // Small pro bonus for bull usage in the 82...95 setup zone.
        if (82...95).contains(startScore), let first = route.first, (first.isBull || first.isOuterBull) {
            score -= 1
        }

        return score
    }

    private func likelyMissLeave(startScore: Int, aimed: DartTarget) -> Int? {
        switch aimed.multiplier {
        case .single:
            return nil
        case .double:
            return startScore - aimed.value
        case .triple:
            return startScore - aimed.value
        }
    }

    private func isSingleIntoDouble(route: [DartTarget], startScore: Int) -> Bool {
        guard route.count == 2 else { return false }
        guard route[0].multiplier == .single, route[1].multiplier == .double else { return false }
        return route.reduce(0) { $0 + $1.total } == startScore
    }

    // MARK: - Helpers

    private func isValidValue(_ value: Int, for multiplier: DartMultiplier) -> Bool {
        if value == 25 { return multiplier != .triple }
        return (1...20).contains(value)
    }

    private func token(for target: DartTarget) -> String {
        if target.isBull { return "Bull" }
        if target.isOuterBull { return "25" }
        switch target.multiplier {
        case .single:
            return "S\(target.value)"
        case .double:
            return "D\(target.value)"
        case .triple:
            return "T\(target.value)"
        }
    }
}
