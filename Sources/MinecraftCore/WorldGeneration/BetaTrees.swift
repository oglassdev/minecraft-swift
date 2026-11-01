public enum BetaTreeKind: Sendable {
    case oak, bigOak, birch, pine, spruce
}

public enum BetaTrees {
    @discardableResult
    public static func generate(
        _ kind: BetaTreeKind, at position: BlockPosition,
        world: inout BlockWorld, random: inout JavaRandom
    ) -> Bool {
        switch kind {
        case .oak, .birch:
            return broadleaf(at: position, birch: kind == .birch, world: &world, random: &random)
        case .pine:
            return pine(at: position, world: &world, random: &random)
        case .spruce:
            return spruce(at: position, world: &world, random: &random)
        case .bigOak:
            var tree = BetaBigOak(seed: random.nextLong(), origin: position)
            return tree.generate(world: &world)
        }
    }

    private static func clear(
        world: BlockWorld, position: BlockPosition,
        height: Int, radius: (Int) -> Int
    ) -> Bool {
        guard position.y >= 1 && position.y + height + 1 <= 128 else { return false }
        for y in position.y...(position.y + height + 1) {
            let distance = radius(y - position.y)
            for x in (position.x - distance)...(position.x + distance) {
                for z in (position.z - distance)...(position.z + distance) {
                    guard y >= 0 && y < 128 else { return false }
                    let kind = world[BlockPosition(x, y, z)]
                    if kind != nil && kind != .leaves { return false }
                }
            }
        }
        return true
    }

    private static func groundIsValid(world: BlockWorld, position: BlockPosition, height: Int) -> Bool {
        let ground = world[BlockPosition(position.x, position.y - 1, position.z)]
        return (ground == .grass || ground == .dirt) && position.y < 128 - height - 1
    }

    private static func leaf(_ position: BlockPosition, metadata: UInt8, world: inout BlockWorld) {
        if world[position]?.isOpaque != true {
            world.setBlock(BlockState(.leaves, metadata: metadata), at: position)
        }
    }

    private static func trunk(
        _ position: BlockPosition, height: Int, metadata: UInt8, world: inout BlockWorld
    ) {
        if height <= 0 { return }
        for dy in 0..<height {
            let target = BlockPosition(position.x, position.y + dy, position.z)
            if world[target] == nil || world[target] == .leaves {
                world.setBlock(BlockState(.wood, metadata: metadata), at: target)
            }
        }
    }

    private static func broadleaf(
        at p: BlockPosition, birch: Bool,
        world: inout BlockWorld, random: inout JavaRandom
    ) -> Bool {
        let height = random.nextInt(bound: 3) + (birch ? 5 : 4)
        guard
            clear(
                world: world, position: p, height: height,
                radius: { offset in
                    if offset == 0 { return 0 }
                    return offset >= height - 1 ? 2 : 1
                }), groundIsValid(world: world, position: p, height: height)
        else { return false }
        world[BlockPosition(p.x, p.y - 1, p.z)] = .dirt
        let metadata: UInt8 = birch ? 2 : 0
        for y in (p.y - 3 + height)...(p.y + height) {
            let relativeY = y - (p.y + height)
            let radius = 1 - relativeY / 2
            for x in (p.x - radius)...(p.x + radius) {
                let dx = x - p.x
                for z in (p.z - radius)...(p.z + radius) {
                    let dz = z - p.z
                    if abs(dx) != radius || abs(dz) != radius
                        || (random.nextInt(bound: 2) != 0 && relativeY != 0)
                    {
                        leaf(BlockPosition(x, y, z), metadata: metadata, world: &world)
                    }
                }
            }
        }
        trunk(p, height: height, metadata: metadata, world: &world)
        return true
    }

    private static func pine(at p: BlockPosition, world: inout BlockWorld, random: inout JavaRandom) -> Bool {
        let height = random.nextInt(bound: 5) + 7
        let trunkHeight = height - random.nextInt(bound: 2) - 3
        let crownHeight = height - trunkHeight
        let maximumRadius = 1 + random.nextInt(bound: crownHeight + 1)
        guard
            clear(
                world: world, position: p, height: height, radius: { $0 < trunkHeight ? 0 : maximumRadius }),
            groundIsValid(world: world, position: p, height: height)
        else { return false }
        world[BlockPosition(p.x, p.y - 1, p.z)] = .dirt
        var radius = 0
        for y in ((p.y + trunkHeight)...(p.y + height)).reversed() {
            for x in (p.x - radius)...(p.x + radius) {
                for z in (p.z - radius)...(p.z + radius) {
                    if abs(x - p.x) != radius || abs(z - p.z) != radius || radius <= 0 {
                        leaf(BlockPosition(x, y, z), metadata: 1, world: &world)
                    }
                }
            }
            if radius >= 1 && y == p.y + trunkHeight + 1 {
                radius -= 1
            } else if radius < maximumRadius {
                radius += 1
            }
        }
        trunk(p, height: height - 1, metadata: 1, world: &world)
        return true
    }

    private static func spruce(at p: BlockPosition, world: inout BlockWorld, random: inout JavaRandom) -> Bool
    {
        let height = random.nextInt(bound: 4) + 6
        let trunkHeight = 1 + random.nextInt(bound: 2)
        let crownHeight = height - trunkHeight
        let maximumRadius = 2 + random.nextInt(bound: 2)
        guard
            clear(
                world: world, position: p, height: height, radius: { $0 < trunkHeight ? 0 : maximumRadius }),
            groundIsValid(world: world, position: p, height: height)
        else { return false }
        world[BlockPosition(p.x, p.y - 1, p.z)] = .dirt
        var radius = random.nextInt(bound: 2)
        var radiusLimit = 1
        var restartRadius = 0
        for offset in 0...crownHeight {
            let y = p.y + height - offset
            for x in (p.x - radius)...(p.x + radius) {
                for z in (p.z - radius)...(p.z + radius) {
                    if abs(x - p.x) != radius || abs(z - p.z) != radius || radius <= 0 {
                        leaf(BlockPosition(x, y, z), metadata: 1, world: &world)
                    }
                }
            }
            if radius >= radiusLimit {
                radius = restartRadius
                restartRadius = 1
                radiusLimit = min(radiusLimit + 1, maximumRadius)
            } else {
                radius += 1
            }
        }
        let trim = random.nextInt(bound: 3)
        trunk(p, height: height - trim, metadata: 1, world: &world)
        return true
    }
}
