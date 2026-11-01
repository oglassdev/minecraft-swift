import Foundation

enum BetaPopulationFeatures {
    static let horizontal = [
        BlockPosition(-1, 0, 0), BlockPosition(1, 0, 0), BlockPosition(0, 0, -1), BlockPosition(0, 0, 1),
    ]
    private static let sineTable: [Float] = (0..<65536).map { Float(sin(Double($0) * .pi * 2 / 65536)) }
    private static func sine(_ value: Float) -> Float { sineTable[Int(value * 10430.378) & 65535] }
    private static func cosine(_ value: Float) -> Float { sineTable[Int(value * 10430.378 + 16384) & 65535] }

    static func kind(_ world: BlockWorld, _ x: Int, _ y: Int, _ z: Int) -> BlockKind? {
        world[BlockPosition(x, y, z)]
    }

    static func solid(_ kind: BlockKind?) -> Bool {
        guard let kind else { return false }
        return kind.isSolid && kind != .snowLayer
    }

    static func height(_ world: BlockWorld, x: Int, z: Int, precipitation: Bool = false) -> Int {
        for y in (1..<128).reversed() {
            guard let block = kind(world, x, y, z) else { continue }
            if precipitation {
                if solid(block) || block.isLiquid { return y + 1 }
            } else if block.isOpaque || block == .leaves || block.isLiquid || block == .ice {
                return y + 1
            }
        }
        return precipitation ? -1 : 0
    }

    static func light(_ world: BlockWorld, x: Int, y: Int, z: Int) -> Int {
        var light = 15
        if y < 0 { return 0 }
        if y >= 128 { return 15 }
        for above in y..<128 {
            guard let block = kind(world, x, above, z) else { continue }
            if block.isOpaque { return 0 }
            if block == .leaves {
                light = max(0, light - 1)
            } else if block.isLiquid || block == .ice {
                light = max(0, light - 3)
            }
        }
        return light
    }

    static func ore(
        _ block: BlockKind, size: Int, at origin: BlockPosition,
        world: inout BlockWorld, random: inout JavaRandom, clay: Bool = false
    ) {
        if clay && kind(world, origin.x, origin.y, origin.z) != .water
            && kind(world, origin.x, origin.y, origin.z) != .stillWater
        {
            return
        }
        let angle = random.nextFloat() * Float(Double.pi)
        let xOffset = sine(angle) * Float(size) / 8
        let zOffset = cosine(angle) * Float(size) / 8
        let x0 = Double(Float(origin.x + 8) + xOffset)
        let x1 = Double(Float(origin.x + 8) - xOffset)
        let z0 = Double(Float(origin.z + 8) + zOffset)
        let z1 = Double(Float(origin.z + 8) - zOffset)
        let y0 = Double(origin.y + random.nextInt(bound: 3) + 2)
        let y1 = Double(origin.y + random.nextInt(bound: 3) + 2)
        for step in 0...size {
            let x = x0 + (x1 - x0) * Double(step) / Double(size)
            let y = y0 + (y1 - y0) * Double(step) / Double(size)
            let z = z0 + (z1 - z0) * Double(step) / Double(size)
            let randomSize = random.nextDouble() * Double(size) / 16
            let diameter = Double(sine(Float(step) * Float(Double.pi) / Float(size)) + 1) * randomSize + 1
            let radius = diameter / 2
            let minX = Int(floor(x - radius))
            let maxX = Int(floor(x + radius))
            let minY = Int(floor(y - radius))
            let maxY = Int(floor(y + radius))
            let minZ = Int(floor(z - radius))
            let maxZ = Int(floor(z + radius))
            for bx in minX...maxX {
                let nx = (Double(bx) + 0.5 - x) / radius
                if nx * nx >= 1 { continue }
                for by in minY...maxY {
                    let ny = (Double(by) + 0.5 - y) / radius
                    if nx * nx + ny * ny >= 1 { continue }
                    for bz in minZ...maxZ {
                        let nz = (Double(bz) + 0.5 - z) / radius
                        if nx * nx + ny * ny + nz * nz < 1 {
                            let position = BlockPosition(bx, by, bz)
                            if world[position] == (clay ? .sand : .stone) { world[position] = block }
                        }
                    }
                }
            }
        }
    }

