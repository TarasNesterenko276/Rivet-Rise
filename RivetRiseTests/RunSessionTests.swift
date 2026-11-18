import Foundation
import Testing
@testable import RivetRise

@MainActor
@Suite("Run session rules")
struct RunSessionTests {
    // MARK: - Helpers

    /// Places the hook at `x` (floor units, no wind) and calms the tower.
    private func aim(_ session: inout RunSession, at x: Double) {
        session.debugSetHook(phase: asin(x / Balance.hookAmplitude))
        session.debugSetWind(.still(nextIn: 100))
    }

    /// Drops at `x` and lets the module land. `swayPhaseAtLanding` lets a test choose the beat.
    @discardableResult
    private func drop(_ session: inout RunSession, at x: Double = 0, swayAmplitude: Double = 0, swayPhaseAtLanding: Double = 0) -> [RunEvent] {
        aim(&session, at: x)
        var events = session.tap()
        events += session.update(Balance.fallDuration - 0.01)
        session.debugSetSway(amplitude: swayAmplitude, phase: swayPhaseAtLanding - Balance.swaySpeed * 0.02)
        events += session.update(0.02)
        return events
    }

    /// Waits out the rivet ring without striking.
    private func skipRivet(_ session: inout RunSession) {
        session.update(Balance.rivetDuration)
    }

    /// Waits until the rivet sweet spot and strikes.
    @discardableResult
    private func strikeRivet(_ session: inout RunSession, offset: Double = 0) -> [RunEvent] {
        guard case .riveting(let elapsed, _) = session.phase else { return [] }
        session.update(Balance.rivetSweetSpot + offset - elapsed)
        var events = session.tap()
        events += session.update(Balance.rivetDuration)
        return events
    }

    private func perfectFloor(_ session: inout RunSession, kind: FloorKind = .residential) {
        session.debugSetKinds(current: kind, next: kind)
        drop(&session)
        skipRivet(&session)
    }

    private func makeSession(_ foreman: Foreman = .mira, seed: UInt64 = 7) -> RunSession {
        RunSession(loadout: Loadout(foreman: foreman), seed: seed)
    }

    // MARK: - Dropping and trimming

    @Test func aCentredDropIsPerfectAndKeepsTheFullWidth() {
        var session = makeSession()
        let events = drop(&session)
        #expect(events.contains(.landed(perfect: true, inTune: false)))
        #expect(session.height == 1)
        #expect(session.currentWidth == 1)
        #expect(session.perfects == 1)
        #expect(session.score == Int((Double(Balance.basePoints) * 2 * session.rushMultiplier).rounded()))
    }

    @Test func anOffsetDropIsTrimmedToTheOverlap() throws {
        var session = makeSession()
        drop(&session, at: 0.3)
        let floor = try #require(session.top)
        #expect(abs(floor.width - 0.7) < 0.001)
        #expect(abs(floor.x - 0.15) < 0.001)
        #expect(abs(session.currentWidth - 0.7) < 0.001)
        #expect(session.perfects == 0)
    }

    @Test func missingTheTowerCostsAHardHat() {
        var session = makeSession(.mira)
        drop(&session, at: 0.7)
        skipRivet(&session)
        let events = drop(&session, at: -0.7)
        #expect(events.contains(.missed(forgiven: false)))
        #expect(session.hardHats == Balance.baseHardHats - 1)
        #expect(session.height == 1)
        #expect(session.rush == 0)
    }

    @Test func gusForgivesTheFirstMissOnly() {
        var session = makeSession(.gus)
        drop(&session, at: 0.7)
        skipRivet(&session)
        #expect(drop(&session, at: -0.7).contains(.missed(forgiven: true)))
        #expect(session.hardHats == Balance.baseHardHats)
        #expect(drop(&session, at: -0.7).contains(.missed(forgiven: false)))
        #expect(session.hardHats == Balance.baseHardHats - 1)
    }

