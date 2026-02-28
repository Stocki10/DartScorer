import Foundation

enum DartMultiplier: Int, CaseIterable, Identifiable, Codable {
    case single = 1
    case double = 2
    case triple = 3

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .single:
            return "Single"
        case .double:
            return "Double"
        case .triple:
            return "Triple"
        }
    }
}

enum DartSegment: Equatable {
    case number(Int)
    case bull

    var baseValue: Int {
        switch self {
        case .number(let value):
            return value
        case .bull:
            return 25
        }
    }

    var label: String {
        switch self {
        case .number(let value):
            return "\(value)"
        case .bull:
            return "Bull"
        }
    }
}

struct DartThrow: Equatable {
    let segment: DartSegment
    let multiplier: DartMultiplier

    init?(segment: DartSegment, multiplier: DartMultiplier) {
        guard Self.isValid(segment: segment, multiplier: multiplier) else {
            return nil
        }
        self.segment = segment
        self.multiplier = multiplier
    }

    static func isValid(segment: DartSegment, multiplier: DartMultiplier) -> Bool {
        switch segment {
        case .number(let value):
            return (0...20).contains(value)
        case .bull:
            return multiplier != .triple
        }
    }

    var points: Int {
        segment.baseValue * multiplier.rawValue
    }

    var isDouble: Bool {
        multiplier == .double
    }

    var displayText: String {
        "\(multiplier.label) \(segment.label) (\(points))"
    }
}
