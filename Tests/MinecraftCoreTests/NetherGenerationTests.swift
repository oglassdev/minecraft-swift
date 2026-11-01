import MinecraftCore
import Testing

@Test func netherTerrainMatchesOriginalClient() {
    let vectors: [(Int64, [UInt64])] = [
        (0, [0x937b_e707_f745_634a, 0xf18e_8353_e8b3_16a6, 0x2c65_4b6b_b673_4cec, 0xf3f5_e707_05ff_8a35]),
        (1, [0xce1f_ae06_d52e_329c, 0xf3ac_3f12_034d_16fb, 0xf179_920d_3551_47b9, 0x9985_7d43_65a8_f4f9]),
        (-1, [0xba3b_5d4c_5da2_8c51, 0x37ce_abbc_4caf_6bf9, 0xdc17_e1c1_6876_5bf3, 0x0088_02b4_e2d1_ebd1]),
        (
            123_456_789,
            [0x4150_df16_c1ee_325e, 0xe3e9_27f7_00fe_65dc, 0x1ad2_8b6b_c388_2fff, 0x0ac9_9298_b6e4_1159]
        ),
    ]
    for (seed, hashes) in vectors {
        var generator = BetaNetherGenerator(seed: seed)
        for ((x, z), expected) in zip([(0, 0), (1, -2), (-7, 9), (100, 100)], hashes) {
            let chunk = generator.generateChunk(x: x, z: z)
            let hash = chunk.blockIDs.reduce(UInt64(0xcbf2_9ce4_8422_2325)) {
                ($0 ^ UInt64($1)) &* 0x100_0000_01b3
            }
            #expect(hash == expected, "Nether seed \(seed), chunk \(x),\(z): \(String(hash, radix: 16))")
            #expect(chunk.skyLight.allSatisfy { $0 == 0 })
            for bx in 0..<16 {
                for bz in 0..<16 {
                    #expect(chunk[bx, 0, bz]?.kind == .bedrock)
                    #expect(chunk[bx, 127, bz]?.kind == .bedrock)
                }
            }
        }
    }
}

@Test func netherPopulationMatchesOriginalWorld() {
    let vectors: [(Int64, [UInt64])] = [
        (0, [0x937b_e707_f745_634a, 0x060f_06aa_1115_e0a7, 0xf3a7_286a_8c53_38d4, 0x6856_9fb9_8d14_0f57]),
        (1, [0x5ccc_aa63_dce8_e66f, 0x7073_8d49_9a94_ea54, 0x425a_09ca_e005_5b7e, 0xbb47_a2ca_89c5_8aab]),
        (-1, [0xba3b_5d4c_5da2_8c51, 0x9afc_2cbc_dcdd_27a0, 0xa4ce_1c79_4ccc_cc7c, 0x6925_31b1_4693_5a7d]),
        (
            123_456_789,
            [0x4150_df16_c1ee_325e, 0xa233_854d_5c62_70eb, 0x83b6_f5b6_b7cc_1039, 0x273c_0136_a804_2257]
        ),
    ]
    for (seed, hashes) in vectors {
        var generator = BetaNetherGenerator(seed: seed)
        var world = BlockWorld(seed: seed, dimension: -1)
        for x in -1...2 {
            for z in -1...2 { world.setChunk(generator.generateChunk(x: x, z: z)) }
        }
        generator.populate(world: &world, chunkX: 0, chunkZ: 0)
        for ((x, z), expected) in zip([(0, 0), (0, 1), (1, 0), (1, 1)], hashes) {
            let blocks = world.chunks[ChunkPosition(x: x, z: z)]!.blockIDs
            let hash = blocks.reduce(UInt64(0xcbf2_9ce4_8422_2325)) { ($0 ^ UInt64($1)) &* 0x100_0000_01b3 }
            #expect(
                hash == expected,
                "Nether population seed \(seed), chunk \(x),\(z): \(String(hash, radix: 16))")
            let metadata = world.chunks[ChunkPosition(x: x, z: z)]!.metadata
            let metadataHash = metadata.reduce(UInt64(0xcbf2_9ce4_8422_2325)) {
                ($0 ^ UInt64($1)) &* 0x100_0000_01b3
            }
            let expectedMetadata: UInt64 =
                seed == 1 && z == 0
                ? (x == 0 ? 0xa8b6_3925_f3e7_7bc4 : 0xa912_7aa6_7c1b_1cf4) : 0x8f69_55bf_94ec_2325
            #expect(metadataHash == expectedMetadata)
        }
        let revision = world.revision
        generator.populate(world: &world, chunkX: 0, chunkZ: 0)
        #expect(world.revision == revision)
    }
}

