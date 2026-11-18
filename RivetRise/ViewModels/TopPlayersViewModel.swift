import Foundation
import Combine

/// State for TOP PLAYERS: the weekly board (from a `LeaderboardService`), the player's
/// building league and the weekly site orders.
@MainActor
final class TopPlayersViewModel: ObservableObject {
    /// Re-publishes store changes so views refresh (iOS 15 has no Observation framework).
    private var storeChanges: [AnyCancellable] = []
    enum Tab: String, CaseIterable, Identifiable {
        case board = "Top 5"
        case orders = "Site Orders"
        var id: String { rawValue }
    }

    private let profileStore: ProfileStore
    private let service: LeaderboardService
    private let haptics: HapticsService
    private let sound: SoundService
    private let clock: () -> Date

    @Published var tab: Tab = .board
    @Published private(set) var board: WeeklyBoard?
    @Published private(set) var isLoading = false
    @Published var message: String?
    @Published var messageIsError = false

    init(profileStore: ProfileStore, service: LeaderboardService, haptics: HapticsService, sound: SoundService, clock: @escaping () -> Date = { .now }) {
        self.profileStore = profileStore
        self.service = service
        self.haptics = haptics
        self.sound = sound
        self.clock = clock
        profileStore.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &storeChanges)
    }

    var week: WeekKey { WeekKey(date: clock()) }
    var weeklyShifts: [ShiftSnapshot] { profileStore.shifts(inWeekOf: clock()) }
    var weeklyBest: Int { weeklyShifts.map(\.floors).max() ?? 0 }
    var league: BuildingLeague { BuildingLeague.tier(forWeeklyBest: weeklyBest) }
    var orders: [WeeklyOrderStatus] { profileStore.weeklyOrders(on: clock()) }
    var readyOrders: Int { orders.filter(\.canClaim).count }

    var leagueProgressText: String {
        guard let next = league.next else { return "Top league reached this week" }
        return "\(next.minimumFloors - weeklyBest) floors to \(next.title)"
    }

    /// The best shift of the week, which is what the board ranks.
    private var localBest: ShiftSnapshot? {
        weeklyShifts.max { ($0.floors, $0.score) < ($1.floors, $1.score) }
    }

    private var localBestRun: RunRecord? {
        let interval = WeekKey.interval(containing: clock())
        return profileStore.runs
            .filter { $0.date >= interval.start && $0.date < interval.end }
            .max { ($0.floors, $0.score) < ($1.floors, $1.score) }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        // Repair a missed fire-and-forget submission from this device before reading the board.
        // The persisted run UUID makes this retry idempotent at the server.
        if service is SupabaseLeaderboardService, let run = localBestRun {
            let submission = ShiftSubmission(
                submissionID: run.id.uuidString.lowercased(),
                week: week.description,
                floors: run.floors,
                score: run.score,
                rivets: run.rivets,
                perfects: run.perfects,
                districts: run.districts,
                durationSeconds: run.duration,
                foremanID: run.foremanID
            )
            do {
                try await service.submit(submission)
            } catch {
                messageIsError = true
                message = "Your shift could not sync: \(error.localizedDescription)"
                NSLog("Rivet Rise leaderboard retry failed: %@", error.localizedDescription)
            }
        }

        do {
            board = try await service.fetchBoard(for: week, localBest: localBest)
        } catch {
            messageIsError = true
            message = error.localizedDescription
        }
    }

    func claim(_ order: WeeklyOrderStatus) {
        do {
            let reward = try profileStore.claimOrder(order.id, on: clock())
            haptics.notify(.success)
            sound.play(.buy)
            messageIsError = false
            message = "\(order.order.title) paid: +\(reward) bolts."
        } catch {
            haptics.notify(.error)
            messageIsError = true
            message = error.localizedDescription
        }
    }

    /// Reward slots are tapped inside the web board; the claim goes through the service.
    func tapRewardSlot(_ id: String) {
        guard let slot = board?.rewards.first(where: { $0.id == id }) else { return }
        haptics.selection()
        switch slot.state {
        case .claimable:
            Task {
                do {
                    _ = try await service.claimReward(id, week: week)
                    messageIsError = false
                    message = "\(slot.title) unlocked for your crane."
                    await load()
                } catch {
                    messageIsError = true
                    message = error.localizedDescription
                }
            }
        case .pending:
            messageIsError = false
            message = "Hold rank \(slot.ranks) until Monday to win the \(slot.title)."
        case .locked:
            messageIsError = false
            message = "Reach rank \(slot.ranks) this week to compete for the \(slot.title)."
        case .claimed:
            messageIsError = false
            message = "\(slot.title) is already on your crane."
        }
    }
}
