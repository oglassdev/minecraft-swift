import MinecraftCore
import Testing

@Test func lightCrossesChunkBoundaryAndClearsRemovedSources() {
    var world = BlockWorld()
    world.setChunk(Chunk(position: ChunkPosition(0, 0)))
    world.setChunk(Chunk(position: ChunkPosition(1, 0)))
    world[BlockPosition(15, 50, 4)] = .torch
    WorldLighting.rebuild(world: &world)
    #expect(world.light(at: BlockPosition(16, 50, 4)).block == 13)
    world[BlockPosition(15, 50, 4)] = nil
    WorldLighting.rebuild(world: &world)
    #expect(world.light(at: BlockPosition(16, 50, 4)).block == 0)
}

@Test func sunlightIsBlockedByRoofAndAttenuatesThroughWater() {
    var world = BlockWorld()
    var chunk = Chunk(position: ChunkPosition(0, 0))
    for x in 0..<16 {
        for z in 0..<16 { chunk[x, 70, z] = BlockState(.stone) }
    }
    chunk[0, 70, 0] = BlockState(.stillWater)
    world.setChunk(chunk)
    WorldLighting.rebuild(world: &world)
    #expect(world.light(at: BlockPosition(8, 71, 8)).sky == 15)
    #expect(world.light(at: BlockPosition(8, 69, 8)).sky == 0)
    #expect(world.light(at: BlockPosition(0, 70, 0)).sky == 12)
    #expect(world.light(at: BlockPosition(0, 69, 0)).sky == 11)
}

@Test func settledLightingMatchesOriginalBetaWorld() {
    var world = lightingReferenceWorld()
    let sources: [(BlockPosition, BlockKind)] = [
        (BlockPosition(15, 50, 8), .torch),
        (BlockPosition(8, 50, 8), .glowstone),
        (BlockPosition(23, 50, 8), .stillLava),
    ]
    // Captured by Tools/reference/LightingParity.java using the original World light-update queue.
    let expected: [[(sky: UInt64, block: UInt64)]] = [
        [(0x33f1_f453_fc9c_24d0, 0x8f69_55bf_94ec_2325), (0x4e7e_b189_a6f5_1200, 0x8f69_55bf_94ec_2325)],
        [(0x86c1_8620_436f_7a1f, 0x377c_d71b_70f7_fc8f), (0xb05f_5115_2466_5bb2, 0xfe1e_e7e9_9ceb_c401)],
        [(0xba71_4962_df79_e794, 0x8f69_55bf_94ec_2325), (0xb23a_d11a_8497_6601, 0x8f69_55bf_94ec_2325)],
    ]
    for stage in expected.indices {
        if stage == 1 {
            for (position, kind) in sources {
                world[BlockPosition(position.x, position.y - 1, position.z)] = .stone
                world[position] = kind
            }
        } else if stage == 2 {
            for (position, _) in sources { world[position] = nil }
        }
        WorldLighting.rebuild(world: &world)
        for x in 0...1 {
            let chunk = world.chunks[ChunkPosition(x, 0)]!
            #expect(lightHash(chunk.skyLight) == expected[stage][x].sky)
            #expect(lightHash(chunk.blockLight) == expected[stage][x].block)
        }
    }
    #expect(world.light(at: BlockPosition(4, 70, 8)).sky == 14)
    #expect(world.light(at: BlockPosition(4, 69, 8)).sky == 13)
    #expect(world.light(at: BlockPosition(12, 70, 8)).sky == 12)
    #expect(world.light(at: BlockPosition(12, 69, 8)).sky == 11)
    #expect(world.light(at: BlockPosition(20, 70, 8)).sky == 12)
    #expect(world.light(at: BlockPosition(28, 70, 8)).sky == 14)
}

@Test func netherLightingMatchesOriginalBetaWorldWithoutSkylight() {
    var world = lightingReferenceWorld(dimension: -1)
    for (position, kind) in [
        (BlockPosition(15, 50, 8), BlockKind.torch),
        (BlockPosition(8, 50, 8), .glowstone),
        (BlockPosition(23, 50, 8), .stillLava),
    ] {
        world[BlockPosition(position.x, position.y - 1, position.z)] = .stone
        world[position] = kind
    }
    WorldLighting.rebuild(world: &world)
    #expect(world.chunks.values.allSatisfy { $0.skyLight.allSatisfy { $0 == 0 } })
    #expect(lightHash(world.chunks[ChunkPosition(0, 0)]!.blockLight) == 0x377c_d71b_70f7_fc8f)
    #expect(lightHash(world.chunks[ChunkPosition(1, 0)]!.blockLight) == 0xfe1e_e7e9_9ceb_c401)
}

