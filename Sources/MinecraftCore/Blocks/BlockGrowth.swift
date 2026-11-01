import Foundation

enum BlockGrowth {
    struct Changes {
        var positions: [BlockPosition] = []
        var events: [BlockEvent] = []
    }

    static func isFlammable(_ kind: BlockKind?) -> Bool {
        guard let kind else { return false }
        return [5, 17, 18, 31, 35, 46, 47, 53, 85].contains(kind.rawValue)
    }

    @discardableResult
    static func growTree(
        at p: BlockPosition, metadata: UInt8, world: inout BlockWorld, random: inout JavaRandom
    ) -> Bool {
        let kind: BetaTreeKind
        switch metadata & 3 {
        case 1: kind = .spruce
        case 2: kind = .birch
        default: kind = random.nextInt(bound: 10) == 0 ? .bigOak : .oak
        }
        world.setBlock(nil, at: p)
        let generated = BetaTrees.generate(kind, at: p, world: &world, random: &random)
        if !generated { world.setBlock(BlockState(.sapling, metadata: metadata & 3), at: p) }
        return generated
    }

    static func randomTick(
        at p: BlockPosition, world: inout BlockWorld, random: inout JavaRandom, time: Int64,
        weather: WorldWeather? = nil
    ) -> Changes {
        var changes = Changes()
        guard let state = world.state(at: p) else { return changes }
        let above = p.adding(BlockPosition(0, 1, 0))
        if [.sapling, .wheat, .tallGrass, .deadBush, .dandelion, .rose].contains(state.kind),
            !BlockPlacement.canRemain(state, at: p, in: world)
                || !hasRequiredLight(state, at: p, world: world)
        {
            changes.events = BlockMining.explosionDrops(for: state, roll: { random.nextInt(bound: $0) }).map {
                .dropItem(position: p.center, stack: $0)
            }
            world.setBlock(nil, at: p)
            changes.positions = [p]
            return changes
        }
        switch state.kind {
        case .brownMushroom, .redMushroom:
            if random.nextInt(bound: 100) == 0 {
                let target = p.adding(
                    BlockPosition(
                        random.nextInt(bound: 3) - 1,
                        random.nextInt(bound: 2) - random.nextInt(bound: 2),
                        random.nextInt(bound: 3) - 1))
                if canGrowMushroom(at: target, world: world) {
                    // The horizontal walk draws do not change this placement target.
                    _ = random.nextInt(bound: 3)
                    _ = random.nextInt(bound: 3)
                    world[target] = state.kind
                    changes.positions.append(target)
                }
            }
        case .stillLava:
            var target = p
            let attempts = random.nextInt(bound: 3)
            for _ in 0..<attempts {
                target = target.adding(
                    BlockPosition(random.nextInt(bound: 3) - 1, 1, random.nextInt(bound: 3) - 1))
                if world[target] == nil {
                    if BlockPosition.neighbors.contains(where: {
                        world[target.adding($0)]?.isMaterialFlammable == true
                    }) {
                        world[target] = .fire
                        changes.positions.append(target)
                        break
                    }
                } else if world[target]?.isMaterialSolid == true {
                    break
                }
            }
        case .grass:
            if light(at: above, world: world, time: time, weather: weather) < 4
                && (world[above]?.lightOpacity ?? 0) > 2
            {
                if random.nextInt(bound: 4) == 0 {
                    world[p] = .dirt
                    changes.positions.append(p)
                }
            } else if light(at: above, world: world, time: time, weather: weather) >= 9 {
                let target = p.adding(
                    BlockPosition(
                        random.nextInt(bound: 3) - 1,
                        random.nextInt(bound: 5) - 3, random.nextInt(bound: 3) - 1))
                let targetAbove = target.adding(BlockPosition(0, 1, 0))
                if world[target] == .dirt && (world[targetAbove]?.lightOpacity ?? 0) <= 2
                    && light(at: targetAbove, world: world, time: time, weather: weather) >= 4
                {
                    world[target] = .grass
                    changes.positions.append(target)
                }
            }
        case .farmland:
            guard random.nextInt(bound: 5) == 0 else { break }
            let hydrated = (-4...4).contains { dx in
                (-4...4).contains { dz in
                    (0...1).contains { dy in
                        BlockPlacement.isWater(world[p.adding(BlockPosition(dx, dy, dz))])
                    }
                }
            }
            if hydrated || weather?.canRain(at: above, in: world) == true {
                world.setBlock(BlockState(.farmland, metadata: 7), at: p)
            } else if state.metadata > 0 {
                world.setBlock(BlockState(.farmland, metadata: state.metadata - 1), at: p)
            } else if world[above] != .wheat {
                world[p] = .dirt
            }
            changes.positions.append(p)
        case .wheat:
            if state.metadata < 7 && light(at: above, world: world, time: time, weather: weather) >= 9 {
                let growth = cropGrowth(at: p, world: world)
                if random.nextInt(bound: Int(100 / growth)) == 0 {
                    world.setBlock(BlockState(.wheat, metadata: state.metadata + 1), at: p)
                    changes.positions.append(p)
                }
            }
        case .sapling:
            if light(at: above, world: world, time: time, weather: weather) >= 9
                && random.nextInt(bound: 30) == 0
            {
                if state.metadata & 8 == 0 {
                    world.setBlock(BlockState(.sapling, metadata: state.metadata | 8), at: p)
                } else {
                    growTree(at: p, metadata: state.metadata, world: &world, random: &random)
                }
                changes.positions.append(p)
            }
        case .sugarCane, .cactus:
            if world[above] == nil {
                var height = 1
                while world[p.adding(BlockPosition(0, -height, 0))] == state.kind { height += 1 }
                if height < 3 {
                    if state.metadata == 15 {
                        world[above] = state.kind
                        world.setBlock(BlockState(state.kind), at: p)
                        changes.positions.append(above)
                    } else {
                        world.setBlock(BlockState(state.kind, metadata: state.metadata + 1), at: p)
                    }
                    changes.positions.append(p)
                }
            }
        case .leaves:
            if state.metadata & 8 != 0 {
                let loaded = (((p.x - 5) >> 4)...((p.x + 5) >> 4)).allSatisfy { x in
                    (((p.z - 5) >> 4)...((p.z + 5) >> 4)).allSatisfy { z in
                        world.chunks[ChunkPosition(x, z)] != nil
                    }
                }
                guard loaded else { break }
                var frontier = [p]
                var visited: Set<BlockPosition> = [p]
                var connected = false
                for _ in 0..<4 {
                    var next: [BlockPosition] = []
                    for leaf in frontier {
                        for offset in BlockPosition.neighbors {
                            let neighbor = leaf.adding(offset)
                            if world[neighbor] == .wood { connected = true }
                            if world[neighbor] == .leaves && visited.insert(neighbor).inserted {
                                next.append(neighbor)
                            }
                        }
                    }
                    frontier = next
                }
                if connected {
                    world.setBlock(BlockState(.leaves, metadata: state.metadata & 7), at: p)
                } else {
                    if random.nextInt(bound: 20) == 0 {
                        changes.events.append(
                            .dropItem(
                                position: p.center,
                                stack: ItemStack(id: 6, damage: UInt16(state.metadata & 3))))
                    }
                    world.setBlock(nil, at: p)
                }
                changes.positions.append(p)
            }
        case .snowLayer, .ice:
            if blockLight(at: p, world: world) > (state.kind == .ice ? 8 : 11) {
                world.setBlock(state.kind == .ice ? BlockState(.water) : nil, at: p)
                changes.positions.append(p)
            }
        case .litRedstoneOre:
            world[p] = .redstoneOre
            changes.positions.append(p)
        default: break
        }
        return changes
    }

