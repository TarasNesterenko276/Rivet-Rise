import SpriteKit
import UIKit

@MainActor
protocol TowerSceneDelegate: AnyObject {
    func scene(_ scene: TowerScene, didUpdate hud: GameHUDState)
    func scene(_ scene: TowerScene, didRegister event: RunEvent)
    func scene(_ scene: TowerScene, didFinishWith summary: RunSummary)
}

/// Draws a `RunSession`: the crane jib and hook, the swaying tower, falling modules,
/// the rivet ring, wind streaks, fog and night. All rules live in `RunSession`.
final class TowerScene: SKScene {
    weak var gameDelegate: TowerSceneDelegate?

    private(set) var session: RunSession
    private let autopilot: Bool
    private var isRunning = false
    private var isSuspended = false
    private var lastTime: TimeInterval?
    private var hudAccumulator: Double = 0

    /// Top inset reserved for the HUD, set by the hosting view.
    var topReserve: CGFloat = 150 { didSet { if oldValue != topReserve { layoutStatic() } } }
    /// Bottom inset reserved for the HUD.
    var bottomReserve: CGFloat = 110 { didSet { if oldValue != bottomReserve { layoutStatic() } } }

    // Layers
    private let skyLayer = SKNode()
    private let world = SKNode()
    private let towerLayer = SKNode()
    private let fxLayer = SKNode()
    private let craneLayer = SKNode()
    private let overlayLayer = SKNode()

    // Nodes
    private var skyNodes: [String: SKSpriteNode] = [:]
    private var activeSky = "sky_dawn"
    private let foundation = SKSpriteNode(imageNamed: "foundation")
    private var floorNodes: [SKSpriteNode] = []
    private let jib = SKSpriteNode(imageNamed: "crane_jib")
    private let trolley = SKSpriteNode(imageNamed: "crane_trolley")
    private let cable = SKShapeNode()
    private let hook = SKSpriteNode(imageNamed: "crane_hook")
    private let module = SKSpriteNode()
    private let fallingModule = SKSpriteNode()
    private let rivetRing = SKShapeNode(circleOfRadius: 60)
    private let rivetTarget = SKShapeNode(circleOfRadius: 20)
    private let plumbLine = SKShapeNode()
    private let plumbBob = SKSpriteNode(imageNamed: "plumb_bob")
    private let tuneBand = SKShapeNode()
    private let nightShade = SKSpriteNode(color: .black, size: .zero)
    private let hookLamp = SKSpriteNode(imageNamed: "spark")
    private let fog = SKSpriteNode(imageNamed: "fog_bank")
    private var cameraOffset: CGFloat = 0
    private var gustStreakTimer: Double = 0

    private var textures: [String: SKTexture] = [:]

    init(size: CGSize, loadout: Loadout, seed: UInt64, autopilot: Bool) {
        session = RunSession(loadout: loadout, seed: seed)
        self.autopilot = autopilot
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.25, green: 0.55, blue: 0.66, alpha: 1)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Geometry

    /// Points per floor unit (a full-width module).
    private var unit: CGFloat { min(size.width * 0.44, size.height * 0.3, 360) }
    private var floorHeight: CGFloat { unit * CGFloat(Balance.floorHeight) * 0.882 }
    private var groundY: CGFloat { bottomReserve + 40 }
    private var jibY: CGFloat { size.height - topReserve }
    private var hookRestY: CGFloat { jibY - 70 - floorHeight }

    private func floorY(_ index: Int) -> CGFloat {
        groundY + floorHeight * (CGFloat(index) + 0.5)
    }

    private func screenX(_ x: Double) -> CGFloat { size.width / 2 + CGFloat(x) * unit }

    // MARK: - Setup