    static func lake(
        _ block: BlockKind, at origin: BlockPosition,
        world: inout BlockWorld, random: inout JavaRandom
    ) {
        let x = origin.x - 8
        let z = origin.z - 8
        var y = origin.y
        while y > 0 && kind(world, x, y, z) == nil { y -= 1 }
        y -= 4
        var mask = Array(repeating: false, count: 2048)
        let ellipsoids = random.nextInt(bound: 4) + 4
        for _ in 0..<ellipsoids {
            let width = random.nextDouble() * 6 + 3
            let height = random.nextDouble() * 4 + 2
            let depth = random.nextDouble() * 6 + 3
            let centerX = random.nextDouble() * (16 - width - 2) + 1 + width / 2
            let centerY = random.nextDouble() * (8 - height - 4) + 2 + height / 2
            let centerZ = random.nextDouble() * (16 - depth - 2) + 1 + depth / 2
            for bx in 1..<15 {
                for bz in 1..<15 {
                    for by in 1..<7 {
                        let nx = (Double(bx) - centerX) / (width / 2)
                        let ny = (Double(by) - centerY) / (height / 2)
                        let nz = (Double(bz) - centerZ) / (depth / 2)
                        if nx * nx + ny * ny + nz * nz < 1 { mask[(bx * 16 + bz) * 8 + by] = true }
                    }
                }
            }
        }
        func boundary(_ bx: Int, _ by: Int, _ bz: Int) -> Bool {
            if mask[(bx * 16 + bz) * 8 + by] { return false }
            return (bx < 15 && mask[((bx + 1) * 16 + bz) * 8 + by])
                || (bx > 0 && mask[((bx - 1) * 16 + bz) * 8 + by])
                || (bz < 15 && mask[(bx * 16 + bz + 1) * 8 + by])
                || (bz > 0 && mask[(bx * 16 + bz - 1) * 8 + by])
                || (by < 7 && mask[(bx * 16 + bz) * 8 + by + 1])
                || (by > 0 && mask[(bx * 16 + bz) * 8 + by - 1])
        }
        for bx in 0..<16 {
            for bz in 0..<16 {
                for by in 0..<8 where boundary(bx, by, bz) {
                    let existing = kind(world, x + bx, y + by, z + bz)
                    if by >= 4 && existing?.isLiquid == true { return }
                    if by < 4 && !solid(existing) && existing != block { return }
                }
            }
        }
        for bx in 0..<16 {
            for bz in 0..<16 {
                for by in 0..<8 where mask[(bx * 16 + bz) * 8 + by] {
                    world[BlockPosition(x + bx, y + by, z + bz)] = by >= 4 ? nil : block
                }
            }
        }
        for bx in 0..<16 {
            for bz in 0..<16 {
                for by in 4..<8 where mask[(bx * 16 + bz) * 8 + by] {
                    let below = BlockPosition(x + bx, y + by - 1, z + bz)
                    if world[below] == .dirt && light(world, x: x + bx, y: y + by, z: z + bz) > 0 {
                        world[below] = .grass
                    }
                }
            }
        }
        if block == .lava || block == .stillLava {
            for bx in 0..<16 {
                for bz in 0..<16 {
                    for by in 0..<8 where boundary(bx, by, bz) {
                        if (by < 4 || random.nextInt(bound: 2) != 0)
                            && solid(kind(world, x + bx, y + by, z + bz))
                        {
                            world[BlockPosition(x + bx, y + by, z + bz)] = .stone
                        }
                    }
                }
            }
        }
    }