    static func light(at p: BlockPosition, world: BlockWorld, time: Int64, weather: WorldWeather? = nil)
        -> Int
    {
        guard (0..<128).contains(p.y), let chunk = world.chunks[p.chunk] else { return 15 }
        let index = Chunk.index(x: p.x & 15, y: p.y, z: p.z & 15)
        if let weather {
            return max(
                Int(chunk.blockLight[index]),
                max(
                    0,
                    Int(chunk.skyLight[index])
                        - weather.skylightSubtraction(time: time, dimension: world.dimension)))
        }
        var angle = Double((time % 24000 + 24000) % 24000) / 24000 - 0.25
        if angle < 0 { angle += 1 }
        let original = angle
        angle = 1 - (cos(angle * .pi) + 1) / 2
        angle = original + (angle - original) / 3
        let darkness = min(1, max(0, 1 - (cos(angle * .pi * 2) * 2 + 0.5)))
        return max(Int(chunk.blockLight[index]), max(0, Int(chunk.skyLight[index]) - Int(darkness * 11)))
    }

    private static func blockLight(at p: BlockPosition, world: BlockWorld) -> Int {
        guard (0..<128).contains(p.y), let chunk = world.chunks[p.chunk] else { return 0 }
        return Int(chunk.blockLight[Chunk.index(x: p.x & 15, y: p.y, z: p.z & 15)])
    }

    static func hasRequiredLight(_ state: BlockState, at p: BlockPosition, world: BlockWorld) -> Bool {
        let light = world.light(at: p)
        let level = max(light.sky, light.block)
        switch state.kind {
        case .brownMushroom, .redMushroom: return level < 13
        case .sapling, .wheat, .tallGrass, .deadBush, .dandelion, .rose: return level >= 8
        default: return true
        }
    }

    private static func canGrowMushroom(at p: BlockPosition, world: BlockWorld) -> Bool {
        guard (0..<128).contains(p.y), world.chunks[p.chunk] != nil, world[p] == nil,
            world[p.adding(BlockPosition(0, -1, 0))]?.isOpaque == true
        else { return false }
        let light = world.light(at: p)
        return max(light.sky, light.block) < 13
    }

    private static func cropGrowth(at p: BlockPosition, world: BlockWorld) -> Float {
        var growth: Float = 1
        for x in -1...1 {
            for z in -1...1 {
                let below = world.state(at: p.adding(BlockPosition(x, -1, z)))
                var contribution: Float = 0
                if let below, below.kind == .farmland { contribution = below.metadata > 0 ? 3 : 1 }
                if x != 0 || z != 0 { contribution /= 4 }
                growth += contribution
            }
        }
        let xRow =
            world[p.adding(BlockPosition(-1, 0, 0))] == .wheat
            || world[p.adding(BlockPosition(1, 0, 0))] == .wheat
        let zRow =
            world[p.adding(BlockPosition(0, 0, -1))] == .wheat
            || world[p.adding(BlockPosition(0, 0, 1))] == .wheat
        let diagonal = [-1, 1].contains { x in
            [-1, 1].contains { z in world[p.adding(BlockPosition(x, 0, z))] == .wheat }
        }
        if xRow && zRow || diagonal { growth /= 2 }
        return growth
    }
}
