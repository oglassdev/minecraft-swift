extension BetaNetherGenerator {
    /// Preserves the original provider's population RNG state, which depends on load order.
    public mutating func populate(world: inout BlockWorld, chunkX: Int, chunkZ: Int) {
        let position = ChunkPosition(x: chunkX, z: chunkZ)
        guard world.chunks[position]?.isTerrainPopulated != true else { return }
        let complete = ((chunkX - 1)...(chunkX + 2)).allSatisfy { x in
            ((chunkZ - 1)...(chunkZ + 2)).allSatisfy { z in world.chunks[ChunkPosition(x: x, z: z)] != nil }
        }
        precondition(complete, "Load the surrounding base chunks before Nether population")
        let x = chunkX * 16
        let z = chunkZ * 16
        for _ in 0..<8 {
            let px = x + random.nextInt(bound: 16) + 8
            let py = random.nextInt(bound: 120) + 4
            let pz = z + random.nextInt(bound: 16) + 8
            spring(at: BlockPosition(px, py, pz), world: &world)
        }
        let fireBound = random.nextInt(bound: 10) + 1
        let fires = random.nextInt(bound: fireBound) + 1
        for _ in 0..<fires {
            let px = x + random.nextInt(bound: 16) + 8
            let py = random.nextInt(bound: 120) + 4
            let pz = z + random.nextInt(bound: 16) + 8
            fire(at: BlockPosition(px, py, pz), world: &world)
        }
        let glowBound = random.nextInt(bound: 10) + 1
        let clusters = random.nextInt(bound: glowBound)
        for _ in 0..<clusters {
            let px = x + random.nextInt(bound: 16) + 8
            let py = random.nextInt(bound: 120) + 4
            let pz = z + random.nextInt(bound: 16) + 8
            glowstone(at: BlockPosition(px, py, pz), world: &world)
        }
        for _ in 0..<10 {
            let px = x + random.nextInt(bound: 16) + 8
            let py = random.nextInt(bound: 128)
            let pz = z + random.nextInt(bound: 16) + 8
            glowstone(at: BlockPosition(px, py, pz), world: &world)
        }
        for block in [BlockKind.brownMushroom, .redMushroom] {
            _ = random.nextInt(bound: 1)
            let px = x + random.nextInt(bound: 16) + 8
            let py = random.nextInt(bound: 128)
            let pz = z + random.nextInt(bound: 16) + 8
            BetaPopulationFeatures.plant(block, at: BlockPosition(px, py, pz), world: &world, random: &random)
        }
        world.markChunkPopulated(at: position)
    }

    private func spring(at p: BlockPosition, world: inout BlockWorld) {
        guard world[p.adding(BlockPosition(0, 1, 0))] == .netherrack,
            world[p] == nil || world[p] == .netherrack
        else { return }
        let neighbors = (BlockPosition.horizontal + [BlockPosition(0, -1, 0)]).map { p.adding($0) }
        guard neighbors.filter({ world[$0] == .netherrack }).count == 4,
            neighbors.filter({ world[$0] == nil }).count == 1
        else { return }
        world[p] = .lava
        notifyNeighbors(at: p, world: &world)
        var flowRandom = JavaRandom(seed: world.seed)
        BetaPopulationFeatures.instantFlow(
            at: p, world: &world, random: &flowRandom,
            context: FluidSimulation.FlowContext())
    }

    private mutating func fire(at origin: BlockPosition, world: inout BlockWorld) {
        for _ in 0..<64 {
            let p = BlockPosition(
                origin.x + random.nextInt(bound: 8) - random.nextInt(bound: 8),
                origin.y + random.nextInt(bound: 4) - random.nextInt(bound: 4),
                origin.z + random.nextInt(bound: 8) - random.nextInt(bound: 8))
            if world[p] == nil && world[p.adding(BlockPosition(0, -1, 0))] == .netherrack {
                world[p] = .fire
                notifyNeighbors(at: p, world: &world)
            }
        }
    }

    private mutating func glowstone(at origin: BlockPosition, world: inout BlockWorld) {
        guard world[origin] == nil, world[origin.adding(BlockPosition(0, 1, 0))] == .netherrack else {
            return
        }
        world[origin] = .glowstone
        notifyNeighbors(at: origin, world: &world)
        for _ in 0..<1500 {
            let p = BlockPosition(
                origin.x + random.nextInt(bound: 8) - random.nextInt(bound: 8),
                origin.y - random.nextInt(bound: 12),
                origin.z + random.nextInt(bound: 8) - random.nextInt(bound: 8))
            if world[p] == nil
                && BlockPosition.neighbors.filter({ world[p.adding($0)] == .glowstone }).count == 1
            {
                world[p] = .glowstone
                notifyNeighbors(at: p, world: &world)
            }
        }
    }

    private func notifyNeighbors(at p: BlockPosition, world: inout BlockWorld) {
        for offset in BlockPosition.neighbors {
            let neighbor = p.adding(offset)
            if !FluidSimulation.mix(at: neighbor, world: &world).positions.isEmpty {
                notifyNeighbors(at: neighbor, world: &world)
            }
            guard let state = world.state(at: neighbor),
                state.kind == .stillWater || state.kind == .stillLava
            else { continue }
            let moving: BlockKind = state.kind == .stillWater ? .water : .lava
            // Population outside a spring queues this tick rather than executing it immediately.
            world.setBlock(BlockState(moving, metadata: state.metadata), at: neighbor)
        }
    }
}
