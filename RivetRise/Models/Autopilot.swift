import Foundation

/// Plays the crane by itself for UI tests and screenshot tours, which cannot react in real time.
/// It predicts where the swaying top will be when a module lands and drops when the hook lines up.
/// Its aim gets sloppier as the tower grows, so a shift always ends and shows trims and misses.
enum Autopilot {
    static func aimTolerance(_ session: RunSession) -> Double {
        session.loadout.perfectTolerance * 0.6 + 0.005 * Double(max(session.height - 6, 0))
    }

    static func shouldTap(_ session: RunSession) -> Bool {
        switch session.phase {
        case .swinging:
            guard let top = session.top else {
                return abs(session.hookX) < aimTolerance(session)
            }
            let futurePhase = session.swayPhase + Balance.swaySpeed * Balance.fallDuration
            let target = top.x + session.swayAmplitude * sin(futurePhase)
            // Once the tower sways hard, also wait for an in-tune landing to calm it.
            let inTune = abs(sin(futurePhase)) < Balance.inTuneBand
            guard inTune || session.swayFraction < 0.5 else { return false }
            // Sloppy aim drops at the edge of the window, not the centre.
            let error = abs(session.hookX - target)
            let tolerance = aimTolerance(session)
            return error < tolerance && (session.height < 8 || error > tolerance * 0.5)
        case .riveting(let elapsed, let tapped):
            return !tapped && abs(elapsed - Balance.rivetSweetSpot) < 0.02
        case .falling, .over:
            return false
        }
    }
}
