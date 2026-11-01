public enum BlockDrops {
    public static func harvest(
        _ state: BlockState, at p: BlockPosition, with tool: ItemStack?, random: inout JavaRandom
    ) -> [BlockEvent] {
        guard BlockMining.canHarvest(state.kind, with: tool) else { return [] }
        if state.kind == .tnt {
            guard tool?.id != 259, state.metadata & 1 == 0 else { return [] }
            return [spawn(ItemStack(id: 46), at: p, random: &random)]
        }
        if state.kind == .snowLayer {
            return [spawn(ItemStack(id: 332), at: p, random: &random)]
        }
        if state.kind == .leaves && tool?.id == 359 {
            return [spawn(ItemStack(id: 18, damage: UInt16(state.metadata & 3)), at: p, random: &random)]
        }
        return destroy(state, at: p, random: &random)
    }

    public static func destroy(
        _ state: BlockState, at p: BlockPosition, chance: Float = 1, random: inout JavaRandom
    ) -> [BlockEvent] {
        if state.kind == .bed && state.metadata & 8 != 0 { return [] }
        var events: [BlockEvent] = []
        let quantity = quantity(for: state.kind, random: &random)
        for _ in 0..<quantity {
            if random.nextFloat() > chance { continue }
            let id = itemID(for: state, random: &random)
            if id > 0 {
                events.append(spawn(ItemStack(id: id, damage: metadata(for: state)), at: p, random: &random))
            }
        }
        if state.kind == .wheat {
            for _ in 0..<3 {
                if random.nextInt(bound: 15) <= Int(state.metadata) {
                    events.append(spawnWheatSeed(at: p, random: &random))
                }
            }
        }
        return events
    }

    private static func quantity(for kind: BlockKind, random: inout JavaRandom) -> Int {
        switch kind {
        case .air, .water, .stillWater, .lava, .stillLava, .glass, .pistonHead, .tnt, .bookshelf,
            .fire, .spawner, .snowLayer, .ice, .portal, .cake:
            return 0
        case .leaves: return random.nextInt(bound: 20) == 0 ? 1 : 0
        case .lapisOre: return 4 + random.nextInt(bound: 5)
        case .doubleSlab: return 2
        case .redstoneOre, .litRedstoneOre: return 4 + random.nextInt(bound: 2)
        case .snow, .clay: return 4
        case .glowstone: return 2 + random.nextInt(bound: 3)
        default: return 1
        }
    }

    private static func itemID(for state: BlockState, random: inout JavaRandom) -> UInt16 {
        switch state.kind {
        case .stone: return 4
        case .grass, .farmland: return 3
        case .gravel: return random.nextInt(bound: 10) == 0 ? 318 : 13
        case .coalOre: return 263
        case .leaves: return 6
        case .lapisOre: return 351
        case .bed: return state.metadata & 8 == 0 ? 355 : 0
        case .cobweb: return 287
        case .tallGrass: return random.nextInt(bound: 8) == 0 ? 295 : 0
        case .deadBush, .pistonHead, .movingPiston: return 0
        case .doubleSlab: return 44
        case .woodenStairs: return 5
        case .redstoneWire, .redstoneOre, .litRedstoneOre: return 331
        case .diamondOre: return 264
        case .wheat: return state.metadata == 7 ? 296 : 0
        case .burningFurnace: return 61
        case .standingSign, .wallSign: return 323
        case .woodenDoor: return state.metadata & 8 == 0 ? 324 : 0
        case .cobblestoneStairs: return 4
        case .ironDoor: return state.metadata & 8 == 0 ? 330 : 0
        case .redstoneTorchOff: return 76
        case .snowLayer, .snow: return 332
        case .clay: return 337
        case .sugarCane: return 338
        case .glowstone: return 348
        case .repeaterOff, .repeaterOn: return 356
        default: return UInt16(state.kind.rawValue)
        }
    }

    private static func metadata(for state: BlockState) -> UInt16 {
        switch state.kind {
        case .sapling, .leaves: return UInt16(state.metadata & 3)
        case .wood, .wool, .doubleSlab, .slab: return UInt16(state.metadata)
        case .lapisOre: return 4
        default: return 0
        }
    }

    private static func spawnWheatSeed(at p: BlockPosition, random: inout JavaRandom) -> BlockEvent {
        let spread: Float = 0.7
        let margin = (1 - spread) * 0.5
        let position = SIMD3(
            Double(Float(p.x) + (random.nextFloat() * spread + margin)),
            Double(Float(p.y) + (random.nextFloat() * spread + margin)),
            Double(Float(p.z) + (random.nextFloat() * spread + margin)))
        return .dropItem(position: position, stack: ItemStack(id: 295))
    }

    private static func spawn(_ stack: ItemStack, at p: BlockPosition, random: inout JavaRandom) -> BlockEvent
    {
        let spread: Float = 0.7
        let margin = Double(1 - spread) * 0.5
        let position = SIMD3(
            Double(p.x) + (Double(random.nextFloat() * spread) + margin),
            Double(p.y) + (Double(random.nextFloat() * spread) + margin),
            Double(p.z) + (Double(random.nextFloat() * spread) + margin))
        return .dropItem(position: position, stack: stack)
    }
}
