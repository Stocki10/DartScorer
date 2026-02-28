import SwiftUI

struct SettingsPopupView: View {
    @Binding var themeMode: AppThemeMode

    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isVisible = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.30)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            VStack(spacing: 0) {
                HStack {
                    Text("Settings")
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)

                    Spacer()

                    Button {
                        dismiss()
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
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()
                    .padding(.horizontal, 20)

                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)

                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(.accentColor)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .frame(maxWidth: 420)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 8)
            .padding(.horizontal, 24)
            .scaleEffect(isVisible ? 1.0 : 0.94)
            .opacity(isVisible ? 1.0 : 0.0)
            .transition(.scale.combined(with: .opacity))
            .animation(.easeOut(duration: 0.22), value: isVisible)
        }
        .onAppear {
            isVisible = true
        }
        .onDisappear {
            isVisible = false
        }
    }
}

private struct SettingsPopupPreviewHost: View {
    @State private var themeMode: AppThemeMode
    private let preferredScheme: ColorScheme?

    init(themeMode: AppThemeMode, preferredScheme: ColorScheme?) {
        _themeMode = State(initialValue: themeMode)
        self.preferredScheme = preferredScheme
    }

    var body: some View {
        SettingsPopupView(
            themeMode: $themeMode,
            onSave: {}
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
