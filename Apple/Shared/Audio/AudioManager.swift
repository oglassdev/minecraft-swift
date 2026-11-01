import AVFoundation
import Foundation
import MinecraftCore
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
        var sourceID = -1
        var expiresAt: CFTimeInterval = 0
        var active = false
    }

    var effectsVolume: Float = 1
    var musicVolume: Float = 1 {
        didSet {
            if musicVolume == 0 {
                musicPlayer?.stop()
                musicPlayer = nil
                musicState = .disabled
            } else {
                musicPlayer?.volume = min(max(musicVolume, 0), 1)
                if oldValue == 0 && musicEnabled { musicState = .waiting }
            }
        }
    }
    var musicEnabled = true {
        didSet {
            if !musicEnabled {
                musicPlayer?.stop()
                musicPlayer = nil
                musicState = .disabled
            } else if !oldValue {
                musicState = musicVolume == 0 ? .disabled : .waiting
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
    private var recordBaseVolume: Float = 0
    private var currentMusicName = ""
    private var musicSchedule = BetaMusicSchedule(seed: Int64.random(in: .min ... .max))
    private var effectRandom = JavaRandom(seed: Int64.random(in: .min ... .max))
    private var musicRandom = JavaRandom(seed: Int64.random(in: .min ... .max))
    private var recordRandom = JavaRandom(seed: Int64.random(in: .min ... .max))
    private var nextVoice = 0
    private var soundSequence = 0
    private var isPaused = false
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
            for _ in 0..<28 {
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
        guard isAvailable, effectsVolume != 0, volume > 0,
            let paths = manifest?.effects[event], !paths.isEmpty
        else { return false }
        let path = paths[effectRandom.nextInt(bound: paths.count)]
        self.listener = listener
        let now = CACurrentMediaTime()
        let parameters = BetaSoundParameters(
            volume: volume, pitch: pitch,
            effectsVolume: effectsVolume, listenerRelative: position == nil)
        if let position, simd_distance(position, listener) >= parameters.radius { return false }
        do {
            let buffer = try soundBuffer(path: path)
            if !engine.isRunning { try engine.start() }
            soundSequence = (soundSequence + 1) % 256
            guard let voice = acquireVoice(now: now, sourceID: soundSequence) else { return false }
            voice.player.stop()
            voice.speed.rate = parameters.pitch
            voice.position = position
            voice.baseVolume = parameters.volume
            voice.radius = parameters.radius
            voice.priority = parameters.priority
            voice.sourceID = soundSequence
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
            recordPlayer?.volume =
                BetaSoundParameters.linearAttenuation(distance: distance, radius: 64) * recordBaseVolume
            recordPlayer?.pan = distance > 0.001 ? simd_dot(offset / distance, right) : 0
        }
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
    }

    @discardableResult
    func playMusicNow() -> Bool {
        guard isAvailable, musicEnabled, musicVolume != 0, !isPaused,
            recordPlayer?.isPlaying != true, let paths = manifest?.music, !paths.isEmpty
        else { return false }
        let path = paths[musicRandom.nextInt(bound: paths.count)]
        musicSchedule.didStartTrack()
        do {
            guard let resourceURL else { return false }
            musicPlayer?.stop()
            let player = try AVAudioPlayer(contentsOf: resourceURL.appendingPathComponent(path))
            player.volume = min(max(musicVolume, 0), 1)
            guard player.play() else {
                return false
            }
            currentMusicName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            musicPlayer = player
            musicState = .playing(currentMusicName)
            return true
        } catch {
            lastError = "Could not play music: \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func playRecord(_ name: String?, at position: SIMD3<Float>? = nil) -> Bool {
        guard isAvailable, effectsVolume != 0 else { return false }
        recordPlayer?.stop()
        recordPlayer = nil
        recordPosition = position ?? listener
        guard let name else { return true }
        guard let resourceURL, let paths = manifest?.records[name], !paths.isEmpty else {
            return false
        }
        let path = paths[recordRandom.nextInt(bound: paths.count)]
        do {
            musicPlayer?.stop()
            musicPlayer = nil
            musicState = .waiting
            let player = try AVAudioPlayer(contentsOf: resourceURL.appendingPathComponent(path))
            recordBaseVolume = min(1, max(0, 0.5 * effectsVolume))
            let distance = simd_distance(recordPosition ?? listener, listener)
            player.volume =
                BetaSoundParameters.linearAttenuation(distance: distance, radius: 64) * recordBaseVolume
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
        var gain = voice.baseVolume
        var pan: Float = 0
        if let position = voice.position {
            let offset = position - listener
            let distance = simd_length(offset)
            gain *= BetaSoundParameters.linearAttenuation(distance: distance, radius: voice.radius)
            if distance > 0.001 { pan = simd_dot(offset / distance, right) }
        }
        voice.player.volume = min(max(gain, 0), 1)
        voice.player.pan = min(max(pan, -1), 1)
    }

    func tick() {
        guard isAvailable, !isPaused, musicEnabled else { return }
        if let player = musicPlayer {
            guard !player.isPlaying else { return }
            musicPlayer = nil
            musicState = .waiting
        }
        if musicSchedule.tick(
            musicPlaying: musicPlayer?.isPlaying == true,
            recordPlaying: recordPlayer?.isPlaying == true, volume: musicVolume)
        {
            playMusicNow()
        }
    }

    private func acquireVoice(now: CFTimeInterval, sourceID: Int) -> Voice? {
        if let matching = voices.first(where: { $0.sourceID == sourceID }) { return matching }
        for allowSteal in [false, true] {
            for offset in voices.indices {
                let index = (nextVoice + offset) % voices.count
                let voice = voices[index]
                if !voice.active || voice.expiresAt <= now || (allowSteal && !voice.priority) {
                    nextVoice = (index + 1) % voices.count
                    return voice
                }
            }
        }
        return nil
    }
}