    override func didMove(to view: SKView) {
        guard skyLayer.parent == nil else { return }
        for name in ["sky_dawn", "sky_day", "sky_dusk", "sky_night", "floor_residential", "floor_office", "floor_garden", "floor_penthouse", "floor_girder", "spark", "dust"] {
            textures[name] = SKTexture(imageNamed: name)
        }
        addChild(skyLayer)
        skyLayer.zPosition = -10
        for name in ["sky_dawn", "sky_day", "sky_dusk", "sky_night"] {
            let node = SKSpriteNode(texture: textures[name])
            node.alpha = name == activeSky ? 1 : 0
            skyNodes[name] = node
            skyLayer.addChild(node)
        }

        addChild(world)
        world.addChild(foundation)
        foundation.zPosition = 1
        world.addChild(towerLayer)
        towerLayer.zPosition = 2
        world.addChild(fxLayer)
        fxLayer.zPosition = 5

        nightShade.alpha = 0
        nightShade.zPosition = 6
        nightShade.anchorPoint = .zero
        addChild(nightShade)

        addChild(craneLayer)
        craneLayer.zPosition = 10
        craneLayer.addChild(jib)
        cable.strokeColor = SKColor(white: 0.1, alpha: 1)
        cable.lineWidth = 2
        craneLayer.addChild(cable)
        craneLayer.addChild(trolley)
        hookLamp.blendMode = .add
        hookLamp.alpha = 0
        craneLayer.addChild(hookLamp)
        craneLayer.addChild(hook)
        craneLayer.addChild(module)
        world.addChild(fallingModule)
        fallingModule.zPosition = 4
        fallingModule.isHidden = true

        fog.alpha = 0
        fog.zPosition = 12
        addChild(fog)

        addChild(overlayLayer)
        overlayLayer.zPosition = 20
        rivetRing.strokeColor = SKColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
        rivetRing.lineWidth = 5
        rivetRing.glowWidth = 2
        rivetRing.isHidden = true
        rivetTarget.strokeColor = SKColor(red: 0.85, green: 0.25, blue: 0.15, alpha: 0.9)
        rivetTarget.lineWidth = 3
        rivetTarget.isHidden = true
        world.addChild(rivetRing)
        world.addChild(rivetTarget)
        rivetRing.zPosition = 8
        rivetTarget.zPosition = 8

        tuneBand.fillColor = SKColor(red: 0.24, green: 0.6, blue: 0.35, alpha: 0.35)
        tuneBand.strokeColor = .clear
        overlayLayer.addChild(tuneBand)
        plumbLine.strokeColor = SKColor(white: 0.1, alpha: 1)
        plumbLine.lineWidth = 2
        overlayLayer.addChild(plumbLine)
        plumbBob.size = CGSize(width: 22, height: 35)
        plumbBob.anchorPoint = CGPoint(x: 0.5, y: 1)
        overlayLayer.addChild(plumbBob)

        layoutStatic()
        rebuildTower()
        updateModuleTexture(force: true)
        renderDynamic(dt: 0)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard skyLayer.parent != nil else { return }
        layoutStatic()
        rebuildTower()
        updateModuleTexture(force: true)
    }

    private func layoutStatic() {
        guard skyLayer.parent != nil else { return }
        for node in skyNodes.values {
            let scale = max(size.width / node.texture!.size().width, size.height / node.texture!.size().height)
            node.setScale(scale)
            node.position = CGPoint(x: size.width / 2, y: size.height / 2)
        }
        foundation.size = CGSize(width: max(size.width, unit * 1.5), height: max(size.width, unit * 1.5) * 170 / 430)
        foundation.anchorPoint = CGPoint(x: 0.5, y: 1)
        foundation.position = CGPoint(x: size.width / 2, y: groundY + foundation.size.height * 22 / 170)
        let jibWidth = max(size.width + 40, unit * 2.4)
        jib.size = CGSize(width: jibWidth, height: jibWidth * 64 / 470)
        jib.position = CGPoint(x: size.width / 2 - 10, y: jibY + jib.size.height * 0.15)
        trolley.size = CGSize(width: 46, height: 24)
        hook.size = CGSize(width: 34, height: 51)
        nightShade.size = size
        fog.size = CGSize(width: size.width * 1.2, height: size.width * 1.2 * 300 / 430)
        fog.position = CGPoint(x: size.width / 2, y: hookRestY + 10)
        hookLamp.size = CGSize(width: unit * 1.6, height: unit * 1.6)

        // Plumb gauge: bottom-left, above the HUD.
        let pivot = CGPoint(x: 34, y: bottomReserve + 132)
        plumbLine.position = pivot
        plumbBob.position = pivot
        let band = CGMutablePath()
        let arc = CGFloat(Balance.inTuneBand) * 0.6
        band.move(to: pivot)
        band.addArc(center: pivot, radius: 70, startAngle: -.pi / 2 - arc, endAngle: -.pi / 2 + arc, clockwise: false)
        band.closeSubpath()
        tuneBand.path = band
    }

