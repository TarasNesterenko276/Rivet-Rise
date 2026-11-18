import Foundation

// MARK: - Payload shared with the web board (encoded to JSON and passed to `RivetBoard.render`)

/// One row of the weekly top list.
struct BoardEntry: Codable, Equatable, Sendable, Identifiable {
    var id: String { playerID }
    let rank: Int
    let playerID: String
    let crewName: String
    let floors: Int
    let score: Int
    let league: BuildingLeague
    let isPlayer: Bool
}

/// An exclusive cosmetic paid out to the top of the weekly board.
struct RewardSlot: Codable, Equatable, Sendable, Identifiable {
    enum State: String, Codable, Sendable {
        /// The player is not in this slot's rank range right now.
        case locked
        /// The player holds the rank; the reward is granted when the week closes.
        case pending
        /// The week closed with the player in range; the server allows claiming.
        case claimable
        case claimed
    }

    let id: String
    let ranks: String
    let title: String
    let detail: String
    /// Cosmetic id the game would apply (crane paint, roof crown, hook).
    let cosmeticID: String
    let state: State
}

/// Everything the TOP PLAYERS screen shows for one week.
struct WeeklyBoard: Codable, Equatable, Sendable {
    let week: String
    let endsAt: Date
    let seasonName: String
    let entries: [BoardEntry]
    /// The local player's row when it is not inside the top 5.
    let playerRow: BoardEntry?
    let rewards: [RewardSlot]
    /// True when the data came from `MockLeaderboardService`, shown as a banner on the board.
    let isMock: Bool
}

/// What the game submits after every finished shift.
struct ShiftSubmission: Codable, Equatable, Sendable {
    let submissionID: String
    let week: String
    let floors: Int
    let score: Int
    let rivets: Int
    let perfects: Int
    let districts: Int
    let durationSeconds: Double
    let foremanID: String
}

// MARK: - Integration point

/// The backend contract for the weekly TOP PLAYERS board.
///
/// Integration points for a real backend (not implemented yet):
/// 1. `fetchBoard(for:localBest:)` → `GET /v1/boards/{week}` returning `WeeklyBoard` JSON
///    (same shape as the mock, ISO-8601 dates).
/// 2. `submit(_:)` → `POST /v1/boards/{week}/shifts`; call it from `GameViewModel` right after
///    `ProfileStore.recordRun` (see `TopPlayersViewModel.submitIfNeeded`). Needs an anti-cheat
///    signature (e.g. App Attest) before going live.
/// 3. `claimReward(_:week:)` → `POST /v1/boards/{week}/rewards/{slotID}/claim`; on success store
///    the cosmetic id in the profile and show it on the crane.
/// 4. Player identity: replace `localPlayerID` with Game Center `GKLocalPlayer.teamPlayerID`
///    or the studio account id.
@MainActor
protocol LeaderboardService {
    func fetchBoard(for week: WeekKey, localBest: ShiftSnapshot?) async throws -> WeeklyBoard
    func submit(_ shift: ShiftSubmission) async throws
    func claimReward(_ slotID: String, week: WeekKey) async throws -> RewardSlot
}

enum LeaderboardError: LocalizedError, Equatable {
    case offline
    case notClaimable

    var errorDescription: String? {
        switch self {
        case .offline: "The league office is offline. Your shifts still count locally."
        case .notClaimable: "Weekly rewards are handed out when the week closes."
        }
    }
}

struct UnavailableLeaderboardService: LeaderboardService {
    func fetchBoard(for week: WeekKey, localBest: ShiftSnapshot?) async throws -> WeeklyBoard { throw LeaderboardError.offline }
    func submit(_ shift: ShiftSubmission) async throws { throw LeaderboardError.offline }
    func claimReward(_ slotID: String, week: WeekKey) async throws -> RewardSlot { throw LeaderboardError.offline }
}

// MARK: - Mock

