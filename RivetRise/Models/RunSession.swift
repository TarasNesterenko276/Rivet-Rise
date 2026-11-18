import Foundation

/// A floor that has been set on the tower.
struct PlacedFloor: Equatable, Sendable {
    /// Centre in the unswayed tower frame (floor units).
    var x: Double
    var width: Double
    var kind: FloorKind
    var heavy: Bool
    var riveted: Bool
    /// Points this floor is worth; lost again if the floor topples in a collapse.
    var points: Int
}

/// Where the wind is in its cycle.
enum WindState: Equatable, Sendable {
    case still(nextIn: Double)
    case warning(remaining: Double, direction: Double)
    case gust(remaining: Double, direction: Double)

    var direction: Double {
        switch self {
        case .still: 0
        case .warning(_, let direction), .gust(_, let direction): direction
        }
    }

    var isGusting: Bool {
        if case .gust = self { return true }
        return false
    }

    var isWarning: Bool {
        if case .warning = self { return true }
        return false
    }
}

/// What the crane is doing right now.
enum CranePhase: Equatable, Sendable {
    /// A module hangs on the hook. `elapsed` counts from the moment it became available.
    case swinging(elapsed: Double)
    /// The module was released at `x` and is falling.
    case falling(elapsed: Double, x: Double, forced: Bool)
    /// The module has landed; the rivet ring is shrinking.
    case riveting(elapsed: Double, tapped: Bool)
    case over
}

/// Something that happened during an update, for sound, haptics, effects and callouts.
enum RunEvent: Equatable, Sendable {
    case released(forced: Bool)
    case landed(perfect: Bool, inTune: Bool)
    case missed(forgiven: Bool)
    case regrow
    case riveted
    case bentRivet
    case district(FloorKind)
    case penthouse(rivetedFloors: Int)
    case collapse(floors: Int)
    case gustWarning(direction: Double)
    case gustStarted(direction: Double)
    case gustEnded
    case creak
    case clutch
    case rushUp(Int)
    case shiftChanged(SiteShift)
    case gameOver
}

/// The pure rules of one shift on the crane. Has no UI or framework dependencies,
/// so every mechanic is unit-tested; the SpriteKit scene only draws this state.
struct RunSession: Sendable {
    let loadout: Loadout
    private var rng: SeededGenerator

    // Tower
    private(set) var floors: [PlacedFloor] = []
    private(set) var currentWidth: Double = Balance.startWidth
    private(set) var currentKind: FloorKind
    private(set) var nextKind: FloorKind

    // Crane
    private(set) var phase: CranePhase = .swinging(elapsed: 0)
    private(set) var hookPhase: Double = 0
    private(set) var hookDirection: Double = 1
    private(set) var windOffset: Double = 0
    private(set) var wind: WindState = .still(nextIn: 6)
    /// Seconds after the module became available when the cable lets go, if it will.
    private(set) var snapAt: Double?
    private var jitterTimer: Double = 1.2

    // Sway
    private(set) var swayPhase: Double = 0
    private(set) var swayAmplitude: Double = 0

    // Shift
    private(set) var shift: SiteShift = .clear
    private var shiftsReached = 0

    // Scoring
    private(set) var score = 0
    private(set) var bonusBolts = 0
    private(set) var hardHats: Int
    private(set) var rush = 0
    private(set) var elapsed: Double = 0
    private(set) var perfectStreak = 0
    private var kindRunKind: FloorKind?
    private var kindRunLength = 0
    private var floorsSincePenthouse = 0
    private var hasUsedForgiveness = false

    // Statistics
    private(set) var bestHeight = 0
    private(set) var perfects = 0
    private(set) var rivets = 0
    private(set) var districts = 0
    private(set) var penthouses = 0
    private(set) var clutches = 0
    private(set) var collapses = 0
    private(set) var bestRush = 0

