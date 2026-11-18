import Foundation
import Combine

/// State for the site log: lifetime records, hard-hat stickers and the shift timesheet.
@MainActor
final class SiteLogViewModel: ObservableObject {
    /// Re-publishes store changes so views refresh (iOS 15 has no Observation framework).
    private var storeChanges: [AnyCancellable] = []
    struct Stat: Identifiable, Equatable {
        let id: String
        let label: String
        let value: String
        let art: String
    }

    struct Entry: Identifiable, Equatable {
        let id: Int
        let date: String
        let time: String
        let foreman: Foreman
        let floors: Int
        let score: String
        let bolts: String
        let duration: String
    }

    private let profileStore: ProfileStore
    @Published var selectedSticker: Achievement?

    init(profileStore: ProfileStore) {
        self.profileStore = profileStore
        profileStore.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &storeChanges)
    }

    var hasHistory: Bool { profileStore.profile.totalRuns > 0 }
    var bestScore: Int { profileStore.profile.bestScore }

    var stats: [Stat] {
        let profile = profileStore.profile
        return [
            Stat(id: "floors", label: "Tallest tower", value: "\(profile.bestFloors) fl", art: "kind_office"),
            Stat(id: "shifts", label: "Shifts worked", value: Formatters.integer(profile.totalRuns), art: "punch_card"),
            Stat(id: "rivets", label: "Rivets driven", value: Formatters.integer(profile.totalRivets), art: "upgrade_rivetGun"),
            Stat(id: "perfects", label: "Perfect drops", value: Formatters.integer(profile.totalPerfects), art: "plumb_bob"),
            Stat(id: "districts", label: "Districts", value: Formatters.integer(profile.totalDistricts), art: "kind_residential"),
            Stat(id: "bolts", label: "Bolts earned", value: Formatters.integer(profile.totalBoltsEarned), art: "icon_bolt")
        ]
    }

    var achievements: [Achievement] { profileStore.achievements }
    var unlockedCount: Int { achievements.filter(\.isUnlocked).count }

    var entries: [Entry] {
        profileStore.recentRuns.enumerated().map { index, run in
            Entry(
                id: index,
                date: Formatters.shiftDate(run.date),
                time: Formatters.shiftTime(run.date),
                foreman: run.foreman,
                floors: run.floors,
                score: Formatters.integer(run.score),
                bolts: Formatters.integer(run.bolts),
                duration: Formatters.duration(run.duration)
            )
        }
    }
}