    static func plant(
        _ block: BlockKind, metadata: UInt8 = 0, at origin: BlockPosition,
        world: inout BlockWorld, random: inout JavaRandom
    ) {
        var baseY = origin.y
        let trials: Int
        if block == .tallGrass || block == .deadBush {
            while baseY > 0 {
                let existing = kind(world, origin.x, baseY, origin.z)
                if existing != nil && existing != .leaves { break }
                baseY -= 1
            }
            trials = block == .tallGrass ? 128 : 4
        } else {
            trials = 64
        }
        for _ in 0..<trials {
            let x = origin.x + random.nextInt(bound: 8) - random.nextInt(bound: 8)
            let y = baseY + random.nextInt(bound: 4) - random.nextInt(bound: 4)
            let z = origin.z + random.nextInt(bound: 8) - random.nextInt(bound: 8)
            guard (0..<128).contains(y), kind(world, x, y, z) == nil else { continue }
            let below = kind(world, x, y - 1, z)
            let lighting = light(world, x: x, y: y, z: z)
            let canStay: Bool
            if block == .brownMushroom || block == .redMushroom {
                canStay = lighting < 13 && below?.isOpaque == true
            } else if block == .deadBush {
                canStay = lighting >= 8 && below == .sand
            } else {
                canStay = lighting >= 8 && (below == .grass || below == .dirt || below == .farmland)
            }
            if canStay { world.setBlock(BlockState(block, metadata: metadata), at: BlockPosition(x, y, z)) }
        }
    }

    static func reeds(at origin: BlockPosition, world: inout BlockWorld, random: inout JavaRandom) {
        for _ in 0..<20 {
            let x = origin.x + random.nextInt(bound: 4) - random.nextInt(bound: 4)
            let z = origin.z + random.nextInt(bound: 4) - random.nextInt(bound: 4)
            let y = origin.y
            if kind(world, x, y, z) == nil
                && horizontal.contains(where: {
                    let block = kind(world, x + $0.x, y - 1, z + $0.z)
                    return block == .water || block == .stillWater
                })
            {
                let bound = random.nextInt(bound: 3) + 1
                let height = 2 + random.nextInt(bound: bound)
                for offset in 0..<height {
                    let below = kind(world, x, y + offset - 1, z)
                    if below == .sugarCane
                        || ((below == .grass || below == .dirt)
                            && horizontal.contains(where: {
                                let block = kind(world, x + $0.x, y + offset - 1, z + $0.z)
                                return block == .water || block == .stillWater
                            }))
                    {
                        world[BlockPosition(x, y + offset, z)] = .sugarCane
                    }
                }
            }
        }
    }

    static func pumpkins(at origin: BlockPosition, world: inout BlockWorld, random: inout JavaRandom) {
        for _ in 0..<64 {
            let x = origin.x + random.nextInt(bound: 8) - random.nextInt(bound: 8)
            let y = origin.y + random.nextInt(bound: 4) - random.nextInt(bound: 4)
            let z = origin.z + random.nextInt(bound: 8) - random.nextInt(bound: 8)
            if kind(world, x, y, z) == nil && kind(world, x, y - 1, z) == .grass {
                world.setBlock(
                    BlockState(.pumpkin, metadata: UInt8(random.nextInt(bound: 4))),
                    at: BlockPosition(x, y, z))
            }
        }
    }

    static func cactus(at origin: BlockPosition, world: inout BlockWorld, random: inout JavaRandom) {
        for _ in 0..<10 {
            let x = origin.x + random.nextInt(bound: 8) - random.nextInt(bound: 8)
            let y = origin.y + random.nextInt(bound: 4) - random.nextInt(bound: 4)
            let z = origin.z + random.nextInt(bound: 8) - random.nextInt(bound: 8)
            if kind(world, x, y, z) == nil {
                let bound = random.nextInt(bound: 3) + 1
                let height = 1 + random.nextInt(bound: bound)
                for offset in 0..<height {
                    let below = kind(world, x, y + offset - 1, z)
                    if (below == .cactus || below == .sand)
                        && !horizontal.contains(where: {
                            solid(kind(world, x + $0.x, y + offset, z + $0.z))
                        })
                    {
                        world[BlockPosition(x, y + offset, z)] = .cactus
                    }
                }
            }
        }
    }

