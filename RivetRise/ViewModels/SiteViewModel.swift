import Foundation
import Combine

/// State for the building site home screen.
@MainActor
final class SiteViewModel: ObservableObject {
    /// Re-publishes store changes so views refresh (iOS 15 has no Observation framework).
    private var storeChanges: [AnyCancellable] = []
    private let profileStore: ProfileStore
    private let sound: SoundService
    private let haptics: HapticsService

    init(profileStore: ProfileStore, sound: SoundService, haptics: HapticsService) {
        self.profileStore = profileStore
        self.sound = sound
        self.haptics = haptics
        profileStore.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &storeChanges)
    }

    var bolts: Int { profileStore.bolts }
    var bestFloors: Int { profileStore.profile.bestFloors }
    var bestScore: Int { profileStore.profile.bestScore }
    var foreman: Foreman { profileStore.profile.selectedForeman }
    var shiftCount: Int { profileStore.profile.totalRuns }
    var persistenceError: String? { profileStore.persistenceErrorMessage }

    /// Upgrades the player can afford right now, used for the little "ready to hoist" lamp.
    var affordableUpgrades: Int {
        UpgradeKind.allCases.filter { kind in
            guard let cost = profileStore.nextCost(of: kind) else { return false }
            return profileStore.canAfford(cost)
        }.count
    }

    var bestLine: String {
        bestFloors == 0 ? "No tower yet" : "Best \(bestFloors) floors · \(Formatters.metres(floors: bestFloors))"
    }

    func punchCard() {
        haptics.impact(.medium)
        sound.play(.tap)
    }
}
