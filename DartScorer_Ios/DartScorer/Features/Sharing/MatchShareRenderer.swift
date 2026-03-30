import SwiftUI

@MainActor
enum MatchShareRenderer {
    static func shareItems(for record: GameRecord) -> [Any] {
        let summary = MatchShareSummary(record: record)
        return shareItems(for: summary)
    }

    static func shareItems(for summary: MatchShareSummary, layout: MatchShareCardLayout = .verticalSocial) -> [Any] {
        var items: [Any] = [summary.textSummary]

        let renderer = ImageRenderer(content: MatchShareCardView(summary: summary, layout: layout))
        renderer.scale = 2
        if let image = renderer.uiImage {
            items.insert(image, at: 0)
        }

        return items
    }
}
