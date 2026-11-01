import Foundation
import Testing

@testable import MinecraftCore

struct WeatherTests {
    @Test func timerTransitionsAndFloatStrengthsMatchOriginalWorld() {
        assertTrace(
            seed: 0, raining: false, thundering: false, rainTime: 0, thunderTime: 0,
            expected: [
                [1, 0, 0, 13948, 129360, 0, 0], [2, 0, 0, 13947, 129359, 0, 0],
                [6, 0, 0, 13943, 129355, 0, 0],
            ],
            nextRandom: 1_033_096_058)
        assertTrace(
            seed: 123_456_789, raining: false, thundering: false, rainTime: 1, thunderTime: 1,
            expected: [
                [1, 1, 1, 0, 0, 0x3c23_d70a, 0x3c23_d70a], [2, 1, 1, 21600, 6565, 0x3ca3_d70a, 0x3ca3_d70a],
                [50, 1, 1, 21552, 6517, 0x3eff_fffa, 0x3eff_fffa],
                [99, 1, 1, 21503, 6468, 0x3f7d_7099, 0x3f7d_7099],
                [100, 1, 1, 21502, 6467, 0x3f7f_fff5, 0x3f7f_fff5],
                [101, 1, 1, 21501, 6466, 0x3f80_0000, 0x3f80_0000],
                [200, 1, 1, 21402, 6367, 0x3f80_0000, 0x3f80_0000],
            ], nextRandom: 1_962_592_967)
        assertTrace(
            seed: 42, raining: true, thundering: true, rainTime: 1, thunderTime: 2,
            expected: [
                [1, 0, 1, 0, 1, 0x3f7d_70a4, 0x3f80_0000], [2, 0, 0, 43130, 0, 0x3f7a_e148, 0x3f7d_70a4],
                [50, 0, 0, 43082, 140716, 0x3f00_0008, 0x3f02_8f64],
                [99, 0, 0, 43033, 140667, 0x3c23_d9ce, 0x3ca3_d86c],
                [100, 0, 0, 43032, 140666, 0x3530_f0a4, 0x3c23_d9ce],
                [101, 0, 0, 43031, 140665, 0, 0x3530_f0a4],
            ],
            nextRandom: -1_360_544_799)
        assertTrace(
            seed: 42, raining: true, thundering: true, rainTime: 1, thunderTime: 2, dimension: -1,
            expected: [
                [1, 1, 1, 1, 2, 0x3f80_0000, 0x3f80_0000], [101, 1, 1, 1, 2, 0x3f80_0000, 0x3f80_0000],
            ],
            nextRandom: -1_170_105_035)
    }

