public enum BlockMining {
    public static func hardness(of block: BlockKind) -> Float { hardnessByID[Int(block.rawValue)] }

    public static func canHarvest(_ block: BlockKind, with tool: ItemStack?) -> Bool {
        let id = block.rawValue
        if !requiresTool.contains(id) { return true }
        guard let tool else { return false }
        switch tool.id {
        case 270, 285: return pickaxeHarvest[0].contains(id)
        case 274: return pickaxeHarvest[1].contains(id)
        case 257: return pickaxeHarvest[2].contains(id)
        case 278: return pickaxeHarvest[3].contains(id)
        case 256, 269, 273, 277, 284: return id == 78 || id == 80
        case 267, 268, 272, 276, 283, 359: return id == 30
        default: return false
        }
    }

    public static func speed(for block: BlockKind, with tool: ItemStack?) -> Float {
        guard let tool else { return 1 }
        let blockID = block.rawValue
        if swordIDs.contains(tool.id) { return blockID == 30 ? 15 : 1.5 }
        if tool.id == 359 {
            if blockID == 18 || blockID == 30 { return 15 }
            return blockID == 35 ? 5 : 1
        }
        guard let properties = tools[tool.id], properties.blocks.contains(blockID) else { return 1 }
        return properties.speed
    }

    public static func progressPerTick(
        for block: BlockKind, with tool: ItemStack?, underwater: Bool = false, onGround: Bool = true
    ) -> Float {
        let hardness = hardness(of: block)
        if hardness < 0 { return 0 }
        if hardness == 0 { return 1 }
        if !canHarvest(block, with: tool) { return 1 / hardness / 100 }
        var strength = speed(for: block, with: tool)
        if underwater { strength /= 5 }
        if !onGround { strength /= 5 }
        return strength / hardness / 30
    }

    public static func durabilityCost(on block: BlockKind, with tool: ItemStack?) -> Int {
        guard let tool else { return 0 }
        if swordIDs.contains(tool.id) { return 2 }
        if tools[tool.id] != nil { return 1 }
        return tool.id == 359 && (block.rawValue == 18 || block.rawValue == 30) ? 1 : 0
    }

    public static func durabilityCostHittingEntity(with tool: ItemStack?) -> Int {
        guard let tool else { return 0 }
        if swordIDs.contains(tool.id) { return 1 }
        return tools[tool.id] != nil ? 2 : 0
    }

    public static func recordsUseWhenMining(with tool: ItemStack?) -> Bool {
        guard let tool else { return false }
        return swordIDs.contains(tool.id) || tools[tool.id] != nil
    }

    public static func drops(
        for state: BlockState, with tool: ItemStack?, requiresHarvest: Bool = true,
        roll: (Int) -> Int = { Int.random(in: 0..<$0) }
    ) -> [ItemStack] {
        let block = state.kind
        guard hardness(of: block) >= 0, !requiresHarvest || canHarvest(block, with: tool) else { return [] }
        let metadata = UInt16(state.metadata)
        switch block.rawValue {
        case 0, 8...11, 20, 32, 34, 36, 47, 51, 52, 79, 90, 92: return []
        case 46: return tool?.id == 259 || state.metadata & 1 != 0 ? [] : [ItemStack(id: 46)]
        case 1: return [ItemStack(id: 4)]
        case 2, 60: return [ItemStack(id: 3)]
        case 6: return [ItemStack(id: 6, damage: metadata & 3)]
        case 13: return [ItemStack(id: roll(10) == 0 ? 318 : 13)]
        case 16: return [ItemStack(id: 263)]
        case 17, 35, 44: return [ItemStack(id: UInt16(block.rawValue), damage: metadata)]
        case 18:
            if tool?.id == 359 { return [ItemStack(id: 18, damage: metadata & 3)] }
            return roll(20) == 0 ? [ItemStack(id: 6, damage: metadata & 3)] : []
        case 21: return [ItemStack(id: 351, count: 4 + roll(5), damage: 4)]
        case 26: return metadata & 8 == 0 ? [ItemStack(id: 355)] : []
        case 30: return [ItemStack(id: 287)]
        case 31: return roll(8) == 0 ? [ItemStack(id: 295)] : []
        case 43: return [ItemStack(id: 44, count: 2, damage: metadata)]
        case 53: return [ItemStack(id: 5)]
        case 55: return [ItemStack(id: 331)]
        case 56: return [ItemStack(id: 264)]
        case 59:
            var drops = metadata == 7 ? [ItemStack(id: 296)] : []
            let seeds = (0..<3).filter { _ in roll(15) <= metadata }.count
            if seeds > 0 { drops.append(ItemStack(id: 295, count: seeds)) }
            return drops
        case 62: return [ItemStack(id: 61)]
        case 63, 68: return [ItemStack(id: 323)]
        case 64: return metadata & 8 == 0 ? [ItemStack(id: 324)] : []
        case 67: return [ItemStack(id: 4)]
        case 71: return metadata & 8 == 0 ? [ItemStack(id: 330)] : []
        case 73, 74: return [ItemStack(id: 331, count: 4 + roll(2))]
        case 75: return [ItemStack(id: 76)]
        case 78: return [ItemStack(id: 332)]
        case 80: return [ItemStack(id: 332, count: 4)]
        case 82: return [ItemStack(id: 337, count: 4)]
        case 83: return [ItemStack(id: 338)]
        case 89: return [ItemStack(id: 348, count: 2 + roll(3))]
        case 93, 94: return [ItemStack(id: 356)]
        default: return [ItemStack(id: UInt16(block.rawValue))]
        }
    }

