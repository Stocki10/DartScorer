import Foundation

enum GameModeHistoryFilter: String, CaseIterable, Identifiable {
    case all
    case x01
    case cricket
    case practice

    nonisolated var id: String { rawValue }

    nonisolated var label: String {
        switch self {
        case .all:
            return L10n.string("All")
        case .x01:
            return GameMode.x01.label
        case .cricket:
            return GameMode.cricket.label
        case .practice:
            return GameMode.practice.label
        }
    }

    nonisolated fileprivate func includes(_ record: GameRecord) -> Bool {
        switch self {
        case .all:
            return true
        case .x01:
            return record.isX01Record
        case .cricket:
            return record.isCricketRecord
        case .practice:
            return record.isPracticeRecord
        }
    }
}

enum GameDateFilter: String, CaseIterable, Identifiable {
    case last7Days
    case last30Days
    case last90Days
    case allTime
    case custom

    nonisolated var id: String { rawValue }

    nonisolated var label: String {
        switch self {
        case .last7Days:
            return L10n.string("7d")
        case .last30Days:
            return L10n.string("30d")
        case .last90Days:
            return L10n.string("90d")
        case .allTime:
            return L10n.string("All")
        case .custom:
            return L10n.string("Custom")
        }
    }
}

struct GameRecordFilter: Equatable {
    var mode: GameModeHistoryFilter = .all
    var date: GameDateFilter = .allTime
    var customStartDate: Date = Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date()
    var customEndDate: Date = Date()

    nonisolated init(
        mode: GameModeHistoryFilter = .all,
        date: GameDateFilter = .allTime,
        customStartDate: Date = Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date(),
        customEndDate: Date = Date()
    ) {
        self.mode = mode
        self.date = date
        self.customStartDate = customStartDate
        self.customEndDate = customEndDate
    }

    nonisolated var isUnfiltered: Bool {
        mode == .all && date == .allTime
    }

    nonisolated func includes(_ record: GameRecord, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        mode.includes(record) && dateIncludes(record.date, now: now, calendar: calendar)
    }

    nonisolated func filteredRecords(from records: [GameRecord], now: Date = Date(), calendar: Calendar = .current) -> [GameRecord] {
        records.filter { includes($0, now: now, calendar: calendar) }
    }

    nonisolated private func dateIncludes(_ dateToCheck: Date, now: Date, calendar: Calendar) -> Bool {
        switch date {
        case .allTime:
            return true
        case .last7Days:
            return contains(dateToCheck, startOffsetDays: 6, now: now, calendar: calendar)
        case .last30Days:
            return contains(dateToCheck, startOffsetDays: 29, now: now, calendar: calendar)
        case .last90Days:
            return contains(dateToCheck, startOffsetDays: 89, now: now, calendar: calendar)
        case .custom:
            let start = calendar.startOfDay(for: min(customStartDate, customEndDate))
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: max(customStartDate, customEndDate))) ?? max(customStartDate, customEndDate)
            return dateToCheck >= start && dateToCheck < end
        }
    }

    nonisolated private func contains(_ dateToCheck: Date, startOffsetDays: Int, now: Date, calendar: Calendar) -> Bool {
        let todayStart = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -startOffsetDays, to: todayStart) ?? todayStart
        let end = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? now
        return dateToCheck >= start && dateToCheck < end
    }
}

enum ProfileTrendMetricStyle {
    case decimal
    case percent
}

enum ProfileTrendDirection {
    case up
    case down
    case flat

    var symbolName: String {
        switch self {
        case .up:
            return "arrow.up"
        case .down:
            return "arrow.down"
        case .flat:
            return "minus"
        }
    }
}

struct ProfileTrendMetric {
    let recentValue: Double?
    let lifetimeValue: Double?
    let style: ProfileTrendMetricStyle

    private var changeThreshold: Double {
        switch style {
        case .decimal:
            return 0.05
        case .percent:
            return 0.005
        }
    }

    var formattedRecentValue: String {
        guard let recentValue else { return L10n.string("—") }
        switch style {
        case .decimal:
            return L10n.decimal(recentValue)
        case .percent:
            return L10n.percent(recentValue)
        }
    }

    var direction: ProfileTrendDirection? {
        guard let delta else { return nil }
        if abs(delta) < changeThreshold {
            return .flat
        }
        return delta > 0 ? .up : .down
    }

    var delta: Double? {
        guard let recentValue, let lifetimeValue else { return nil }
        return recentValue - lifetimeValue
    }

