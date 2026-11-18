import Foundation

/// The tenants a floor module is built for. Three of a kind in a row form a district.
enum FloorKind: String, CaseIterable, Codable, Sendable {
    case residential
    case office
    case garden
    /// Rare crown module: rivets every floor below it.
    case penthouse

    /// Kinds that come off the truck in normal rotation.
    static let regular: [FloorKind] = [.residential, .office, .garden]

    var title: String {
        switch self {
        case .residential: "Residential"
        case .office: "Office"
        case .garden: "Sky Garden"
        case .penthouse: "Penthouse"
        }
    }

    var districtEffect: String {
        switch self {
        case .residential: "+\(Balance.residentialBonus) points"
        case .office: "+\(Balance.officeBolts) bolts"
        case .garden: "Sway halved"
        case .penthouse: "Rivets every floor below"
        }
    }

    /// Floor texture in the asset catalog. Heavy girders replace every kind during a heavy shift.
    func art(heavy: Bool) -> String {
        heavy ? "floor_girder" : "floor_\(rawValue)"
    }

    var iconArt: String { "kind_\(rawValue)" }
}

/// A random "site shift" that changes the rules for ten floors at a time.
enum SiteShift: String, CaseIterable, Codable, Sendable {
    case clear
    case fog
    case night
    case jitter
    case heavy
    case calm

    /// Shifts that can be drawn after the opening clear shift.
    static let drawable: [SiteShift] = [.fog, .night, .jitter, .heavy, .calm]

    var title: String {
        switch self {
        case .clear: "Clear Morning"
        case .fog: "Fog Bank"
        case .night: "Night Shift"
        case .jitter: "Jumpy Crane"
        case .heavy: "Steel Girders"
        case .calm: "Dead Calm"
        }
    }

    var detail: String {
        switch self {
        case .clear: "Good light, steady crane."
        case .fog: "The hook is hidden in cloud. Points x1.3."
        case .night: "Only the hook lamp lights the floor. Points x1.3."
        case .jitter: "The trolley changes direction without warning."
        case .heavy: "Heavy girders sway the tower more. Points x1.5."
        case .calm: "No wind and a slow hook. Points x0.8."
        }
    }

    var scoreFactor: Double {
        switch self {
        case .clear: 1
        case .fog, .night: 1.3
        case .jitter: 1.2
        case .heavy: 1.5
        case .calm: 0.8
        }
    }

    var hasWind: Bool { self != .calm }
    var hookSpeedFactor: Double { self == .calm ? 0.85 : 1 }
    var swayFactor: Double { self == .heavy ? 1.6 : 1 }
    var badgeArt: String { "shift_\(rawValue)" }
}
