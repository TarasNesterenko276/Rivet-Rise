import Foundation
import Combine

/// Preferences and progress reset in the site office.
@MainActor
final class SiteOfficeViewModel: ObservableObject {
    /// Re-publishes store changes so views refresh (iOS 15 has no Observation framework).
    private var storeChanges: [AnyCancellable] = []
    private let profileStore: ProfileStore
    private let settings: SettingsStore
    private let haptics: HapticsService

    @Published var isConfirmingReset = false
    @Published var toastMessage: String?
    @Published private(set) var toastIsError = false

    init(profileStore: ProfileStore, settings: SettingsStore, haptics: HapticsService) {
        self.profileStore = profileStore
        self.settings = settings
        self.haptics = haptics
        profileStore.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &storeChanges)
        settings.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &storeChanges)
    }

    var hapticsEnabled: Bool {
        get { settings.hapticsEnabled }
        set {
            settings.hapticsEnabled = newValue
            haptics.selection()
        }
    }

    var soundEnabled: Bool {
        get { settings.soundEnabled }
        set { settings.soundEnabled = newValue }
    }

    var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    func requestReset() {
        isConfirmingReset = true
    }

    func confirmReset() {
        do {
            try profileStore.resetProgress()
            settings.hasSeenGuide = false
            toastIsError = false
            toastMessage = "The site is cleared. Fresh start!"
            haptics.notify(.warning)
        } catch {
            toastIsError = true
            toastMessage = "Could not reset: \(error.localizedDescription)"
            haptics.notify(.error)
        }
    }
}
