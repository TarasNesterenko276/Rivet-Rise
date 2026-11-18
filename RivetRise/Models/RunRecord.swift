import Foundation

/// A saved record of one finished shift: a row on the site log timesheet.
struct RunRecord: Codable, Equatable, Identifiable {
    var id = UUID()
    var date: Date
    var score: Int
    var bolts: Int
    var floors: Int
    var duration: TimeInterval
    var perfects: Int
    var rivets: Int
    var districts: Int
    var foremanID: String

    init(summary: RunSummary, date: Date = Date()) {
        self.date = date
        score = summary.score
        bolts = summary.bolts
        floors = summary.floors
        duration = summary.duration
        perfects = summary.perfects
        rivets = summary.rivets
        districts = summary.districts
        foremanID = summary.foremanID
    }

    var foreman: Foreman {
        Foreman(rawValue: foremanID) ?? .starter
    }
}
