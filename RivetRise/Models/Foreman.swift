import Foundation

/// The crew foremen who run the crane. Each brings a passive perk.
enum Foreman: String, CaseIterable, Identifiable, Codable, Sendable {
    case gus
    case mira
    case dolores
    case kenji
    case tony
    case ola

    static let starter: Foreman = .gus

    var id: String { rawValue }

    var name: String {
        switch self {
        case .gus: "Gus"
        case .mira: "Mira"
        case .dolores: "Dolores"
        case .kenji: "Kenji"
        case .tony: "Big Tony"
        case .ola: "Ola"
        }
    }

    var trade: String {
        switch self {
        case .gus: "Site veteran"
        case .mira: "Ironworker"
        case .dolores: "Wind surveyor"
        case .kenji: "Roof gardener"
        case .tony: "Heavy lifter"
        case .ola: "Speed rigger"
        }
    }

    var perkTitle: String {
        switch self {
        case .gus: "Second Chance"
        case .mira: "Steady Hands"
        case .dolores: "Wind Reader"
        case .kenji: "Green Thumb"
        case .tony: "Iron Back"
        case .ola: "Rush Hour"
        }
    }

    var perkDetail: String {
        switch self {
        case .gus: "The first floor you drop past the tower each shift costs no hard hat."
        case .mira: "The rivet window is 40% wider."
        case .dolores: "Gusts are announced a second earlier and push the hook 30% less."
        case .kenji: "Sky Garden districts also pay 10 bolts."
        case .tony: "Steel girders add no extra sway during a heavy shift."
        case .ola: "Rush goes up to 7 and only drops by one when you hesitate."
        }
    }

    /// Bolts needed to hire this foreman. The starter is free.
    var price: Int {
        switch self {
        case .gus: 0
        case .mira: 400
        case .dolores: 800
        case .kenji: 1_400
        case .tony: 2_200
        case .ola: 3_200
        }
    }

    var portraitArt: String { "foreman_\(rawValue)" }
}
