import Foundation

/// The floors the hoist pendant can send the player to.
enum SiteFloor: String, CaseIterable, Identifiable, Hashable {
    case yard
    case lockers
    case log
    case manual
    case office
    case board

    var id: String { rawValue }

    /// The number on the hoist indicator.
    var level: Int {
        switch self {
        case .yard: 1
        case .lockers: 2
        case .log: 3
        case .manual: 4
        case .office: 5
        case .board: 6
        }
    }

    var title: String {
        switch self {
        case .yard: "Rigging Yard"
        case .lockers: "Crew Lockers"
        case .log: "Site Log"
        case .manual: "Site Manual"
        case .office: "Site Office"
        case .board: "Top Players"
        }
    }

    /// Short label printed under the pendant button.
    var buttonLabel: String {
        switch self {
        case .yard: "Yard"
        case .lockers: "Crew"
        case .log: "Log"
        case .manual: "Manual"
        case .office: "Office"
        case .board: "Top"
        }
    }

    var hint: String {
        switch self {
        case .yard: "Crane upgrades"
        case .lockers: "Hire foremen"
        case .log: "Records and stickers"
        case .manual: "How to play"
        case .office: "Settings"
        case .board: "Weekly league and orders"
        }
    }

    var pictogram: String { "pict_\(rawValue)" }
}
