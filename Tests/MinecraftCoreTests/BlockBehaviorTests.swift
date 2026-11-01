import Testing

@testable import MinecraftCore

@Suite struct BlockBehaviorTests {
    private let distantPlayer = AxisAlignedBox(min: SIMD3(30, 1, 30), max: SIMD3(30.6, 2.8, 30.6))

    private func world(seed: Int64 = 1, dimension: Int8 = 0) -> BlockWorld {
        var world = BlockWorld(seed: seed, dimension: dimension)
        for x in -1...1 {
            for z in -1...1 { world.setChunk(Chunk(position: ChunkPosition(x, z))) }
        }
        for x in 2...14 {
            for z in 2...14 { world[BlockPosition(x, 0, z)] = .stone }
        }
        return world
    }

    private func hit(_ p: BlockPosition, face: BlockPosition = BlockPosition(0, 1, 0)) -> BlockHit {
        BlockHit(position: p, face: face, distance: 1, point: p.center)
    }

    @Test func farmingUsesSoilSeedsAndBoneMeal() {
        var world = world()
        let soil = BlockPosition(8, 0, 8)
        let crop = BlockPosition(8, 1, 8)
        world[soil] = .dirt
        let hoed = BlockInteractions.use(
            hit: hit(soil), holding: ItemStack(id: 290), yaw: 0,
            playerBounds: distantPlayer, world: &world)
        #expect(hoed.handled && hoed.durabilityDamage == 1)
        #expect(world[soil] == .farmland)
        let planted = BlockInteractions.use(
            hit: hit(soil), holding: ItemStack(id: 295), yaw: 0,
            playerBounds: distantPlayer, world: &world)
        #expect(planted.consumed == 1 && world[crop] == .wheat)
        let grown = BlockInteractions.use(
            hit: hit(crop), holding: ItemStack(id: 351, damage: 15), yaw: 0,
            playerBounds: distantPlayer, world: &world)
        #expect(grown.consumed == 1 && world.state(at: crop)?.metadata == 7)
    }

    @Test func bucketsOnlyCollectSourcesAndReturnTheCorrectContainer() {
        var world = world()
        let p = BlockPosition(8, 1, 8)
        world.setBlock(BlockState(.water, metadata: 1), at: p)
        let missed = BlockInteractions.use(
            hit: hit(p), holding: ItemStack(id: 325), yaw: 0,
            playerBounds: distantPlayer, world: &world)
        #expect(!missed.handled)
        world.setBlock(BlockState(.stillWater), at: p)
        let filled = BlockInteractions.use(
            hit: hit(p), holding: ItemStack(id: 325), yaw: 0,
            playerBounds: distantPlayer, world: &world)
        #expect(filled.replaceHeldStack && filled.replacement?.id == 326 && world[p] == nil)
        let poured = BlockInteractions.use(
            hit: hit(BlockPosition(8, 0, 8)), holding: filled.replacement, yaw: 0,
            playerBounds: distantPlayer, world: &world)
        #expect(poured.replacement?.id == 325 && world[p] == .water)
    }

