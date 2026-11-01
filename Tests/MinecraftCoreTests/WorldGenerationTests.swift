import Testing

@testable import MinecraftCore

// Golden outputs use the original client SHA1 43db9b498cb67058d2e12d394e6507722e71bb45.
// Regenerate with Tools/reference/TerrainParity.java and the locally imported client jar.

@Test func javaRandomMatchesOriginalSequences() {
    let vectors: [(Int64, [Int32], Int64, Double, Float, [Int])] = [
        (
            0, [-1_155_484_576, -723_955_400, 1_033_096_058], -7_261_648_964_369_397_258,
            0.30905056819970920, 0.117006600, [9, 12, 715_581_077]
        ),
        (
            1, [-1_155_869_325, 431_529_176, 1_761_283_695], 7_515_937_759_503_895_804,
            0.036235382150367700, 0.658867180, [8, 11, 13_136_569]
        ),
        (
            -1, [1_155_099_827, 1_887_904_451, 52_699_159], -8_337_289_232_527_761_815,
            0.60079546893296110, 0.399288476, [5, 0, 665_220_512]
        ),
        (
            123_456_789, [-1_442_945_365, -1_016_548_095, 1_962_592_967], 4_701_514_676_984_888_228,
            0.21659655710073045, 0.425489962, [7, 6, 771_983_441]
        ),
    ]
    for (seed, integers, long, double, float, bounded) in vectors {
        var random = JavaRandom(seed: seed)
        for expected in integers { #expect(random.nextInt() == expected) }
        #expect(random.nextLong() == long)
        #expect(abs(random.nextDouble() - double) < 0.0000000000000001)
        #expect(abs(random.nextFloat() - float) < 0.00000001)
        for (bound, expected) in zip([10, 16, 1_073_741_825], bounded) {
            #expect(random.nextInt(bound: bound) == expected)
        }
    }
}

@Test func betaNoiseMatchesOriginalClient() {
    let vectors: [(Int64, Double, [Double], [Double])] = [
        (
            0, 0.31013618881172744,
            [
                -1.6367463297779203, -1.5370367713838424, -1.5789872602243615,
                -1.4416627373397206, -1.5189860514692892, -1.4649947536338257,
            ],
            [
                2.4235507312072553, 2.4132976638292510, 2.4300069854589300,
                2.4195579755393903, 2.4356420175709466, 2.4250718303326320,
            ]
        ),
        (
            1, -0.11400422548893091,
            [
                2.0958309395522560, 2.4479482244546507, 2.4893288441101310,
                3.4362011509584580, 2.5355329893259180, 3.4976027199863610,
            ],
            [
                -0.23577751221367138, -0.23538932210111074, -0.32498522467401325,
                -0.32702439172517140, -0.41724534670517020, -0.42144919941097060,
            ]
        ),
        (
            -1, 0.085316055389252350,
            [
                -0.042892032192261900, -0.30159751974318830, -0.26712161236151677,
                -0.69742185007476040, -0.24324507815312557, -0.61486997354026220,
            ],
            [
                1.6887436220253869, 1.6664833520189180, 1.6234649099655203,
                1.6002279907315480, 1.5539468775615997, 1.5298243209306950,
            ]
        ),
        (
            123_456_789, -0.033614489219325860,
            [
                -0.62779262188723320, -0.93357225387283750, -0.91344114313946200,
                -1.6048066118299538, -0.83586028749720250, -1.5293189809519285,
            ],
            [
                -0.48161481372809150, -0.52165555353782380, -0.52981214468202250,
                -0.56693108715973010, -0.57764967269958250, -0.61166359377772440,
            ]
        ),
    ]
    for (seed, point, volume, plane) in vectors {
        var random = JavaRandom(seed: seed)
        let noise = BetaPerlinNoise(random: &random)
        #expect(abs(noise.sample(x: -30.5, y: 25.25, z: 42.75) - point) < 1e-14)
        random.setSeed(seed)
        let octaves = BetaOctaveNoise(random: &random, count: 4)
        let field = octaves.generate(
            x: -30.5, y: 25.25, z: 42.75, sizeX: 3, sizeY: 4, sizeZ: 2,
            scaleX: 0.03125, scaleY: 0.125, scaleZ: 0.03125)
        for (index, expected) in zip([0, 1, 5, 11, 17, 23], volume) {
            #expect(abs(field[index] - expected) < 1e-14)
        }
        let flat = octaves.generate(
            x: -30.5, y: 25.25, z: 42.75, sizeX: 3, sizeY: 1, sizeZ: 2,
            scaleX: 0.03125, scaleY: 0.125, scaleZ: 0.03125)
        for (actual, expected) in zip(flat, plane) { #expect(abs(actual - expected) < 1e-14) }
    }
}

@Test func betaClimateMatchesOriginalClient() {
    let vectors: [(Int64, Double, Double, BetaBiome, Double, Double, BetaBiome)] = [
        (
            0, 0.97187390228152120, 0.57612321419059830, .forest,
            0.98423300437605970, 0.54214523655296480, .seasonalForest
        ),
        (
            1, 0.98438886470578920, 0.00048458850420641270, .desert,
            0.97170573260207950, 0.13366338290609947, .desert
        ),
        (
            -1, 0.77040336793980300, 0.29994377923256420, .shrubland,
            0.84149419347573200, 0.49274456129846980, .forest
        ),
        (
            123_456_789, 0.68446676548343290, 0.11216592644823242, .savanna,
            0.64718188189239620, 0.20477092578544360, .savanna
        ),
    ]
    for (seed, firstTemp, firstHumidity, firstBiome, lastTemp, lastHumidity, lastBiome) in vectors {
        let samples = BetaClimateSource(seed: seed).region(x: -32, z: 48)
        #expect(abs(samples[0].temperature - firstTemp) < 1e-14)
        #expect(abs(samples[0].humidity - firstHumidity) < 1e-14)
        #expect(samples[0].biome == firstBiome)
        #expect(abs(samples[255].temperature - lastTemp) < 1e-14)
        #expect(abs(samples[255].humidity - lastHumidity) < 1e-14)
        #expect(samples[255].biome == lastBiome)
    }
}

@Test func betaTerrainMatchesOriginalClientChunks() {
    let vectors: [(Int64, [UInt64])] = [
        (0, [0x6011_7da3_9304_52a2, 0xe8b8_7348_6629_4c4e, 0xba8b_9e85_8794_ede9, 0x3ec1_3492_7c58_cf80]),
        (1, [0x1457_c414_99ba_e68e, 0xe45c_e116_18f5_6620, 0x4828_db8f_162f_6902, 0xa0fd_f9b0_b909_59c3]),
        (-1, [0xdc3b_1de8_dede_ad47, 0xbbaa_7705_9416_a121, 0xb3e3_8cbd_4c55_a435, 0xfa97_7c19_42ac_4de1]),
        (
            123_456_789,
            [0x0118_a025_6ca6_8952, 0x8661_ce98_51dd_af25, 0xc2e3_8205_68fd_1345, 0x584d_2a8e_97ce_4756]
        ),
    ]
    for (seed, hashes) in vectors {
        var generator = BetaTerrainGenerator(seed: seed)
        for ((x, z), expected) in zip([(0, 0), (1, -2), (-7, 9), (100, 100)], hashes) {
            let chunk = generator.generateChunk(x: x, z: z)
            let hash = chunk.blockIDs.reduce(UInt64(0xcbf2_9ce4_8422_2325)) {
                ($0 ^ UInt64($1)) &* 0x100_0000_01b3
            }
            #expect(hash == expected, "seed \(seed), chunk \(x),\(z): \(String(hash, radix: 16))")
        }
    }
}

@Test func betaPopulationMatchesOriginalWorld() {
    let vectors: [(Int64, [UInt64])] = [
        (0, [0xa276_d880_efbf_0196, 0x2b71_2738_9311_fc4a, 0xf9df_f33d_2645_5541, 0xf214_a80c_50b5_407d]),
        (1, [0xe2f9_c3e9_fc7a_af54, 0x769f_faf0_c777_25e1, 0x6a52_83ec_aa26_26d8, 0x1812_9441_e708_fb54]),
        (-1, [0x9ff8_f5c9_f88a_ce9b, 0xb9ec_3a5c_3846_3f94, 0x046c_0f15_0c23_ec0e, 0x1f49_e483_93ae_e64e]),
        (
            123_456_789,
            [0x44c2_bb3c_cb0b_70d6, 0xbbef_9d7e_40d6_64fc, 0x7e9c_a131_eee1_e846, 0xa679_5cce_d26e_c4cf]
        ),
        (95, [0x69ef_bb5e_c86d_4c04, 0xa949_ce52_c34a_650b, 0x0b33_4744_2e76_e7f5, 0x62e8_c126_0482_fcf5]),
    ]
    for (seed, hashes) in vectors {
        var generator = BetaTerrainGenerator(seed: seed)
        var world = BlockWorld(seed: seed)
        generator.populate(world: &world, chunkX: 0, chunkZ: 0)
        for ((x, z), expected) in zip([(0, 0), (0, 1), (1, 0), (1, 1)], hashes) {
            let blocks = world.chunks[ChunkPosition(x: x, z: z)]!.blockIDs
            let hash = blocks.reduce(UInt64(0xcbf2_9ce4_8422_2325)) { ($0 ^ UInt64($1)) &* 0x100_0000_01b3 }
            #expect(hash == expected, "population seed \(seed), chunk \(x),\(z): \(String(hash, radix: 16))")
        }
        if seed == 95 {
            var firstChest = [ItemStack?](repeating: nil, count: 27)
            firstChest[2] = ItemStack(id: 351, damage: 3)
            firstChest[3] = ItemStack(id: 329)
            firstChest[13] = ItemStack(id: 289)
            firstChest[14] = ItemStack(id: 297)
            firstChest[20] = ItemStack(id: 287)
            #expect(world.blockEntity(at: BlockPosition(22, 28, 13)) == .chest(slots: firstChest))
            var secondChest = [ItemStack?](repeating: nil, count: 27)
            secondChest[0] = ItemStack(id: 265, count: 3)
            secondChest[5] = ItemStack(id: 287, count: 3)
            secondChest[6] = ItemStack(id: 265, count: 2)
            secondChest[9] = ItemStack(id: 331, count: 3)
            secondChest[10] = ItemStack(id: 265, count: 4)
            secondChest[19] = ItemStack(id: 329)
            secondChest[23] = ItemStack(id: 325)
            #expect(world.blockEntity(at: BlockPosition(22, 28, 14)) == .chest(slots: secondChest))
            #expect(world.blockEntity(at: BlockPosition(23, 28, 11)) == .spawner(mobID: "Zombie", delay: 20))
        }
        let revision = world.revision
        generator.populate(world: &world, chunkX: 0, chunkZ: 0)
        #expect(world.revision == revision)
    }
}
