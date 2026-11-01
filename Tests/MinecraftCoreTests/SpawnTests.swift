import MinecraftCore
import Testing

@Suite struct SpawnTests {
    @Test func initialAndPlayerSpawnsMatchOriginalClient() {
        let vectors: [(Int64, BlockPosition, Double, Int64)] = [
            (0, BlockPosition(-118, 64, 48), 66, -6_626_094_279_135_658_848),
            (1, BlockPosition(42, 64, 14), 66, 4_344_647_195_749_500_666),
            (-1, BlockPosition(55, 64, -27), 66, 8_265_573_421_575_953_197),
            (123_456_789, BlockPosition(-216, 64, -36), 65, 8_805_434_323_613_044_292),
        ]
        for (seed, expected, height, nextRandom) in vectors {
            var generator = BetaTerrainGenerator(seed: seed)
            var world = BlockWorld(seed: seed)
            var random = JavaRandom(seed: 12345)
            let spawn = BetaSpawn.initialGlobal(world: &world, random: &random) {
                generator.generateChunk(x: $0.x, z: $0.z)
            }
            #expect(spawn == expected)
            #expect(random.nextLong() == nextRandom)
            let position = BetaSpawn.playerPosition(world: &world, spawn: spawn) {
                generator.generateChunk(x: $0.x, z: $0.z)
            }
            #expect(position == SIMD3(Double(expected.x) + 0.5, height, Double(expected.z) + 0.5))
            #expect(Player(position: position).eyePositionDouble.y == height + Double(Float(1.62)))
        }
    }

    @Test func respawnValidationMatchesOriginalRandomWalk() {
        var world = BlockWorld()
        var spawn = BlockPosition(-20, -1, 30)
        var random = JavaRandom(seed: 54321)
        BetaSpawn.adjustGlobal(world: &world, spawn: &spawn, random: &random) { position in
            var chunk = Chunk(position: position)
            for x in 0..<16 {
                for z in 0..<16 where ((position.x * 16 + x) * 31 + (position.z * 16 + z) * 17) & 15 == 5 {
                    chunk[x, 63, z] = BlockState(.stone)
                }
            }
            return chunk
        }
        #expect(spawn == BlockPosition(-16, 64, 37))
        #expect(random.nextLong() == 8_295_652_541_495_436_128)
    }

    @Test func spawnSearchPreservesLoadedChunks() {
        var world = BlockWorld()
        world[BlockPosition(0, 63, 0)] = .sand
        world.setBlock(BlockState(.wood, metadata: 2), at: BlockPosition(5, 70, 5))
        let revision = world.revision
        var random = JavaRandom(seed: 0)
        var originalRandom = random
        var loads = 0
        let spawn = BetaSpawn.initialGlobal(world: &world, random: &random) {
            loads += 1
            return Chunk(position: $0)
        }
        let position = BetaSpawn.playerPosition(world: &world, spawn: spawn) {
            loads += 1
            return Chunk(position: $0)
        }
        #expect(spawn == BlockPosition(0, 64, 0))
        #expect(position == SIMD3(0.5, 65, 0.5))
        #expect(random.nextLong() == originalRandom.nextLong())
        #expect(world.state(at: BlockPosition(5, 70, 5)) == BlockState(.wood, metadata: 2))
        #expect(world.revision == revision)
        #expect(loads == 0)
    }
}
