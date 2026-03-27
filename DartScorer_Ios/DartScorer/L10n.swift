import Foundation

enum L10n {
    static func string(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: Locale.current, arguments: arguments)
    }

    static func decimal(_ value: Double, fractionDigits: Int = 1) -> String {
        value.formatted(
            .number
                .precision(.fractionLength(fractionDigits))
        )
    }

    static func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

    static func localizedStoredRule(_ value: String) -> String {
        switch value {
        case FinishRule.doubleOut.rawValue:
            return FinishRule.doubleOut.label
        case FinishRule.singleOut.rawValue:
            return FinishRule.singleOut.label
        case InRule.default.rawValue:
            return InRule.default.label
        case InRule.doubleIn.rawValue:
            return InRule.doubleIn.label
        case GameMode.cricket.rawValue:
            return GameMode.cricket.label
        case GameMode.practice.rawValue:
            return GameMode.practice.label
        case GameMode.x01.rawValue:
            return GameMode.x01.label
        default:
            return value
        }
    }
}
