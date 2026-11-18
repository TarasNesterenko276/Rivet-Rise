import Foundation

/// The single persistent player profile: bolts, upgrades, crew and lifetime stats.
struct PlayerProfile: Codable, Equatable {
    var bolts: Int = 0
    var bestScore: Int = 0
    var bestFloors: Int = 0
    var totalRuns: Int = 0
    var totalBoltsEarned: Int = 0
    var totalFloors: Int = 0
    var totalPerfects: Int = 0
    var totalRivets: Int = 0
    var totalDistricts: Int = 0
    var totalPenthouses: Int = 0
    var totalClutches: Int = 0

    var cableLevel: Int = 0
    var counterweightLevel: Int = 0
    var concreteLevel: Int = 0
    var boomLevel: Int = 0
    var rivetGunLevel: Int = 0

    /// Weekly site orders already paid out, stored as "<week>#<order id>".
    var claimedOrderKeys: [String] = []

    var hiredForemanIDs: [String] = [Foreman.starter.rawValue]
    var selectedForemanID: String = Foreman.starter.rawValue
    var createdAt: Date = Date()

    init(bolts: Int = 0, createdAt: Date = Date()) {
        self.bolts = bolts
        self.createdAt = createdAt
    }

    // MARK: - Derived values

    var selectedForeman: Foreman {
        Foreman(rawValue: selectedForemanID) ?? .starter
    }

    func isHired(_ foreman: Foreman) -> Bool {
        foreman.price == 0 || hiredForemanIDs.contains(foreman.rawValue)
    }

    func level(for kind: UpgradeKind) -> Int {
        switch kind {
        case .cable: cableLevel
        case .counterweight: counterweightLevel
        case .concrete: concreteLevel
        case .boom: boomLevel
        case .rivetGun: rivetGunLevel
        }
    }

    mutating func setLevel(_ level: Int, for kind: UpgradeKind) {
        switch kind {
        case .cable: cableLevel = level
        case .counterweight: counterweightLevel = level
        case .concrete: concreteLevel = level
        case .boom: boomLevel = level
        case .rivetGun: rivetGunLevel = level
        }
    }

    /// The gameplay numbers the current foreman and upgrades produce.
    var loadout: Loadout {
        var loadout = Loadout(foreman: selectedForeman)
        for kind in UpgradeKind.allCases {
            loadout.setLevel(level(for: kind), for: kind)
        }
        return loadout
    }

    /// Value snapshot used for achievement evaluation.
    var statsSnapshot: PlayerStats {
        PlayerStats(
            bestScore: bestScore,
            bestFloors: bestFloors,
            totalRuns: totalRuns,
            totalBoltsEarned: totalBoltsEarned,
            totalPerfects: totalPerfects,
            totalRivets: totalRivets,
            totalDistricts: totalDistricts,
            totalPenthouses: totalPenthouses,
            totalClutches: totalClutches,
            hiredForemanCount: Foreman.allCases.filter { isHired($0) }.count,
            maxedUpgradeCount: UpgradeKind.allCases.filter { level(for: $0) >= $0.maxLevel }.count
        )
    }
}