    public static func explosionDrops(
        for state: BlockState, roll: (Int) -> Int = { Int.random(in: 0..<$0) }
    ) -> [ItemStack] {
        if state.kind == .snowLayer || state.kind == .tnt { return [] }
        return drops(for: state, with: nil, requiresHarvest: false, roll: roll)
    }

    private struct Tool: Sendable {
        let speed: Float
        let blocks: Set<UInt8>
    }

    private static let shovelBlocks: Set<UInt8> = [2, 3, 12, 13, 60, 78, 80, 82]
    private static let pickaxeBlocks: Set<UInt8> = [
        1, 4, 14, 15, 16, 21, 22, 24, 41, 42, 43, 44, 48, 56, 57, 79, 87,
    ]
    private static let axeBlocks: Set<UInt8> = [5, 17, 47, 54]
    private static let swordIDs: Set<UInt16> = [267, 268, 272, 276, 283]
    private static let tools: [UInt16: Tool] = [
        256: Tool(speed: 6, blocks: shovelBlocks), 269: Tool(speed: 2, blocks: shovelBlocks),
        273: Tool(speed: 4, blocks: shovelBlocks), 277: Tool(speed: 8, blocks: shovelBlocks),
        284: Tool(speed: 12, blocks: shovelBlocks),
        257: Tool(speed: 6, blocks: pickaxeBlocks), 270: Tool(speed: 2, blocks: pickaxeBlocks),
        274: Tool(speed: 4, blocks: pickaxeBlocks), 278: Tool(speed: 8, blocks: pickaxeBlocks),
        285: Tool(speed: 12, blocks: pickaxeBlocks),
        258: Tool(speed: 6, blocks: axeBlocks), 271: Tool(speed: 2, blocks: axeBlocks),
        275: Tool(speed: 4, blocks: axeBlocks), 279: Tool(speed: 8, blocks: axeBlocks),
        286: Tool(speed: 12, blocks: axeBlocks),
    ]
    private static let requiresTool: Set<UInt8> = [
        1, 4, 7, 14, 15, 16, 21, 22, 23, 24, 30, 41, 42, 43, 44, 45, 48, 49, 52, 56, 57, 61, 62, 67, 70, 71,
        73, 74, 78, 80, 87, 89,
    ]
    private static let pickaxeHarvest: [Set<UInt8>] = [
        [1, 4, 7, 16, 23, 24, 43, 44, 45, 48, 52, 61, 62, 67, 70, 71, 87, 89],
        [1, 4, 7, 15, 16, 21, 22, 23, 24, 42, 43, 44, 45, 48, 52, 61, 62, 67, 70, 71, 87, 89],
        [
            1, 4, 7, 14, 15, 16, 21, 22, 23, 24, 41, 42, 43, 44, 45, 48, 52, 56, 57, 61, 62, 67, 70, 71, 73,
            74, 87, 89,
        ],
        [
            1, 4, 7, 14, 15, 16, 21, 22, 23, 24, 41, 42, 43, 44, 45, 48, 49, 52, 56, 57, 61, 62, 67, 70, 71,
            73, 74, 87, 89,
        ],
    ]
    private static let hardnessByID: [Float] = [
        0.0, 1.5, 0.6, 0.5, 2.0, 2.0, 0.0, -1.0, 100.0, 100.0, 0.0, 100.0,
        0.5, 0.6, 3.0, 3.0, 3.0, 2.0, 0.2, 0.6, 0.3, 3.0, 3.0, 3.5,
        0.8, 0.8, 0.2, 0.7, 0.7, 0.5, 4.0, 0.0, 0.0, 0.5, 0.5, 0.8,
        -1.0, 0.0, 0.0, 0.0, 0.0, 3.0, 5.0, 2.0, 2.0, 2.0, 0.0, 1.5,
        2.0, 10.0, 0.0, 0.0, 5.0, 2.0, 2.5, 0.0, 3.0, 5.0, 2.5, 0.0,
        0.6, 3.5, 3.5, 1.0, 3.0, 0.4, 0.7, 2.0, 1.0, 0.5, 0.5, 5.0,
        0.5, 3.0, 3.0, 0.0, 0.0, 0.5, 0.1, 0.5, 0.2, 0.4, 0.6, 0.0,
        2.0, 2.0, 1.0, 0.4, 0.5, 0.3, -1.0, 1.0, 0.5, 0.0, 0.0, 0.0,
        3.0,
    ]
}