    init(loadout: Loadout = .starter, seed: UInt64 = 1) {
        self.loadout = loadout
        rng = SeededGenerator(seed: seed)
        hardHats = loadout.hardHats
        currentKind = .residential
        nextKind = .office
        currentKind = drawKind(after: nil)
        nextKind = drawKind(after: currentKind)
        wind = .still(nextIn: rng.range(Balance.gustGapRange))
    }

    // MARK: - Derived state

    var isOver: Bool { phase == .over }
    var height: Int { floors.count }
    var top: PlacedFloor? { floors.last }

    /// Horizontal hook position in floor units.
    var hookX: Double { Balance.hookAmplitude * sin(hookPhase) + windOffset }

    /// Sideways displacement of the tower top right now.
    var swayOffset: Double { floors.isEmpty ? 0 : swayAmplitude * sin(swayPhase) }

    /// How close the tower is to collapsing, `0...1`.
    var swayFraction: Double { min(swayAmplitude / Balance.maxSway, 1) }

    /// Whether a module landing now would be "in tune" with the sway.
    var isInTuneNow: Bool { abs(sin(swayPhase)) < Balance.inTuneBand }

    var rushMultiplier: Double { 1 + Balance.rushScoreStep * Double(rush) }

    var hookSpeed: Double {
        let height = Double(min(floors.count, Balance.hookSpeedFloorCap))
        return Balance.baseHookSpeed
            * (1 + Balance.hookSpeedPerFloor * height)
            * (1 + Balance.rushSpeedStep * Double(rush))
            * loadout.hookSpeedFactor
            * shift.hookSpeedFactor
    }

    var isHeavyShift: Bool { shift == .heavy }

    /// The cable is creaking: a snap is coming.
    var isCreaking: Bool {
        guard case .swinging(let elapsed) = phase, let snapAt else { return false }
        return elapsed >= snapAt - Balance.snapCreak
    }

    /// Progress of the shrinking rivet ring, `0...1`, or `nil` outside the rivet phase.
    var rivetProgress: Double? {
        guard case .riveting(let elapsed, _) = phase else { return nil }
        return min(elapsed / Balance.rivetDuration, 1)
    }

    /// Ring progress at the centre of the rivet window.
    static var rivetSweetProgress: Double { Balance.rivetSweetSpot / Balance.rivetDuration }

    var rivetWindowProgress: Double { loadout.rivetWindow / Balance.rivetDuration }

    /// Bolts earned so far: the score converted to pay plus district and clutch bonuses.
    var bolts: Int { score / Balance.pointsPerBolt + bonusBolts }

    var summary: RunSummary {
        RunSummary(
            score: score,
            bolts: bolts,
            floors: bestHeight,
            duration: elapsed,
            perfects: perfects,
            rivets: rivets,
            districts: districts,
            penthouses: penthouses,
            clutches: clutches,
            collapses: collapses,
            bestRush: bestRush,
            foremanID: loadout.foreman.rawValue
        )
    }

    // MARK: - Input

    /// The single tap: drops the module or, right after a landing, drives the rivet.
    @discardableResult
    mutating func tap() -> [RunEvent] {
        var events: [RunEvent] = []
        switch phase {
        case .swinging(let elapsed):
            release(forced: false, availableFor: elapsed, events: &events)
        case .riveting(let elapsed, let tapped) where !tapped:
            phase = .riveting(elapsed: elapsed, tapped: true)
            strikeRivet(at: elapsed, events: &events)
        default:
            break
        }
        return events
    }

    // MARK: - Simulation

