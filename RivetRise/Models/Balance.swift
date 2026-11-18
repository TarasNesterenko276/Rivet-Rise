import Foundation

/// Tuning constants for one shift on the crane.
/// Horizontal positions are in "floor units": a full-width floor module is 1.0 wide
/// and the tower base is centred on x = 0.
enum Balance {
    // Hook
    static let hookAmplitude: Double = 0.78
    static let baseHookSpeed: Double = 1.75
    static let hookSpeedPerFloor: Double = 0.035
    static let hookSpeedFloorCap = 30
    static let fallDuration: Double = 0.42

    // Floors
    static let startWidth: Double = 1.0
    static let basePerfectTolerance: Double = 0.035
    static let perfectStreakForRegrow = 4
    static let regrowAmount: Double = 0.06
    static let floorHeight: Double = 0.34

    // Sway rhythm
    static let swaySpeed: Double = 1.35
    static let inTuneBand: Double = 0.34
    static let inTuneDamping: Double = 0.55
    static let swayPerFloor: Double = 0.006
    static let swayOffBeat: Double = 0.034
    static let swayPerOffset: Double = 0.12
    static let maxSway: Double = 0.30
    static let swayAfterCollapse: Double = 0.06
    static let maxCollapseFloors = 6

    // Rivet strike
    static let rivetDuration: Double = 0.85
    static let rivetSweetSpot: Double = 0.58
    static let baseRivetWindow: Double = 0.085
    static let rivetSwayRelief: Double = 0.02
    static let bentRivetSway: Double = 0.03

    // Districts
    static let districtLength = 3
    static let residentialBonus = 150
    static let officeBolts = 12
    static let gardenDamping: Double = 0.5
    static let penthouseMinGap = 9
    static let penthouseGuaranteedGap = 14
    static let penthousePointsPerFloor = 20
    static let penthouseBolts = 5
    static let repeatKindChance: Double = 0.42

    // Wind and Rush
    static let gustWarning: Double = 1.5
    static let gustDuration: Double = 2.2
    static let gustGapRange: ClosedRange<Double> = 5...9
    static let gustForce: Double = 0.26
    static let firstGustFloor = 3
    static let rushWindow: Double = 1.3
    static let rushCap = 5
    static let rushDecay = 2
    static let rushScoreStep: Double = 0.2
    static let rushSpeedStep: Double = 0.1

    // Cable snap
    static let snapFirstFloor = 6
    static let snapBaseChance: Double = 0.06
    static let snapChancePerFloor: Double = 0.005
    static let snapChanceCap: Double = 0.18
    static let snapCreak: Double = 0.6
    static let snapDelayRange: ClosedRange<Double> = 1.0...2.6
    static let clutchBonus = 100
    static let clutchBolts = 5

    // Site shifts
    static let floorsPerShift = 10
    static let jitterGapRange: ClosedRange<Double> = 0.8...2.0

    // Score and pay
    static let basePoints = 10
    static let pointsPerFloorHeight = 1
    static let pointsPerBolt = 12
    static let baseHardHats = 3
}
