import SwiftUI

/// Hosts the building site, the hoist cab carrying the current section, and the full-screen shift.
/// Sections ride up from the bottom like a construction hoist instead of being pushed sideways.
struct RootView: View {
    let dependencies: AppDependencies

    @State private var floor: SiteFloor?
    /// When the manual is shown before the very first shift, finishing it starts the game.
    @State private var manualStartsShift = false
    @State private var game: GameViewModel?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            SiteView(
                viewModel: SiteViewModel(profileStore: dependencies.profileStore, sound: dependencies.sound, haptics: dependencies.haptics),
                animates: !reduceMotion && !dependencies.isUITesting && floor == nil && game == nil,
                onOpen: open,
                onClockIn: clockIn
            )

            if let floor {
                section(floor)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom))
                    .zIndex(1)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.92), value: floor)
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $game) { model in
            GameView(viewModel: model) { destination in
                game = nil
                if let destination { open(destination) }
            }
        }
    }

    @ViewBuilder
    private func section(_ floor: SiteFloor) -> some View {
        switch floor {
        case .yard:
            RiggingYardView(viewModel: RiggingYardViewModel(profileStore: dependencies.profileStore, haptics: dependencies.haptics, sound: dependencies.sound), onGround: ground)
        case .lockers:
            CrewLockersView(viewModel: CrewLockersViewModel(profileStore: dependencies.profileStore, haptics: dependencies.haptics, sound: dependencies.sound), onGround: ground)
        case .log:
            SiteLogView(viewModel: SiteLogViewModel(profileStore: dependencies.profileStore), onGround: ground)
        case .manual:
            ManualView(viewModel: ManualViewModel(settings: dependencies.settings, startsShiftWhenDone: manualStartsShift) { startShift in
                ground()
                if startShift { launchGame() }
            }, onGround: ground)
        case .board:
            TopPlayersView(
                viewModel: TopPlayersViewModel(profileStore: dependencies.profileStore, service: dependencies.leaderboard, haptics: dependencies.haptics, sound: dependencies.sound),
                onGround: ground
            )
        case .office:
            SiteOfficeView(
                viewModel: SiteOfficeViewModel(profileStore: dependencies.profileStore, settings: dependencies.settings, haptics: dependencies.haptics),
                onShowManual: { open(.manual) },
                onGround: ground
            )
        }
    }

    private func open(_ next: SiteFloor) {
        manualStartsShift = false
        dependencies.sound.play(.tap, volume: 0.5)
        floor = next
    }

    private func ground() {
        manualStartsShift = false
        floor = nil
    }

    /// The first shift is preceded by the site manual so new players learn the rules.
    private func clockIn() {
        if dependencies.settings.hasSeenGuide {
            launchGame()
        } else {
            floor = .manual
            manualStartsShift = true
        }
    }

    private func launchGame() {
        game = GameViewModel(
            profileStore: dependencies.profileStore,
            haptics: dependencies.haptics,
            sound: dependencies.sound,
            leaderboard: dependencies.leaderboard,
            usesAutopilot: dependencies.usesAutopilot
        )
    }
}
