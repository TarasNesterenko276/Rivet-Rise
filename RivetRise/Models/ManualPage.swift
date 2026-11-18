import Foundation

/// One page of the site manual (the how-to-play guide), each with its own illustration.
struct ManualPage: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    let body: String
    let art: String

    static let all: [ManualPage] = [
        ManualPage(
            id: 0,
            title: "Drop the module",
            body: "The crane swings a floor module over the tower. Tap anywhere to release it. Whatever hangs over the edge is cut off, so the next floor is narrower. Land within a hair of the centre for a Perfect: double points, and every fourth Perfect in a row widens the module again.",
            art: "manual_drop"
        ),
        ManualPage(
            id: 1,
            title: "Ride the sway",
            body: "The taller the tower, the more it sways. The plumb bob shows how close it is to collapsing. Land a module while the top swings through the centre to be In Tune and calm it down. Off-beat landings and sloppy drops rock it harder.",
            art: "manual_sway"
        ),
        ManualPage(
            id: 2,
            title: "Strike the rivet",
            body: "After each landing a ring closes in on the joint. Tap again the moment it meets the yellow mark to rivet the floor: double points and a calmer tower. A mistimed tap bends the rivet and shakes the tower. If the tower collapses, only floors above the last rivet fall.",
            art: "manual_rivet"
        ),
        ManualPage(
            id: 3,
            title: "Build districts",
            body: "Modules come for different tenants. Stack three of a kind in a row to form a district: Residential pays points, Office pays bolts, Sky Garden halves the sway. Every so often a Penthouse arrives: land it to rivet every floor below.",
            art: "manual_districts"
        ),
        ManualPage(
            id: 4,
            title: "Wind and Rush",
            body: "Watch the weathervane: it turns red before a gust pushes the hook sideways. Drop quickly after a module appears to build Rush, a points multiplier of up to x2. Rush also speeds up the hook, and hesitating drains it.",
            art: "manual_wind"
        ),
        ManualPage(
            id: 5,
            title: "Expect the unexpected",
            body: "A creaking cable means it is about to snap and drop the module on its own: line up fast. Land a snapped module perfectly for a Cable Catch bonus. Every ten floors a new site shift begins: fog, night, a jumpy crane, steel girders or dead calm.",
            art: "manual_shifts"
        ),
        ManualPage(
            id: 6,
            title: "Get paid, build better",
            body: "You have three hard hats. A module that misses the tower or a collapse costs one. When the shift ends your points are paid in bolts. Spend them in the Rigging Yard on crane upgrades and hire foremen with their own perks in the Crew Lockers.",
            art: "manual_pay"
        )
    ]
}
