import Foundation
import Testing
@testable import RivetRise

@MainActor
@Suite("Profile store")
struct ProfileStoreTests {
    private func makeStore() throws -> (ProfileStore, ProfileStorage) {
        let storage = try PersistenceController.makeStorage(inMemory: true)
        return (try ProfileStore(storage: storage), storage)
    }

    private func summary(score: Int = 600, bolts: Int = 60, floors: Int = 18, seconds: Double = 80) -> RunSummary {
        RunSummary(score: score, bolts: bolts, floors: floors, duration: seconds, perfects: 5, rivets: 7, districts: 2,
                   penthouses: 1, clutches: 0, collapses: 1, bestRush: 3, foremanID: Foreman.gus.rawValue)
    }

    @Test func freshProfileStartsEmptyWithTheStarterForeman() throws {
        let (store, _) = try makeStore()
        #expect(store.bolts == 0)
        #expect(store.loadout.foreman == .gus)
        #expect(store.recentRuns.isEmpty)
        #expect(UpgradeKind.allCases.allSatisfy { store.level(of: $0) == 0 })
    }

    @Test func hoistingAnUpgradeSpendsBoltsAndRaisesTheLevel() throws {
        let (store, _) = try makeStore()
        try store.grantBolts(500)
        let cost = try #require(store.nextCost(of: .boom))
        try store.purchaseUpgrade(.boom)
        #expect(store.level(of: .boom) == 1)
        #expect(store.bolts == 500 - cost)
        #expect(store.loadout.boom == 1)
    }

    @Test func hoistIsRefusedWithoutEnoughBolts() throws {
        let (store, _) = try makeStore()
        try store.grantBolts(10)
        #expect(throws: ProfileError.insufficientBolts(needed: 50)) {
            try store.purchaseUpgrade(.rivetGun)
        }
        #expect(store.bolts == 10)
        #expect(store.level(of: .rivetGun) == 0)
    }

    @Test func maxedUpgradesCannotBeHoisted() throws {
        let (store, _) = try makeStore()
        try store.grantBolts(100_000)
        for _ in 0..<UpgradeKind.cable.maxLevel { try store.purchaseUpgrade(.cable) }
        #expect(store.nextCost(of: .cable) == nil)
        #expect(throws: ProfileError.upgradeMaxed) { try store.purchaseUpgrade(.cable) }
    }

    @Test func hiringAForemanPutsThemInTheCab() throws {
        let (store, _) = try makeStore()
        try store.grantBolts(Foreman.mira.price)
        try store.hireForeman(.mira)
        #expect(store.bolts == 0)
        #expect(store.loadout.foreman == .mira)
        #expect(throws: ProfileError.foremanAlreadyHired) { try store.hireForeman(.mira) }
        try store.selectForeman(.gus)
        #expect(store.loadout.foreman == .gus)
    }

    @Test func lockedForemenCannotBeHiredOrSelected() throws {
        let (store, _) = try makeStore()
        #expect(throws: ProfileError.insufficientBolts(needed: Foreman.ola.price)) { try store.hireForeman(.ola) }
        #expect(throws: ProfileError.foremanNotHired) { try store.selectForeman(.ola) }
        #expect(store.loadout.foreman == .gus)
    }

    @Test func recordingAShiftPaysBoltsAndUpdatesRecords() throws {
        let (store, _) = try makeStore()
        let first = store.recordRun(summary(score: 900, bolts: 80, floors: 20))
        #expect(first.isNewBestScore && first.isNewBestFloors)
        #expect(first.totalBolts == 80)
        let second = store.recordRun(summary(score: 300, bolts: 20, floors: 12))
        #expect(!second.isNewBestScore && !second.isNewBestFloors)
        #expect(second.previousBestFloors == 20)
        #expect(store.profile.totalRuns == 2)
        #expect(store.profile.totalRivets == 14)
        #expect(store.profile.totalPenthouses == 2)
        #expect(store.profile.bestFloors == 20)
        #expect(store.bolts == 100)
        #expect(store.recentRuns.count == 2)
        #expect(store.recentRuns.first?.bolts == 20, "Newest shift first")
    }

    @Test func progressSurvivesANewStoreOnTheSameStorage() throws {
        let (store, storage) = try makeStore()
        try store.grantBolts(Foreman.mira.price + 200)
        try store.hireForeman(.mira)
        try store.purchaseUpgrade(.rivetGun)
        store.recordRun(summary())

        let reopened = try ProfileStore(storage: storage)
        #expect(reopened.loadout.foreman == .mira)
        #expect(reopened.level(of: .rivetGun) == 1)
        #expect(reopened.recentRuns.count == 1)
        #expect(reopened.bolts == store.bolts)
    }

    @Test func progressIsWrittenToAndReadFromAFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rivetrise-\(UUID().uuidString)/save.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = try ProfileStore(storage: .file(at: url))
        try store.grantBolts(300)
        try store.purchaseUpgrade(.boom)
        store.recordRun(summary(score: 700, floors: 21))

        let reopened = try ProfileStore(storage: .file(at: url))
        #expect(reopened.bolts == store.bolts)
        #expect(reopened.level(of: .boom) == 1)
        #expect(reopened.profile.bestFloors == 21)
        #expect(reopened.recentRuns.count == 1)
    }

    @Test func historyIsTrimmedToTheLimit() throws {
        let (store, _) = try makeStore()
        for index in 0..<(ProfileStore.recentRunLimit + 5) {
            store.recordRun(summary(bolts: index))
        }
        #expect(store.recentRuns.count == ProfileStore.recentRunLimit)
        #expect(store.profile.totalRuns == ProfileStore.recentRunLimit + 5)
    }

    @Test func resetClearsTheSite() throws {
        let (store, _) = try makeStore()
        try store.grantBolts(5_000)
        try store.purchaseUpgrade(.concrete)
        try store.hireForeman(.kenji)
        store.recordRun(summary())
        try store.resetProgress()
        #expect(store.bolts == 0)
        #expect(store.level(of: .concrete) == 0)
        #expect(store.loadout.foreman == .gus)
        #expect(store.recentRuns.isEmpty)
        #expect(store.profile.totalRuns == 0)
    }

    @Test func achievementsGrowFromRecordedShifts() throws {
        let (store, _) = try makeStore()
        #expect(store.achievements.allSatisfy { !$0.isUnlocked })
        store.recordRun(summary(score: 1_000, floors: 26))
        let unlocked = Set(store.achievements.filter(\.isUnlocked).map(\.id))
        #expect(unlocked.isSuperset(of: ["firstShift", "floors25"]))
        #expect(!unlocked.contains("floors50"))
        #expect(!unlocked.contains("clutch"))
    }
}
