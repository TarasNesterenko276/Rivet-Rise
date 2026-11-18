import SpriteKit
import SwiftUI

/// Full-screen shift: SpriteKit crane and tower underneath, SwiftUI HUD and overlays on top.
struct GameView: View {
    @StateObject private var viewModel: GameViewModel
    /// Called when the player leaves. A floor means "send the hoist there next".
    let onExit: (SiteFloor?) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var hitFlash: Double = 0

    init(viewModel: GameViewModel, onExit: @escaping (SiteFloor?) -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onExit = onExit
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Theme.Colors.asphalt.ignoresSafeArea()

                if let scene = viewModel.scene {
                    SpriteView(scene: scene, preferredFramesPerSecond: 60)
                        .id(viewModel.sceneID)
                        .ignoresSafeArea()
                        .accessibilityElement()
                        .accessibilityLabel("Crane and tower")
                        .accessibilityHint("Tap to drop the module. Tap again right after landing to drive the rivet.")
                        .accessibilityAddTraits(.allowsDirectInteraction)
                        .accessibilityAction { viewModel.tap() }
                        .accessibilityIdentifier(AccessibilityID.Game.tapArea)
                        .onAppear { updateReserves(scene, proxy: proxy) }
                        .onChange(of: proxy.size) { _ in updateReserves(scene, proxy: proxy) }
                }

                RadialGradient(colors: [.clear, Theme.Colors.danger.opacity(0.55)], center: .center, startRadius: 160, endRadius: 600)
                    .ignoresSafeArea()
                    .opacity(hitFlash)
                    .allowsHitTesting(false)

                GameHUDView(
                    hud: viewModel.hud,
                    callout: viewModel.callout,
                    shiftBanner: viewModel.shiftBanner,
                    bestFloors: viewModel.bestFloors,
                    isVisible: viewModel.isRunning || viewModel.phase == .paused,
                    onPause: viewModel.pause
                )

                overlays
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Game.screen)
        .statusBarHidden()
        .hidesSystemOverlays()
        .onAppear { viewModel.prepareScene() }
        .onDisappear { viewModel.tearDown() }
        .onChange(of: scenePhase) { newPhase in
            viewModel.handleScenePhaseChange(newPhase)
        }
        .onChange(of: viewModel.hitFlashCount) { _ in
            hitFlash = 1
            withAnimation(.easeOut(duration: 0.7)) { hitFlash = 0 }
        }
    }

    /// Keeps the crane jib below the top HUD and the tower base above the bottom HUD.
    private func updateReserves(_ scene: TowerScene, proxy: GeometryProxy) {
        scene.topReserve = proxy.safeAreaInsets.top + 128
        scene.bottomReserve = proxy.safeAreaInsets.bottom + 92
    }

    @ViewBuilder
    private var overlays: some View {
        switch viewModel.phase {
        case .ready:
            ShiftBriefingOverlay(
                foreman: viewModel.foreman,
                shiftNumber: viewModel.shiftNumber,
                bestFloors: viewModel.bestFloors,
                bestScore: viewModel.bestScore,
                onStart: viewModel.beginRun,
                onLeave: { onExit(nil) }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        case .countdown(let value):
            CountdownOverlay(value: value)
                .transition(.opacity)
        case .running:
            EmptyView()
        case .paused:
            PauseOverlay(
                hud: viewModel.hud,
                onResume: viewModel.resume,
                onRestart: viewModel.restart,
                onQuit: { onExit(nil) }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        case .finished(let outcome):
            PayEnvelopeOverlay(
                outcome: outcome,
                foreman: viewModel.foreman,
                onAgain: viewModel.restart,
                onYard: { onExit(.yard) },
                onSite: { onExit(nil) }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
