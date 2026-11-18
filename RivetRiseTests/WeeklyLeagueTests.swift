import Foundation
import Testing
@testable import RivetRise

@MainActor
@Suite("Top players: leagues, orders and the mock board")
struct WeeklyLeagueTests {
    private let wednesday = ISO8601DateFormatter().date(from: "2026-11-18T12:00:00Z")!

    private func shift(floors: Int = 20, score: Int = 900, perfects: Int = 4, rivets: Int = 10, districts: Int = 1, date: Date? = nil) -> ShiftSnapshot {
        ShiftSnapshot(date: date ?? wednesday, score: score, floors: floors, perfects: perfects, rivets: rivets, districts: districts)
    }

    @Test func weekKeysUseIsoWeeksInUTC() {
        #expect(WeekKey(date: wednesday).description == "2026-W47")
        let interval = WeekKey.interval(containing: wednesday)
        #expect(WeekKey(date: interval.start) == WeekKey(date: wednesday))
        #expect(WeekKey(date: interval.end) != WeekKey(date: wednesday))
        #expect(interval.duration == 7 * 86_400)
    }

    @Test func leagueTiersFollowTheWeeklyBest() {
        #expect(BuildingLeague.tier(forWeeklyBest: 0) == .scaffold)
        #expect(BuildingLeague.tier(forWeeklyBest: 19) == .scaffold)
        #expect(BuildingLeague.tier(forWeeklyBest: 20) == .girder)
        #expect(BuildingLeague.tier(forWeeklyBest: 49) == .rivet)
        #expect(BuildingLeague.tier(forWeeklyBest: 80) == .skyline)
        #expect(BuildingLeague.skyline.next == nil)
        #expect(BuildingLeague.scaffold.next == .girder)
    }

    @Test func ordersMeasureTheWholeWeekOrTheBestShift() {
        let shifts = [shift(perfects: 6, rivets: 25, districts: 1), shift(floors: 31, perfects: 11, rivets: 18, districts: 3)]
        let statuses = WeeklyOrderStatus.evaluate(shifts: shifts, week: WeekKey(date: wednesday), claimedKeys: [])
        let byID = Dictionary(uniqueKeysWithValues: statuses.map { ($0.id, $0) })
        #expect(byID["rivets40"]?.progress == 43)
        #expect(byID["perfect10"]?.progress == 11)
        #expect(byID["districts3"]?.isComplete == true)
        #expect(byID["floors30"]?.canClaim == true)
    }

    @Test func claimedOrdersStayPaidOnlyForTheirWeek() {
        let week = WeekKey(date: wednesday)
        let order = WeeklyOrder.catalog[0]
        let claimed: Set<String> = [order.claimKey(week)]
        let thisWeek = WeeklyOrderStatus.evaluate(shifts: [shift(rivets: 50)], week: week, claimedKeys: claimed)
        #expect(thisWeek[0].isClaimed && !thisWeek[0].canClaim)
        let nextWeek = WeeklyOrderStatus.evaluate(shifts: [shift(rivets: 50)], week: WeekKey(year: 2026, week: 48), claimedKeys: claimed)
        #expect(nextWeek[0].canClaim)
    }

    @Test func profileStorePaysAnOrderOnce() throws {
        let store = try ProfileStore(storage: PersistenceController.makeStorage(inMemory: true))
        store.recordRun(RunSummary(score: 900, bolts: 50, floors: 22, duration: 90, perfects: 3, rivets: 41, districts: 1,
                                   penthouses: 0, clutches: 0, collapses: 0, bestRush: 2, foremanID: "gus"))
        let before = store.bolts
        #expect(store.shifts(inWeekOf: .now).count == 1)
        #expect(try store.claimOrder("rivets40") == 120)
        #expect(store.bolts == before + 120)
        #expect(throws: ProfileError.orderNotReady) { try store.claimOrder("rivets40") }
        #expect(throws: ProfileError.orderNotReady) { try store.claimOrder("floors30") }
    }

    @Test func mockBoardRanksThePlayerAmongRivals() {
        let week = WeekKey(date: wednesday)
        let empty = MockLeaderboardService.makeBoard(for: week, localBest: nil, now: wednesday)
        #expect(empty.entries.count == 5)
        #expect(empty.entries.map(\.rank) == [1, 2, 3, 4, 5])
        #expect(empty.playerRow == nil)
        #expect(empty.rewards.allSatisfy { $0.state == .locked })
        #expect(empty.isMock)

        let low = MockLeaderboardService.makeBoard(for: week, localBest: shift(floors: 8), now: wednesday)
        #expect(low.playerRow?.isPlayer == true)
        #expect((low.playerRow?.rank ?? 0) > 5)

        let champion = MockLeaderboardService.makeBoard(for: week, localBest: shift(floors: 200, score: 99_999), now: wednesday)
        #expect(champion.entries.first?.isPlayer == true)
        #expect(champion.entries.first?.league == .skyline)
        #expect(champion.rewards.first { $0.id == "gold-jib" }?.state == .pending)
        #expect(champion.rewards.first { $0.id == "chrome-hook" }?.state == .locked)
    }

    @Test func mockBoardIsStablePerWeekAndChangesNextWeek() {
        let a = MockLeaderboardService.makeBoard(for: WeekKey(year: 2026, week: 47), localBest: nil, now: wednesday)
        let b = MockLeaderboardService.makeBoard(for: WeekKey(year: 2026, week: 47), localBest: nil, now: wednesday)
        let c = MockLeaderboardService.makeBoard(for: WeekKey(year: 2026, week: 48), localBest: nil, now: wednesday)
        #expect(a == b)
        #expect(a.entries.map(\.crewName) != c.entries.map(\.crewName))
    }

    @Test func boardPayloadEncodesForTheWebTemplate() throws {
        let board = MockLeaderboardService.makeBoard(for: WeekKey(date: wednesday), localBest: shift(), now: wednesday)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = try #require(String(data: encoder.encode(board), encoding: .utf8))
        for key in ["\"entries\"", "\"rewards\"", "\"crewName\"", "\"isPlayer\"", "\"endsAt\"", "\"seasonName\""] {
            #expect(json.contains(key), "Missing \(key)")
        }
        #expect(Bundle.main.url(forResource: "top_players", withExtension: "html") != nil)
    }

    @Test func mockRewardsCannotBeClaimedBeforeTheWeekCloses() async {
        await #expect(throws: LeaderboardError.notClaimable) {
            _ = try await MockLeaderboardService().claimReward("gold-jib", week: WeekKey(date: wednesday))
        }
    }
}
