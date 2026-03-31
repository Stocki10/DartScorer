import SwiftUI

struct SettingsPopupView: View {
    @Binding var themeMode: AppThemeMode
    @Binding var accentColor: Color

    let onSave: () -> Void
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isVisible = false

    var body: some View {
        ZStack {
            Color.black.opacity(backdropOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }

            VStack(spacing: 0) {
                HStack {
                    Text("Settings")
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)

                    Spacer()

                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.semibold))
                            .padding(8)
                            .background(Color(.tertiarySystemFill), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close settings")
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 10)

                Divider()
                    .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Theme", systemImage: "moon.fill")
                        Spacer(minLength: 12)
                        Picker("Theme", selection: $themeMode) {
                            ForEach(AppThemeMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 180)
                    }

                    HStack {
                        Label("Color", systemImage: "paintpalette.fill")
                        Spacer(minLength: 12)
                        ColorPicker("Accent Color", selection: $accentColor, supportsOpacity: false)
                            .labelsHidden()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()
                    .padding(.horizontal, 20)

                HStack(spacing: 12) {
                    Button("Cancel") {
                        onClose()
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)

                    Button("Save") {
                        onSave()
                        onClose()
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(AppAccentColor.currentColor)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .frame(maxWidth: 420)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(.separator).opacity(colorScheme == .dark ? 0.28 : 0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.14 : 0.08), radius: 10, x: 0, y: 4)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.06 : 0.03), radius: 2, x: 0, y: 1)
            .padding(.horizontal, 24)
            .offset(y: isVisible ? 0 : 14)
            .opacity(isVisible ? 1.0 : 0.0)
            .transition(.opacity)
            .animation(.easeOut(duration: 0.22), value: isVisible)
        }
        .onAppear {
            isVisible = true
        }
        .onDisappear {
            isVisible = false
        }
    }

    private var backdropOpacity: Double {
        colorScheme == .dark ? 0.24 : 0.18
    }
}

private struct SettingsPopupPreviewHost: View {
    @State private var themeMode: AppThemeMode
    @State private var accentColor: Color
    private let preferredScheme: ColorScheme?

    init(themeMode: AppThemeMode, preferredScheme: ColorScheme?) {
        _themeMode = State(initialValue: themeMode)
        _accentColor = State(
            initialValue: AppAccentColor.makeColor(
                red: AppAccentColor.defaultRed,
                green: AppAccentColor.defaultGreen,
                blue: AppAccentColor.defaultBlue
            )
        )
        self.preferredScheme = preferredScheme
    }

    var body: some View {
        SettingsPopupView(
            themeMode: $themeMode,
            accentColor: $accentColor,
            onSave: {},
            onClose: {}
        )
        .preferredColorScheme(preferredScheme)
    }
}

struct SettingsPopupView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SettingsPopupPreviewHost(
                themeMode: .light,
                preferredScheme: .light
            )
            .previewDisplayName("Light")

            SettingsPopupPreviewHost(
                themeMode: .dark,
                preferredScheme: .dark
            )
            .previewDisplayName("Dark")
        }
    }
}
