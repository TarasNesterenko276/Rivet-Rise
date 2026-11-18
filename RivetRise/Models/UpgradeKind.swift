import Foundation

/// Permanent crane upgrades hoisted in the rigging yard with bolts.
enum UpgradeKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case cable
    case counterweight
    case concrete
    case boom
    case rivetGun

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cable: "Steel Cable"
        case .counterweight: "Counterweight"
        case .concrete: "Fast Concrete"
        case .boom: "Long Boom"
        case .rivetGun: "Rivet Gun"
        }
    }

    var summary: String {
        switch self {
        case .cable: "A thicker cable snaps less often."
        case .counterweight: "Slows the hook so you can line up the drop."
        case .concrete: "Stiffer floors: the tower sways less as it grows."
        case .boom: "A longer jib makes perfect drops easier."
        case .rivetGun: "A wider window to drive a rivet home."
        }
    }

    var art: String { "upgrade_\(rawValue)" }

    var maxLevel: Int { 5 }

    var baseCost: Int {
        switch self {
        case .cable: 70
        case .counterweight: 90
        case .concrete: 110
        case .boom: 80
        case .rivetGun: 60
        }
    }

    /// Bolt cost to reach `level` (1-based). Returns `nil` when `level` is out of range.
    func cost(forLevel level: Int) -> Int? {
        guard level >= 1, level <= maxLevel else { return nil }
        let raw = Double(baseCost) * pow(1.7, Double(level - 1))
        return Int((raw / 5).rounded()) * 5
    }

    /// Human readable effect at a given level, e.g. "Snaps -30%".
    func effectDescription(atLevel level: Int) -> String {
        var loadout = Loadout.starter
        loadout.setLevel(level, for: self)
        switch self {
        case .cable:
            return "Snaps " + Formatters.percent(loadout.snapFactor)
        case .counterweight:
            return "Hook speed " + Formatters.percent(loadout.hookSpeedFactor)
        case .concrete:
            return "Sway growth " + Formatters.percent(loadout.swayGrowthFactor)
        case .boom:
            return "Perfect zone " + Formatters.percent(loadout.perfectTolerance / Balance.basePerfectTolerance)
        case .rivetGun:
            return "Rivet window " + Formatters.milliseconds(loadout.rivetWindow * 2)
        }
    }
}