/// Deterministic mock data: a fixed rival crew list per week plus the player's local best.
/// Replace with a networked implementation of `LeaderboardService`; nothing else changes.
struct MockLeaderboardService: LeaderboardService {
    static let localPlayerID = "local-player"

    static let rewardCatalog: [(id: String, ranks: ClosedRange<Int>, title: String, detail: String, cosmetic: String)] = [
        ("gold-jib", 1...1, "Gold Leaf Jib", "The crane jib is painted gold for a week.", "crane.jib.gold"),
        ("neon-crown", 2...3, "Neon Crown", "Penthouses get a glowing rooftop crown.", "roof.crown.neon"),
        ("chrome-hook", 4...5, "Chrome Hook", "A polished chrome hook block with a beacon.", "hook.chrome")
    ]

    private static let rivals = [
        "Skyhook Sam", "Girder Gita", "Bolt Brothers", "Plumb Line Paz", "Crane Queen Ivy",
        "Night Shift Nils", "Rivet Rosa", "High Steel Hank", "Topper Tomo", "Windy Wren"
    ]

    func fetchBoard(for week: WeekKey, localBest: ShiftSnapshot?) async throws -> WeeklyBoard {
        Self.makeBoard(for: week, localBest: localBest, now: .now)
    }

    func submit(_ shift: ShiftSubmission) async throws {
        // The mock keeps no server state: the board is rebuilt from the local best on every fetch.
    }

    func claimReward(_ slotID: String, week: WeekKey) async throws -> RewardSlot {
        throw LeaderboardError.notClaimable
    }

    /// Pure board builder so tests can check ranking and reward states.
    static func makeBoard(for week: WeekKey, localBest: ShiftSnapshot?, now: Date) -> WeeklyBoard {
        var generator = SeededGenerator(seed: UInt64(week.year * 100 + week.week))
        // Five rivals with descending heights, different every week.
        var floors = 58 + Int(generator.unit() * 14)
        var rivalsRows: [(String, Int, Int)] = []
        var names = rivals
        for _ in 0..<6 {
            let index = Int(generator.unit() * Double(names.count)) % names.count
            let name = names.remove(at: index)
            let score = floors * 160 + Int(generator.unit() * 900)
            rivalsRows.append((name, floors, score))
            floors -= 4 + Int(generator.unit() * 8)
        }

        var rows: [(id: String, name: String, floors: Int, score: Int, isPlayer: Bool)] =
            rivalsRows.enumerated().map { ("rival-\($0.offset)", $0.element.0, $0.element.1, $0.element.2, false) }
        if let localBest, localBest.floors > 0 {
            rows.append((localPlayerID, "Your crew", localBest.floors, localBest.score, true))
        }
        rows.sort { ($0.floors, $0.score) > ($1.floors, $1.score) }

        let ranked = rows.enumerated().map { index, row in
            BoardEntry(rank: index + 1, playerID: row.id, crewName: row.name, floors: row.floors, score: row.score,
                       league: BuildingLeague.tier(forWeeklyBest: row.floors), isPlayer: row.isPlayer)
        }
        let top = Array(ranked.prefix(5))
        let player = ranked.first { $0.isPlayer }
        let playerRank = player?.rank

        let rewards = rewardCatalog.map { slot in
            RewardSlot(
                id: slot.id,
                ranks: slot.ranks.count == 1 ? "#\(slot.ranks.lowerBound)" : "#\(slot.ranks.lowerBound)–\(slot.ranks.upperBound)",
                title: slot.title,
                detail: slot.detail,
                cosmeticID: slot.cosmetic,
                state: playerRank.map { slot.ranks.contains($0) } == true ? .pending : .locked
            )
        }

        return WeeklyBoard(
            week: week.description,
            endsAt: WeekKey.interval(containing: now).end,
            seasonName: "Season 1 · Steel Spring",
            entries: top,
            playerRow: (player?.rank ?? 0) > 5 ? player : nil,
            rewards: rewards,
            isMock: true
        )
    }
}