    @Test func fourPerfectsInARowWidenTheModule() {
        var session = makeSession()
        drop(&session, at: 0.2)
        skipRivet(&session)
        let narrowed = session.currentWidth
        var sawRegrow = false
        for _ in 0..<4 {
            aim(&session, at: session.top!.x)
            var events = session.tap()
            events += session.update(Balance.fallDuration - 0.01)
            session.debugSetSway(amplitude: 0, phase: 0)
            events += session.update(0.02)
            sawRegrow = sawRegrow || events.contains(.regrow)
            skipRivet(&session)
        }
        #expect(sawRegrow)
        #expect(session.currentWidth > narrowed)
    }

    @Test func runOutOfHardHatsEndsTheShift() {
        var session = makeSession(.mira)
        drop(&session, at: 0.7)
        skipRivet(&session)
        var events: [RunEvent] = []
        for _ in 0..<Balance.baseHardHats { events += drop(&session, at: -0.7) }
        #expect(events.contains(.gameOver))
        #expect(session.isOver)
        #expect(session.tap().isEmpty)
        #expect(session.update(1).isEmpty)
    }

    // MARK: - Sway rhythm and collapse

    @Test func landingInTuneCalmsTheSway() {
        var session = makeSession()
        perfectFloor(&session)
        let events = drop(&session, swayAmplitude: 0.2, swayPhaseAtLanding: 0)
        #expect(events.contains(.landed(perfect: true, inTune: true)))
        #expect(session.swayAmplitude < 0.2)
    }

    @Test func landingOffBeatRocksTheTower() {
        var session = makeSession()
        perfectFloor(&session)
        // At the top of the swing the tower is displaced, so aim there to stay perfect.
        aim(&session, at: 0.1)
        session.tap()
        session.update(Balance.fallDuration - 0.01)
        session.debugSetSway(amplitude: 0.1, phase: .pi / 2 - Balance.swaySpeed * 0.02)
        let events = session.update(0.02)
        #expect(events.contains(.landed(perfect: true, inTune: false)))
        #expect(session.swayAmplitude > 0.1)
    }

    @Test func tooMuchSwayCollapsesDownToTheLastRivet() {
        var session = makeSession(.mira)
        session.debugSetKinds(current: .residential, next: .office)
        drop(&session)
        #expect(strikeRivet(&session).contains(.riveted))
        session.debugSetKinds(current: .office, next: .garden)
        drop(&session)
        skipRivet(&session)
        session.debugSetKinds(current: .garden, next: .residential)
        drop(&session)
        skipRivet(&session)
        #expect(session.height == 3)
        let scoreBefore = session.score

        session.debugSetKinds(current: .residential, next: .office)
        aim(&session, at: 0.29)
        session.tap()
        session.update(Balance.fallDuration - 0.01)
        session.debugSetSway(amplitude: 0.29, phase: .pi / 2 - Balance.swaySpeed * 0.02)
        let events = session.update(0.02)

        #expect(events.contains(.collapse(floors: 3)))
        #expect(session.height == 1, "Only the riveted ground floor stays up")
        #expect(session.top?.riveted == true)
        #expect(session.hardHats == Balance.baseHardHats - 1)
        #expect(session.score < scoreBefore)
        #expect(session.swayAmplitude == Balance.swayAfterCollapse)
        #expect(session.collapses == 1)
    }

    // MARK: - Rivet strike

    @Test func aTimedRivetLocksTheFloorAndDoublesItsPoints() throws {
        var session = makeSession()
        drop(&session)
        let points = try #require(session.top?.points)
        let events = strikeRivet(&session)
        #expect(events.contains(.riveted))
        #expect(session.top?.riveted == true)
        #expect(session.top?.points == points * 2)
        #expect(session.score == points * 2)
        #expect(session.rivets == 1)
    }

    @Test func aMistimedRivetBendsAndShakesTheTower() {
        var session = makeSession()
        perfectFloor(&session)
        drop(&session)
        let sway = session.swayAmplitude
        let events = strikeRivet(&session, offset: -0.3)
        #expect(events.contains(.bentRivet))
        #expect(session.top?.riveted == false)
        #expect(session.swayAmplitude > sway)
    }

