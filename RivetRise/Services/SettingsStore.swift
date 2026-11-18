import Combine
import Foundation

/// Player preferences backed by `UserDefaults`.
@MainActor
final class SettingsStore: ObservableObject {
    private enum Keys {
        static let hapticsEnabled = "settings.hapticsEnabled"
        static let soundEnabled = "settings.soundEnabled"
        static let hasSeenGuide = "settings.hasSeenGuide"
    }

    private let defaults: UserDefaults

    @Published var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.hapticsEnabled) }
    }

    @Published var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Keys.soundEnabled) }
    }

    /// Whether the site manual has been read before the first shift on the crane.
    @Published var hasSeenGuide: Bool {
        didSet { defaults.set(hasSeenGuide, forKey: Keys.hasSeenGuide) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hapticsEnabled = defaults.object(forKey: Keys.hapticsEnabled) as? Bool ?? true
        soundEnabled = defaults.object(forKey: Keys.soundEnabled) as? Bool ?? true
        hasSeenGuide = defaults.bool(forKey: Keys.hasSeenGuide)
    }
}