    @Test func daylightMatchesOriginalCelestialAngleAndWeatherDarkening() {
        // Raw Float bits and light subtraction from Tools/reference/WeatherParity.java.
        let times: [Int64] = [0, 6000, 12000, 13000, 18000, 23000, -1]
        let angles: [[UInt32]] = [
            [0x3f48_d629, 0x3f48_d793, 0x3f48_d8fd], [0, 0x3769_0000, 0x37e9_0000],
            [0x3e5c_a75d, 0x3e5c_ad09, 0x3e5c_b2b1], [0x3e84_f0f6, 0x3e84_f3e9, 0x3e84_f6df],
            [0x3f00_0000, 0x3f00_01a1, 0x3f00_0340], [0x3f3d_8785, 0x3f3d_8900, 0x3f3d_8a79],
            [0x3f48_d354, 0x3f48_d4be, 0x3f48_d629],
        ]
        let darkening = [[0, 0, 0, 6, 11, 6, 0], [3, 2, 3, 7, 11, 7, 3], [6, 5, 6, 9, 11, 9, 6]]
        var weather = WorldWeather(seed: 0)
        for index in times.indices {
            for (partialIndex, partial): (Int, Float) in [0, 0.5, 1].enumerated() {
                #expect(
                    weather.celestialAngle(time: times[index], partialTick: partial).bitPattern
                        == angles[index][partialIndex])
            }
            for (strengthIndex, strength): (Int, Float) in [0, 0.5, 1].enumerated() {
                weather.rainStrength = strength
                weather.thunderStrength = strength
                #expect(weather.skylightSubtraction(time: times[index]) == darkening[strengthIndex][index])
            }
        }
        #expect(weather.celestialAngle(time: 0, dimension: -1) == 0.5)
    }

    @Test func coldBiomePrecipitationMatchesOriginalSnowAndFreezingRules() {
        // The original initialized World.n() produces snow/ice in all 361 active chunks
        // for these uniform cold fixtures; ineligible fixtures produce neither.
        let cases: [(BlockKind, UInt8, UInt8, Bool, BlockKind?)] = [
            (.stone, 0, 0, true, .snowLayer), (.leaves, 0, 0, true, .snowLayer),
            (.stillWater, 0, 0, false, .ice), (.stillWater, 1, 0, true, nil),
            (.stillWater, 0, 10, true, nil), (.stone, 0, 9, true, .snowLayer), (.stone, 0, 10, true, nil),
        ]
        for (floor, metadata, light, raining, expected) in cases {
            var world = BlockWorld(seed: 11)
            var chunk = Chunk(position: ChunkPosition(0, 0))
            for x in 0..<16 { for z in 0..<16 { chunk[x, 64, z] = BlockState(floor, metadata: metadata) } }
            chunk.blockLight = Array(repeating: light, count: Chunk.volume)
            world.setChunk(chunk, updateLighting: false)
            var weather = WorldWeather(seed: 11, raining: raining, rainTime: 1000, thunderTime: 1000)
            #expect(weather.precipitation(atX: 0, z: 0, in: world) == .snow)
            for tick in 0..<128 {
                _ = weather.tick(world: &world, players: [SIMD3(8, 66, 8)], time: Int64(tick))
            }
            let blocks = world.chunks[ChunkPosition(0, 0)]!.blockIDs
            if let expected {
                #expect(blocks.contains(expected.rawValue))
            } else {
                #expect(
                    !blocks.contains(BlockKind.snowLayer.rawValue) && !blocks.contains(BlockKind.ice.rawValue)
                )
            }
        }
    }

    @Test func rainExposureLightningThresholdAndSleepingFadeMatchOriginal() {
        var world = BlockWorld(seed: 0)
        var chunk = Chunk(position: ChunkPosition(0, 0))
        for (position, kind) in [
            (BlockPosition(4, 64, 4), BlockKind.stone), (BlockPosition(4, 70, 4), .stone),
            (BlockPosition(8, 64, 8), .leaves), (BlockPosition(12, 64, 12), .stillWater),
        ] {
            chunk[position.x & 15, position.y, position.z & 15] = BlockState(kind)
        }
        world.setChunk(chunk, updateLighting: false)
        var weather = WorldWeather(seed: 0, raining: true, thundering: true)
        for (position, expected) in [
            (BlockPosition(4, 65, 4), false), (BlockPosition(4, 71, 4), true),
            (BlockPosition(8, 65, 8), true), (BlockPosition(12, 65, 12), true),
            (BlockPosition(1, 64, 1), true),
        ] {
            #expect(weather.canRain(at: position, in: world) == expected)
            #expect(weather.canStrikeLightning(at: position, in: world) == expected)
        }
        #expect(WorldWeather.precipitation(temperature: 1, humidity: 0) == .none)
        #expect(WorldWeather.precipitation(temperature: 0.4, humidity: 0.9) == .snow)
        #expect(WorldWeather.precipitation(temperature: 1, humidity: 1) == .rain)
        weather.thunderStrength = 0.9
        #expect(!weather.canStrikeLightning(at: BlockPosition(1, 64, 1), in: world))
        weather.rainStrength = Float(0.2).nextDown
        #expect(!weather.canRain(at: BlockPosition(1, 64, 1), in: world))
        weather.rainStrength = 0.2
        #expect(weather.canRain(at: BlockPosition(1, 64, 1), in: world))
        #expect(!weather.canStrikeLightning(at: BlockPosition(1, -1, 1), in: world))
        weather.rainStrength = 1
        weather.stopPrecipitation()
        #expect(!weather.raining && !weather.thundering && weather.rainTime == 0 && weather.thunderTime == 0)
        #expect(weather.rainStrength == 1)
        _ = weather.tick(world: &world, players: [], time: 0)
        #expect(weather.rainStrength.bitPattern == 0x3f7d_70a4)
        #expect(weather.interpolatedRainStrength(0) == 1)
        #expect(weather.interpolatedRainStrength(1) == weather.rainStrength)
    }

    private func assertTrace(
        seed: Int64, raining: Bool, thundering: Bool, rainTime: Int, thunderTime: Int,
        dimension: Int8 = 0, expected: [[Int]], nextRandom: Int32
    ) {
        var world = BlockWorld(seed: seed, dimension: dimension)
        var weather = WorldWeather(
            seed: seed, raining: raining, thundering: thundering,
            rainTime: rainTime, thunderTime: thunderTime)
        var random = JavaRandom(seed: seed)
        for tick in 1...expected.last![0] {
            #expect(weather.tick(world: &world, players: [], time: Int64(tick), random: &random).isEmpty)
            if let row = expected.first(where: { $0[0] == tick }) {
                #expect(
                    [
                        tick, weather.raining ? 1 : 0, weather.thundering ? 1 : 0,
                        weather.rainTime, weather.thunderTime, Int(weather.rainStrength.bitPattern),
                        Int(weather.thunderStrength.bitPattern),
                    ] == row)
            }
        }
        #expect(random.nextInt() == nextRandom)
    }
}
