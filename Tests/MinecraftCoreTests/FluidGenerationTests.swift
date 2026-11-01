import Foundation
import Testing

@testable import MinecraftCore

#if canImport(Darwin)
    import Darwin
#endif

@Suite struct FluidGenerationTests {
    @Test func deepSpringMatchesOriginalClientOnCooperativeStack() async {
        let result = await Task.detached {
            var world = BlockWorld()
            for x in -1...1 {
                for z in -1...1 { world.setChunk(Chunk(position: ChunkPosition(x, z))) }
            }
            for y in 0..<128 {
                for (x, z) in [(7, 8), (9, 8), (8, 7), (8, 9)] { world[BlockPosition(x, y, z)] = .stone }
            }
            world[BlockPosition(8, 0, 8)] = .stone
            world[BlockPosition(8, 121, 8)] = .stone
            world[BlockPosition(8, 120, 8)] = .water
            var random = JavaRandom(seed: 42)
            BetaPopulationFeatures.instantFlow(
                at: BlockPosition(8, 120, 8), world: &world, random: &random,
                context: FluidSimulation.FlowContext())
            let chunk = world.chunks[ChunkPosition(0, 0)]!
            return (Self.hash(chunk.blockIDs), Self.hash(chunk.metadata), random.nextLong(), Self.stackSize)
        }.value
        #expect(result.0 == 0xb2d5_d81e_3c6c_5237)
        #expect(result.1 == 0xa96e_f875_4ea2_592d)
        #expect(result.2 == -5_025_562_857_975_149_833)
        #if canImport(Darwin)
            #expect(result.3 < 1024 * 1024)
        #endif
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["MINECRAFT_FLUID_STRESS"] == "1"))
    func fluidStreamingLargeRegionOnCooperativeStack() async {
        let result = await Task.detached(priority: .utility) {
            var generator = BetaTerrainGenerator(seed: 0)
            var world = BlockWorld(seed: 0)
            for radius in [3, 6, 12, 16] {
                for x in -radius...radius {
                    for z in -radius...radius where world.chunks[ChunkPosition(x, z)] == nil {
                        world.setChunk(generator.generateChunk(x: x, z: z))
                    }
                }
                print("Fluid stress: loaded radius \(radius), \(world.chunks.count) chunks")
                for x in (-radius + 1)...(radius - 2) {
                    for z in (-radius + 1)...(radius - 2) {
                        generator.populate(world: &world, chunkX: x, chunkZ: z)
                    }
                    if x % 8 == 0 { print("Fluid stress: populated through chunk x=\(x)") }
                }
            }
            let populated = world.chunks.values.filter(\.isTerrainPopulated).count
            var hash: UInt64 = 0xcbf2_9ce4_8422_2325
            for x in -16...16 {
                for z in -16...16 {
                    for block in world.chunks[ChunkPosition(x, z)]!.blockIDs {
                        hash = (hash ^ UInt64(block)) &* 0x100_0000_01b3
                    }
                }
            }
            return (world.chunks.count, populated, hash, Self.stackSize)
        }.value
        #expect(result.0 == 1089)
        #expect(result.1 == 900)
        #if canImport(Darwin)
            #expect(result.3 < 1024 * 1024)
        #endif
        print(
            "Fluid stress: completed 900 populated chunks, hash \(String(result.2, radix: 16)), stack \(result.3) bytes"
        )
    }

    private static func hash(_ bytes: [UInt8]) -> UInt64 {
        bytes.reduce(UInt64(0xcbf2_9ce4_8422_2325)) { ($0 ^ UInt64($1)) &* 0x100_0000_01b3 }
    }

    private static var stackSize: Int {
        #if canImport(Darwin)
            pthread_get_stacksize_np(pthread_self())
        #else
            0
        #endif
    }
}
