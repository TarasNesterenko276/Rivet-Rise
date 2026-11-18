import Foundation

/// Composition root: builds the stores and services the whole app shares.
@MainActor
final class AppDependencies {
    let storage: ProfileStorage
    let profileStore: ProfileStore
    let settings: SettingsStore
    let haptics: HapticsService
    let sound: SoundService
    /// Weekly TOP PLAYERS board. Swap `MockLeaderboardService` for a networked implementation.
    let leaderboard: LeaderboardService
    let onlineLeaderboard: SupabaseLeaderboardService?
    let isUITesting: Bool
    /// The crane plays by itself (UI tests and screenshot tours cannot play in real time).
    let usesAutopilot: Bool

    static let uiTestingArgument = "--uitesting"
    static let autopilotArgument = "--autopilot"
    /// Starts a UI-test session with no bolts, for empty-state and refusal checks.
    static let brokeArgument = "--broke"
    /// Seeds a few finished shifts so the site log has history.
    static let historyArgument = "--history"
    /// Keeps the site manual unread so the first-shift flow can be tested.
    static let showManualArgument = "--show-manual"
    private static let uiTestingDefaultsSuite = "com.rivetrise.game18.uitesting"

    init(launchArguments: [String] = CommandLine.arguments) throws {
        isUITesting = launchArguments.contains(Self.uiTestingArgument)
        usesAutopilot = launchArguments.contains(Self.autopilotArgument)

        let defaults: UserDefaults
        if isUITesting, let suite = UserDefaults(suiteName: Self.uiTestingDefaultsSuite) {
            suite.removePersistentDomain(forName: Self.uiTestingDefaultsSuite)
            defaults = suite
        } else {
            defaults = .standard
        }

        storage = try PersistenceController.makeStorage(inMemory: isUITesting)
        profileStore = try ProfileStore(storage: storage)
        settings = SettingsStore(defaults: defaults)

        let settings = self.settings
        haptics = HapticsService { settings.hapticsEnabled }
        sound = isUITesting ? .silent : SoundService { settings.soundEnabled }
        let configuredOnlineLeaderboard = SupabaseLeaderboardService()
        onlineLeaderboard = configuredOnlineLeaderboard
        if isUITesting {
            leaderboard = MockLeaderboardService()
        } else if let configuredOnlineLeaderboard {
            leaderboard = configuredOnlineLeaderboard
        } else {
            leaderboard = UnavailableLeaderboardService()
        }

        if isUITesting {
            // Deterministic state so UI tests can exercise purchases without playing.
            settings.hasSeenGuide = !launchArguments.contains(Self.showManualArgument)
            if !launchArguments.contains(Self.brokeArgument) {
                try profileStore.grantBolts(1_000)
            }
            if launchArguments.contains(Self.historyArgument) {
                Self.seedHistory(into: profileStore)
            }
        }
    }

    private static func seedHistory(into store: ProfileStore) {
        // (score, floors, seconds, perfects, rivets, districts)
        let shifts: [(Int, Int, Double, Int, Int, Int)] = [
            (620, 14, 71, 4, 6, 1), (1_480, 27, 140, 11, 15, 3), (980, 19, 96, 7, 9, 2),
            (2_240, 36, 188, 17, 22, 5), (1_760, 31, 160, 13, 18, 4)
        ]
        for (score, floors, seconds, perfects, rivets, districts) in shifts {
            store.recordRun(RunSummary(
                score: score,
                bolts: score / Balance.pointsPerBolt + districts * 4,
                floors: floors,
                duration: seconds,
                perfects: perfects,
                rivets: rivets,
                districts: districts,
                penthouses: floors / 14,
                clutches: districts > 3 ? 1 : 0,
                collapses: 1,
                bestRush: 3,
                foremanID: Foreman.starter.rawValue
            ))
        }
        // Keep the seeded bolts predictable for purchase tests.
        try? store.grantBolts(-store.bolts + 1_000)
    }
}
