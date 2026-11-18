import Foundation
import Testing
import UIKit
@testable import RivetRise

@MainActor
@Suite("Upgrades, crew and catalog")
struct ModelTests {
    @Test func upgradeCostsGrowAndStopAtMax() {
        for kind in UpgradeKind.allCases {
            var previous = 0
            for level in 1...kind.maxLevel {
                let cost = kind.cost(forLevel: level)!
                #expect(cost > previous)
                #expect(cost % 5 == 0)
                previous = cost
            }
            #expect(kind.cost(forLevel: 0) == nil)
            #expect(kind.cost(forLevel: kind.maxLevel + 1) == nil)
        }
    }

    @Test func upgradesImproveTheLoadout() {
        var loadout = Loadout.starter
        let base = loadout
        for kind in UpgradeKind.allCases { loadout.setLevel(kind.maxLevel, for: kind) }
        #expect(loadout.snapFactor < base.snapFactor)
        #expect(loadout.hookSpeedFactor < base.hookSpeedFactor)
        #expect(loadout.swayGrowthFactor < base.swayGrowthFactor)
        #expect(loadout.perfectTolerance > base.perfectTolerance)
        #expect(loadout.rivetWindow > base.rivetWindow)
        #expect(loadout.snapFactor > 0 && loadout.swayGrowthFactor > 0 && loadout.hookSpeedFactor > 0)
    }

    @Test func foremanPerksChangeTheirNumbers() {
        #expect(Loadout(foreman: .gus).forgivesFirstMiss)
        #expect(!Loadout(foreman: .mira).forgivesFirstMiss)
        #expect(Loadout(foreman: .mira).rivetWindow > Loadout(foreman: .gus).rivetWindow)
        #expect(Loadout(foreman: .dolores).gustWarning > Loadout(foreman: .gus).gustWarning)
        #expect(Loadout(foreman: .dolores).gustForceFactor < 1)
        #expect(Loadout(foreman: .kenji).gardenBolts > 0)
        #expect(Loadout(foreman: .tony).ignoresHeavySway)
        #expect(Loadout(foreman: .ola).rushCap == 7 && Loadout(foreman: .ola).rushDecay == 1)
        #expect(Foreman.allCases.filter { $0.price == 0 } == [.gus])
    }

    @Test func effectDescriptionsReadWell() {
        #expect(UpgradeKind.counterweight.effectDescription(atLevel: 0) == "Hook speed 100%")
        #expect(UpgradeKind.counterweight.effectDescription(atLevel: 5) == "Hook speed 80%")
        #expect(UpgradeKind.rivetGun.effectDescription(atLevel: 0) == "Rivet window 170 ms")
    }

    @Test func achievementsUnlockAtTheirTargets() {
        var stats = PlayerStats()
        #expect(AchievementCatalog.evaluate(stats).allSatisfy { !$0.isUnlocked })
        stats.totalRuns = 1
        stats.bestFloors = 50
        stats.totalClutches = 1
        let unlocked = Set(AchievementCatalog.evaluate(stats).filter(\.isUnlocked).map(\.id))
        #expect(unlocked == ["firstShift", "floors25", "floors50", "clutch"])
        let rivets = AchievementCatalog.evaluate(PlayerStats(totalRivets: 25)).first { $0.id == "rivets50" }
        #expect(rivets?.progress == 0.5)
    }

    @Test func formattersAreLocaleIndependent() {
        #expect(Formatters.duration(125) == "2:05")
        #expect(Formatters.multiplier(1.2) == "x1.2")
        #expect(Formatters.multiplier(2) == "x2")
        #expect(Formatters.metres(floors: 10) == "35 m")
        #expect(Formatters.percent(0.86) == "86%")
    }

    @Test func manualCoversEveryMechanic() {
        #expect(ManualPage.all.count == 7)
        #expect(Set(ManualPage.all.map(\.id)).count == ManualPage.all.count)
        #expect(ManualPage.all.allSatisfy { !$0.body.isEmpty })
    }

    /// actool can silently rename an asset; every generated image must load by its plain name.
    @Test func everyArtworkLoadsFromTheCatalog() {
        var names = ["logo", "bg_site", "foundation", "crane_jib", "crane_trolley", "crane_hook", "spark", "dust",
                     "sky_dawn", "sky_day", "sky_dusk", "sky_night", "fog_bank", "tex_manila", "tex_concrete", "tex_pegsteel",
                     "plate_beam", "plate_hivis", "icon_bolt", "hard_hat", "hard_hat_empty", "hard_hat_big", "weathervane",
                     "plumb_bob", "gauge_rush", "gauge_needle", "tape_measure", "time_clock", "punch_card", "locker_closed",
                     "locker_open", "envelope", "photo_topping", "sticker_locked", "floor_girder"]
        names += FloorKind.allCases.flatMap { [$0.art(heavy: false), $0.iconArt] }
        names += SiteShift.allCases.map(\.badgeArt)
        names += Foreman.allCases.map(\.portraitArt)
        names += UpgradeKind.allCases.map(\.art)
        names += SiteFloor.allCases.map(\.pictogram)
        names += ManualPage.all.map(\.art)
        names += (0..<6).map { "sticker_\($0)" }
        for name in names {
            #expect(UIImage(named: name) != nil, "Missing artwork \(name)")
        }
    }

    @Test func everySoundIsBundled() {
        for effect in SoundEffect.allCases {
            #expect(Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") != nil, "Missing \(effect.rawValue)")
        }
        #expect(Bundle.main.url(forResource: "ambience_site", withExtension: "wav") != nil)
    }
}
