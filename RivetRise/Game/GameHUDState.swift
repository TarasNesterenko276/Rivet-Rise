import Foundation

/// The values the SwiftUI HUD displays, mirrored from the running scene about ten times a second.
struct GameHUDState: Equatable, Sendable {
    var score = 0
    var bolts = 0
    var floors = 0
    var hardHats: Int
    var maxHardHats: Int
    var swayFraction: Double = 0
    var rush = 0
    var rushCap: Int
    var rushMultiplier: Double = 1
    var wind: WindState = .still(nextIn: 0)
    var currentKind: FloorKind = .residential
    var nextKind: FloorKind = .office
    var shift: SiteShift = .clear
    var isCreaking = false
    var perfectStreak = 0
    var elapsed: TimeInterval = 0

    init(loadout: Loadout) {
        hardHats = loadout.hardHats
        maxHardHats = loadout.hardHats
        rushCap = loadout.rushCap
    }

    init(session: RunSession) {
        self.init(loadout: session.loadout)
        score = session.score
        bolts = session.bolts
        floors = session.height
        hardHats = session.hardHats
        swayFraction = (session.swayFraction * 20).rounded() / 20
        rush = session.rush
        rushMultiplier = session.rushMultiplier
        wind = Self.coarse(session.wind)
        currentKind = session.currentKind
        nextKind = session.nextKind
        shift = session.shift
        isCreaking = session.isCreaking
        perfectStreak = session.perfectStreak
        elapsed = (session.elapsed * 2).rounded() / 2
    }

    /// Drops the countdown timers so the HUD only refreshes when the wind actually changes.
    private static func coarse(_ wind: WindState) -> WindState {
        switch wind {
        case .still: .still(nextIn: 0)
        case .warning(_, let direction): .warning(remaining: 0, direction: direction)
        case .gust(_, let direction): .gust(remaining: 0, direction: direction)
        }
    }
}
