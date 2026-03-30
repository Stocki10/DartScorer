import SwiftUI
import UIKit

enum AppAccentColor {
    static let defaultRed: Double = 0.0
    static let defaultGreen: Double = 122.0 / 255.0
    static let defaultBlue: Double = 1.0

    static func makeColor(red: Double, green: Double, blue: Double) -> Color {
        Color(
            red: red.clamped(to: 0...1),
            green: green.clamped(to: 0...1),
            blue: blue.clamped(to: 0...1)
        )
    }

    static func components(from color: Color) -> (red: Double, green: Double, blue: Double) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return (Double(red), Double(green), Double(blue))
        }
        return (defaultRed, defaultGreen, defaultBlue)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