    var formattedDeltaText: String? {
        guard let delta else { return nil }
        guard abs(delta) >= changeThreshold else { return L10n.string("No change") }

        let magnitude: String
        switch style {
        case .decimal:
            magnitude = L10n.decimal(abs(delta))
        case .percent:
            magnitude = L10n.percent(abs(delta))
        }

        return delta > 0
            ? L10n.format("+%@ vs lifetime", magnitude)
            : L10n.format("-%@ vs lifetime", magnitude)
    }
}

struct ProfileTrendSnapshot {
    let filter: GameRecordFilter
    let sampleSize: Int
    let average: ProfileTrendMetric
    let firstNineAverage: ProfileTrendMetric
    let checkoutPercentage: ProfileTrendMetric
    let winRate: ProfileTrendMetric
    let recent180Count: Int
    let recent140PlusCount: Int
    let currentWinStreak: Int
    let bestRecentWinStreak: Int

    var hasRecords: Bool {
        sampleSize > 0
    }

    var sampleLabel: String {
        L10n.format("Last %@", "\(sampleSize)")
    }
}

struct FilteredProfileStatsSnapshot {
    let filter: GameRecordFilter
    let recordCount: Int
    let gamesPlayed: Int?
    let gamesWon: Int?
    let winRate: Double?
    let average: Double?
    let firstNineAverage: Double?
    let checkoutPercentage: Double?
    let bestCheckout: Int?
    let bestTurn: Int?
    let highestScore: Int?
    let score180Count: Int?
    let score140PlusCount: Int?

    var hasRecords: Bool {
        recordCount > 0
    }

    var scopeLabel: String {
        L10n.format("Based on %@ records", "\(recordCount)")
    }
}

enum FilteredProfileStatsBuilder {
    static func makeSnapshot(
        for profileID: UUID,
        stats: PlayerProfileStats,
        records: [GameRecord],
        filter: GameRecordFilter,
        now: Date = Date()
    ) -> FilteredProfileStatsSnapshot {
        if filter.isUnfiltered {
            return FilteredProfileStatsSnapshot(
                filter: filter,
                recordCount: stats.gamesPlayed,
                gamesPlayed: stats.gamesPlayed > 0 ? stats.gamesPlayed : nil,
                gamesWon: stats.gamesPlayed > 0 ? stats.gamesWon : nil,
                winRate: stats.winRate,
                average: stats.legAverage,
                firstNineAverage: stats.firstNineAverage,
                checkoutPercentage: stats.checkoutPercentage,
                bestCheckout: stats.highestCheckout > 0 ? stats.highestCheckout : nil,
                bestTurn: stats.highestTurnScore > 0 ? stats.highestTurnScore : nil,
                highestScore: stats.highestScore > 0 ? stats.highestScore : nil,
                score180Count: stats.gamesPlayed > 0 ? stats.score180Count : nil,
                score140PlusCount: stats.gamesPlayed > 0 ? stats.score140PlusCount : nil
            )
        }

        let results = ProfileTrends.filteredPlayerResults(
            for: profileID,
            records: records,
            filter: filter,
            now: now
        ).map(\.1)

        let totalDarts = results.reduce(0) { $0 + $1.totalDartsThrown }
        let totalPoints = results.reduce(0) { $0 + $1.totalPointsScored }
        let totalFirstNinePoints = results.reduce(0) { $0 + $1.totalFirstNinePoints }
        let totalFirstNineDarts = results.reduce(0) { $0 + $1.totalFirstNineDarts }
        let totalCheckoutAttempts = results.reduce(0) { $0 + $1.checkoutAttempts }
        let totalCheckoutHits = results.reduce(0) { $0 + $1.checkoutHits }

        return FilteredProfileStatsSnapshot(
            filter: filter,
            recordCount: results.count,
            gamesPlayed: results.isEmpty ? nil : results.count,
            gamesWon: results.isEmpty ? nil : results.filter(\.isWinner).count,
            winRate: results.isEmpty ? nil : Double(results.filter(\.isWinner).count) / Double(results.count),
            average: totalDarts > 0 ? (Double(totalPoints) / Double(totalDarts)) * 3.0 : nil,
            firstNineAverage: totalFirstNineDarts > 0 ? (Double(totalFirstNinePoints) / Double(totalFirstNineDarts)) * 3.0 : nil,
            checkoutPercentage: totalCheckoutAttempts > 0 ? Double(totalCheckoutHits) / Double(totalCheckoutAttempts) : nil,
            bestCheckout: results.map(\.highestCheckout).max().flatMap { $0 > 0 ? $0 : nil },
            bestTurn: results.map(\.highestTurnScore).max().flatMap { $0 > 0 ? $0 : nil },
            highestScore: results.map(\.highestScore).max().flatMap { $0 > 0 ? $0 : nil },
            score180Count: results.isEmpty ? nil : results.reduce(0) { $0 + $1.score180Count },
            score140PlusCount: results.isEmpty ? nil : results.reduce(0) { $0 + $1.score140PlusCount }
        )
    }
}

