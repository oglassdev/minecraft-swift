import Foundation

extension EntitySimulation {
    mutating func spawnNatural(in world: BlockWorld, near player: Player, time: Int64) {
        guard player.health > 0 else { return }
        let center = ChunkPosition(Int(floor(player.position.x / 16)), Int(floor(player.position.z / 16)))
        let chunks = Self.spawningChunks(around: center, warmed: spawnSetWarmed).filter {
            world.chunks[$0] != nil
        }
        spawnSetWarmed = true
        for category in 0..<3 {
            let population = entities.filter { Self.spawnCategory($0.kind) == category }.count
            guard population <= [70, 15, 5][category] * 289 / 256 else { continue }
            for chunk in chunks {
                let choices = spawnChoices(in: world, chunk: chunk, category: category)
                guard !choices.isEmpty else { continue }
                var roll = random.nextInt(bound: choices.reduce(0) { $0 + $1.1 })
                var kind = choices[0].0
                for choice in choices {
                    roll -= choice.1
                    if roll < 0 {
                        kind = choice.0
                        break
                    }
                }
                let initial = BlockPosition(
                    chunk.x * 16 + random.nextInt(bound: 16), random.nextInt(bound: 128),
                    chunk.z * 16 + random.nextInt(bound: 16))
                guard world[initial]?.isOpaque != true else { continue }
                if category == 2 {
                    guard world[initial] == .water || world[initial] == .stillWater else { continue }
                } else {
                    guard world[initial] == nil else { continue }
                }
                var spawned = 0
                let limit = kind == "ghast" ? 1 : (kind == "wolf" ? 8 : 4)
                pack: for _ in 0..<3 {
                    var candidate = initial
                    for _ in 0..<4 {
                        candidate.x += random.nextInt(bound: 6) - random.nextInt(bound: 6)
                        candidate.y += random.nextInt(bound: 1) - random.nextInt(bound: 1)
                        candidate.z += random.nextInt(bound: 6) - random.nextInt(bound: 6)
                        guard world.chunks[candidate.chunk] != nil,
                            Self.spawnSurface(in: world, at: candidate, water: category == 2)
                        else { continue }
                        let position = SIMD3(
                            Double(Float(candidate.x) + 0.5), Double(Float(candidate.y)),
                            Double(Float(candidate.z) + 0.5))
                        guard EntityMotion.squaredLength(position - player.position) >= 576 else { continue }
                        let spawnDelta = SIMD3<Float>(position - spawnPosition)
                        guard
                            spawnDelta.x * spawnDelta.x + spawnDelta.y * spawnDelta.y + spawnDelta.z
                                * spawnDelta.z >= 576
                        else { continue }
                        var probe = GameEntity(id: 0, kind: kind, position: position)
                        if kind == "slime" {
                            probe.metadata = UInt8(1 << random.nextInt(bound: 3))
                            probe.width = Double(Float(0.6) * Float(probe.metadata))
                            probe.height = probe.width
                        }
                        let yaw = random.nextFloat() * 2 * BetaMath.pi
                        guard canSpawnNaturally(probe, in: world, time: time, difficulty: player.difficulty)
                        else { continue }
                        let id = spawn(
                            kind: kind, position: position, metadata: kind == "slime" ? probe.metadata : nil)
                        entities[entities.count - 1].yaw = yaw
                        if kind == "spider", random.nextInt(bound: 100) == 0 {
                            spawn(kind: "skeleton", position: position)
                            entities[entities.count - 1].yaw = yaw
                            if let spiderIndex = entities.firstIndex(where: { $0.id == id }) {
                                entities[spiderIndex].riderID = entities.last?.id
                            }
                        }
                        spawned += 1
                        if spawned >= limit { break pack }
                    }
                }
            }
        }
    }

    private func spawnChoices(in world: BlockWorld, chunk: ChunkPosition, category: Int) -> [(String, Int)] {
        if world.dimension == -1 { return category == 0 ? [("ghast", 10), ("pigZombie", 10)] : [] }
        if category == 0 {
            return [("spider", 10), ("zombie", 10), ("skeleton", 10), ("creeper", 10), ("slime", 10)]
        }
        if category == 2 { return [("squid", 10)] }
        let climate = world.climate(atX: chunk.x * 16 + 8, z: chunk.z * 16 + 8)
        let biome = BetaBiome.lookup(temperature: climate.temperature, humidity: climate.humidity)
        return [("sheep", 12), ("pig", 10), ("chicken", 10), ("cow", 8)]
            + ((biome == .forest || biome == .taiga) ? [("wolf", 2)] : [])
    }

