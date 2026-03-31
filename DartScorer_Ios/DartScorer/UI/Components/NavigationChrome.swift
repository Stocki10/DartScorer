import SwiftUI

struct ToolbarBackButton: View {
    let action: () -> Void
    var systemImage: String = "chevron.left"
    var accessibilityLabel: LocalizedStringKey = "Back"
    private var accentColor: Color { AppAccentColor.currentColor }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(accentColor)
                .padding(10)
                .background(
                    Circle()
                        .fill(accentColor.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}