    @discardableResult
    mutating func update(_ dt: Double) -> [RunEvent] {
        guard !isOver, dt > 0 else { return [] }
        var events: [RunEvent] = []
        elapsed += dt
        swayPhase += Balance.swaySpeed * dt
        updateWind(dt, events: &events)
        updateJitter(dt)
        hookPhase += hookDirection * hookSpeed * dt

        switch phase {
        case .swinging(let available):
            let now = available + dt
            phase = .swinging(elapsed: now)
            if let snapAt {
                if available < snapAt - Balance.snapCreak, now >= snapAt - Balance.snapCreak {
                    events.append(.creak)
                }
                if now >= snapAt {
                    release(forced: true, availableFor: now, events: &events)
                }
            }
        case .falling(let fall, let x, let forced):
            let now = fall + dt
            if now >= Balance.fallDuration {
                land(at: x, forced: forced, events: &events)
            } else {
                phase = .falling(elapsed: now, x: x, forced: forced)
            }
        case .riveting(let time, let tapped):
            let now = time + dt
            if now >= Balance.rivetDuration {
                prepareNextModule()
            } else {
                phase = .riveting(elapsed: now, tapped: tapped)
            }
        case .over:
            break
        }
        return events
    }

    // MARK: - Release and landing

    private mutating func release(forced: Bool, availableFor: Double, events: inout [RunEvent]) {
        let x = hookX
        if !forced {
            if availableFor <= Balance.rushWindow {
                let before = rush
                rush = min(rush + 1, loadout.rushCap)
                bestRush = max(bestRush, rush)
                if rush > before { events.append(.rushUp(rush)) }
            } else {
                rush = max(rush - loadout.rushDecay, 0)
            }
        }
        snapAt = nil
        phase = .falling(elapsed: 0, x: x, forced: forced)
        events.append(.released(forced: forced))
    }

    private mutating func land(at x: Double, forced: Bool, events: inout [RunEvent]) {
        let support = top ?? PlacedFloor(x: 0, width: Balance.startWidth, kind: .residential, heavy: false, riveted: true, points: 0)
        let supportX = support.x + swayOffset
        let width = currentWidth
        let offset = x - supportX
        let left = max(x - width / 2, supportX - support.width / 2)
        let right = min(x + width / 2, supportX + support.width / 2)

        guard right - left > 0.001 else {
            miss(events: &events)
            return
        }

        let perfect = abs(offset) <= loadout.perfectTolerance
        var newX: Double
        var newWidth: Double
        if perfect {
            newX = support.x
            newWidth = width
            perfectStreak += 1
            perfects += 1
            if perfectStreak % Balance.perfectStreakForRegrow == 0, width < Balance.startWidth {
                newWidth = min(Balance.startWidth, width + Balance.regrowAmount)
                events.append(.regrow)
            }
        } else {
            newX = (left + right) / 2 - swayOffset
            newWidth = right - left
            perfectStreak = 0
        }

        // Sway rhythm: landing while the top passes its centre calms the tower.
        let inTune = !floors.isEmpty && isInTuneNow
        let heavy = isHeavyShift
        let heavyFactor = heavy && !loadout.ignoresHeavySway ? shift.swayFactor : 1
        var growth = Balance.swayPerFloor * heavyFactor
        if inTune {
            swayAmplitude *= Balance.inTuneDamping
        } else if !floors.isEmpty {
            growth += Balance.swayOffBeat * abs(sin(swayPhase)) * heavyFactor
        }
        if !perfect { growth += Balance.swayPerOffset * abs(offset) }
        swayAmplitude += growth * loadout.swayGrowthFactor

        let rawPoints = Double(Balance.basePoints + floors.count * Balance.pointsPerFloorHeight)
            * (perfect ? 2 : 1) * rushMultiplier * shift.scoreFactor
        let points = Int(rawPoints.rounded())
        let kind = currentKind
        floors.append(PlacedFloor(x: newX, width: newWidth, kind: kind, heavy: heavy, riveted: false, points: points))
        currentWidth = newWidth
        score += points
        bestHeight = max(bestHeight, floors.count)
        events.append(.landed(perfect: perfect, inTune: inTune))

        if forced, perfect {
            clutches += 1
            score += Balance.clutchBonus
            bonusBolts += Balance.clutchBolts
            events.append(.clutch)
        }

        applyTenants(kind, events: &events)
        advanceShiftIfNeeded(events: &events)

        if swayAmplitude >= Balance.maxSway {
            collapse(events: &events)
        } else {
            phase = .riveting(elapsed: 0, tapped: false)
        }
    }