    static func spawnSurface(in world: BlockWorld, at p: BlockPosition, water: Bool) -> Bool {
        guard world[BlockPosition(p.x, p.y + 1, p.z)]?.isOpaque != true else { return false }
        if water { return world[p]?.isLiquid == true }
        return world[BlockPosition(p.x, p.y - 1, p.z)]?.isOpaque == true && world[p]?.isOpaque != true
            && world[p]?.isLiquid != true
    }

    mutating func canSpawnNaturally(_ entity: GameEntity, in world: BlockWorld, time: Int64, difficulty: Int)
        -> Bool
    {
        let p = BlockPosition(
            Int(floor(entity.position.x)), Int(floor(entity.bounds.min.y)), Int(floor(entity.position.z)))
        if entity.kind == "slime" {
            let x = Int32(truncatingIfNeeded: p.chunk.x)
            let z = Int32(truncatingIfNeeded: p.chunk.z)
            let first = Int64(x &* x &* 4_987_142)
            let second = Int64(x &* 5_947_611)
            let third = Int64(z &* z) &* 4_392_871
            let fourth = Int64(z &* 389_711)
            var slimeRandom = JavaRandom(
                seed: (world.seed &+ first &+ second &+ third &+ fourth) ^ 987_234_911)
            return (entity.metadata == 1 || difficulty > 0) && random.nextInt(bound: 10) == 0
                && slimeRandom.nextInt(bound: 10) == 0 && entity.position.y < 16
        }
        if entity.kind == "ghast", random.nextInt(bound: 20) != 0 { return false }
        if entity.kind == "pigZombie" || entity.kind == "ghast" {
            guard difficulty > 0 else { return false }
        } else if Self.spawnCategory(entity.kind) == 0 {
            guard Int(world.light(at: p).sky) <= random.nextInt(bound: 32) else { return false }
            let darkening = thunderStrength * rainStrength > 0.9 ? 10 : nil as Int?
            let light = EntityMotion.light(
                in: world, position: p, time: time, rain: rainStrength, thunder: thunderStrength,
                darkeningOverride: darkening)
            guard light <= random.nextInt(bound: 8) else { return false }
        } else if Self.spawnCategory(entity.kind) == 1 {
            let light = world.light(at: p)
            guard world[BlockPosition(p.x, p.y - 1, p.z)] == .grass, max(light.sky, light.block) > 8 else {
                return false
            }
        }
        guard
            !entities.contains(where: {
                $0.health > 0
                    && ($0.isLiving || ["boat", "minecart", "primedTnt", "fallingSand"].contains($0.kind))
                    && $0.bounds.intersects(entity.bounds)
            })
        else {
            return false
        }
        if entity.kind == "squid" { return true }
        return BlockCollision.boxes(in: world, intersecting: entity.bounds).isEmpty
            && !EntityMotion.isFluid(in: world, bounds: entity.bounds, water: true)
            && !EntityMotion.isFluid(in: world, bounds: entity.bounds, water: false)
    }

    private static func spawnCategory(_ kind: String) -> Int? {
        switch kind {
        case "spider", "zombie", "skeleton", "creeper", "slime", "pigZombie", "ghast": 0
        case "sheep", "pig", "chicken", "cow", "wolf": 1
        case "squid": 2
        default: nil
        }
    }

    // Java 6 HashSet traversal determines which chunks consume the shared world RNG first.
    static func spawningChunks(around center: ChunkPosition, warmed: Bool = false) -> [ChunkPosition] {
        var buckets = [[ChunkPosition]](repeating: [], count: warmed ? 512 : 16)
        func hash(_ p: ChunkPosition) -> UInt32 {
            var h = UInt32(
                truncatingIfNeeded: (p.x < 0 ? Int(Int32.min) : 0) | ((p.x & 32767) << 16)
                    | (p.z < 0 ? 32768 : 0) | (p.z & 32767))
            h ^= (h >> 20) ^ (h >> 12)
            return h ^ (h >> 7) ^ (h >> 4)
        }
        var size = 0
        for x in -8...8 {
            for z in -8...8 {
                let p = ChunkPosition(center.x + x, center.z + z)
                let index = Int(hash(p)) & (buckets.count - 1)
                buckets[index].insert(p, at: 0)
                size += 1
                if size > buckets.count * 3 / 4 {
                    var expanded = [[ChunkPosition]](repeating: [], count: buckets.count * 2)
                    for bucket in buckets {
                        for value in bucket {
                            expanded[Int(hash(value)) & (expanded.count - 1)].insert(value, at: 0)
                        }
                    }
                    buckets = expanded
                }
            }
        }
        return buckets.flatMap { $0 }
    }
}
