import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            DartsGameView()
                .navigationTitle("DartScorer")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
