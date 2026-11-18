import Foundation
import Combine

/// State and actions for the rigging yard, where crane upgrades are hoisted with bolts.
@MainActor
final class RiggingYardViewModel: ObservableObject {
    /// Re-publishes store changes so views refresh (iOS 15 has no Observation framework).
    private var storeChanges: [AnyCancellable] = []
    struct Row: Identifiable, Equatable {
        let kind: UpgradeKind
        let level: Int
        let cost: Int?
        let canAfford: Bool
        let currentEffect: String
        let nextEffect: String?

        var id: String { kind.rawValue }
        var isMaxed: Bool { cost == nil }
    }

    private let profileStore: ProfileStore
    private let haptics: HapticsService
    private let sound: SoundService

    @Published var message: String?
    @Published var messageIsError = false
    /// The upgrade that was just hoisted, so its load can bounce.
    @Published private(set) var lastHoisted: UpgradeKind?

    init(profileStore: ProfileStore, haptics: HapticsService, sound: SoundService) {
        self.profileStore = profileStore
        self.haptics = haptics
        self.sound = sound
        profileStore.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &storeChanges)
    }

    var bolts: Int { profileStore.bolts }

    var rows: [Row] {
        UpgradeKind.allCases.map { kind in
            let level = profileStore.level(of: kind)
            let cost = profileStore.nextCost(of: kind)
            return Row(
                kind: kind,
                level: level,
                cost: cost,
                canAfford: cost.map(profileStore.canAfford) ?? false,
                currentEffect: kind.effectDescription(atLevel: level),
                nextEffect: level < kind.maxLevel ? kind.effectDescription(atLevel: level + 1) : nil
            )
        }
    }

    func hoist(_ kind: UpgradeKind) {
        do {
            try profileStore.purchaseUpgrade(kind)
            lastHoisted = kind
            haptics.notify(.success)
            sound.play(.buy)
            messageIsError = false
            message = "\(kind.title) is now level \(profileStore.level(of: kind))."
        } catch {
            haptics.notify(.error)
            messageIsError = true
            message = error.localizedDescription
        }
    }
}
