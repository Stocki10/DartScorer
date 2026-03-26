import SwiftUI

struct WinnerOverlayView: View {
    let winnerName: String
    let title: String
    let subtitle: String
    let showNewLeg: Bool
    let canUndo: Bool
    let canUndoLocally: Bool
    let onNewLegRandom: (() -> Void)?
    let onNewGame: (() -> Void)?
    let onUndo: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.96)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)
                Text(winnerName)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .foregroundStyle(.secondary)

                if onNewLegRandom != nil || onNewGame != nil {
                    HStack(spacing: 12) {
                        if showNewLeg, let onNewLegRandom {
                            Button("New Leg (Random)", action: onNewLegRandom)
                                .buttonStyle(.borderedProminent)
                        }

                        if let onNewGame {
                            Button(showNewLeg ? "New Game" : "Start New Game", action: onNewGame)
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(.bordered)
            .disabled(!canUndo || !canUndoLocally)
            .padding(.top, 12)
            .padding(.trailing, 12)
        }
    }
}
