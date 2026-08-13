//
//  SoundManager.swift
//  Retro Season Manager
//
//  Audio hooks for key game moments. No sound files are bundled yet —
//  `play(_:)` is a safe no-op whenever the named asset isn't found, so
//  wiring call sites in now costs nothing, and dropping in real audio
//  later (a "goal_crowd.caf" etc. added to the app bundle) needs no
//  further code changes anywhere this is called.
//

import AVFoundation

/// Named sound cues for key game moments, matched to a bundled audio file
/// of the same name (tries .caf, then .mp3, then .wav) when one exists.
enum SoundCue: String {
    case buttonTap = "button_tap"
    case whistleKickOff = "whistle_kickoff"
    case whistleHalfTime = "whistle_halftime"
    case whistleFullTime = "whistle_fulltime"
    case goalCrowd = "goal_crowd"
    case yellowCard = "card_yellow"
    case redCard = "card_red"
    case substitution = "substitution"
    case promotion = "promotion"
    case trophyLift = "trophy_lift"
}

@MainActor
final class SoundManager {
    static let shared = SoundManager()
    private init() {}

    /// Master mute — not wired to a Settings toggle yet, but the hook
    /// exists so adding one later is a one-line change at the call site.
    var isMuted = false

    private var player: AVAudioPlayer?

    func play(_ cue: SoundCue) {
        guard !isMuted else { return }
        let extensions = ["caf", "mp3", "wav"]
        guard let url = extensions.lazy.compactMap({ Bundle.main.url(forResource: cue.rawValue, withExtension: $0) }).first else {
            return
        }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}