    private mutating func miss(events: inout [RunEvent]) {
        rush = 0
        perfectStreak = 0
        if loadout.forgivesFirstMiss, !hasUsedForgiveness {
            hasUsedForgiveness = true
            events.append(.missed(forgiven: true))
        } else {
            hardHats -= 1
            events.append(.missed(forgiven: false))
        }
        finishOrContinue(events: &events)
    }

    // MARK: - Tenants and districts

    private mutating func applyTenants(_ kind: FloorKind, events: inout [RunEvent]) {
        if kind == .penthouse {
            floorsSincePenthouse = 0
            kindRunKind = nil
            kindRunLength = 0
            var newlyRiveted = 0
            for index in floors.indices where !floors[index].riveted {
                floors[index].riveted = true
                newlyRiveted += 1
            }
            penthouses += 1
            score += newlyRiveted * Balance.penthousePointsPerFloor
            bonusBolts += Balance.penthouseBolts
            events.append(.penthouse(rivetedFloors: newlyRiveted))
            return
        }

        floorsSincePenthouse += 1
        if kindRunKind == kind {
            kindRunLength += 1
        } else {
            kindRunKind = kind
            kindRunLength = 1
        }
        guard kindRunLength >= Balance.districtLength else { return }
        kindRunLength = 0
        kindRunKind = nil
        districts += 1
        switch kind {
        case .residential:
            score += Int((Double(Balance.residentialBonus) * rushMultiplier).rounded())
        case .office:
            bonusBolts += Balance.officeBolts
        case .garden:
            swayAmplitude *= Balance.gardenDamping
            bonusBolts += loadout.gardenBolts
        case .penthouse:
            break
        }
        events.append(.district(kind))
    }

    /// Picks the next module type. Repeats are likely so districts can be planned for.
    private mutating func drawKind(after previous: FloorKind?) -> FloorKind {
        let queued = floorsSincePenthouse + (previous == nil ? 0 : 1)
        let crownDue = queued >= Balance.penthouseGuaranteedGap
            || (queued >= Balance.penthouseMinGap && rng.unit() < 0.25)
        if previous != .penthouse, crownDue {
            return .penthouse
        }
        if let previous, previous != .penthouse, rng.unit() < Balance.repeatKindChance {
            return previous
        }
        return FloorKind.regular[Int(rng.unit() * Double(FloorKind.regular.count)) % FloorKind.regular.count]
    }

    private mutating func prepareNextModule() {
        currentKind = nextKind
        nextKind = drawKind(after: currentKind)
        phase = .swinging(elapsed: 0)
        snapAt = nil
        if floors.count >= Balance.snapFirstFloor {
            let extra = Double(floors.count - Balance.snapFirstFloor) * Balance.snapChancePerFloor
            let chance = min(Balance.snapBaseChance + extra, Balance.snapChanceCap) * loadout.snapFactor
            if rng.unit() < chance {
                snapAt = rng.range(Balance.snapDelayRange)
            }
        }
    }

    // MARK: - Rivets and collapses

    private mutating func strikeRivet(at time: Double, events: inout [RunEvent]) {
        guard let last = floors.indices.last else { return }
        if abs(time - Balance.rivetSweetSpot) <= loadout.rivetWindow {
            if !floors[last].riveted {
                floors[last].riveted = true
                score += floors[last].points
                floors[last].points *= 2
            }
            rivets += 1
            swayAmplitude = max(0, swayAmplitude - Balance.rivetSwayRelief)
            events.append(.riveted)
        } else {
            swayAmplitude += Balance.bentRivetSway * loadout.swayGrowthFactor
            events.append(.bentRivet)
            if swayAmplitude >= Balance.maxSway {
                collapse(events: &events)
            }
        }
    }

