import Foundation

/// A single target on a dartboard.
struct DartTarget: Codable, Identifiable, Hashable {
    let value: Int
    let multiplier: DartMultiplier

    var id: String { "\(multiplier.rawValue)-\(value)" }

    var total: Int {
        if value == 25 && multiplier == .double { return 50 }
        return value * multiplier.rawValue
    }

    var label: String {
        if isBull { return "Bull" }
        if isOuterBull { return "25" }
        switch multiplier {
        case .single:
            return "\(value)"
        case .double:
            return "D\(value)"
        case .triple:
            return "T\(value)"
        }
    }

    var isOuterBull: Bool {
        value == 25 && multiplier == .single
    }

    var isBull: Bool {
        value == 25 && multiplier == .double
    }

    static let outerBull = DartTarget(value: 25, multiplier: .single)
    static let bull = DartTarget(value: 25, multiplier: .double)
}

/// Suggested checkout sequence and metadata.
struct FinishRoute: Codable, Identifiable {
    let darts: [DartTarget]
    let label: String
    let rationale: String

    var id: String {
        let sequence = darts.map(\.label).joined(separator: "-")
        return "\(label)|\(sequence)|\(rationale)"
    }
}
