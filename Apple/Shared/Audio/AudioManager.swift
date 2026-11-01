import AVFoundation
import Foundation
import QuartzCore
import simd

@MainActor
final class AudioManager {
    enum MusicState: Equatable {
        case waiting
        case playing(String)
        case paused
        case disabled
    }

    private struct Manifest: Decodable {
        let effects: [String: [String]]
        let music: [String]
        let records: [String: [String]]
    }

    private final class Voice {
        let player = AVAudioPlayerNode()
        let speed = AVAudioUnitVarispeed()
        var position: SIMD3<Float>?
        var baseVolume: Float = 1
        var radius: Float = 16
        var priority = false
        var expiresAt: CFTimeInterval = 0
        var active = false
    }

    var effectsVolume: Float = 1
    var musicVolume: Float = 1 {
        didSet { musicPlayer?.volume = min(max(musicVolume, 0), 1) }
    }
    var musicEnabled = true {
        didSet {
            if !musicEnabled {
                musicPlayer?.stop()
                musicPlayer = nil
                musicState = .disabled
            } else if !oldValue {
                musicWait = Double(Int.random(in: 0..<12_000)) / 20
                musicState = .waiting
            }
        }
    }
    private(set) var musicState: MusicState = .waiting
    private(set) var lastError: String?
    private(set) var isAvailable = false
    private let engine = AVAudioEngine()
    private let resourceURL: URL?
    private var manifest: Manifest?
    private var voices: [Voice] = []
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var musicPlayer: AVAudioPlayer?
    private var recordPlayer: AVAudioPlayer?
    private var recordPosition: SIMD3<Float>?
    private var currentMusicName = ""
    private var musicWait = Double(Int.random(in: 0..<12_000)) / 20
    private var previousUpdateTime = CACurrentMediaTime()
    private var pausedAt: CFTimeInterval?
    private var listener = SIMD3<Float>.zero
    private var right = SIMD3<Float>(1, 0, 0)

