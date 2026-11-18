import Foundation
import Combine
import SwiftUI

/// Drives one shift on the crane: briefing, countdown, running, pause and the pay envelope.
/// Bridges the SpriteKit scene to SwiftUI state.
@MainActor
final class GameViewModel: ObservableObject, Identifiable {
    /// Re-publishes store changes so views refresh (iOS 15 has no Observation framework).
    private var storeChanges: [AnyCancellable] = []
    enum Phase: Equatable {
        case ready
        case countdown(Int)
        case running
        case paused
        case finished(RunOutcome)
    }

    /// A short callout shown under the HUD after notable moments.
    struct Callout: Equatable {
        enum Style { case great, good, warning, danger }
        let id = UUID()
        let text: String
        let style: Style
    }

    let id = UUID()
    @Published private(set) var phase: Phase = .ready
    @Published private(set) var hud: GameHUDState
    /// Created lazily in `prepareScene()` so presenting the view is cheap.
    @Published private(set) var scene: TowerScene?
    /// Changes whenever a fresh scene is created so SwiftUI rebuilds the `SpriteView`.
    @Published private(set) var sceneID = UUID()
    @Published private(set) var callout: Callout?
    /// The site shift that just started, shown as a banner for a moment.
    @Published private(set) var shiftBanner: SiteShift?
    /// Incremented on misses and collapses so the view can flash.
    @Published private(set) var hitFlashCount = 0

    private let profileStore: ProfileStore
    private let haptics: HapticsService
    private let sound: SoundService
    private let leaderboard: LeaderboardService?
    private let usesAutopilot: Bool
    private let seedSource: () -> UInt64
    private var countdownTask: Task<Void, Never>?
    private var calloutTask: Task<Void, Never>?
    private var bannerTask: Task<Void, Never>?

    var foreman: Foreman { profileStore.loadout.foreman }
    var loadout: Loadout { profileStore.loadout }
    var bestScore: Int { profileStore.profile.bestScore }
    var bestFloors: Int { profileStore.profile.bestFloors }
    var shiftNumber: Int { profileStore.profile.totalRuns + (isFinished ? 0 : 1) }

    var isRunning: Bool { phase == .running }
    var isFinished: Bool {
        if case .finished = phase { return true }
        return false
    }

    init(
        profileStore: ProfileStore,
        haptics: HapticsService,
        sound: SoundService,
        leaderboard: LeaderboardService? = nil,
        usesAutopilot: Bool = false,
        seedSource: @escaping () -> UInt64 = { UInt64.random(in: 1...UInt64.max) }
    ) {
        self.profileStore = profileStore
        self.haptics = haptics
        self.sound = sound
        self.leaderboard = leaderboard
        self.usesAutopilot = usesAutopilot
        self.seedSource = seedSource
        hud = GameHUDState(loadout: profileStore.loadout)
        profileStore.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &storeChanges)
    }

    // MARK: - Scene management

    /// Builds the scene if it does not exist yet. Safe to call repeatedly.
    func prepareScene() {
        guard scene == nil else { return }
        installScene()
    }

    private func installScene() {
        scene?.gameDelegate = nil
        let loadout = profileStore.loadout
        hud = GameHUDState(loadout: loadout)
        // The autopilot always plays the same shift so UI tests and screenshot tours are repeatable.
        let seed = usesAutopilot ? 1218 : seedSource()
        let newScene = TowerScene(size: CGSize(width: 402, height: 874), loadout: loadout, seed: seed, autopilot: usesAutopilot)
        newScene.gameDelegate = self
        scene = newScene
        sceneID = UUID()
    }

    // MARK: - Intents

    /// Starts the 3-2-1 countdown and then the shift.
    func beginRun() {
        guard phase == .ready else { return }
        prepareScene()
        haptics.prepare()
        sound.updateAmbience(playing: true)
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            for value in stride(from: 3, through: 1, by: -1) {
                guard let self, !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { self.phase = .countdown(value) }
                self.haptics.impact(.light)
                self.sound.play(.count, volume: 0.6)
                try? await Task.sleep(nanoseconds: 650_000_000)
            }
            guard let self, !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { self.phase = .running }
            self.sound.play(.go, volume: 0.7)
            self.scene?.startRun()
        }
    }

    /// The accessibility alternative to tapping the scene.
    func tap() {
        guard phase == .running else { return }
        scene?.handleTap()
    }

    func pause() {
        guard phase == .running else { return }
        scene?.setSuspended(true)
        withAnimation(.easeOut(duration: 0.2)) { phase = .paused }
        haptics.selection()
    }

    func resume() {
        guard phase == .paused else { return }
        scene?.setSuspended(false)
        withAnimation(.easeOut(duration: 0.2)) { phase = .running }
        haptics.selection()
    }

    /// Pauses automatically when the app leaves the foreground mid-shift.
    func handleScenePhaseChange(_ scenePhase: ScenePhase) {
        guard scenePhase != .active else { return }
        if case .countdown = phase {
            countdownTask?.cancel()
            phase = .ready
        } else {
            pause()
        }
    }

    /// Creates a fresh scene with the latest upgrades and returns to the briefing.
    func restart() {
        countdownTask?.cancel()
        callout = nil
        shiftBanner = nil
        installScene()
        withAnimation(.easeOut(duration: 0.25)) { phase = .ready }
    }

    /// Releases the scene when the game screen goes away.
    func tearDown() {
        countdownTask?.cancel()
        calloutTask?.cancel()
        bannerTask?.cancel()
        sound.updateAmbience(playing: false)
        scene?.gameDelegate = nil
        scene = nil
    }

    private func show(_ text: String, style: Callout.Style) {
        let next = Callout(text: text, style: style)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { callout = next }
        calloutTask?.cancel()
        calloutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            guard let self, !Task.isCancelled, self.callout == next else { return }
            withAnimation(.easeOut(duration: 0.3)) { self.callout = nil }
        }
    }

    private func announce(_ shift: SiteShift) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { shiftBanner = shift }
        bannerTask?.cancel()
        bannerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard let self, !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { self.shiftBanner = nil }
        }
    }
}