@Test func localizedLightingMatchesFullRebuildAtCornerWithOutsideBoundarySources() {
    var world = BlockWorld()
    for x in -3...3 {
        for z in -2...2 {
            var chunk = Chunk(position: ChunkPosition(x, z))
            for localX in 0..<16 {
                for localZ in 0..<16 { chunk[localX, 70, localZ] = BlockState(.stone) }
            }
            world.setChunk(chunk, updateLighting: false)
        }
    }
    let source = BlockPosition(15, 50, 15)
    let roof = BlockPosition(15, 70, 15)
    world[source] = .torch
    world[BlockPosition(32, 50, 8)] = .torch
    world[BlockPosition(32, 70, 8)] = nil
    WorldLighting.rebuild(world: &world)
    let farPosition = ChunkPosition(3, 2)
    let far = world.chunks[farPosition]!
    let farRevision = world.chunkRevisions[farPosition]
    let stages: [(BlockKind?, BlockKind?)] = [(nil, nil), (.glowstone, .stone), (nil, .stillWater)]
    for (block, covering) in stages {
        world[source] = block
        world[roof] = covering
        var full = world
        WorldLighting.rebuild(world: &full)
        WorldLighting.rebuild(world: &world, changedChunks: [ChunkPosition(0, 0)])
        for position in world.chunks.keys {
            #expect(world.chunks[position]!.skyLight == full.chunks[position]!.skyLight)
            #expect(world.chunks[position]!.blockLight == full.chunks[position]!.blockLight)
        }
        #expect(world.light(at: BlockPosition(31, 50, 8)).sky == 14)
        #expect(world.light(at: BlockPosition(31, 50, 8)).block == 13)
        #expect(world.chunks[farPosition]!.skyLight == far.skyLight)
        #expect(world.chunks[farPosition]!.blockLight == far.blockLight)
        #expect(world.chunkRevisions[farPosition] == farRevision)
    }
    #expect(world.light(at: roof).sky == 12)
    #expect(world.light(at: BlockPosition(15, 69, 15)).sky == 11)
}

@Test func localizedNetherRelightPreservesOutsideEmitterAndLeavesFarChunksAlone() {
    var world = BlockWorld(dimension: -1)
    for x in -2...3 { world.setChunk(Chunk(position: ChunkPosition(x, 0)), updateLighting: false) }
    world[BlockPosition(15, 50, 8)] = .glowstone
    world[BlockPosition(32, 50, 8)] = .torch
    WorldLighting.rebuild(world: &world)
    let farPosition = ChunkPosition(3, 0)
    let farRevision = world.chunkRevisions[farPosition]
    world[BlockPosition(15, 50, 8)] = nil
    var full = world
    WorldLighting.rebuild(world: &full)
    WorldLighting.rebuild(world: &world, changedChunks: [ChunkPosition(0, 0)])
    for position in world.chunks.keys {
        #expect(world.chunks[position]!.skyLight == full.chunks[position]!.skyLight)
        #expect(world.chunks[position]!.blockLight == full.chunks[position]!.blockLight)
    }
    #expect(world.light(at: BlockPosition(31, 50, 8)).block == 13)
    #expect(world.light(at: BlockPosition(15, 50, 8)).block == 0)
    #expect(world.chunks.values.allSatisfy { $0.skyLight.allSatisfy { $0 == 0 } })
    #expect(world.chunkRevisions[farPosition] == farRevision)
    let unchangedRevision = world.revision
    WorldLighting.rebuild(world: &world, changedChunks: [])
    #expect(world.revision == unchangedRevision)
}

private func lightingReferenceWorld(dimension: Int8 = 0) -> BlockWorld {
    var world = BlockWorld(dimension: dimension)
    for x in -1...2 {
        for z in -1...1 {
            var chunk = Chunk(position: ChunkPosition(x, z))
            for localX in 0..<16 {
                for localZ in 0..<16 { chunk[localX, 0, localZ] = BlockState(.bedrock) }
            }
            world.setChunk(chunk, updateLighting: false)
        }
    }
    for x in 0..<32 {
        for z in 0..<16 { world[BlockPosition(x, 70, z)] = .stone }
    }
    let materials: [BlockKind] = [.leaves, .stillWater, .ice, .cobweb]
    for panel in materials.indices {
        for x in (2 + panel * 8)...(6 + panel * 8) {
            for z in 6...10 { world[BlockPosition(x, 70, z)] = materials[panel] }
        }
    }
    return world
}

private func lightHash(_ values: [UInt8]) -> UInt64 {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for value in values { hash = (hash ^ UInt64(value)) &* 0x100_0000_01b3 }
    return hash
}
