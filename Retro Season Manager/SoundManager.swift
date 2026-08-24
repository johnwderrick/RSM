//
//  SoundManager.swift
//  Retro Season Manager
//
//  Audio hooks for key game moments. Bundled files are preferred when
//  available; the experience selector also has a tiny generated fallback
//  tone so its audio identity works without shipping a large sound pack.
//

import AVFoundation

/// Named sound cues for key game moments, matched to a bundled audio file
/// of the same name (tries .caf, then .mp3, then .wav) when one exists.
enum SoundCue: String {
    case buttonTap = "button_tap"
    case menuCareer = "menu_career"
    case menuLegends = "menu_legends"
    case menuSettings = "menu_settings"
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
    private static let mutedDefaultsKey = "SoundManager.isMuted"

    private init() {
        isMuted = UserDefaults.standard.bool(forKey: Self.mutedDefaultsKey)
    }

    /// Master mute — an app-wide preference shared by Career Mode and
    /// RSM Legends, and persisted independently from either save file.
    var isMuted: Bool {
        didSet { UserDefaults.standard.set(isMuted, forKey: Self.mutedDefaultsKey) }
    }

    private var player: AVAudioPlayer?

    func play(_ cue: SoundCue) {
        guard !isMuted else { return }
        let extensions = ["caf", "mp3", "wav"]
        if let url = extensions.lazy.compactMap({
            Bundle.main.url(forResource: cue.rawValue, withExtension: $0)
        }).first {
            player = try? AVAudioPlayer(contentsOf: url)
            player?.play()
            return
        }

        // The selector cues remain audible in the current asset catalogue,
        // which intentionally contains artwork but no licensed audio files.
        switch cue {
        case .menuCareer:
            playFallbackTone(frequencies: [392, 523])
        case .menuLegends:
            playFallbackTone(frequencies: [523, 659])
        case .menuSettings:
            playFallbackTone(frequencies: [659])
        default:
            break
        }
    }

    private func playFallbackTone(frequencies: [Double]) {
        guard !frequencies.isEmpty else { return }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        player = try? AVAudioPlayer(data: Self.makeToneData(frequencies: frequencies))
        player?.volume = 0.16
        player?.prepareToPlay()
        player?.play()
    }

    /// Creates a short, quiet 16-bit PCM WAV in memory. This avoids adding
    /// an opaque binary resource solely for three navigation confirmations.
    private static func makeToneData(frequencies: [Double], duration: Double = 0.09) -> Data {
        let sampleRate: UInt32 = 44_100
        let sampleCount = Int(Double(sampleRate) * duration)
        var pcm = Data(capacity: sampleCount * 2)

        for index in 0..<sampleCount {
            let time = Double(index) / Double(sampleRate)
            let progress = Double(index) / Double(max(1, sampleCount - 1))
            let envelope = min(1, progress * 30) * min(1, (1 - progress) * 20)
            let sample = frequencies.reduce(0.0) { partial, frequency in
                partial + sin(2 * .pi * frequency * time) / Double(frequencies.count)
            }
            let value = Int16(max(-1, min(1, sample * envelope)) * 8_000)
            appendLittleEndian(UInt16(bitPattern: value), to: &pcm)
        }

        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        appendLittleEndian(UInt32(36 + pcm.count), to: &data)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        appendLittleEndian(UInt32(16), to: &data)
        appendLittleEndian(UInt16(1), to: &data) // PCM
        appendLittleEndian(UInt16(1), to: &data) // mono
        appendLittleEndian(sampleRate, to: &data)
        appendLittleEndian(sampleRate * 2, to: &data)
        appendLittleEndian(UInt16(2), to: &data)
        appendLittleEndian(UInt16(16), to: &data)
        data.append(contentsOf: Array("data".utf8))
        appendLittleEndian(UInt32(pcm.count), to: &data)
        data.append(pcm)
        return data
    }

    private static func appendLittleEndian(_ value: UInt16, to data: inout Data) {
        data.append(UInt8(value & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
    }

    private static func appendLittleEndian(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(value & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 24) & 0xff))
    }
}
