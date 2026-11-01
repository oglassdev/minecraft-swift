enum FireSimulation {
    private static let fuels: [BlockKind: (encouragement: Int, flammability: Int)] = [
        .planks: (5, 20), .fence: (5, 20), .woodenStairs: (5, 20), .wood: (5, 5),
        .leaves: (30, 60), .bookshelf: (30, 20), .tnt: (15, 100), .tallGrass: (60, 100), .wool: (30, 60),
    ]

    static func tick(
        at p: BlockPosition, world: inout BlockWorld, random: inout JavaRandom, weather: WorldWeather? = nil
    )
        -> BlockGrowth.Changes
    {
        var result = BlockGrowth.Changes()
        guard let state = world.state(at: p), state.kind == .fire else { return result }
        let below = p.adding(BlockPosition(0, -1, 0))
        let permanent = world[below] == .netherrack
        let adjacentFuel = BlockPosition.neighbors.contains { encouragement(of: world[p.adding($0)]) > 0 }
        if !BlockPlacement.canRemain(state, at: p, in: world) {
            world.setBlock(nil, at: p)
            result.positions = [p]
            return result
        }
        if !permanent, let weather,
            ([p] + BlockPosition.horizontal.map { p.adding($0) }).contains(where: {
                weather.canRain(at: $0, in: world)
            })
        {
            world.setBlock(nil, at: p)
            result.positions = [p]
            return result
        }
        let age = Int(state.metadata)
        if age < 15 {
            world.setBlock(BlockState(.fire, metadata: UInt8(age + random.nextInt(bound: 3) / 2)), at: p)
        }
        result.positions.append(p)
        if !permanent && !adjacentFuel {
            if world[below]?.isNormalCube != true || age > 3 { world.setBlock(nil, at: p) }
            return result
        }
        if !permanent && encouragement(of: world[below]) == 0 && age == 15 && random.nextInt(bound: 4) == 0 {
            world.setBlock(nil, at: p)
            return result
        }
        let offsets = [
            BlockPosition(1, 0, 0), BlockPosition(-1, 0, 0), BlockPosition(0, -1, 0),
            BlockPosition(0, 1, 0), BlockPosition(0, 0, -1), BlockPosition(0, 0, 1),
        ]
        for offset in offsets {
            let target = p.adding(offset)
            let bound = offset.y == 0 ? 300 : 250
            let kind = world[target]
            let flammability = kind.flatMap { fuels[$0]?.flammability } ?? 0
            if random.nextInt(bound: bound) < flammability {
                if random.nextInt(bound: age + 10) < 5 && weather?.canRain(at: target, in: world) != true {
                    world.setBlock(
                        BlockState(.fire, metadata: UInt8(min(15, age + random.nextInt(bound: 5) / 4))),
                        at: target)
                } else {
                    world.setBlock(nil, at: target)
                }
                result.positions.append(target)
                if kind == .tnt {
                    result.events.append(
                        .spawnEntity(
                            kind: "PrimedTnt", position: target.center - SIMD3(0, Double(Float(0.98)) / 2, 0))
                    )
                }
            }
        }
        for x in -1...1 {
            for z in -1...1 {
                for y in -1...4 where x != 0 || y != 0 || z != 0 {
                    let target = p.adding(BlockPosition(x, y, z))
                    guard (0..<128).contains(target.y), world[target] == nil,
                        world.chunks[target.chunk] != nil
                    else { continue }
                    let spreadStrength =
                        BlockPosition.neighbors.map { encouragement(of: world[target.adding($0)]) }.max() ?? 0
                    let chance = (spreadStrength + 40) / (age + 30)
                    let bound = 100 + max(0, y - 1) * 100
                    let dry = [
                        target, BlockPosition(target.x - 1, target.y, p.z),
                        target.adding(BlockPosition(1, 0, 0)), target.adding(BlockPosition(0, 0, -1)),
                        target.adding(BlockPosition(0, 0, 1)),
                    ].allSatisfy { weather?.canRain(at: $0, in: world) != true }
                    if spreadStrength > 0 && chance > 0 && random.nextInt(bound: bound) <= chance && dry {
                        world.setBlock(
                            BlockState(.fire, metadata: UInt8(min(15, age + random.nextInt(bound: 5) / 4))),
                            at: target)
                        result.positions.append(target)
                    }
                }
            }
        }
        return result
    }

    private static func encouragement(of kind: BlockKind?) -> Int {
        kind.flatMap { fuels[$0]?.encouragement } ?? 0
    }
}
