public enum BlockKind: UInt8, CaseIterable, Codable, Sendable {
    case air = 0
    case stone, grass, dirt, cobblestone, planks, sapling, bedrock
    case water, stillWater, lava, stillLava, sand, gravel, goldOre, ironOre, coalOre
    case wood, leaves, sponge, glass, lapisOre, lapisBlock, dispenser, sandstone, noteBlock
    case bed, poweredRail, detectorRail, stickyPiston, cobweb, tallGrass, deadBush, piston, pistonHead
    case wool, movingPiston, dandelion, rose, brownMushroom, redMushroom, goldBlock, ironBlock
    case doubleSlab, slab, bricks, tnt, bookshelf, mossyCobblestone, obsidian, torch, fire, spawner
    case woodenStairs, chest, redstoneWire, diamondOre, diamondBlock, craftingTable, wheat, farmland
    case furnace, burningFurnace, standingSign, woodenDoor, ladder, rail, cobblestoneStairs, wallSign
    case lever, stonePressurePlate, ironDoor, woodenPressurePlate, redstoneOre, litRedstoneOre
    case redstoneTorchOff, redstoneTorch, stoneButton, snowLayer, ice, snow, cactus, clay, sugarCane
    case jukebox, fence, pumpkin, netherrack, soulSand, glowstone, portal, jackOLantern, cake
    case repeaterOff, repeaterOn, lockedChest, trapdoor

    public var isLiquid: Bool { self == .water || self == .stillWater || self == .lava || self == .stillLava }

    public var isSolid: Bool {
        switch self {
        case .air, .water, .stillWater, .lava, .stillLava, .sapling, .tallGrass, .deadBush,
            .dandelion, .rose, .brownMushroom, .redMushroom, .torch, .fire, .redstoneWire, .wheat,
            .ladder, .rail, .poweredRail, .detectorRail, .lever, .redstoneTorchOff, .redstoneTorch,
            .stoneButton, .sugarCane, .portal, .repeaterOff, .repeaterOn, .snowLayer:
            false
        default: true
        }
    }

    public var isOpaque: Bool {
        guard isSolid else { return false }
        return switch self {
        case .leaves, .cobweb, .glass, .ice, .slab, .bed, .stickyPiston, .piston, .pistonHead, .movingPiston,
            .woodenStairs,
            .spawner, .farmland, .woodenDoor, .cobblestoneStairs, .ironDoor, .snowLayer, .cactus,
            .fence, .cake, .trapdoor, .standingSign, .wallSign, .stonePressurePlate, .woodenPressurePlate:
            false
        default: true
        }
    }

    public var lightEmission: UInt8 {
        switch self {
        case .lava, .stillLava, .fire, .glowstone, .jackOLantern, .lockedChest: 15
        case .torch: 14
        case .burningFurnace: 13
        case .portal: 11
        case .litRedstoneOre, .repeaterOn: 9
        case .redstoneTorch: 7
        case .brownMushroom: 1
        default: 0
        }
    }

    public var lightOpacity: UInt8 {
        switch self {
        case .water, .stillWater, .ice: 3
        case .leaves, .cobweb: 1
        case .stone, .grass, .dirt, .cobblestone, .planks, .bedrock, .lava, .stillLava,
            .sand, .gravel, .goldOre, .ironOre, .coalOre, .wood, .sponge, .lapisOre, .lapisBlock,
            .dispenser, .sandstone, .noteBlock, .wool, .goldBlock, .ironBlock, .doubleSlab, .slab,
            .bricks, .tnt, .bookshelf, .mossyCobblestone, .obsidian, .woodenStairs, .chest,
            .diamondOre, .diamondBlock, .craftingTable, .farmland, .furnace, .burningFurnace,
            .cobblestoneStairs, .redstoneOre, .litRedstoneOre, .snow, .clay, .jukebox, .pumpkin,
            .netherrack, .soulSand, .glowstone, .jackOLantern, .lockedChest:
            15
        default: 0
        }
    }

    public var color: SIMD3<Float> {
        switch self {
        case .grass: SIMD3(0.36, 0.64, 0.24)
        case .dirt, .farmland: SIMD3(0.48, 0.31, 0.19)
        case .wood, .planks, .craftingTable, .chest: SIMD3(0.42, 0.28, 0.14)
        case .leaves, .sapling, .tallGrass: SIMD3(0.23, 0.48, 0.20)
        case .sand, .sandstone: SIMD3(0.82, 0.75, 0.50)
        case .water, .stillWater: SIMD3(0.18, 0.34, 0.79)
        case .lava, .stillLava: SIMD3(0.95, 0.30, 0.04)
        case .snow, .snowLayer: SIMD3(0.96, 0.98, 1)
        default: SIMD3(0.56, 0.59, 0.62)
        }
    }
}

public struct BlockState: Equatable, Codable, Sendable {
    public var kind: BlockKind
    public var metadata: UInt8

    public init(_ kind: BlockKind, metadata: UInt8 = 0) {
        self.kind = kind
        self.metadata = metadata & 15
    }
}
