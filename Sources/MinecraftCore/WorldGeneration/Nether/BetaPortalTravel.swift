import Foundation

public enum BetaPortalTravel {
    /// Searches loaded chunks within the original 128-block horizontal radius.
    public static func existing(in world: BlockWorld, near: SIMD3<Double>) -> SIMD3<Double>? {
        let centerX = Int(floor(near.x))
        let centerZ = Int(floor(near.z))
        var best: BlockPosition?
        var bestDistance = -1.0
        for (chunkPosition, chunk) in world.chunks {
            if chunkPosition.x * 16 > centerX + 128 || chunkPosition.x * 16 + 15 < centerX - 128
                || chunkPosition.z * 16 > centerZ + 128 || chunkPosition.z * 16 + 15 < centerZ - 128
            {
                continue
            }
            for index in chunk.blockIDs.indices where chunk.blockIDs[index] == BlockKind.portal.rawValue {
                let x = chunkPosition.x * 16 + (index >> 11)
                let y = index & 127
                let z = chunkPosition.z * 16 + ((index >> 7) & 15)
                guard abs(x - centerX) <= 128, abs(z - centerZ) <= 128,
                    world[BlockPosition(x, y - 1, z)] != .portal
                else { continue }
                let dx = Double(x) + 0.5 - near.x
                let dy = Double(y) + 0.5 - near.y
                let dz = Double(z) + 0.5 - near.z
                let distance = dx * dx + dy * dy + dz * dz
                let candidate = BlockPosition(x, y, z)
                let earlier =
                    best.map {
                        if x != $0.x { return x < $0.x }
                        if z != $0.z { return z < $0.z }
                        return y > $0.y
                    } ?? true
                if bestDistance < 0 || distance < bestDistance || (distance == bestDistance && earlier) {
                    best = candidate
                    bestDistance = distance
                }
            }
        }
        guard let best else { return nil }
        var position = SIMD3(Double(best.x) + 0.5, Double(best.y) + 0.5, Double(best.z) + 0.5)
        if world[best.adding(BlockPosition(-1, 0, 0))] == .portal { position.x -= 0.5 }
        if world[best.adding(BlockPosition(1, 0, 0))] == .portal { position.x += 0.5 }
        if world[best.adding(BlockPosition(0, 0, -1))] == .portal { position.z -= 0.5 }
        if world[best.adding(BlockPosition(0, 0, 1))] == .portal { position.z += 0.5 }
        return position
    }

    /// Returns position only; the caller preserves yaw and resets pitch and velocity.
    public static func place(world: inout BlockWorld, near: SIMD3<Double>, yaw: Float) -> SIMD3<Double> {
        var random = JavaRandom(seed: world.seed ^ Int64(truncatingIfNeeded: world.revision))
        return place(world: &world, near: near, yaw: yaw, random: &random)
    }

    public static func place(
        world: inout BlockWorld, near: SIMD3<Double>, yaw: Float,
        random: inout JavaRandom
    ) -> SIMD3<Double> {
        if let position = existing(in: world, near: near) { return position }
        create(world: &world, near: near, random: &random)
        return existing(in: world, near: near) ?? near
    }

    private struct Site {
        var position: BlockPosition
        var orientation: Int
        var distance: Double
    }

    private static func air(_ p: BlockPosition, world: BlockWorld) -> Bool {
        world.chunks[p.chunk] != nil && world[p] == nil
    }

    private static func directions(_ orientation: Int, signed: Bool = true) -> (x: Int, z: Int) {
        var x = orientation % 2
        var z = 1 - x
        if signed && orientation % 4 >= 2 {
            x = -x
            z = -z
        }
        return (x, z)
    }

    private static func clear(at p: BlockPosition, orientation: Int, deep: Bool, world: BlockWorld) -> Bool {
        let direction = directions(orientation, signed: deep)
        for depth in 0..<(deep ? 3 : 1) {
            for width in 0..<4 {
                for height in -1..<4 {
                    let target = BlockPosition(
                        p.x + (width - 1) * direction.x + depth * direction.z,
                        p.y + height,
                        p.z + (width - 1) * direction.z - depth * direction.x)
                    if height < 0 {
                        if world[target]?.isMaterialSolid != true { return false }
                    } else if !air(target, world: world) {
                        return false
                    }
                }
            }
        }
        return true
    }

    private static func findSite(world: BlockWorld, near: SIMD3<Double>, start: Int, deep: Bool) -> Site? {
        let centerX = Int(floor(near.x))
        let centerZ = Int(floor(near.z))
        var best: Site?
        for x in (centerX - 16)...(centerX + 16) {
            let dx = Double(x) + 0.5 - near.x
            for z in (centerZ - 16)...(centerZ + 16) {
                if world.chunks[ChunkPosition(x: x >> 4, z: z >> 4)] == nil { continue }
                let dz = Double(z) + 0.5 - near.z
                var y = 127
                scan: while y >= 0 {
                    if air(BlockPosition(x, y, z), world: world) {
                        while y > 0 && air(BlockPosition(x, y - 1, z), world: world) { y -= 1 }
                        for orientation in start..<(start + (deep ? 4 : 2)) {
                            let position = BlockPosition(x, y, z)
                            if !clear(at: position, orientation: orientation, deep: deep, world: world) {
                                y -= 1
                                continue scan
                            }
                            let dy = Double(y) + 0.5 - near.y
                            let distance = dx * dx + dy * dy + dz * dz
                            if best == nil || distance < best!.distance {
                                best = Site(
                                    position: position, orientation: orientation % (deep ? 4 : 2),
                                    distance: distance)
                            }
                        }
                    }
                    y -= 1
                }
            }
        }
        return best
    }

    private static func create(world: inout BlockWorld, near: SIMD3<Double>, random: inout JavaRandom) {
        let start = random.nextInt(bound: 4)
        let site =
            findSite(world: world, near: near, start: start, deep: true)
            ?? findSite(world: world, near: near, start: start, deep: false)
        var origin =
            site?.position ?? BlockPosition(Int(floor(near.x)), Int(floor(near.y)), Int(floor(near.z)))
        let direction = directions(site?.orientation ?? 0)
        for width in 0..<4 {
            let p = BlockPosition(
                origin.x + (width - 1) * direction.x, origin.y,
                origin.z + (width - 1) * direction.z)
            if world.chunks[p.chunk] == nil { return }
        }
        if site == nil {
            origin.y = min(118, max(70, origin.y))
            let required = (-1...1).allSatisfy { depth in
                (1..<3).allSatisfy { width in
                    let target = BlockPosition(
                        origin.x + (width - 1) * direction.x + depth * direction.z,
                        origin.y, origin.z + (width - 1) * direction.z - depth * direction.x)
                    return world.chunks[target.chunk] != nil
                }
            }
            if !required { return }
            for depth in -1...1 {
                for width in 1..<3 {
                    for height in -1..<3 {
                        let p = BlockPosition(
                            origin.x + (width - 1) * direction.x + depth * direction.z,
                            origin.y + height, origin.z + (width - 1) * direction.z - depth * direction.x)
                        world[p] = height < 0 ? .obsidian : nil
                    }
                }
            }
        }
        for _ in 0..<4 {
            for width in 0..<4 {
                for height in -1..<4 {
                    let p = BlockPosition(
                        origin.x + (width - 1) * direction.x, origin.y + height,
                        origin.z + (width - 1) * direction.z)
                    let frame = width == 0 || width == 3 || height == -1 || height == 3
                    world[p] = frame ? .obsidian : .portal
                }
            }
        }
    }
}
