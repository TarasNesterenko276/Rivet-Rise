import Foundation
import Combine

/// State and actions for the crew lockers, where foremen are hired and put in the crane cab.
@MainActor
final class CrewLockersViewModel: ObservableObject {
    /// Re-publishes store changes so views refresh (iOS 15 has no Observation framework).
    private var storeChanges: [AnyCancellable] = []
    enum Action: Equatable {
        case hire(price: Int, affordable: Bool)
        case assign
        case onShift
    }

    private let profileStore: ProfileStore
    private let haptics: HapticsService
    private let sound: SoundService

    /// The locker whose door is open.
    @Published var opened: Foreman
    @Published var message: String?
    @Published var messageIsError = false

    init(profileStore: ProfileStore, haptics: HapticsService, sound: SoundService) {
        self.profileStore = profileStore
        self.haptics = haptics
        self.sound = sound
        opened = profileStore.profile.selectedForeman
        profileStore.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &storeChanges)
    }

    var bolts: Int { profileStore.bolts }
    var onShift: Foreman { profileStore.profile.selectedForeman }

    func isHired(_ foreman: Foreman) -> Bool { profileStore.profile.isHired(foreman) }

    var action: Action {
        if opened == onShift { return .onShift }
        if isHired(opened) { return .assign }
        return .hire(price: opened.price, affordable: profileStore.canAfford(opened.price))
    }

    func open(_ foreman: Foreman) {
        guard foreman != opened else { return }
        opened = foreman
        haptics.selection()
        sound.play(.tap, volume: 0.5)
    }

    func performAction() {
        do {
            switch action {
            case .hire:
                try profileStore.hireForeman(opened)
                haptics.notify(.success)
                sound.play(.buy)
                messageIsError = false
                message = "\(opened.name) joined the crew and took the cab."
            case .assign:
                try profileStore.selectForeman(opened)
                haptics.impact(.medium)
                messageIsError = false
                message = "\(opened.name) is in the cab."
            case .onShift:
                break
            }
        } catch {
            haptics.notify(.error)
            messageIsError = true
            message = error.localizedDescription
        }
    }
}