@Test func farLandsMatchesOriginalClient() {
    let vectors: [(Int, Int, UInt64, UInt64)] = [
        (784425, 0, 0xc286_3760_3ef8_6fb6, 0x08cb_0537_682f_ab5d),
        (784426, 0, 0x6b10_8ecb_3ca0_7d76, 0xc38a_de19_908f_6c9b),
        (784427, 0, 0x2f6e_5666_482e_b4f7, 0xe4b1_35d1_5e86_32f0),
        (-784426, 0, 0xf76a_f06f_8ee7_f729, 0x3cf4_79a2_703e_eb4d),
        (-784427, 0, 0x61d4_0385_7b0a_cd77, 0xa2dd_e468_5a98_f762),
        (0, 784426, 0xfbc2_c61d_73b8_6594, 0xc6ac_aa24_9ac4_dd2d),
        (0, -784427, 0xb9bf_8a28_5734_e267, 0x319a_c276_3e4f_80db),
        (784426, 784426, 0xe1d2_3bff_48b3_2084, 0x9cbc_e7e0_26a3_0d98),
    ]
    var overworld = BetaTerrainGenerator(seed: 0)
    var nether = BetaNetherGenerator(seed: 0)
    for (x, z, expectedOverworld, expectedNether) in vectors {
        for (chunk, expected) in [
            (overworld.generateChunk(x: x, z: z), expectedOverworld),
            (nether.generateChunk(x: x, z: z), expectedNether),
        ] {
            let hash = chunk.blockIDs.reduce(UInt64(0xcbf2_9ce4_8422_2325)) {
                ($0 ^ UInt64($1)) &* 0x100_0000_01b3
            }
            #expect(hash == expected, "Far Lands chunk \(x),\(z): \(String(hash, radix: 16))")
        }
    }
}

@Test func portalCreationMatchesOriginalTeleporter() {
    let vectors: [(SIMD3<Double>, SIMD3<Double>, UInt64, Int64)] = [
        (SIMD3(0.25, 65, -0.25), SIMD3(0.5, 64.5, -1), 0x30e3_e67d_db2a_8045, -3_109_364_765_729_502_342),
        (SIMD3(15.6, 40, 15.6), SIMD3(15.5, 70.5, 16), 0x4af5_4a5f_20b4_1b9d, 1_853_403_699_951_111_791),
        (
            SIMD3(-15.6, 125, -15.6), SIMD3(-15.5, 118.5, -15), 0xf8ee_80e0_4872_7a07,
            5_411_842_376_618_821_008
        ),
        (SIMD3(0.25, 65, -0.25), SIMD3(0.5, 64.5, 0), 0x136e_b859_4e3f_6d4d, -8_072_133_231_410_116_475),
    ]
    for (index, vector) in vectors.enumerated() {
        var world = BlockWorld(seed: 0, dimension: -1)
        for cx in -2...2 {
            for cz in -2...2 {
                var chunk = Chunk(position: ChunkPosition(cx, cz))
                for x in 0..<16 {
                    for z in 0..<16 {
                        for y in 0..<(index == 0 ? 64 : 128) {
                            if index == 3 && cx * 16 + x == 0 && (64..<68).contains(y) { continue }
                            chunk[x, y, z] = BlockState(index == 0 ? .stone : .netherrack)
                        }
                    }
                }
                world.setChunk(chunk)
            }
        }
        var random = JavaRandom(seed: Int64(index))
        let result = BetaPortalTravel.place(world: &world, near: vector.0, yaw: 15, random: &random)
        #expect(result == vector.1)
        #expect(random.nextLong() == vector.3)
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for cx in -1...1 {
            for cz in -1...1 {
                for block in world.chunks[ChunkPosition(cx, cz)]!.blockIDs {
                    hash = (hash ^ UInt64(block)) &* 0x100_0000_01b3
                }
            }
        }
        #expect(hash == vector.2, "Portal fixture \(index): \(String(hash, radix: 16))")
        #expect(world.chunks.count == 25)
        let revision = world.revision
        #expect(BetaPortalTravel.place(world: &world, near: vector.0, yaw: 15, random: &random) == result)
        #expect(world.revision == revision)
    }
    var unloaded = BlockWorld()
    #expect(BetaPortalTravel.place(world: &unloaded, near: SIMD3(0, 60, 0), yaw: 0) == SIMD3(0, 60, 0))
    #expect(unloaded.chunks.isEmpty)
    unloaded.setChunk(Chunk(position: ChunkPosition(0, 0)))
    let revision = unloaded.revision
    #expect(BetaPortalTravel.place(world: &unloaded, near: SIMD3(8, 40, 0), yaw: 0) == SIMD3(8, 40, 0))
    #expect(unloaded.revision == revision)
}
