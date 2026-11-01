public struct BetaSoundParameters: Sendable, Equatable {
    public let radius: Float
    public let volume: Float
    public let pitch: Float
    public let priority: Bool

    public init(volume: Float, pitch: Float, effectsVolume: Float, listenerRelative: Bool = false) {
        radius = listenerRelative ? 0 : (volume > 1 ? 16 * volume : 16)
        let sourceVolume = min(volume, 1) * (listenerRelative ? 0.25 : 1) * effectsVolume
        self.volume = min(1, max(0, sourceVolume))
        self.pitch = min(2, max(0.5, pitch))
        priority = !listenerRelative && volume > 1
    }

    public func gain(distance: Float) -> Float {
        volume * (radius == 0 ? 1 : Self.linearAttenuation(distance: distance, radius: radius))
    }

    public static func linearAttenuation(distance: Float, radius: Float) -> Float {
        if distance <= 0 { return 1 }
        if distance >= radius { return 0 }
        return min(1, max(0, 1 - distance / radius))
    }
}

public struct BetaMusicSchedule: Sendable {
    public private(set) var remainingTicks: Int
    private var random: JavaRandom

    public init(seed: Int64) {
        var random = JavaRandom(seed: seed)
        remainingTicks = random.nextInt(bound: 12000)
        self.random = random
    }

    public mutating func tick(musicPlaying: Bool, recordPlaying: Bool, volume: Float) -> Bool {
        guard volume != 0, !musicPlaying, !recordPlaying else { return false }
        if remainingTicks > 0 {
            remainingTicks -= 1
            return false
        }
        return true
    }

    public mutating func didStartTrack() { remainingTicks = random.nextInt(bound: 12000) + 12000 }
}