    @Test func theRivetWindowWidensWithTheRivetGun() {
        var loadout = Loadout(foreman: .gus)
        let edge = loadout.rivetWindow + 0.01
        var plain = RunSession(loadout: loadout, seed: 1)
        drop(&plain)
        #expect(strikeRivet(&plain, offset: edge).contains(.bentRivet))

        loadout.rivetGun = 5
        var upgraded = RunSession(loadout: loadout, seed: 1)
        drop(&upgraded)
        #expect(strikeRivet(&upgraded, offset: edge).contains(.riveted))
    }

    @Test func onlyOneRivetStrikePerFloor() {
        var session = makeSession()
        drop(&session)
        session.update(Balance.rivetSweetSpot)
        #expect(session.tap().contains(.riveted))
        #expect(session.tap().isEmpty)
    }

    // MARK: - Tenants and districts

    @Test func threeOfficesInARowFormADistrictThatPaysBolts() {
        var session = makeSession()
        var events: [RunEvent] = []
        for _ in 0..<3 {
            session.debugSetKinds(current: .office, next: .office)
            events += drop(&session)
            skipRivet(&session)
        }
        #expect(events.contains(.district(.office)))
        #expect(session.districts == 1)
        #expect(session.bonusBolts == Balance.officeBolts)
    }

    @Test func aGardenDistrictHalvesTheSway() {
        var session = makeSession()
        for _ in 0..<2 { perfectFloor(&session, kind: .garden) }
        session.debugSetKinds(current: .garden, next: .office)
        drop(&session, swayAmplitude: 0.2, swayPhaseAtLanding: 0)
        // In tune (x0.55), then the garden district (x0.5), plus a tiny growth per floor.
        #expect(session.swayAmplitude < 0.2 * 0.55 * 0.5 + 0.01)
    }

    @Test func aBrokenRunDoesNotFormADistrict() {
        var session = makeSession()
        for kind in [FloorKind.office, .office, .garden, .office] {
            perfectFloor(&session, kind: kind)
        }
        #expect(session.districts == 0)
    }

    @Test func aPenthouseRivetsEveryFloorBelow() {
        var session = makeSession()
        for _ in 0..<4 { perfectFloor(&session, kind: .office) }
        session.debugSetKinds(current: .penthouse, next: .residential)
        let events = drop(&session)
        #expect(events.contains(.penthouse(rivetedFloors: 5)))
        #expect(session.floors.allSatisfy { $0.riveted })
        #expect(session.penthouses == 1)
    }

    @Test func penthousesArriveRegularly() {
        var session = makeSession(seed: 3)
        var kinds: [FloorKind] = []
        for _ in 0..<40 {
            kinds.append(session.currentKind)
            drop(&session)
            skipRivet(&session)
        }
        #expect(kinds.contains(.penthouse))
        #expect(kinds.filter { $0 == .penthouse }.count <= 40 / Balance.penthouseMinGap + 1)
    }

    // MARK: - Wind, rush and the cable

    @Test func quickDropsBuildRushAndHesitationDrainsIt() {
        var session = makeSession()
        for _ in 0..<3 { perfectFloor(&session) }
        #expect(session.rush == 3)
        #expect(session.rushMultiplier > 1.5)
        let calm = session.hookSpeed
        session.update(Balance.rushWindow + 0.2)
        drop(&session)
        #expect(session.rush == 3 - Balance.rushDecay)
        #expect(session.hookSpeed < calm * 1.2)
    }

    @Test func aGustIsTelegraphedThenPushesTheHook() {
        var session = makeSession()
        for _ in 0..<Balance.firstGustFloor { perfectFloor(&session) }
        session.debugSetWind(.still(nextIn: 0.05))
        var events = session.update(0.1)
        let warning = events.compactMap { event -> Double? in
            if case .gustWarning(let direction) = event { return direction }
            return nil
        }.first
        #expect(warning != nil, "A gust warning should come first")
        let direction = warning
        events = []
        for _ in 0..<120 { events += session.update(1.0 / 60.0) }
        #expect(events.contains(.gustStarted(direction: direction ?? 1)))
        #expect(session.windOffset * (direction ?? 1) > 0.1)
    }