    @Test func woodenDoorsShareTheirOpenStateAndLoseUnsupportedPairs() {
        var world = world()
        let base = BlockPosition(8, 1, 8)
        let top = BlockPosition(8, 2, 8)
        let placed = BlockInteractions.use(
            hit: hit(BlockPosition(8, 0, 8)), holding: ItemStack(id: 324), yaw: 0,
            playerBounds: distantPlayer, world: &world)
        #expect(placed.consumed == 1)
        #expect(world.state(at: base)?.metadata == 3 && world.state(at: top)?.metadata == 11)
        _ = BlockInteractions.use(
            hit: hit(top), holding: nil, yaw: 0,
            playerBounds: distantPlayer, world: &world)
        #expect(world.state(at: base)?.metadata == 7 && world.state(at: top)?.metadata == 15)
        world[BlockPosition(8, 0, 8)] = nil
        var simulation = BlockSimulation(seed: 1)
        let events = simulation.blockChanged(at: BlockPosition(8, 0, 8), world: &world, time: 0)
        #expect(world[base] == nil && world[top] == nil)
        #expect(
            events.contains {
                if case .dropItem(_, let stack) = $0 { return stack.id == 324 }
                return false
            })
    }

    @Test func waterFlowsOnItsFifthTickAndLavaMixesByLevel() {
        var world = world()
        let source = BlockPosition(8, 1, 8)
        world[source] = .water
        var simulation = BlockSimulation(seed: 1)
        _ = simulation.blockChanged(at: source, world: &world, time: 0)
        for time in 0..<5 { _ = simulation.tick(world: &world, players: [], time: Int64(time)) }
        #expect(world[BlockPosition(7, 1, 8)] == nil)
        _ = simulation.tick(world: &world, players: [], time: 5)
        #expect(world[BlockPosition(7, 1, 8)] == .water)
        #expect(world.state(at: BlockPosition(7, 1, 8))?.metadata == 1)
        let lava = BlockPosition(9, 1, 8)
        world[lava] = .lava
        _ = simulation.blockChanged(at: lava, world: &world, time: 6)
        #expect(world[lava] == .obsidian)
    }

    @Test func fallingBlocksWaitThreeTicksAndFurnacesRetainTheirInventory() {
        var world = world()
        let sand = BlockPosition(8, 5, 8)
        let restoredSand = BlockPosition(12, 5, 12)
        let furnace = BlockPosition(5, 1, 5)
        world[sand] = .sand
        world[restoredSand] = .sand
        world[furnace] = .furnace
        world.setBlockEntity(
            .furnace(FurnaceState(input: ItemStack(id: 15), fuel: ItemStack(id: 263))), at: furnace)
        var simulation = BlockSimulation(seed: 1)
        _ = simulation.blockChanged(at: sand, world: &world, time: 0)
        for time in 0..<3 { _ = simulation.tick(world: &world, players: [], time: Int64(time)) }
        #expect(world[sand] == .sand)
        _ = simulation.tick(world: &world, players: [], time: 3)
        #expect(world[sand] == nil && world[BlockPosition(8, 1, 8)] == .sand)
        #expect(world[restoredSand] == .sand)
        for time in 4..<200 { _ = simulation.tick(world: &world, players: [], time: Int64(time)) }
        if case .furnace(let state) = world.blockEntity(at: furnace) {
            #expect(state.output?.id == 265 && state.input == nil)
        } else {
            Issue.record("Furnace state was lost during burning-block transition")
        }
    }

    @Test func redstoneWireAttenuatesAndRepeatersDelayTheirOutput() {
        var world = world()
        let lever = BlockPosition(5, 1, 8)
        world.setBlock(BlockState(.lever, metadata: 13), at: lever)
        for x in 6...8 { world[BlockPosition(x, 1, 8)] = .redstoneWire }
        let repeater = BlockPosition(9, 1, 8)
        world.setBlock(BlockState(.repeaterOff, metadata: 1), at: repeater)
        var simulation = BlockSimulation(seed: 1)
        _ = simulation.blockChanged(at: lever, world: &world, time: 0)
        #expect(world.state(at: BlockPosition(6, 1, 8))?.metadata == 15)
        #expect(world.state(at: BlockPosition(8, 1, 8))?.metadata == 13)
        _ = simulation.tick(world: &world, players: [], time: 1)
        #expect(world[repeater] == .repeaterOff)
        _ = simulation.tick(world: &world, players: [], time: 2)
        #expect(world[repeater] == .repeaterOn)
        world.setBlock(BlockState(.lever, metadata: 5), at: lever)
        _ = simulation.blockChanged(at: lever, world: &world, time: 2)
        #expect(world.state(at: BlockPosition(8, 1, 8))?.metadata == 0)
        _ = simulation.tick(world: &world, players: [], time: 4)
        #expect(world[repeater] == .repeaterOff)
    }

    @Test func stickyPistonsPushThenPullTheNearestBlock() {
        var world = world()
        let lever = BlockPosition(5, 1, 8)
        let piston = BlockPosition(6, 1, 8)
        world.setBlock(BlockState(.stickyPiston, metadata: 5), at: piston)
        world.setBlock(BlockState(.lever, metadata: 13), at: lever)
        world[BlockPosition(7, 1, 8)] = .stone
        world[BlockPosition(8, 1, 8)] = .stone
        var simulation = BlockSimulation(seed: 1)
        _ = simulation.blockChanged(at: lever, world: &world, time: 0)
        #expect(world[piston] == .stickyPiston && world.state(at: piston)?.metadata == 13)
        #expect(world[BlockPosition(7, 1, 8)] == .movingPiston)
        #expect(world[BlockPosition(9, 1, 8)] == .movingPiston)
        if case .piston(let state) = world.blockEntity(at: BlockPosition(7, 1, 8)) {
            #expect(state.block == BlockState(.pistonHead, metadata: 13))
            #expect(state.progress == 0 && state.previousProgress == 0 && state.extending)
        } else {
            Issue.record("Extension did not create the original moving head tile")
        }
        let firstStep = simulation.tickAnimations(world: &world, time: 1)
        #expect(firstStep.count == 3)
        if case .displace(let bounds, let delta) = firstStep.first {
            #expect(bounds == AxisAlignedBox(min: SIMD3(6.5, 1, 8), max: SIMD3(7.5, 2, 9)))
            #expect(delta == SIMD3(0.5625, 0, 0))
        } else {
            Issue.record("An extending piston did not displace intersecting entities")
        }
        if case .piston(let state) = world.blockEntity(at: BlockPosition(7, 1, 8)) {
            #expect(state.progress == 0.5 && state.previousProgress == 0)
            #expect(state.offset(interpolation: 0.5) == SIMD3(-0.75, 0, 0))
        }
        _ = simulation.tickAnimations(world: &world, time: 2)
        #expect(world[BlockPosition(7, 1, 8)] == .movingPiston)
        _ = simulation.tickAnimations(world: &world, time: 3)
        #expect(world[BlockPosition(7, 1, 8)] == .pistonHead)
        #expect(world[BlockPosition(9, 1, 8)] == .stone)
        world.setBlock(BlockState(.lever, metadata: 5), at: lever)
        _ = simulation.blockChanged(at: lever, world: &world, time: 3)
        #expect(world[piston] == .movingPiston && world[BlockPosition(8, 1, 8)] == nil)
        #expect(world[BlockPosition(7, 1, 8)] == .movingPiston)
        for time in 4...6 { _ = simulation.tickAnimations(world: &world, time: Int64(time)) }
        #expect(world[BlockPosition(7, 1, 8)] == .stone)
        #expect(world[BlockPosition(8, 1, 8)] == nil)
        #expect(world[piston] == .stickyPiston && world.state(at: piston)?.metadata == 5)
    }

    @Test func railsChooseOriginalJunctionPriorityAndPowerOnlyEightNeighbors() {
        var world = world()
        let center = BlockPosition(8, 1, 8)
        for p in [center, BlockPosition(7, 1, 8), BlockPosition(9, 1, 8), BlockPosition(8, 1, 9)] {
            world[p] = .rail
        }
        _ = RailSimulation.updateTopology(at: center, world: &world, force: true)
        #expect(world.state(at: center)?.metadata == 6)
        world.setBlock(BlockState(.lever, metadata: 13), at: BlockPosition(8, 1, 7))
        _ = RailSimulation.updateTopology(at: center, world: &world, force: true)
        #expect(world.state(at: center)?.metadata == 7)

        world = self.world()
        for x in 4...15 {
            world[BlockPosition(x, 0, 8)] = .stone
            world.setBlock(BlockState(.poweredRail, metadata: 1), at: BlockPosition(x, 1, 8))
        }
        let lever = BlockPosition(3, 1, 8)
        world.setBlock(BlockState(.lever, metadata: 13), at: lever)
        var simulation = BlockSimulation(seed: 1)
        _ = simulation.blockChanged(at: lever, world: &world, time: 0)
        #expect(
            (4...15).map { world.state(at: BlockPosition($0, 1, 8))?.metadata } == [
                9, 9, 9, 9, 9, 9, 9, 9, 9, 1, 1, 1,
            ])
        world.setBlock(BlockState(.lever, metadata: 5), at: lever)
        _ = simulation.blockChanged(at: lever, world: &world, time: 1)
        #expect((4...15).allSatisfy { world.state(at: BlockPosition($0, 1, 8))?.metadata == 1 })
    }

    @Test func netherWaterEvaporatesBedsExplodeAndLavaSpreadsOneLevel() {
        var world = world(dimension: -1)
        let poured = BlockInteractions.use(
            hit: hit(BlockPosition(8, 0, 8)), holding: ItemStack(id: 326), yaw: 0,
            playerBounds: distantPlayer, world: &world)
        #expect(poured.replacement?.id == 325 && world[BlockPosition(8, 1, 8)] == nil)
        #expect(poured.events.count == 9)
        _ = BlockInteractions.use(
            hit: hit(BlockPosition(8, 0, 8)), holding: ItemStack(id: 355), yaw: 0,
            playerBounds: distantPlayer, world: &world)
        let used = BlockInteractions.use(
            hit: hit(BlockPosition(8, 1, 8)), holding: nil, yaw: 0,
            playerBounds: distantPlayer, world: &world)
        #expect(world[BlockPosition(8, 1, 8)] == nil && world[BlockPosition(8, 1, 7)] == nil)
        if case .explosion(_, let power) = used.events.first {
            #expect(power == 5)
        } else {
            Issue.record("A Nether bed did not explode")
        }
        let source = BlockPosition(8, 1, 8)
        world[source] = .lava
        var random = JavaRandom(seed: 1)
        _ = FluidSimulation.tick(at: source, world: &world, random: &random)
        #expect(world.state(at: BlockPosition(7, 1, 8)) == BlockState(.lava, metadata: 1))
    }

    @Test func mushroomsUseRawLightAndLavaIgnitesMaterialFuel() {
        var world = world()
        for position in world.chunks.keys {
            var chunk = world.chunks[position]!
            chunk.skyLight = Array(repeating: 0, count: Chunk.volume)
            world.setChunk(chunk)
        }
        let source = BlockPosition(8, 1, 8)
        world[source] = .brownMushroom
        var random = JavaRandom(seed: 18)
        _ = BlockGrowth.randomTick(at: source, world: &world, random: &random, time: 0)
        #expect(world[BlockPosition(9, 1, 9)] == .brownMushroom)

        world[source] = .stillLava
        for x in 7...9 {
            for z in 7...9 { world[BlockPosition(x, 3, z)] = .planks }
        }
        random = JavaRandom(seed: 2)
        _ = BlockGrowth.randomTick(at: source, world: &world, random: &random, time: 0)
        #expect(world[BlockPosition(7, 2, 9)] == .fire)
        #expect(BlockKind.woodenDoor.isMaterialFlammable && !BlockGrowth.isFlammable(.woodenDoor))
    }

    @Test func pressurePlatesReleaseOnTheirScheduledCheck() {
        var world = world()
        let plate = BlockPosition(8, 1, 8)
        world[plate] = .stonePressurePlate
        var simulation = BlockSimulation(seed: 1)
        _ = simulation.tick(world: &world, players: [SIMD3(8.1, 1, 8.5)], time: 0)
        #expect(world.state(at: plate)?.metadata == 1)
        _ = simulation.tick(world: &world, players: [], time: 1)
        #expect(world.state(at: plate)?.metadata == 1)
        _ = simulation.tick(world: &world, players: [], time: 20)
        #expect(world.state(at: plate)?.metadata == 0)
    }

    @Test func rainHydratesFarmlandAndExtinguishesExposedFire() {
        let rainySeed = (0..<32).map(Int64.init).first { seed in
            let biome = BetaClimateSource(seed: seed).sample(x: 8, z: 8).biome
            return !biome.hasSnow && biome != .desert
        }
        guard let rainySeed else {
            Issue.record("No temperate rain fixture was found")
            return
        }
        var world = world(seed: rainySeed)
        let weather = WorldWeather(seed: rainySeed, raining: true)
        let soil = BlockPosition(8, 0, 8)
        let above = BlockPosition(8, 1, 8)
        let receivesRain = weather.canRain(at: above, in: world)
        #expect(receivesRain)
        world[soil] = .farmland
        var random = JavaRandom(seed: 0)
        _ = BlockGrowth.randomTick(at: soil, world: &world, random: &random, time: 0, weather: weather)
        #expect(world.state(at: soil)?.metadata == 7)
        world[soil] = .stone
        world[above] = .fire
        _ = FireSimulation.tick(at: above, world: &world, random: &random, weather: weather)
        #expect(world[above] == nil)
        world[soil] = .netherrack
        world[above] = .fire
        _ = FireSimulation.tick(at: above, world: &world, random: &random, weather: weather)
        #expect(world[above] == .fire)
    }

    @Test func blockAttackAndStepCallbacksPreserveBetaBehavior() {
        var world = world()
        let p = BlockPosition(8, 1, 8)
        world[p] = .noteBlock
        world.setBlockEntity(.note(pitch: 4), at: p)
        var simulation = BlockSimulation(seed: 1)
        let note = simulation.attack(hit: hit(p), holding: nil, health: 20, world: &world, time: 0)
        #expect(world.blockEntity(at: p) == .note(pitch: 4) && note.events.count == 1)
        world[p] = .redstoneOre
        _ = simulation.attack(hit: hit(p), holding: nil, health: 20, world: &world, time: 0)
        #expect(world[p] == .litRedstoneOre)
        world[p] = .redstoneOre
        let oreUse = BlockInteractions.use(
            hit: hit(p), holding: ItemStack(id: 261), yaw: 0,
            playerBounds: distantPlayer, world: &world)
        #expect(!oreUse.handled && !oreUse.changedPositions.isEmpty && !oreUse.events.isEmpty)
        _ = simulation.tick(world: &world, players: [], time: 30)
        #expect(world[p] == .redstoneOre)
        world[p] = .cake
        let cake = simulation.attack(hit: hit(p), holding: nil, health: 10, world: &world, time: 31)
        #expect(cake.healthRestored == 3 && world.state(at: p)?.metadata == 1)
        let soil = BlockPosition(8, 0, 8)
        world[soil] = .farmland
        world[p] = .wheat
        simulation = BlockSimulation(seed: 1)
        let trampled = simulation.stepped(at: soil, world: &world, time: 0)
        #expect(world[soil] == .dirt && world[p] == nil && !trampled.isEmpty)
    }

    @Test func containerStacksScatterLikeTheOriginalSeededChest() {
        var random = JavaRandom(seed: 1234)
        let drops = BlockInteractions.containerDrops(
            .chest(slots: [ItemStack(id: 35, count: 64, damage: 2)]), at: BlockPosition(8, 1, 8),
            random: &random)
        let counts = drops.compactMap { event -> Int? in
            if case .dropItemMoving(_, let stack, _) = event { return stack.count }
            return nil
        }
        #expect(counts == [28, 12, 22, 2])
        if case .dropItemMoving(let position, let stack, let velocity) = drops.first {
            #expect(position == SIMD3(8.617265701293945, 1.307831883430481, 8.861085891723633))
            #expect(stack.damage == 2)
            #expect(velocity == SIMD3(0.05692359805107117, 0.19335126876831055, -0.030262578278779984))
        } else {
            Issue.record("Chest contents did not retain their scattered velocity")
        }
    }

    @Test func theOriginalFixedSizePortalFormsAndCollapsesWithItsFrame() {
        var world = world()
        for x in 6...9 {
            for y in 1...5 where x == 6 || x == 9 || y == 1 || y == 5 {
                world[BlockPosition(x, y, 8)] = .obsidian
            }
        }
        let fire = BlockPosition(7, 2, 8)
        world[fire] = .fire
        var simulation = BlockSimulation(seed: 1)
        _ = simulation.blockChanged(at: fire, world: &world, time: 0)
        #expect(world[fire] == .portal && world[BlockPosition(8, 4, 8)] == .portal)
        world[BlockPosition(6, 3, 8)] = nil
        _ = simulation.blockChanged(at: BlockPosition(6, 3, 8), world: &world, time: 1)
        #expect(world[fire] == nil && world[BlockPosition(8, 4, 8)] == nil)
    }
}