enum ProfileTrends {
    static let recentLimit = 5

    static func makeSnapshot(
        for profileID: UUID,
        stats: PlayerProfileStats,
        records: [GameRecord],
        filter: GameRecordFilter,
        now: Date = Date(),
        recentLimit: Int = recentLimit
    ) -> ProfileTrendSnapshot {
        let qualifyingResults = filteredPlayerResults(
            for: profileID,
            records: records,
            filter: filter,
            now: now
        )

        let recentResults = Array(qualifyingResults.prefix(recentLimit))
        let resultValues = recentResults.map(\.1)

        let totalDarts = resultValues.reduce(0) { $0 + $1.totalDartsThrown }
        let totalPoints = resultValues.reduce(0) { $0 + $1.totalPointsScored }
        let totalFirstNinePoints = resultValues.reduce(0) { $0 + $1.totalFirstNinePoints }
        let totalFirstNineDarts = resultValues.reduce(0) { $0 + $1.totalFirstNineDarts }
        let totalCheckoutAttempts = resultValues.reduce(0) { $0 + $1.checkoutAttempts }
        let totalCheckoutHits = resultValues.reduce(0) { $0 + $1.checkoutHits }

        let recentAverage = totalDarts > 0 ? (Double(totalPoints) / Double(totalDarts)) * 3.0 : nil
        let recentFirstNineAverage = totalFirstNineDarts > 0 ? (Double(totalFirstNinePoints) / Double(totalFirstNineDarts)) * 3.0 : nil
        let recentCheckoutPercentage = totalCheckoutAttempts > 0 ? Double(totalCheckoutHits) / Double(totalCheckoutAttempts) : nil
        let recentWinRate = !resultValues.isEmpty ? Double(resultValues.filter(\.isWinner).count) / Double(resultValues.count) : nil

        return ProfileTrendSnapshot(
            filter: filter,
            sampleSize: resultValues.count,
            average: ProfileTrendMetric(recentValue: recentAverage, lifetimeValue: stats.legAverage, style: .decimal),
            firstNineAverage: ProfileTrendMetric(recentValue: recentFirstNineAverage, lifetimeValue: stats.firstNineAverage, style: .decimal),
            checkoutPercentage: ProfileTrendMetric(recentValue: recentCheckoutPercentage, lifetimeValue: stats.checkoutPercentage, style: .percent),
            winRate: ProfileTrendMetric(recentValue: recentWinRate, lifetimeValue: stats.winRate, style: .percent),
            recent180Count: resultValues.reduce(0) { $0 + $1.score180Count },
            recent140PlusCount: resultValues.reduce(0) { $0 + $1.score140PlusCount },
            currentWinStreak: currentWinStreak(in: resultValues),
            bestRecentWinStreak: bestWinStreak(in: resultValues)
        )
    }

    fileprivate static func filteredPlayerResults(
        for profileID: UUID,
        records: [GameRecord],
        filter: GameRecordFilter,
        now: Date = Date()
    ) -> [(GameRecord, PlayerGameResult)] {
        filter.filteredRecords(from: records, now: now)
            .sorted { $0.date > $1.date }
            .compactMap { record in
                guard let result = record.playerResults.first(where: { $0.profileID == profileID }) else { return nil }
                return (record, result)
            }
    }

    private static func currentWinStreak(in results: [PlayerGameResult]) -> Int {
        var streak = 0
        for result in results {
            if result.isWinner {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    private static func bestWinStreak(in results: [PlayerGameResult]) -> Int {
        var best = 0
        var current = 0

        for result in results {
            if result.isWinner {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }

        return best
    }
}

extension GameRecord {
    nonisolated var isPracticeRecord: Bool {
        practiceMode != nil || finishRule == GameMode.practice.rawValue
    }

    nonisolated var isCricketRecord: Bool {
        finishRule == GameMode.cricket.rawValue
    }

    nonisolated var isX01Record: Bool {
        !isPracticeRecord && !isCricketRecord && startingScore > 0
    }
}
