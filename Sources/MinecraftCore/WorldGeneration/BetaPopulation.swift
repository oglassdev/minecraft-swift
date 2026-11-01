extension BetaTerrainGenerator {
    /// Populate once, after the surrounding base chunks exist; features cross chunk boundaries.
    @discardableResult
    public mutating func populate(world: inout BlockWorld, chunkX: Int, chunkZ: Int) -> BetaPopulationResult {
        let position = ChunkPosition(x: chunkX, z: chunkZ)
        if world.chunks[position]?.isTerrainPopulated == true { return BetaPopulationResult() }
        for x in (chunkX - 1)...(chunkX + 2) {
            for z in (chunkZ - 1)...(chunkZ + 2) where world.chunks[ChunkPosition(x: x, z: z)] == nil {
                world.setChunk(generateChunk(x: x, z: z))
            }
        }
        let x = chunkX * 16
        let z = chunkZ * 16
        let biome = climate.sample(x: x + 16, z: z + 16).biome
        var random = JavaRandom(seed: seed)
        let xSeed = random.nextLong() / 2 * 2 + 1
        let zSeed = random.nextLong() / 2 * 2 + 1
        random.setSeed((Int64(chunkX) &* xSeed &+ Int64(chunkZ) &* zSeed) ^ seed)
        var result = BetaPopulationResult()
        if random.nextInt(bound: 4) == 0 {
            let px = x + random.nextInt(bound: 16) + 8
            let py = random.nextInt(bound: 128)
            let pz = z + random.nextInt(bound: 16) + 8
            BetaPopulationFeatures.lake(
                .stillWater, at: BlockPosition(px, py, pz), world: &world, random: &random)
        }
        if random.nextInt(bound: 8) == 0 {
            let px = x + random.nextInt(bound: 16) + 8
            let bound = random.nextInt(bound: 120) + 8
            let py = random.nextInt(bound: bound)
            let pz = z + random.nextInt(bound: 16) + 8
            if py < 64 || random.nextInt(bound: 10) == 0 {
                BetaPopulationFeatures.lake(
                    .stillLava, at: BlockPosition(px, py, pz), world: &world, random: &random)
            }
        }
        for _ in 0..<8 {
            let px = x + random.nextInt(bound: 16) + 8
            let py = random.nextInt(bound: 128)
            let pz = z + random.nextInt(bound: 16) + 8
            BetaDungeons.generate(
                at: BlockPosition(px, py, pz), world: &world, random: &random, result: &result)
        }
        let ores: [(BlockKind, Int, Int, Int)] = [
            (.clay, 10, 32, 128), (.dirt, 20, 32, 128), (.gravel, 10, 32, 128), (.coalOre, 20, 16, 128),
            (.ironOre, 20, 8, 64), (.goldOre, 2, 8, 32), (.redstoneOre, 8, 7, 16), (.diamondOre, 1, 7, 16),
            (.lapisOre, 1, 6, 16),
        ]
        for (block, attempts, size, maximumY) in ores {
            for _ in 0..<attempts {
                let px = x + random.nextInt(bound: 16)
                var py = random.nextInt(bound: maximumY)
                if block == .lapisOre { py += random.nextInt(bound: 16) }
                let pz = z + random.nextInt(bound: 16)
                BetaPopulationFeatures.ore(
                    block, size: size, at: BlockPosition(px, py, pz), world: &world,
                    random: &random, clay: block == .clay)
            }
        }
        let density = Int(
            (treeNoise.sample(x: Double(x) * 0.5, z: Double(z) * 0.5) / 8
                + random.nextDouble() * 4 + 4) / 3)
        var trees = random.nextInt(bound: 10) == 0 ? 1 : 0
        switch biome {
        case .forest, .rainforest, .taiga: trees += density + 5
        case .seasonalForest: trees += density + 2
        case .desert, .tundra, .plains: trees -= 20
        default: break
        }
        if trees > 0 {
            for _ in 0..<trees {
                let px = x + random.nextInt(bound: 16) + 8
                let pz = z + random.nextInt(bound: 16) + 8
                let kind: BetaTreeKind
                if biome == .forest {
                    if random.nextInt(bound: 5) == 0 {
                        kind = .birch
                    } else {
                        kind = random.nextInt(bound: 3) == 0 ? .bigOak : .oak
                    }
                } else if biome == .taiga {
                    kind = random.nextInt(bound: 3) == 0 ? .pine : .spruce
                } else if biome == .rainforest {
                    kind = random.nextInt(bound: 3) == 0 ? .bigOak : .oak
                } else {
                    kind = random.nextInt(bound: 10) == 0 ? .bigOak : .oak
                }
                let py = BetaPopulationFeatures.height(world, x: px, z: pz)
                BetaTrees.generate(kind, at: BlockPosition(px, py, pz), world: &world, random: &random)
            }
        }
        let flowers: Int
        switch biome {
        case .forest, .taiga: flowers = 2
        case .seasonalForest: flowers = 4
        case .plains: flowers = 3
        default: flowers = 0
        }
        for _ in 0..<flowers {
            let px = x + random.nextInt(bound: 16) + 8
            let py = random.nextInt(bound: 128)
            let pz = z + random.nextInt(bound: 16) + 8
            BetaPopulationFeatures.plant(
                .dandelion, at: BlockPosition(px, py, pz), world: &world, random: &random)
        }
        let grasses: Int
        switch biome {
        case .forest, .seasonalForest: grasses = 2
        case .rainforest, .plains: grasses = 10
        case .taiga: grasses = 1
        default: grasses = 0
        }
        for _ in 0..<grasses {
            let metadata: UInt8 = biome == .rainforest && random.nextInt(bound: 3) != 0 ? 2 : 1
            let px = x + random.nextInt(bound: 16) + 8
            let py = random.nextInt(bound: 128)
            let pz = z + random.nextInt(bound: 16) + 8
            BetaPopulationFeatures.plant(
                .tallGrass, metadata: metadata, at: BlockPosition(px, py, pz),
                world: &world, random: &random)
        }
        if biome == .desert {
            for _ in 0..<2 {
                let px = x + random.nextInt(bound: 16) + 8
                let py = random.nextInt(bound: 128)
                let pz = z + random.nextInt(bound: 16) + 8
                BetaPopulationFeatures.plant(
                    .deadBush, at: BlockPosition(px, py, pz), world: &world, random: &random)
            }
        }
        for (block, chance) in [(BlockKind.rose, 2), (.brownMushroom, 4), (.redMushroom, 8)] {
            if random.nextInt(bound: chance) == 0 {
                let px = x + random.nextInt(bound: 16) + 8
                let py = random.nextInt(bound: 128)
                let pz = z + random.nextInt(bound: 16) + 8
                BetaPopulationFeatures.plant(
                    block, at: BlockPosition(px, py, pz), world: &world, random: &random)
            }
        }
        for _ in 0..<10 {
            let px = x + random.nextInt(bound: 16) + 8
            let py = random.nextInt(bound: 128)
            let pz = z + random.nextInt(bound: 16) + 8
            BetaPopulationFeatures.reeds(at: BlockPosition(px, py, pz), world: &world, random: &random)
        }
        if random.nextInt(bound: 32) == 0 {
            let px = x + random.nextInt(bound: 16) + 8
            let py = random.nextInt(bound: 128)
            let pz = z + random.nextInt(bound: 16) + 8
            BetaPopulationFeatures.pumpkins(at: BlockPosition(px, py, pz), world: &world, random: &random)
        }
        if biome == .desert {
            for _ in 0..<10 {
                let px = x + random.nextInt(bound: 16) + 8
                let py = random.nextInt(bound: 128)
                let pz = z + random.nextInt(bound: 16) + 8
                BetaPopulationFeatures.cactus(at: BlockPosition(px, py, pz), world: &world, random: &random)
            }
        }
        for _ in 0..<50 {
            let px = x + random.nextInt(bound: 16) + 8
            let bound = random.nextInt(bound: 120) + 8
            let py = random.nextInt(bound: bound)
            let pz = z + random.nextInt(bound: 16) + 8
            BetaPopulationFeatures.spring(.water, at: BlockPosition(px, py, pz), world: &world)
        }
        for _ in 0..<20 {
            let px = x + random.nextInt(bound: 16) + 8
            let firstBound = random.nextInt(bound: 112) + 8
            let secondBound = random.nextInt(bound: firstBound) + 8
            let py = random.nextInt(bound: secondBound)
            let pz = z + random.nextInt(bound: 16) + 8
            BetaPopulationFeatures.spring(.lava, at: BlockPosition(px, py, pz), world: &world)
        }
        let samples = climate.region(x: x + 8, z: z + 8)
        for px in (x + 8)..<(x + 24) {
            for pz in (z + 8)..<(z + 24) {
                let py = BetaPopulationFeatures.height(world, x: px, z: pz, precipitation: true)
                let temperature =
                    samples[(px - x - 8) * 16 + pz - z - 8].temperature
                    - Double(py - 64) / 64 * 0.3
                if temperature < 0.5 && py > 0 && py < 128 && world[BlockPosition(px, py, pz)] == nil {
                    let below = world[BlockPosition(px, py - 1, pz)]
                    if BetaPopulationFeatures.solid(below) && below != .ice {
                        world[BlockPosition(px, py, pz)] = .snowLayer
                    }
                }
            }
        }
        for (position, slots) in result.chests { world.setBlockEntity(.chest(slots: slots), at: position) }
        for (position, mobID) in result.spawners {
            world.setBlockEntity(.spawner(mobID: mobID, delay: 20), at: position)
        }
        world.markChunkPopulated(at: position)
        return result
    }
}
