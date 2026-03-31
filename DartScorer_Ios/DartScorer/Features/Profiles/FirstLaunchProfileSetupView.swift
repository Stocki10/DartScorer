import SwiftUI

struct FirstLaunchProfileSetupView: View {
    let onCreate: (String, String) -> Void
    let onSkip: () -> Void

    @State private var name = ""
    @State private var color: Color = AppAccentColor.currentColor

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.string("Create your player profile"))
                        .font(.largeTitle.bold())
                    Text(L10n.string("Track your stats and use your profile in new games."))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.string("Your name"))
                            .font(.subheadline.weight(.semibold))
                        TextField(L10n.string("Name"), text: $name)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.string("Color"))
                            .font(.subheadline.weight(.semibold))

                        HStack(spacing: 14) {
                            Circle()
                                .fill(color)
                                .frame(width: 44, height: 44)

                            ColorPicker(L10n.string("Profile Color"), selection: $color, supportsOpacity: false)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        onCreate(trimmedName, color.hexString)
                    } label: {
                        Text(L10n.string("Create Profile"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(trimmedName.isEmpty)

                    Button(L10n.string("Skip for now"), action: onSkip)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }
}
