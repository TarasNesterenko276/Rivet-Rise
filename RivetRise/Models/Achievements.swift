import Foundation

/// Value snapshot of lifetime statistics used to evaluate achievements.
struct PlayerStats: Equatable, Sendable {
    var bestScore = 0
    var bestFloors = 0
    var totalRuns = 0
    var totalBoltsEarned = 0
    var totalPerfects = 0
    var totalRivets = 0
    var totalDistricts = 0
    var totalPenthouses = 0
    var totalClutches = 0
    var hiredForemanCount = 1
    var maxedUpgradeCount = 0
}

/// A sticker on the hard hat, earned by reaching a milestone.
struct Achievement: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let detail: String
    /// Index of the sticker artwork (`sticker_<n>`).
    let sticker: Int
    let isUnlocked: Bool
    /// Progress in `0...1` toward unlocking.
    let progress: Double

    var art: String { isUnlocked ? "sticker_\(sticker)" : "sticker_locked" }
}

/// Defines and evaluates all achievements. Evaluation is pure so it can be tested.
enum AchievementCatalog {
    private struct Definition {
        let id: String
        let title: String
        let detail: String
        let target: Double
        let value: @Sendable (PlayerStats) -> Double
    }

    private static let definitions: [Definition] = [
        Definition(id: "firstShift", title: "Clocked In", detail: "Finish your first shift on the crane.", target: 1) { Double($0.totalRuns) },
        Definition(id: "floors25", title: "Mid-Rise", detail: "Stand a tower 25 floors tall.", target: 25) { Double($0.bestFloors) },
        Definition(id: "floors50", title: "Skyscraper", detail: "Stand a tower 50 floors tall.", target: 50) { Double($0.bestFloors) },
        Definition(id: "perfects100", title: "Plumb Line", detail: "Land 100 perfect drops in total.", target: 100) { Double($0.totalPerfects) },
        Definition(id: "rivets50", title: "Hot Rivets", detail: "Drive 50 rivets home.", target: 50) { Double($0.totalRivets) },
        Definition(id: "districts10", title: "Town Planner", detail: "Form 10 tenant districts.", target: 10) { Double($0.totalDistricts) },
        Definition(id: "penthouses5", title: "Topping Out", detail: "Crown 5 penthouses.", target: 5) { Double($0.totalPenthouses) },
        Definition(id: "clutch", title: "Cable Catch", detail: "Land a snapped module perfectly.", target: 1) { Double($0.totalClutches) },
        Definition(id: "score5000", title: "Overtime", detail: "Score 5,000 points in one shift.", target: 5_000) { Double($0.bestScore) },
        Definition(id: "bolts5000", title: "Full Toolbox", detail: "Earn 5,000 bolts in total.", target: 5_000) { Double($0.totalBoltsEarned) },
        Definition(id: "crew3", title: "Full Crew", detail: "Hire 3 foremen.", target: 3) { Double($0.hiredForemanCount) },
        Definition(id: "maxUpgrade", title: "Rigging Master", detail: "Max out any crane upgrade.", target: 1) { Double($0.maxedUpgradeCount) }
    ]

    static var count: Int { definitions.count }

    static func evaluate(_ stats: PlayerStats) -> [Achievement] {
        definitions.enumerated().map { index, definition in
            let value = definition.value(stats)
            return Achievement(
                id: definition.id,
                title: definition.title,
                detail: definition.detail,
                sticker: index % 6,
                isUnlocked: value >= definition.target,
                progress: min(max(value / definition.target, 0), 1)
            )
        }
    }
}
