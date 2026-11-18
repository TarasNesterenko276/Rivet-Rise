import AVFoundation
import Foundation

/// Generated sound effects (see `Artwork/generate_sounds.swift`).
enum SoundEffect: String, CaseIterable {
    case release = "sfx_release"
    case land = "sfx_land"
    case perfect = "sfx_perfect"
    case rivet = "sfx_rivet"
    case bent = "sfx_bent"
    case district = "sfx_district"
    case penthouse = "sfx_penthouse"
    case collapse = "sfx_collapse"
    case miss = "sfx_miss"
    case creak = "sfx_creak"
    case gust = "sfx_gust"
    case shift = "sfx_shift"
    case count = "sfx_count"
    case go = "sfx_go"
    case tap = "sfx_tap"
    case buy = "sfx_buy"
    case gameOver = "sfx_gameover"

    /// How many copies may overlap.
    var voices: Int {
        switch self {
        case .land, .release, .rivet: 3
        default: 2
        }
    }
}

/// Plays effects and the site ambience while respecting the Sound setting.
/// Uses the ambient session so the game mixes with other audio and honours the silent switch.
@MainActor
final class SoundService {
    private var pools: [SoundEffect: [AVAudioPlayer]] = [:]
    private var nextVoice: [SoundEffect: Int] = [:]
    private var ambience: AVAudioPlayer?
    private let isEnabled: () -> Bool
    private var isPrepared = false

    /// A service that never plays anything (tests and UI-test runs).
    static let silent = SoundService { false }

    init(isEnabled: @escaping () -> Bool) {
        self.isEnabled = isEnabled
    }

    private func prepareIfNeeded() {
        guard !isPrepared else { return }
        isPrepared = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for effect in SoundEffect.allCases {
            guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") else { continue }
            pools[effect] = (0..<effect.voices).compactMap { _ in
                let player = try? AVAudioPlayer(contentsOf: url)
                player?.prepareToPlay()
                return player
            }
        }
    }

    func play(_ effect: SoundEffect, volume: Float = 1) {
        guard isEnabled() else { return }
        prepareIfNeeded()
        guard let pool = pools[effect], !pool.isEmpty else { return }
        let index = (nextVoice[effect] ?? 0) % pool.count
        nextVoice[effect] = index + 1
        let player = pool[index]
        player.volume = volume
        player.currentTime = 0
        player.play()
    }

    /// Starts (or stops, when sound is off) the wind-and-site ambience loop.
    func updateAmbience(playing: Bool) {
        guard playing, isEnabled() else {
            ambience?.setVolume(0, fadeDuration: 0.4)
            ambience?.pause()
            return
        }
        prepareIfNeeded()
        if ambience == nil, let url = Bundle.main.url(forResource: "ambience_site", withExtension: "wav") {
            ambience = try? AVAudioPlayer(contentsOf: url)
            ambience?.numberOfLoops = -1
            ambience?.volume = 0
        }
        guard let ambience, !ambience.isPlaying else { return }
        ambience.play()
        ambience.setVolume(0.45, fadeDuration: 1)
    }
}