    // MARK: - Control

    func startRun() {
        isRunning = true
        lastTime = nil
    }

    func setSuspended(_ suspended: Bool) {
        isSuspended = suspended
        isPaused = suspended
        lastTime = nil
    }

    /// Taps are ignored until the countdown is over, so a countdown tap never drops a module.
    func handleTap() {
        guard isRunning, !isSuspended, !session.isOver, !autopilot else { return }
        apply(session.tap())
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTap()
    }

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        guard isRunning, !isSuspended else {
            lastTime = currentTime
            renderDynamic(dt: 0)
            return
        }
        let dt = min(currentTime - (lastTime ?? currentTime), 1.0 / 30.0)
        lastTime = currentTime
        guard !session.isOver else { return }

        if autopilot, Autopilot.shouldTap(session) {
            apply(session.tap())
        }
        apply(session.update(dt))
        renderDynamic(dt: dt)

        hudAccumulator += dt
        if hudAccumulator >= 0.1 {
            hudAccumulator = 0
            gameDelegate?.scene(self, didUpdate: GameHUDState(session: session))
        }
    }

    private func apply(_ events: [RunEvent]) {
        for event in events {
            handle(event)
            gameDelegate?.scene(self, didRegister: event)
        }
        if !events.isEmpty {
            gameDelegate?.scene(self, didUpdate: GameHUDState(session: session))
        }
        if events.contains(.gameOver) {
            isRunning = false
            run(.wait(forDuration: 0.9)) { [weak self] in
                guard let self else { return }
                self.gameDelegate?.scene(self, didFinishWith: self.session.summary)
            }
        }
    }

    // MARK: - Event visuals

    private func handle(_ event: RunEvent) {
        switch event {
        case .released:
            fallingModule.texture = module.texture
            fallingModule.size = module.size
            fallingModule.isHidden = false
        case .landed(let perfect, _):
            fallingModule.isHidden = true
            addLandedFloor(perfect: perfect)
        case .missed:
            dropMissedModule()
        case .riveted:
            floorNodes.last?.colorBlendFactor = 0
            sparks(at: jointPoint, count: 14)
        case .bentRivet:
            shake(intensity: 4)
        case .collapse(let floors):
            collapse(floors)
        case .penthouse:
            for node in floorNodes { node.colorBlendFactor = 0 }
            sparks(at: jointPoint, count: 24)
        case .shiftChanged:
            updateSkyTarget()
        default:
            break
        }
    }

    private var jointPoint: CGPoint {
        guard let last = floorNodes.last else { return CGPoint(x: size.width / 2, y: groundY) }
        return CGPoint(x: last.position.x, y: last.position.y - floorHeight / 2)
    }

    private func texture(for kind: FloorKind, heavy: Bool, width: Double) -> SKTexture {
        let base = textures[kind.art(heavy: heavy)] ?? SKTexture(imageNamed: kind.art(heavy: heavy))
        // Trimmed modules are cropped from the centre of the full module, never stretched.
        let w = min(max(width, 0.02), 1)
        return SKTexture(rect: CGRect(x: (1 - w) / 2, y: 0, width: w, height: 1), in: base)
    }

    private var moduleKey = ""

    /// Refreshes the module on the hook when its kind, width or the shift changes.
    private func updateModuleTexture(force: Bool = false) {
        let width = session.currentWidth
        let key = "\(session.currentKind.rawValue)-\(session.isHeavyShift)-\(width)-\(unit)"
        guard force || key != moduleKey else { return }
        moduleKey = key
        module.texture = texture(for: session.currentKind, heavy: session.isHeavyShift, width: width)
        module.size = CGSize(width: CGFloat(width) * unit, height: floorHeight)
    }

    private func rebuildTower() {
        towerLayer.removeAllChildren()
        floorNodes = session.floors.enumerated().map { index, floor in
            let node = makeFloorNode(floor)
            node.position = CGPoint(x: screenX(floor.x), y: floorY(index))
            towerLayer.addChild(node)
            return node
        }
    }

    private func makeFloorNode(_ floor: PlacedFloor) -> SKSpriteNode {
        let node = SKSpriteNode(texture: texture(for: floor.kind, heavy: floor.heavy, width: floor.width))
        node.size = CGSize(width: CGFloat(floor.width) * unit, height: floorHeight)
        node.color = .black
        node.colorBlendFactor = floor.riveted ? 0 : 0.12
        return node
    }

    private func addLandedFloor(perfect: Bool) {
        guard let floor = session.floors.last else { return }
        let index = session.floors.count - 1
        let node = makeFloorNode(floor)
        node.position = CGPoint(x: screenX(floor.x + session.swayOffset), y: floorY(index))
        towerLayer.addChild(node)
        floorNodes.append(node)
        node.run(.sequence([.scaleY(to: 0.9, duration: 0.06), .scaleY(to: 1, duration: 0.12)]))

        // The overhang that was cut off tumbles away.
        let dropped = session.currentWidth
        if !perfect {
            let fallX = lastReleaseX
            let full = lastReleaseWidth
            let cut = full - dropped
            if cut > 0.01 {
                let side: Double = (fallX - (floor.x + session.swayOffset)) > 0 ? 1 : -1
                let pieceX = floor.x + session.swayOffset + side * (dropped / 2 + cut / 2)
                let piece = SKSpriteNode(texture: texture(for: floor.kind, heavy: floor.heavy, width: cut))
                piece.size = CGSize(width: CGFloat(cut) * unit, height: floorHeight)
                piece.position = CGPoint(x: screenX(pieceX), y: floorY(index))
                fxLayer.addChild(piece)
                piece.run(.sequence([
                    .group([
                        .moveBy(x: CGFloat(side) * 60, y: -size.height * 0.9, duration: 1.1),
                        .rotate(byAngle: CGFloat(-side) * 2.2, duration: 1.1),
                        .fadeOut(withDuration: 1.1)
                    ]),
                    .removeFromParent()
                ]))
            }
        }
        dust(at: CGPoint(x: node.position.x, y: node.position.y - floorHeight / 2))
        if perfect { sparks(at: CGPoint(x: node.position.x, y: node.position.y + floorHeight / 2), count: 8) }
    }

    private var lastReleaseX: Double = 0
    private var lastReleaseWidth: Double = 1

    private func dropMissedModule() {
        let node = SKSpriteNode(texture: fallingModule.texture)
        node.size = fallingModule.size
        node.position = fallingModule.position
        fallingModule.isHidden = true
        fxLayer.addChild(node)
        node.run(.sequence([
            .group([.moveBy(x: 0, y: -size.height, duration: 1.2), .rotate(byAngle: 1.4, duration: 1.2), .fadeOut(withDuration: 1.2)]),
            .removeFromParent()
        ]))
        shake(intensity: 6)
    }

    private func collapse(_ count: Int) {
        let removed = floorNodes.suffix(count)
        floorNodes.removeLast(min(count, floorNodes.count))
        for (offset, node) in removed.enumerated() {
            node.removeFromParent()
            fxLayer.addChild(node)
            let side: CGFloat = session.swayOffset >= 0 ? 1 : -1
            node.run(.sequence([
                .wait(forDuration: Double(offset) * 0.05),
                .group([
                    .moveBy(x: side * CGFloat(80 + offset * 30), y: -size.height, duration: 1.4),
                    .rotate(byAngle: -side * CGFloat(1 + Double(offset) * 0.3), duration: 1.4),
                    .fadeOut(withDuration: 1.4)
                ]),
                .removeFromParent()
            ]))
        }
        shake(intensity: 12)
        rebuildTower()
    }

    private func dust(at point: CGPoint) {
        for i in 0..<6 {
            let puff = SKSpriteNode(texture: textures["dust"])
            puff.size = CGSize(width: 26, height: 26)
            puff.position = point
            puff.alpha = 0.8
            fxLayer.addChild(puff)
            let dx = CGFloat(i - 3) * 14
            puff.run(.sequence([
                .group([.moveBy(x: dx, y: 8, duration: 0.5), .scale(to: 1.8, duration: 0.5), .fadeOut(withDuration: 0.5)]),
                .removeFromParent()
            ]))
        }
    }

    private func sparks(at point: CGPoint, count: Int) {
        for i in 0..<count {
            let spark = SKSpriteNode(texture: textures["spark"])
            spark.size = CGSize(width: 10, height: 10)
            spark.position = point
            spark.blendMode = .add
            fxLayer.addChild(spark)
            let angle = CGFloat(i) / CGFloat(count) * .pi * 2
            let distance = CGFloat(30 + (i * 13) % 30)
            spark.run(.sequence([
                .group([.moveBy(x: cos(angle) * distance, y: sin(angle) * distance - 10, duration: 0.45), .fadeOut(withDuration: 0.45)]),
                .removeFromParent()
            ]))
        }
    }

    private func shake(intensity: CGFloat) {
        let moves = (0..<6).map { i -> SKAction in
            let d = intensity * (1 - CGFloat(i) / 6)
            return .moveBy(x: i % 2 == 0 ? d : -d, y: 0, duration: 0.04)
        }
        craneLayer.run(.sequence(moves + [.move(to: .zero, duration: 0.04)]))
    }

    // MARK: - Continuous rendering

    private func renderDynamic(dt: Double) {
        guard skyLayer.parent != nil else { return }
        let sway = session.swayOffset
        let count = floorNodes.count

        // Camera: keep the tower top a few floors below the hook.
        let topY = floorY(max(count - 1, 0)) + floorHeight / 2
        let desired = max(0, topY - (hookRestY - floorHeight * 3.2))
        cameraOffset += (desired - cameraOffset) * CGFloat(min(1, dt * 4 + (dt == 0 ? 1 : 0)))
        world.position = CGPoint(x: 0, y: -cameraOffset)

        // Sway: displacement grows towards the top of the tower.
        for (index, node) in floorNodes.enumerated() where index < session.floors.count {
            let floor = session.floors[index]
            let share = pow(Double(index + 1) / Double(max(count, 1)), 1.5)
            node.position = CGPoint(x: screenX(floor.x + sway * share), y: floorY(index))
            node.zRotation = CGFloat(-sway * share * 0.08)
        }

        // Crane: trolley and hook follow the hook position; the cable flashes red while creaking.
        let hookScreenX = screenX(session.hookX)
        trolley.position = CGPoint(x: hookScreenX, y: jibY - 8)
        let creaking = session.isCreaking
        let jitter: CGFloat = creaking ? CGFloat.random(in: -2...2) : 0
        hook.position = CGPoint(x: hookScreenX + jitter, y: hookRestY + floorHeight / 2 + 30)
        module.position = CGPoint(x: hookScreenX + jitter, y: hookRestY)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: hookScreenX, y: jibY - 16))
        path.addLine(to: CGPoint(x: hookScreenX + jitter, y: hook.position.y + 22))
        cable.path = path
        cable.strokeColor = creaking ? SKColor(red: 0.85, green: 0.2, blue: 0.15, alpha: 1) : SKColor(white: 0.1, alpha: 1)
        cable.lineWidth = creaking ? 3 : 2
        hookLamp.position = CGPoint(x: hookScreenX, y: hookRestY - 30)
        if case .swinging = session.phase {
            updateModuleTexture()
            module.isHidden = false
        } else {
            module.isHidden = true
        }

        // Falling module (screen hook height converted into world space).
        if case .falling(let elapsed, let x, _) = session.phase {
            lastReleaseX = x
            lastReleaseWidth = session.currentWidth
            let t = CGFloat(min(elapsed / Balance.fallDuration, 1))
            let startY = hookRestY + cameraOffset
            let endY = floorY(count)
            fallingModule.position = CGPoint(x: screenX(x), y: startY + (endY - startY) * t * t)
            fallingModule.isHidden = false
        }

        // Rivet ring around the newest joint.
        if let progress = session.rivetProgress, case .riveting(_, let tapped) = session.phase, !tapped {
            let joint = jointPoint
            rivetRing.isHidden = false
            rivetTarget.isHidden = false
            rivetRing.position = joint
            rivetTarget.position = joint
            let maxR: CGFloat = 70, minR: CGFloat = 8
            rivetRing.setScale((maxR - (maxR - minR) * CGFloat(progress)) / 60)
            let sweet = maxR - (maxR - minR) * CGFloat(RunSession.rivetSweetProgress)
            rivetTarget.setScale(sweet / 20)
            let window = CGFloat(session.rivetWindowProgress) * (maxR - minR)
            rivetTarget.lineWidth = max(3, window * 2 / (sweet / 20))
            rivetTarget.strokeColor = SKColor(red: 0.96, green: 0.76, blue: 0.11, alpha: 0.35)
        } else {
            rivetRing.isHidden = true
            rivetTarget.isHidden = true
        }

        // Plumb bob gauge: swings with the sway phase, its arc scaled by how close collapse is.
        let fraction = session.swayFraction
        let angle = CGFloat(sin(session.swayPhase) * (0.15 + 0.85 * fraction)) * 0.9
        let length: CGFloat = 60
        let bobPoint = CGPoint(x: sin(angle) * length, y: -cos(angle) * length)
        let line = CGMutablePath()
        line.move(to: .zero)
        line.addLine(to: bobPoint)
        plumbLine.path = line
        plumbBob.position = CGPoint(x: plumbLine.position.x + bobPoint.x, y: plumbLine.position.y + bobPoint.y)
        plumbBob.zRotation = angle
        let inTune = session.isInTuneNow
        tuneBand.fillColor = inTune
            ? SKColor(red: 0.24, green: 0.7, blue: 0.35, alpha: 0.55)
            : SKColor(red: 0.24, green: 0.6, blue: 0.35, alpha: 0.22)
        plumbLine.strokeColor = fraction > 0.75 ? SKColor(red: 0.85, green: 0.2, blue: 0.15, alpha: 1) : SKColor(white: 0.1, alpha: 1)

        renderWeather(dt: dt)
        updateSkyTarget(animated: dt > 0)
    }

    private func renderWeather(dt: Double) {
        let shift = session.shift
        let targetNight: CGFloat = shift == .night ? 0.55 : 0
        nightShade.alpha += (targetNight - nightShade.alpha) * CGFloat(min(1, dt * 2))
        hookLamp.alpha = nightShade.alpha * 1.4
        let targetFog: CGFloat = shift == .fog ? 0.92 : 0
        fog.alpha += (targetFog - fog.alpha) * CGFloat(min(1, dt * 1.5))
        if fog.alpha > 0.01 {
            fog.position.x = size.width / 2 + CGFloat(sin(session.elapsed * 0.4)) * 30
        }

        // Wind streaks while a gust blows.
        if session.wind.isGusting, dt > 0 {
            gustStreakTimer -= dt
            if gustStreakTimer <= 0 {
                gustStreakTimer = 0.07
                let direction = CGFloat(session.wind.direction)
                let streak = SKShapeNode(rectOf: CGSize(width: CGFloat.random(in: 40...90), height: 2), cornerRadius: 1)
                streak.fillColor = SKColor(white: 1, alpha: 0.7)
                streak.strokeColor = .clear
                let y = CGFloat.random(in: (size.height * 0.3)...(size.height * 0.85))
                streak.position = CGPoint(x: direction > 0 ? -60 : size.width + 60, y: y)
                streak.zPosition = 15
                addChild(streak)
                streak.run(.sequence([.moveBy(x: direction * (size.width + 160), y: 0, duration: 0.6), .removeFromParent()]))
            }
        }
    }

    private func skyName() -> String {
        if session.shift == .night { return "sky_night" }
        switch session.height {
        case ..<15: return "sky_dawn"
        case ..<30: return "sky_day"
        case ..<45: return "sky_dusk"
        default: return "sky_night"
        }
    }

    private func updateSkyTarget(animated: Bool = true) {
        let target = skyName()
        guard target != activeSky else { return }
        activeSky = target
        for (name, node) in skyNodes {
            node.removeAllActions()
            let alpha: CGFloat = name == target ? 1 : 0
            if animated { node.run(.fadeAlpha(to: alpha, duration: 1.2)) } else { node.alpha = alpha }
        }
    }
}
