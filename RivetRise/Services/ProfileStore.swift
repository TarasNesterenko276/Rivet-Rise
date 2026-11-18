import Combine
import Foundation

/// Errors surfaced to the interface when a purchase or selection is not possible.
enum ProfileError: LocalizedError, Equatable {
    case insufficientBolts(needed: Int)
    case upgradeMaxed
    case foremanAlreadyHired
    case foremanNotHired
    case orderNotReady

    var errorDescription: String? {
        switch self {
        case .insufficientBolts(let needed):
            "You need \(Formatters.integer(needed)) more bolts."
        case .upgradeMaxed:
            "This upgrade is already at full spec."
        case .foremanAlreadyHired:
            "This foreman is already on your crew."
        case .foremanNotHired:
            "Hire this foreman before putting them in the cab."
        case .orderNotReady:
            "This site order is not finished yet, or it was already paid."
        }
    }
}

/// Owns the player's profile and shift log, saved as one JSON file.
/// All mutations go through here so views and view models never touch storage.
@MainActor
final class ProfileStore: ObservableObject {
    private let storage: ProfileStorage

    @Published private(set) var profile: PlayerProfile
    /// Every kept shift, newest first.
    @Published private(set) var runs: [RunRecord]
    /// Set when a save fails so the interface can tell the player.
    @Published private(set) var persistenceErrorMessage: String?

    /// Shifts shown on the timesheet.
    static let recentRunLimit = 24
    /// Shifts kept on disk; enough to cover a busy week of weekly orders.
    static let storedRunLimit = 200

    init(storage: ProfileStorage) throws {
        self.storage = storage
        if let saved = try storage.load() {
            profile = saved.profile
            runs = saved.runs
        } else {
            profile = PlayerProfile()
            runs = []
            try storage.save(SaveFile(profile: profile, runs: runs))
        }
    }

    // MARK: - Derived state

    var bolts: Int { profile.bolts }
    var loadout: Loadout { profile.loadout }
    var recentRuns: [RunRecord] { Array(runs.prefix(Self.recentRunLimit)) }

    var achievements: [Achievement] {
        AchievementCatalog.evaluate(profile.statsSnapshot)
    }

    func level(of kind: UpgradeKind) -> Int {
        profile.level(for: kind)
    }

    /// Cost of the next level, or `nil` when the upgrade is maxed.
    func nextCost(of kind: UpgradeKind) -> Int? {
        kind.cost(forLevel: profile.level(for: kind) + 1)
    }

    func canAfford(_ amount: Int) -> Bool {
        profile.bolts >= amount
    }

    // MARK: - Mutations

    func purchaseUpgrade(_ kind: UpgradeKind) throws {
        guard let cost = nextCost(of: kind) else { throw ProfileError.upgradeMaxed }
        guard canAfford(cost) else { throw ProfileError.insufficientBolts(needed: cost - profile.bolts) }
        var next = profile
        next.bolts -= cost
        next.setLevel(next.level(for: kind) + 1, for: kind)
        try commit(next)
    }

    func hireForeman(_ foreman: Foreman) throws {
        guard !profile.isHired(foreman) else { throw ProfileError.foremanAlreadyHired }
        guard canAfford(foreman.price) else { throw ProfileError.insufficientBolts(needed: foreman.price - profile.bolts) }
        var next = profile
        next.bolts -= foreman.price
        next.hiredForemanIDs.append(foreman.rawValue)
        next.selectedForemanID = foreman.rawValue
        try commit(next)
    }

    func selectForeman(_ foreman: Foreman) throws {
        guard profile.isHired(foreman) else { throw ProfileError.foremanNotHired }
        var next = profile
        next.selectedForemanID = foreman.rawValue
        try commit(next)
    }

    /// Stores a finished shift, credits bolts and updates lifetime statistics.
    @discardableResult
    func recordRun(_ summary: RunSummary) -> RunOutcome {
        let previousBestScore = profile.bestScore
        let previousBestFloors = profile.bestFloors
        let isNewBestScore = summary.score > previousBestScore
        let isNewBestFloors = summary.floors > previousBestFloors

        var next = profile
        next.bolts += summary.bolts
        next.totalRuns += 1
        next.totalBoltsEarned += summary.bolts
        next.totalFloors += summary.floors
        next.totalPerfects += summary.perfects
        next.totalRivets += summary.rivets
        next.totalDistricts += summary.districts
        next.totalPenthouses += summary.penthouses
        next.totalClutches += summary.clutches
        if isNewBestScore { next.bestScore = summary.score }
        if isNewBestFloors { next.bestFloors = summary.floors }

        // Keeps the history bounded so the save never grows without limit.
        let nextRuns = Array(([RunRecord(summary: summary)] + runs).prefix(Self.storedRunLimit))
        do {
            try commit(next, runs: nextRuns)
        } catch {
            // The shift still counts for this session even if the disk write failed.
            profile = next
            runs = nextRuns
            persistenceErrorMessage = "Progress could not be saved: \(error.localizedDescription)"
        }

        return RunOutcome(
            summary: summary,
            previousBestScore: previousBestScore,
            previousBestFloors: previousBestFloors,
            isNewBestScore: isNewBestScore,
            isNewBestFloors: isNewBestFloors,
            totalBolts: profile.bolts
        )
    }

    // MARK: - Weekly league

    /// Shifts finished inside the week that contains `date`, newest first.
    func shifts(inWeekOf date: Date = Date()) -> [ShiftSnapshot] {
        let interval = WeekKey.interval(containing: date)
        return runs
            .filter { $0.date >= interval.start && $0.date < interval.end }
            .map { ShiftSnapshot(date: $0.date, score: $0.score, floors: $0.floors, perfects: $0.perfects, rivets: $0.rivets, districts: $0.districts) }
    }

    func weeklyOrders(on date: Date = Date()) -> [WeeklyOrderStatus] {
        WeeklyOrderStatus.evaluate(shifts: shifts(inWeekOf: date), week: WeekKey(date: date), claimedKeys: Set(profile.claimedOrderKeys))
    }

    /// Pays a finished weekly order once.
    func claimOrder(_ id: String, on date: Date = Date()) throws -> Int {
        guard let status = weeklyOrders(on: date).first(where: { $0.id == id }), status.canClaim else {
            throw ProfileError.orderNotReady
        }
        var next = profile
        next.bolts += status.order.reward
        next.totalBoltsEarned += status.order.reward
        next.claimedOrderKeys.append(status.order.claimKey(WeekKey(date: date)))
        try commit(next)
        return status.order.reward
    }

    /// Deletes every shift and restores the profile to its initial state.
    func resetProgress() throws {
        try commit(PlayerProfile(), runs: [])
    }

    /// Grants bolts without a shift. Used only to seed deterministic UI-test sessions.
    func grantBolts(_ amount: Int) throws {
        var next = profile
        next.bolts += amount
        try commit(next)
    }

    // MARK: - Persistence

    /// Writes first and only then publishes, so a failed save never shows unsaved progress.
    private func commit(_ nextProfile: PlayerProfile, runs nextRuns: [RunRecord]? = nil) throws {
        let file = SaveFile(profile: nextProfile, runs: nextRuns ?? runs)
        try storage.save(file)
        profile = file.profile
        runs = file.runs
        persistenceErrorMessage = nil
    }
}
