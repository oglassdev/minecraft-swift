public struct BetaPopulationResult: Sendable {
    public internal(set) var chests: [BlockPosition: [ItemStack?]] = [:]
    public internal(set) var spawners: [BlockPosition: String] = [:]
}

enum BetaDungeons {
    static func generate(
        at p: BlockPosition, world: inout BlockWorld, random: inout JavaRandom,
        result: inout BetaPopulationResult
    ) {
        let radiusX = random.nextInt(bound: 2) + 2
        let radiusZ = random.nextInt(bound: 2) + 2
        let minX = p.x - radiusX - 1
        let maxX = p.x + radiusX + 1
        let minZ = p.z - radiusZ - 1
        let maxZ = p.z + radiusZ + 1
        var openings = 0
        for x in minX...maxX {
            for y in (p.y - 1)...(p.y + 4) {
                for z in minZ...maxZ {
                    let kind = world[BlockPosition(x, y, z)]
                    if (y == p.y - 1 || y == p.y + 4) && !BetaPopulationFeatures.solid(kind) { return }
                    if (x == minX || x == maxX || z == minZ || z == maxZ)
                        && y == p.y && kind == nil && world[BlockPosition(x, y + 1, z)] == nil
                    {
                        openings += 1
                    }
                }
            }
        }
        guard openings >= 1 && openings <= 5 else { return }
        for x in minX...maxX {
            for y in ((p.y - 1)...(p.y + 3)).reversed() {
                for z in minZ...maxZ {
                    let position = BlockPosition(x, y, z)
                    if x != minX && y != p.y - 1 && z != minZ && x != maxX && z != maxZ {
                        world[position] = nil
                    } else if y >= 0 && !BetaPopulationFeatures.solid(world[BlockPosition(x, y - 1, z)]) {
                        world[position] = nil
                    } else if BetaPopulationFeatures.solid(world[position]) {
                        world[position] =
                            y == p.y - 1 && random.nextInt(bound: 4) != 0 ? .mossyCobblestone : .cobblestone
                    }
                }
            }
        }
        for _ in 0..<2 {
            for _ in 0..<3 {
                let x = p.x + random.nextInt(bound: radiusX * 2 + 1) - radiusX
                let z = p.z + random.nextInt(bound: radiusZ * 2 + 1) - radiusZ
                let position = BlockPosition(x, p.y, z)
                if world[position] == nil {
                    let walls = BetaPopulationFeatures.horizontal.filter {
                        BetaPopulationFeatures.solid(world[BlockPosition(x + $0.x, p.y, z + $0.z)])
                    }.count
                    if walls == 1 {
                        world[position] = .chest
                        var slots = [ItemStack?](repeating: nil, count: 27)
                        for _ in 0..<8 {
                            if let stack = loot(random: &random) { slots[random.nextInt(bound: 27)] = stack }
                        }
                        result.chests[position] = slots
                        break
                    }
                }
            }
        }
        world[p] = .spawner
        result.spawners[p] = ["Skeleton", "Zombie", "Zombie", "Spider"][random.nextInt(bound: 4)]
    }

    private static func loot(random: inout JavaRandom) -> ItemStack? {
        switch random.nextInt(bound: 11) {
        case 0: return ItemStack(id: 329)
        case 1: return ItemStack(id: 265, count: random.nextInt(bound: 4) + 1)
        case 2: return ItemStack(id: 297)
        case 3: return ItemStack(id: 296, count: random.nextInt(bound: 4) + 1)
        case 4: return ItemStack(id: 289, count: random.nextInt(bound: 4) + 1)
        case 5: return ItemStack(id: 287, count: random.nextInt(bound: 4) + 1)
        case 6: return ItemStack(id: 325)
        case 7: return random.nextInt(bound: 100) == 0 ? ItemStack(id: 322) : nil
        case 8:
            return random.nextInt(bound: 2) == 0
                ? ItemStack(id: 331, count: random.nextInt(bound: 4) + 1) : nil
        case 9:
            return random.nextInt(bound: 10) == 0
                ? ItemStack(id: UInt16(2256 + random.nextInt(bound: 2))) : nil
        case 10: return ItemStack(id: 351, damage: 3)
        default: return nil
        }
    }
}
