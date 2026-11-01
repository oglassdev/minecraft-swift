import MinecraftCore
import Testing

struct AudioTests {
    @Test func effectParametersMatchOriginalSoundManagerAndPaulscodeGain() {
        let normal = BetaSoundParameters(volume: 0.25, pitch: 0.4, effectsVolume: 0.8)
        #expect(normal.radius == 16 && normal.volume == 0.2 && normal.pitch == 0.5 && !normal.priority)
        #expect(normal.gain(distance: 8) == 0.1)
        let loud = BetaSoundParameters(volume: 4, pitch: 3, effectsVolume: 0.8)
        #expect(loud.radius == 64 && loud.volume == 0.8 && loud.pitch == 2 && loud.priority)
        #expect(loud.gain(distance: 32) == 0.4)
        let relative = BetaSoundParameters(volume: 2, pitch: 1, effectsVolume: 0.8, listenerRelative: true)
        #expect(relative.radius == 0 && relative.volume == 0.2 && !relative.priority)
        #expect(relative.gain(distance: 100) == 0.2)
        // Captured by invoking the original SourceLWJGLOpenAL.calculateGain method.
        let vectors: [(Float, Float, UInt32)] = [
            (16, 0, 0x3f80_0000), (16, 4, 0x3f40_0000), (16, 8, 0x3f00_0000), (16, 15.5, 0x3d00_0000),
            (16, 16, 0), (16, 17, 0), (64, 32, 0x3f00_0000), (64, 64, 0),
        ]
        for (radius, distance, bits) in vectors {
            #expect(
                BetaSoundParameters.linearAttenuation(distance: distance, radius: radius).bitPattern == bits)
        }
    }

    @Test func musicTicksMatchOriginalSoundManagerAndFreezeWhileOccupiedOrMuted() {
        // Original yo.c() was called with a recording, silent SoundSystem and seeded Random.
        for (seed, initial, first, second): (Int64, Int, Int, Int) in [
            (0, 9360, 13948, 20029), (42, 7130, 20763, 19248), (123_456_789, 2965, 21600, 20483),
        ] {
            var clock = BetaMusicSchedule(seed: seed)
            #expect(clock.remainingTicks == initial)
            for _ in 0..<31 { _ = clock.tick(musicPlaying: true, recordPlaying: false, volume: 1) }
            for _ in 0..<50 { _ = clock.tick(musicPlaying: false, recordPlaying: true, volume: 1) }
            for _ in 0..<70 { _ = clock.tick(musicPlaying: false, recordPlaying: false, volume: 0) }
            #expect(clock.remainingTicks == initial)
            var earlyStart = false
            for _ in 0..<initial {
                earlyStart = clock.tick(musicPlaying: false, recordPlaying: false, volume: 1) || earlyStart
            }
            #expect(!earlyStart && clock.remainingTicks == 0)
            let firstReady = clock.tick(musicPlaying: false, recordPlaying: false, volume: 1)
            #expect(firstReady)
            clock.didStartTrack()
            #expect(clock.remainingTicks == first)
            for _ in 0..<100 { _ = clock.tick(musicPlaying: true, recordPlaying: false, volume: 1) }
            #expect(clock.remainingTicks == first)
            for _ in 0..<first { _ = clock.tick(musicPlaying: false, recordPlaying: false, volume: 1) }
            let secondReady = clock.tick(musicPlaying: false, recordPlaying: false, volume: 1)
            #expect(secondReady)
            clock.didStartTrack()
            #expect(clock.remainingTicks == second)
        }
    }
}