    @Test func aCreakingCableSnapsAndDropsTheModule() {
        var session = makeSession()
        session.debugSetSnap(at: 1.0)
        var events: [RunEvent] = []
        for _ in 0..<70 { events += session.update(1.0 / 60.0) }
        #expect(events.contains(.creak))
        #expect(events.contains(.released(forced: true)))
        if case .falling(_, _, let forced) = session.phase { #expect(forced) } else { Issue.record("Module should be falling") }
    }

    @Test func aPerfectlyLandedSnapIsACableCatch() {
        var session = makeSession()
        aim(&session, at: 0)
        session.debugSetSnap(at: 0.0001)
        var events = session.update(0.001)
        #expect(events.contains(.released(forced: true)))
        events += session.update(Balance.fallDuration)
        #expect(events.contains(.clutch))
        #expect(session.clutches == 1)
        #expect(session.bonusBolts == Balance.clutchBolts)
    }

    // MARK: - Site shifts

    @Test func aNewSiteShiftStartsEveryTenFloors() {
        var session = makeSession()
        var events: [RunEvent] = []
        for _ in 0..<Balance.floorsPerShift {
            session.debugSetKinds(current: .residential, next: .residential)
            events += drop(&session)
            skipRivet(&session)
        }
        let shift = events.compactMap { event -> SiteShift? in
            if case .shiftChanged(let shift) = event { return shift }
            return nil
        }
        #expect(shift.count == 1)
        #expect(session.shift != .clear)
        #expect(SiteShift.drawable.contains(session.shift))
    }

    @Test func aJumpyCraneReversesTheHook() {
        var session = makeSession()
        session.debugSetShift(.jitter)
        var flips = 0
        var direction = session.hookDirection
        for _ in 0..<(60 * 6) {
            session.update(1.0 / 60.0)
            if session.hookDirection != direction { flips += 1; direction = session.hookDirection }
        }
        #expect(flips >= 2)
    }

    @Test func heavyGirdersSwayMoreUnlessTonyLifts() {
        func swayAfterHeavyDrop(_ foreman: Foreman) -> Double {
            var session = RunSession(loadout: Loadout(foreman: foreman), seed: 5)
            perfectFloor(&session)
            session.debugSetShift(.heavy)
            drop(&session, swayAmplitude: 0, swayPhaseAtLanding: .pi / 2)
            return session.swayAmplitude
        }
        #expect(swayAfterHeavyDrop(.mira) > swayAfterHeavyDrop(.tony))
    }

    // MARK: - Determinism and autopilot

    @Test func theSameSeedPlaysTheSameShift() {
        var first = RunSession(loadout: .starter, seed: 99)
        var second = RunSession(loadout: .starter, seed: 99)
        for step in 0..<600 {
            if step % 50 == 0 { first.tap(); second.tap() }
            first.update(1.0 / 60.0)
            second.update(1.0 / 60.0)
        }
        #expect(first.summary == second.summary)
        #expect(first.floors == second.floors)
    }

    @Test func theAutopilotBuildsATallTower() {
        var session = RunSession(loadout: .starter, seed: 1218)
        for _ in 0..<(60 * 90) where !session.isOver {
            if Autopilot.shouldTap(session) { session.tap() }
            session.update(1.0 / 60.0)
        }
        #expect(session.bestHeight >= 15)
        #expect(session.perfects > 5)
        #expect(session.rivets > 5)
    }

    /// UI tests and the screenshot tour wait for the autopilot's shift to end.
    @Test func theAutopilotShiftEndsWithinFourMinutes() {
        var session = RunSession(loadout: .starter, seed: 1218)
        var frames = 0
        while !session.isOver, frames < 60 * 240 {
            if Autopilot.shouldTap(session) { session.tap() }
            session.update(1.0 / 60.0)
            frames += 1
        }
        #expect(session.isOver, "Still building after \(session.elapsed) s at \(session.height) floors")
    }

    @Test func summaryReflectsTheShift() {
        var session = makeSession(.ola)
        perfectFloor(&session)
        drop(&session)
        strikeRivet(&session)
        let summary = session.summary
        #expect(summary.floors == 2)
        #expect(summary.rivets == 1)
        #expect(summary.perfects == 2)
        #expect(summary.foremanID == Foreman.ola.rawValue)
        #expect(summary.bolts == session.score / Balance.pointsPerBolt)
    }
}
