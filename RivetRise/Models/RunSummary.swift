import Foundation

/// The result of one finished shift, produced by `RunSession`.
struct RunSummary: Equatable, Sendable {
    var score: Int
    var bolts: Int
    /// Tallest the tower stood during the shift.
    var floors: Int
    var duration: TimeInterval
    var perfects: Int
    var rivets: Int
    var districts: Int
    var penthouses: Int
    var clutches: Int
    var collapses: Int
    var bestRush: Int
    var foremanID: String
}

/// A summary plus how it compares to the player's previous records.
struct RunOutcome: Equatable, Sendable {
    let summary: RunSummary
    let previousBestScore: Int
    let previousBestFloors: Int
    let isNewBestScore: Bool
    let isNewBestFloors: Bool
    let totalBolts: Int
}