    /// Too much sway: unriveted floors topple down to the last riveted one.
    private mutating func collapse(events: inout [RunEvent]) {
        var removed = 0
        while removed < Balance.maxCollapseFloors, let last = floors.last, !last.riveted {
            score -= last.points
            floors.removeLast()
            removed += 1
        }
        score = max(score, 0)
        collapses += 1
        hardHats -= 1
        rush = 0
        perfectStreak = 0
        swayAmplitude = Balance.swayAfterCollapse
        currentWidth = floors.last?.width ?? Balance.startWidth
        kindRunKind = nil
        kindRunLength = 0
        events.append(.collapse(floors: removed))
        finishOrContinue(events: &events)
    }

    private mutating func finishOrContinue(events: inout [RunEvent]) {
        if hardHats <= 0 {
            hardHats = 0
            phase = .over
            snapAt = nil
            events.append(.gameOver)
        } else {
            prepareNextModule()
        }
    }

    // MARK: - Wind, jitter and shifts

    private mutating func updateWind(_ dt: Double, events: inout [RunEvent]) {
        let active = shift.hasWind && floors.count >= Balance.firstGustFloor
        switch wind {
        case .still(let nextIn):
            if active {
                let remaining = nextIn - dt
                if remaining <= 0 {
                    let direction: Double = rng.unit() < 0.5 ? -1 : 1
                    wind = .warning(remaining: loadout.gustWarning, direction: direction)
                    events.append(.gustWarning(direction: direction))
                } else {
                    wind = .still(nextIn: remaining)
                }
            }
        case .warning(let remaining, let direction):
            let left = remaining - dt
            if left <= 0 {
                wind = .gust(remaining: Balance.gustDuration, direction: direction)
                events.append(.gustStarted(direction: direction))
            } else {
                wind = .warning(remaining: left, direction: direction)
            }
        case .gust(let remaining, let direction):
            let left = remaining - dt
            if left <= 0 {
                wind = .still(nextIn: rng.range(Balance.gustGapRange))
                events.append(.gustEnded)
            } else {
                wind = .gust(remaining: left, direction: direction)
            }
        }
        let target = wind.isGusting ? wind.direction * Balance.gustForce * loadout.gustForceFactor : 0
        windOffset += (target - windOffset) * min(1, dt * 3)
    }

    private mutating func updateJitter(_ dt: Double) {
        guard shift == .jitter, case .swinging = phase else { return }
        jitterTimer -= dt
        if jitterTimer <= 0 {
            hookDirection *= -1
            jitterTimer = rng.range(Balance.jitterGapRange)
        }
    }

    private mutating func advanceShiftIfNeeded(events: inout [RunEvent]) {
        let reached = floors.count / Balance.floorsPerShift
        guard reached > shiftsReached else { return }
        shiftsReached = reached
        let options = SiteShift.drawable.filter { $0 != shift }
        shift = options[Int(rng.unit() * Double(options.count)) % options.count]
        hookDirection = 1
        events.append(.shiftChanged(shift))
    }
}

extension SeededGenerator {
    /// A uniform value inside `range`.
    mutating func range(_ range: ClosedRange<Double>) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * unit()
    }
}

#if DEBUG
extension RunSession {
    /// Test hooks that put the session into precise states.
    mutating func debugSetSway(amplitude: Double, phase: Double) {
        swayAmplitude = amplitude
        swayPhase = phase
    }

    mutating func debugSetHook(phase: Double) {
        hookPhase = phase
        windOffset = 0
    }

    mutating func debugSetKinds(current: FloorKind, next: FloorKind) {
        currentKind = current
        nextKind = next
    }

    mutating func debugSetShift(_ shift: SiteShift) {
        self.shift = shift
    }

    mutating func debugSetSnap(at time: Double?) {
        snapAt = time
    }

    mutating func debugSetWind(_ wind: WindState) {
        self.wind = wind
    }
}
#endif