    init(resourceURL: URL? = Bundle.main.resourceURL?.appendingPathComponent("Vanilla")) {
        self.resourceURL = resourceURL
        guard let resourceURL else { return }
        do {
            let data = try Data(contentsOf: resourceURL.appendingPathComponent("sounds-apple.json"))
            manifest = try JSONDecoder().decode(Manifest.self, from: data)
            #if os(iOS)
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            #endif
            guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) else {
                return
            }
            for _ in 0..<32 {
                let voice = Voice()
                engine.attach(voice.player)
                engine.attach(voice.speed)
                engine.connect(voice.player, to: voice.speed, format: format)
                engine.connect(voice.speed, to: engine.mainMixerNode, format: format)
                voices.append(voice)
            }
            engine.prepare()
            isAvailable = true
        } catch {
            lastError = "Audio assets unavailable: \(error.localizedDescription). Run Tools/convert_audio.py."
        }
    }

    @discardableResult
    func play(
        event: String,
        at position: SIMD3<Float>? = nil,
        listener: SIMD3<Float>,
        volume: Float = 1,
        pitch: Float = 1
    ) -> Bool {
        guard isAvailable, pausedAt == nil, volume > 0,
            let path = manifest?.effects[event]?.randomElement()
        else { return false }
        self.listener = listener
        let now = CACurrentMediaTime()
        let radius = 16 * max(volume, 1)
        if let position, simd_distance(position, listener) >= radius { return false }
        do {
            let buffer = try soundBuffer(path: path)
            if !engine.isRunning { try engine.start() }
            let voice =
                voices.first(where: { !$0.active || $0.expiresAt <= now })
                ?? voices.filter({ !$0.priority }).min(by: { $0.expiresAt < $1.expiresAt })
                ?? (volume > 1 ? voices.min(by: { $0.expiresAt < $1.expiresAt }) : nil)
            guard let voice else { return false }
            voice.player.stop()
            voice.speed.rate = min(max(pitch, 0.5), 2)
            voice.position = position
            voice.baseVolume = min(volume, 1) * (position == nil ? 0.25 : 1)
            voice.radius = radius
            voice.priority = volume > 1
            voice.expiresAt =
                now + Double(buffer.frameLength) / buffer.format.sampleRate / Double(voice.speed.rate)
            voice.active = true
            positionVoice(voice)
            voice.player.scheduleBuffer(buffer)
            voice.player.play()
            return true
        } catch {
            lastError = "Audio playback failed: \(error.localizedDescription)"
            return false
        }
    }

    func update(listener: SIMD3<Float>, forward: SIMD3<Float>) {
        self.listener = listener
        let horizontal = SIMD3<Float>(-forward.z, 0, forward.x)
        if simd_length_squared(horizontal) > 0.0001 { right = simd_normalize(horizontal) }
        let now = CACurrentMediaTime()
        let elapsed = max(0, now - previousUpdateTime)
        previousUpdateTime = now
        guard pausedAt == nil else { return }
        for voice in voices where voice.active {
            if voice.expiresAt <= now {
                voice.player.stop()
                voice.active = false
            } else {
                positionVoice(voice)
            }
        }
        if let recordPosition {
            let offset = recordPosition - listener
            let distance = simd_length(offset)
            recordPlayer?.volume = max(0, 1 - distance / 64) * 0.5 * effectsVolume
            recordPlayer?.pan = distance > 0.001 ? simd_dot(offset / distance, right) : 0
        }
        updateMusic(elapsed: elapsed)
    }

    func setPaused(_ paused: Bool) {
        let now = CACurrentMediaTime()
        previousUpdateTime = now
        if paused, pausedAt == nil {
            pausedAt = now
            for voice in voices where voice.active { voice.player.pause() }
            engine.pause()
            musicPlayer?.pause()
            recordPlayer?.pause()
            if musicEnabled { musicState = .paused }
        } else if !paused, let pausedAt {
            let elapsed = now - pausedAt
            self.pausedAt = nil
            do {
                if voices.contains(where: \.active) && !engine.isRunning { try engine.start() }
                for voice in voices where voice.active {
                    voice.expiresAt += elapsed
                    voice.player.play()
                }
                if let musicPlayer {
                    musicPlayer.play()
                    musicState = .playing(currentMusicName)
                } else if musicEnabled {
                    musicState = .waiting
                }
                recordPlayer?.play()
            } catch {
                lastError = "Could not resume audio: \(error.localizedDescription)"
            }
        }
    }

    @discardableResult
    func playMusicNow() -> Bool {
        guard musicEnabled, pausedAt == nil, let path = manifest?.music.randomElement() else { return false }
        do {
            guard let resourceURL else { return false }
            let player = try AVAudioPlayer(contentsOf: resourceURL.appendingPathComponent(path))
            player.volume = min(max(musicVolume, 0), 1)
            guard player.play() else {
                musicWait = 30
                return false
            }
            currentMusicName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            musicPlayer = player
            musicState = .playing(currentMusicName)
            musicWait = Double(Int.random(in: 12_000..<24_000)) / 20
            return true
        } catch {
            lastError = "Could not play music: \(error.localizedDescription)"
            musicWait = 30
            return false
        }
    }

    @discardableResult
    func playRecord(_ name: String?, at position: SIMD3<Float>? = nil) -> Bool {
        recordPlayer?.stop()
        recordPlayer = nil
        recordPosition = position
        guard let name else { return true }
        guard pausedAt == nil, let resourceURL, let path = manifest?.records[name]?.first else {
            return false
        }
        do {
            musicPlayer?.stop()
            musicPlayer = nil
            musicState = .waiting
            let player = try AVAudioPlayer(contentsOf: resourceURL.appendingPathComponent(path))
            player.volume = 0.5 * effectsVolume
            guard player.play() else { return false }
            recordPlayer = player
            return true
        } catch {
            lastError = "Could not play record: \(error.localizedDescription)"
            return false
        }
    }

    func shutdown() {
        for voice in voices {
            voice.player.stop()
            voice.active = false
        }
        musicPlayer?.stop()
        recordPlayer?.stop()
        engine.stop()
        buffers.removeAll()
    }

    private func soundBuffer(path: String) throws -> AVAudioPCMBuffer {
        if let buffer = buffers[path] { return buffer }
        guard let resourceURL else { throw CocoaError(.fileNoSuchFile) }
        let file = try AVAudioFile(forReading: resourceURL.appendingPathComponent(path))
        guard file.length > 0, file.length <= Int64(UInt32.max),
            let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))
        else { throw CocoaError(.fileReadCorruptFile) }
        try file.read(into: buffer)
        buffers[path] = buffer
        return buffer
    }

    private func positionVoice(_ voice: Voice) {
        var gain = voice.baseVolume * effectsVolume
        var pan: Float = 0
        if let position = voice.position {
            let offset = position - listener
            let distance = simd_length(offset)
            gain *= max(0, 1 - distance / voice.radius)
            if distance > 0.001 { pan = simd_dot(offset / distance, right) }
        }
        voice.player.volume = min(max(gain, 0), 1)
        voice.player.pan = min(max(pan, -1), 1)
    }

    private func updateMusic(elapsed: TimeInterval) {
        guard musicEnabled, recordPlayer?.isPlaying != true else { return }
        if let player = musicPlayer {
            guard !player.isPlaying else { return }
            musicPlayer = nil
            musicState = .waiting
        }
        musicWait -= elapsed
        if musicWait <= 0 { playMusicNow() }
    }
}