    static func spring(_ block: BlockKind, at p: BlockPosition, world: inout BlockWorld) {
        guard kind(world, p.x, p.y + 1, p.z) == .stone,
            kind(world, p.x, p.y - 1, p.z) == .stone,
            world[p] == nil || world[p] == .stone
        else { return }
        let neighbors = horizontal.map { BlockPosition(p.x + $0.x, p.y, p.z + $0.z) }
        guard neighbors.filter({ world[$0] == .stone }).count == 3,
            neighbors.filter({ world[$0] == nil }).count == 1
        else { return }
        world[p] = block
        var flowRandom = JavaRandom(seed: world.seed)
        instantFlow(at: p, world: &world, random: &flowRandom, context: FluidSimulation.FlowContext())
    }

    private enum FlowWork {
        case tick(FluidSimulation.Tick, suppressed: Bool)
        case notify(BlockPosition, neighbor: Int)
        case inspectNeighbor(BlockPosition)
        case retryNeighbor(BlockPosition, moving: BlockKind)
    }

    static func instantFlow(
        at p: BlockPosition, world: inout BlockWorld, random: inout JavaRandom,
        context: FluidSimulation.FlowContext, suppressNotifications: Bool = false
    ) {
        guard flowAreaLoaded(at: p, world: world) else { return }
        var work: [FlowWork] = [.tick(FluidSimulation.Tick(at: p), suppressed: suppressNotifications)]
        while let next = work.popLast() {
            switch next {
            case .tick(var tick, let suppressed):
                guard let event = tick.resume(world: &world, random: &random, flowContext: context) else {
                    continue
                }
                work.append(.tick(tick, suppressed: suppressed))
                switch event {
                case .schedule(let position):
                    if flowAreaLoaded(at: position, world: world) {
                        work.append(.tick(FluidSimulation.Tick(at: position), suppressed: suppressed))
                    }
                case .notify(let position):
                    if !suppressed { work.append(.notify(position, neighbor: 0)) }
                }
            case .notify(let position, let index):
                guard index < BlockPosition.neighbors.count else { continue }
                let neighbor = position.adding(BlockPosition.neighbors[index])
                work.append(.notify(position, neighbor: index + 1))
                work.append(.inspectNeighbor(neighbor))
                if !FluidSimulation.mix(at: neighbor, world: &world).positions.isEmpty {
                    work.append(.notify(neighbor, neighbor: 0))
                }
            case .inspectNeighbor(let neighbor):
                guard let state = world.state(at: neighbor),
                    state.kind == .stillWater || state.kind == .stillLava
                else { continue }
                let moving: BlockKind = state.kind == .stillWater ? .water : .lava
                world.setBlock(BlockState(moving, metadata: state.metadata), at: neighbor)
                work.append(.retryNeighbor(neighbor, moving: moving))
                if flowAreaLoaded(at: neighbor, world: world) {
                    work.append(.tick(FluidSimulation.Tick(at: neighbor), suppressed: true))
                }
            case .retryNeighbor(let neighbor, let moving):
                if world[neighbor] == moving && flowAreaLoaded(at: neighbor, world: world) {
                    work.append(.tick(FluidSimulation.Tick(at: neighbor), suppressed: true))
                }
            }
        }
    }

    private static func flowAreaLoaded(at p: BlockPosition, world: BlockWorld) -> Bool {
        let chunksX = ((p.x - 8) >> 4)...((p.x + 8) >> 4)
        let chunksZ = ((p.z - 8) >> 4)...((p.z + 8) >> 4)
        return chunksX.allSatisfy { x in
            chunksZ.allSatisfy { z in world.chunks[ChunkPosition(x: x, z: z)] != nil }
        }
    }
}