// MARK: - Weekly league

extension GameViewModel {
    /// Integration point: every finished shift is reported to the weekly board.
    /// The mock ignores it; a networked service posts it (see `LeaderboardService`).
    private func submitToLeague(_ summary: RunSummary) {
        guard let leaderboard else { return }
        let runID = profileStore.runs.first?.id ?? UUID()
        let submission = ShiftSubmission(
            submissionID: runID.uuidString.lowercased(),
            week: WeekKey(date: .now).description,
            floors: summary.floors,
            score: summary.score,
            rivets: summary.rivets,
            perfects: summary.perfects,
            districts: summary.districts,
            durationSeconds: summary.duration,
            foremanID: summary.foremanID
        )
        Task {
            do {
                try await leaderboard.submit(submission)
            } catch {
                NSLog("Rivet Rise leaderboard submission failed: %@", error.localizedDescription)
            }
        }
    }
}

// MARK: - TowerSceneDelegate

extension GameViewModel: TowerSceneDelegate {
    func scene(_ scene: TowerScene, didUpdate hud: GameHUDState) {
        guard scene === self.scene, self.hud != hud else { return }
        self.hud = hud
    }

    func scene(_ scene: TowerScene, didRegister event: RunEvent) {
        guard scene === self.scene else { return }
        switch event {
        case .released(let forced):
            sound.play(.release, volume: forced ? 0.9 : 0.6)
            if forced { haptics.notify(.warning) }
        case .landed(let perfect, let inTune):
            sound.play(perfect ? .perfect : .land, volume: perfect ? 0.8 : 0.7)
            haptics.impact(perfect ? .heavy : .medium)
            if perfect, inTune {
                show("PERFECT · IN TUNE", style: .great)
            } else if perfect {
                show(hud.perfectStreak >= 2 ? "PERFECT x\(hud.perfectStreak + 1)" : "PERFECT", style: .great)
            } else if inTune {
                show("IN TUNE · sway calmed", style: .good)
            }
        case .missed(let forgiven):
            hitFlashCount += 1
            sound.play(.miss)
            haptics.notify(.error)
            show(forgiven ? "\(foreman.name) saved it: no hard hat lost" : "Missed the tower! -1 hard hat", style: .danger)
        case .regrow:
            show("Streak bonus: module widened", style: .good)
        case .riveted:
            sound.play(.rivet)
            haptics.impact(.heavy)
            show("RIVETED · points x2", style: .great)
        case .bentRivet:
            sound.play(.bent)
            haptics.notify(.warning)
            show("Bent rivet! The tower shakes", style: .warning)
        case .district(let kind):
            sound.play(.district)
            haptics.notify(.success)
            show("\(kind.title.uppercased()) DISTRICT · \(kind.districtEffect)", style: .great)
        case .penthouse(let count):
            sound.play(.penthouse)
            haptics.notify(.success)
            show("PENTHOUSE · \(count) \(count == 1 ? "floor" : "floors") riveted", style: .great)
        case .collapse(let floors):
            hitFlashCount += 1
            sound.play(.collapse)
            haptics.notify(.error)
            show(floors > 0 ? "COLLAPSE! \(floors) floors fell" : "Too much sway! -1 hard hat", style: .danger)
        case .gustWarning(let direction):
            sound.play(.gust, volume: 0.5)
            show("Gust coming from the \(direction > 0 ? "left" : "right")!", style: .warning)
        case .creak:
            sound.play(.creak)
            haptics.impact(.light)
            show("Cable creaking! It's about to snap", style: .warning)
        case .clutch:
            haptics.notify(.success)
            show("CABLE CATCH · +\(Balance.clutchBonus)", style: .great)
        case .rushUp(let level):
            if level == loadout.rushCap { show("FULL RUSH · \(Formatters.multiplier(hud.rushMultiplier))", style: .good) }
        case .shiftChanged(let shift):
            sound.play(.shift)
            haptics.impact(.medium)
            announce(shift)
        case .gustStarted, .gustEnded, .gameOver:
            break
        }
    }

    func scene(_ scene: TowerScene, didFinishWith summary: RunSummary) {
        guard scene === self.scene else { return }
        let outcome = profileStore.recordRun(summary)
        submitToLeague(summary)
        sound.play(.gameOver, volume: 0.7)
        sound.updateAmbience(playing: false)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { phase = .finished(outcome) }
        if outcome.isNewBestScore { haptics.notify(.success) }
    }
}
