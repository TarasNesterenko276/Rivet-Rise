import Foundation

/// The gameplay numbers produced by the chosen foreman and the bought upgrades.
struct Loadout: Equatable, Sendable {
    var foreman: Foreman
    var cable = 0
    var counterweight = 0
    var concrete = 0
    var boom = 0
    var rivetGun = 0

    static let starter = Loadout(foreman: .starter)

    func level(for kind: UpgradeKind) -> Int {
        switch kind {
        case .cable: cable
        case .counterweight: counterweight
        case .concrete: concrete
        case .boom: boom
        case .rivetGun: rivetGun
        }
    }

    mutating func setLevel(_ level: Int, for kind: UpgradeKind) {
        switch kind {
        case .cable: cable = level
        case .counterweight: counterweight = level
        case .concrete: concrete = level
        case .boom: boom = level
        case .rivetGun: rivetGun = level
        }
    }

    /// Multiplier on the cable snap chance.
    var snapFactor: Double { 1 - 0.14 * Double(cable) }

    /// Multiplier on hook swing speed.
    var hookSpeedFactor: Double { 1 - 0.04 * Double(counterweight) }

    /// Multiplier on every source of sway growth.
    var swayGrowthFactor: Double { 1 - 0.08 * Double(concrete) }

    var perfectTolerance: Double { Balance.basePerfectTolerance * (1 + 0.12 * Double(boom)) }

    /// Half-width of the rivet window around the sweet spot, in seconds.
    var rivetWindow: Double {
        let base = Balance.baseRivetWindow + 0.012 * Double(rivetGun)
        return foreman == .mira ? base * 1.4 : base
    }

    var hardHats: Int { Balance.baseHardHats }
    var forgivesFirstMiss: Bool { foreman == .gus }
    var gustWarning: Double { foreman == .dolores ? Balance.gustWarning + 1 : Balance.gustWarning }
    var gustForceFactor: Double { foreman == .dolores ? 0.7 : 1 }
    var gardenBolts: Int { foreman == .kenji ? 10 : 0 }
    var ignoresHeavySway: Bool { foreman == .tony }
    var rushCap: Int { foreman == .ola ? 7 : Balance.rushCap }
    var rushDecay: Int { foreman == .ola ? 1 : Balance.rushDecay }
}
