import Foundation

/// Identifies one leaderboard week, e.g. "2026-W47" (ISO week, Monday start).
struct WeekKey: Hashable, Codable, Sendable, CustomStringConvertible {
    let year: Int
    let week: Int

    init(year: Int, week: Int) {
        self.year = year
        self.week = week
    }

    init(date: Date, calendar: Calendar = WeekKey.calendar) {
        let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        year = parts.yearForWeekOfYear ?? 0
        week = parts.weekOfYear ?? 0
    }

    var description: String { String(format: "%d-W%02d", year, week) }

    /// ISO-8601 weeks in UTC, so every player's week flips at the same moment.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    /// Start (inclusive) and end (exclusive) of the week containing `date`.
    static func interval(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 7 * 86_400)
    }
}

/// Seasonal building leagues: the tier is set by the tallest tower of the current week.
enum BuildingLeague: String, CaseIterable, Codable, Sendable {
    case scaffold
    case girder
    case rivet
    case skyline

    /// Floors needed this week to enter the league.
    var minimumFloors: Int {
        switch self {
        case .scaffold: 0
        case .girder: 20
        case .rivet: 35
        case .skyline: 50
        }
    }

    var title: String {
        switch self {
        case .scaffold: "Scaffold League"
        case .girder: "Girder League"
        case .rivet: "Gold Rivet League"
        case .skyline: "Skyline League"
        }
    }

    /// Bonus bolts paid on every shift while in this league (applied by the backend at week end).
    var weeklyStipend: Int {
        switch self {
        case .scaffold: 0
        case .girder: 60
        case .rivet: 150
        case .skyline: 300
        }
    }

    static func tier(forWeeklyBest floors: Int) -> BuildingLeague {
        allCases.last { floors >= $0.minimumFloors } ?? .scaffold
    }

    var next: BuildingLeague? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), index + 1 < all.count else { return nil }
        return all[index + 1]
    }
}

/// A finished shift reduced to the numbers weekly orders care about.
struct ShiftSnapshot: Equatable, Sendable {
    var date: Date
    var score: Int
    var floors: Int
    var perfects: Int
    var rivets: Int
    var districts: Int
}

/// Weekly "site orders": precision and rivet-streak tasks that pay bolts once per week.
struct WeeklyOrder: Identifiable, Equatable, Sendable {
    enum Measure: Equatable, Sendable {
        /// Summed over every shift of the week.
        case weeklyRivets
        /// Best single shift of the week.
        case perfectsInOneShift
        case districtsInOneShift
        case floorsInOneShift
    }

    let id: String
    let title: String
    let detail: String
    let measure: Measure
    let target: Int
    let reward: Int

    static let catalog: [WeeklyOrder] = [
        WeeklyOrder(id: "rivets40", title: "Rivet Crew", detail: "Drive 40 rivets this week.", measure: .weeklyRivets, target: 40, reward: 120),
        WeeklyOrder(id: "perfect10", title: "Plumb Perfect", detail: "Land 10 perfect drops in one shift.", measure: .perfectsInOneShift, target: 10, reward: 150),
        WeeklyOrder(id: "districts3", title: "Zoning Board", detail: "Form 3 tenant districts in one shift.", measure: .districtsInOneShift, target: 3, reward: 100),
        WeeklyOrder(id: "floors30", title: "High Rise Permit", detail: "Stand a tower 30 floors tall.", measure: .floorsInOneShift, target: 30, reward: 200)
    ]

    func progress(in shifts: [ShiftSnapshot]) -> Int {
        switch measure {
        case .weeklyRivets: shifts.reduce(0) { $0 + $1.rivets }
        case .perfectsInOneShift: shifts.map(\.perfects).max() ?? 0
        case .districtsInOneShift: shifts.map(\.districts).max() ?? 0
        case .floorsInOneShift: shifts.map(\.floors).max() ?? 0
        }
    }

    /// The key stored when the order is claimed, unique per week.
    func claimKey(_ week: WeekKey) -> String { "\(week)#\(id)" }
}

/// An order together with this week's progress and claim state.
struct WeeklyOrderStatus: Identifiable, Equatable, Sendable {
    let order: WeeklyOrder
    let progress: Int
    let isClaimed: Bool

    var id: String { order.id }
    var isComplete: Bool { progress >= order.target }
    var canClaim: Bool { isComplete && !isClaimed }
    var fraction: Double { min(Double(progress) / Double(order.target), 1) }

    static func evaluate(shifts: [ShiftSnapshot], week: WeekKey, claimedKeys: Set<String>) -> [WeeklyOrderStatus] {
        WeeklyOrder.catalog.map { order in
            WeeklyOrderStatus(order: order, progress: order.progress(in: shifts), isClaimed: claimedKeys.contains(order.claimKey(week)))
        }
    }
}
