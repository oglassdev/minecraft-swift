public struct ItemDefinition: Sendable {
    public let id: UInt16
    public let name: String
    public let maximumStackSize: Int
    public let maximumDurability: Int
    public let iconIndex: Int
    public let hasSubtypes: Bool
    public let containerItemID: UInt16?
    public let foodHealing: Int
    public let attackDamage: Int
    /// Helmet, chestplate, leggings, boots are slots 0 through 3.
    public let armorSlot: Int?
    public let armorPoints: Int

    public var iconTexture: String { id < 256 ? "terrain" : "gui/items" }

    private init(
        id: UInt16, name: String, iconIndex: Int, maximumStackSize: Int = 64,
        maximumDurability: Int = 0, hasSubtypes: Bool = false, containerItemID: UInt16? = nil,
        foodHealing: Int = 0, attackDamage: Int = 1, armorSlot: Int? = nil, armorPoints: Int = 0
    ) {
        self.id = id
        self.name = name
        self.iconIndex = iconIndex
        self.maximumStackSize = maximumStackSize
        self.maximumDurability = maximumDurability
        self.hasSubtypes = hasSubtypes
        self.containerItemID = containerItemID
        self.foodHealing = foodHealing
        self.attackDamage = attackDamage
        self.armorSlot = armorSlot
        self.armorPoints = armorPoints
    }

    public static func definition(for id: UInt16) -> Self? { catalog[id] }

    public func iconIndex(damage: UInt16) -> Int {
        if let variants = Self.variantIcons[id] { return variants[Int(damage) & 15] }
        return iconIndex
    }

    public func name(damage: UInt16) -> String {
        if id == 263 && damage == 1 { return "Charcoal" }
        if id == 351 { return Self.dyeNames[Int(damage) & 15] }
        if id == 35 { return Self.woolNames[Int(damage) & 15] }
        if id == 44 {
            return ["Stone Slab", "Sandstone Slab", "Wooden Slab", "Cobblestone Slab"][Int(damage) & 3]
        }
        return name
    }

    private static let dyeNames = [
        "Ink Sac", "Rose Red", "Cactus Green", "Cocoa Beans", "Lapis Lazuli", "Purple Dye", "Cyan Dye",
        "Light Gray Dye", "Gray Dye", "Pink Dye", "Lime Dye", "Dandelion Yellow", "Light Blue Dye",
        "Magenta Dye", "Orange Dye", "Bone Meal",
    ]
    private static let woolNames = [
        "Wool", "Orange Wool", "Magenta Wool", "Light Blue Wool", "Yellow Wool", "Lime Wool", "Pink Wool",
        "Gray Wool", "Light Gray Wool", "Cyan Wool", "Purple Wool", "Blue Wool", "Brown Wool", "Green Wool",
        "Red Wool", "Black Wool",
    ]

    private static let variantIcons: [UInt16: [Int]] = [
        6: [15, 63, 79, 15, 15, 63, 79, 15, 15, 63, 79, 15, 15, 63, 79, 15],
        17: [20, 116, 117, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20],
        18: [52, 132, 52, 52, 52, 132, 52, 52, 52, 132, 52, 52, 52, 132, 52, 52],
        35: [113, 129, 145, 161, 177, 193, 209, 225, 114, 130, 146, 162, 178, 194, 210, 64],
        44: [5, 192, 4, 16, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6],
        351: [78, 94, 110, 126, 142, 158, 174, 190, 79, 95, 111, 127, 143, 159, 175, 191],
    ]

    // Catalog values were checked against the unmodified Beta 1.7.3 client.
    public static let all: [ItemDefinition] = [
        ItemDefinition(id: 1, name: "Stone", iconIndex: 1),
        ItemDefinition(id: 2, name: "Grass", iconIndex: 3),
        ItemDefinition(id: 3, name: "Dirt", iconIndex: 2),
        ItemDefinition(id: 4, name: "Cobblestone", iconIndex: 16),
        ItemDefinition(id: 5, name: "Wooden Planks", iconIndex: 4),
        ItemDefinition(id: 6, name: "Sapling", iconIndex: 15, hasSubtypes: true),
        ItemDefinition(id: 7, name: "Bedrock", iconIndex: 17),
        ItemDefinition(id: 8, name: "Water", iconIndex: 206),
        ItemDefinition(id: 9, name: "Water", iconIndex: 206),
        ItemDefinition(id: 10, name: "Lava", iconIndex: 238),
        ItemDefinition(id: 11, name: "Lava", iconIndex: 238),
        ItemDefinition(id: 12, name: "Sand", iconIndex: 18),
        ItemDefinition(id: 13, name: "Gravel", iconIndex: 19),
        ItemDefinition(id: 14, name: "Gold Ore", iconIndex: 32),
        ItemDefinition(id: 15, name: "Iron Ore", iconIndex: 33),
        ItemDefinition(id: 16, name: "Coal Ore", iconIndex: 34),
        ItemDefinition(id: 17, name: "Wood", iconIndex: 20, hasSubtypes: true),
        ItemDefinition(id: 18, name: "Leaves", iconIndex: 52, hasSubtypes: true),
        ItemDefinition(id: 19, name: "Sponge", iconIndex: 48),
        ItemDefinition(id: 20, name: "Glass", iconIndex: 49),
        ItemDefinition(id: 21, name: "Lapis Lazuli Ore", iconIndex: 160),
        ItemDefinition(id: 22, name: "Lapis Lazuli Block", iconIndex: 144),
        ItemDefinition(id: 23, name: "Dispenser", iconIndex: 45),
        ItemDefinition(id: 24, name: "Sandstone", iconIndex: 192),
        ItemDefinition(id: 25, name: "Note Block", iconIndex: 74),
        ItemDefinition(id: 26, name: "Bed", iconIndex: 134),
        ItemDefinition(id: 27, name: "Powered Rail", iconIndex: 179),
        ItemDefinition(id: 28, name: "Detector Rail", iconIndex: 195),
        ItemDefinition(id: 29, name: "Sticky Piston", iconIndex: 106),
        ItemDefinition(id: 30, name: "Cobweb", iconIndex: 11),
        ItemDefinition(id: 31, name: "Tall Grass", iconIndex: 39),
        ItemDefinition(id: 32, name: "Dead Bush", iconIndex: 55),
        ItemDefinition(id: 33, name: "Piston", iconIndex: 107),
        ItemDefinition(id: 34, name: "Piston Head", iconIndex: 107),
        ItemDefinition(id: 35, name: "Wool", iconIndex: 113, hasSubtypes: true),
        ItemDefinition(id: 36, name: "Moving Piston", iconIndex: 0),
        ItemDefinition(id: 37, name: "Flower", iconIndex: 13),
        ItemDefinition(id: 38, name: "Rose", iconIndex: 12),
        ItemDefinition(id: 39, name: "Brown Mushroom", iconIndex: 29),
        ItemDefinition(id: 40, name: "Red Mushroom", iconIndex: 28),
        ItemDefinition(id: 41, name: "Block of Gold", iconIndex: 23),
        ItemDefinition(id: 42, name: "Block of Iron", iconIndex: 22),
        ItemDefinition(id: 43, name: "Double Stone Slab", iconIndex: 5),
        ItemDefinition(id: 44, name: "Stone Slab", iconIndex: 5, hasSubtypes: true),
        ItemDefinition(id: 45, name: "Bricks", iconIndex: 7),
        ItemDefinition(id: 46, name: "TNT", iconIndex: 8),
        ItemDefinition(id: 47, name: "Bookshelf", iconIndex: 35),
        ItemDefinition(id: 48, name: "Moss Stone", iconIndex: 36),
        ItemDefinition(id: 49, name: "Obsidian", iconIndex: 37),
        ItemDefinition(id: 50, name: "Torch", iconIndex: 80),
        ItemDefinition(id: 51, name: "Fire", iconIndex: 31),
        ItemDefinition(id: 52, name: "Monster Spawner", iconIndex: 65),
        ItemDefinition(id: 53, name: "Wooden Stairs", iconIndex: 4),
        ItemDefinition(id: 54, name: "Chest", iconIndex: 26),
        ItemDefinition(id: 55, name: "Redstone Dust", iconIndex: 164),
        ItemDefinition(id: 56, name: "Diamond Ore", iconIndex: 50),
        ItemDefinition(id: 57, name: "Block of Diamond", iconIndex: 24),
        ItemDefinition(id: 58, name: "Crafting Table", iconIndex: 60),
        ItemDefinition(id: 59, name: "Crops", iconIndex: 88),
        ItemDefinition(id: 60, name: "Farmland", iconIndex: 87),
        ItemDefinition(id: 61, name: "Furnace", iconIndex: 45),
        ItemDefinition(id: 62, name: "Furnace", iconIndex: 45),
        ItemDefinition(id: 63, name: "Sign", iconIndex: 4),
        ItemDefinition(id: 64, name: "Wooden Door", iconIndex: 97),
        ItemDefinition(id: 65, name: "Ladder", iconIndex: 83),
        ItemDefinition(id: 66, name: "Rail", iconIndex: 128),
        ItemDefinition(id: 67, name: "Stone Stairs", iconIndex: 16),
        ItemDefinition(id: 68, name: "Sign", iconIndex: 4),
        ItemDefinition(id: 69, name: "Lever", iconIndex: 96),
        ItemDefinition(id: 70, name: "Stone Pressure Plate", iconIndex: 1),
        ItemDefinition(id: 71, name: "Iron Door", iconIndex: 98),
        ItemDefinition(id: 72, name: "Wooden Pressure Plate", iconIndex: 4),
        ItemDefinition(id: 73, name: "Redstone Ore", iconIndex: 51),
        ItemDefinition(id: 74, name: "Glowing Redstone Ore", iconIndex: 51),
        ItemDefinition(id: 75, name: "Unlit Redstone Torch", iconIndex: 115),
        ItemDefinition(id: 76, name: "Redstone Torch", iconIndex: 99),
        ItemDefinition(id: 77, name: "Button", iconIndex: 1),
        ItemDefinition(id: 78, name: "Snow Layer", iconIndex: 66),
        ItemDefinition(id: 79, name: "Ice", iconIndex: 67),
        ItemDefinition(id: 80, name: "Snow Block", iconIndex: 66),
        ItemDefinition(id: 81, name: "Cactus", iconIndex: 70),
        ItemDefinition(id: 82, name: "Clay", iconIndex: 72),
        ItemDefinition(id: 83, name: "Sugar cane", iconIndex: 73),
        ItemDefinition(id: 84, name: "Jukebox", iconIndex: 74),
        ItemDefinition(id: 85, name: "Fence", iconIndex: 4),
        ItemDefinition(id: 86, name: "Pumpkin", iconIndex: 118),
        ItemDefinition(id: 87, name: "Netherrack", iconIndex: 103),
        ItemDefinition(id: 88, name: "Soul Sand", iconIndex: 104),
        ItemDefinition(id: 89, name: "Glowstone", iconIndex: 105),
        ItemDefinition(id: 90, name: "Portal", iconIndex: 14),
        ItemDefinition(id: 91, name: "Jack 'o' Lantern", iconIndex: 118),
        ItemDefinition(id: 92, name: "Cake", iconIndex: 122),
        ItemDefinition(id: 93, name: "Redstone Repeater", iconIndex: 5),
        ItemDefinition(id: 94, name: "Powered Redstone Repeater", iconIndex: 5),
        ItemDefinition(id: 95, name: "Locked chest", iconIndex: 26),
        ItemDefinition(id: 96, name: "Trapdoor", iconIndex: 84),
        ItemDefinition(
            id: 256, name: "Iron Shovel", iconIndex: 82, maximumStackSize: 1, maximumDurability: 250,
            attackDamage: 3),
        ItemDefinition(
            id: 257, name: "Iron Pickaxe", iconIndex: 98, maximumStackSize: 1, maximumDurability: 250,
            attackDamage: 4),
        ItemDefinition(
            id: 258, name: "Iron Axe", iconIndex: 114, maximumStackSize: 1, maximumDurability: 250,
            attackDamage: 5),
        ItemDefinition(
            id: 259, name: "Flint and Steel", iconIndex: 5, maximumStackSize: 1, maximumDurability: 64),
        ItemDefinition(id: 260, name: "Apple", iconIndex: 10, maximumStackSize: 1, foodHealing: 4),
        ItemDefinition(id: 261, name: "Bow", iconIndex: 21, maximumStackSize: 1),
        ItemDefinition(id: 262, name: "Arrow", iconIndex: 37),
        ItemDefinition(id: 263, name: "Coal", iconIndex: 7, hasSubtypes: true),
        ItemDefinition(id: 264, name: "Diamond", iconIndex: 55),
        ItemDefinition(id: 265, name: "Iron Ingot", iconIndex: 23),
        ItemDefinition(id: 266, name: "Gold Ingot", iconIndex: 39),
        ItemDefinition(
            id: 267, name: "Iron Sword", iconIndex: 66, maximumStackSize: 1, maximumDurability: 250,
            attackDamage: 8),
        ItemDefinition(
            id: 268, name: "Wooden Sword", iconIndex: 64, maximumStackSize: 1, maximumDurability: 59,
            attackDamage: 4),
        ItemDefinition(
            id: 269, name: "Wooden Shovel", iconIndex: 80, maximumStackSize: 1, maximumDurability: 59),
        ItemDefinition(
            id: 270, name: "Wooden Pickaxe", iconIndex: 96, maximumStackSize: 1, maximumDurability: 59,
            attackDamage: 2),
        ItemDefinition(
            id: 271, name: "Wooden Axe", iconIndex: 112, maximumStackSize: 1, maximumDurability: 59,
            attackDamage: 3),
        ItemDefinition(
            id: 272, name: "Stone Sword", iconIndex: 65, maximumStackSize: 1, maximumDurability: 131,
            attackDamage: 6),
        ItemDefinition(
            id: 273, name: "Stone Shovel", iconIndex: 81, maximumStackSize: 1, maximumDurability: 131,
            attackDamage: 2),
        ItemDefinition(
            id: 274, name: "Stone Pickaxe", iconIndex: 97, maximumStackSize: 1, maximumDurability: 131,
            attackDamage: 3),
        ItemDefinition(
            id: 275, name: "Stone Axe", iconIndex: 113, maximumStackSize: 1, maximumDurability: 131,
            attackDamage: 4),
        ItemDefinition(
            id: 276, name: "Diamond Sword", iconIndex: 67, maximumStackSize: 1, maximumDurability: 1561,
            attackDamage: 10),
        ItemDefinition(
            id: 277, name: "Diamond Shovel", iconIndex: 83, maximumStackSize: 1, maximumDurability: 1561,
            attackDamage: 4),
        ItemDefinition(
            id: 278, name: "Diamond Pickaxe", iconIndex: 99, maximumStackSize: 1, maximumDurability: 1561,
            attackDamage: 5),
        ItemDefinition(
            id: 279, name: "Diamond Axe", iconIndex: 115, maximumStackSize: 1, maximumDurability: 1561,
            attackDamage: 6),
        ItemDefinition(id: 280, name: "Stick", iconIndex: 53),
        ItemDefinition(id: 281, name: "Bowl", iconIndex: 71),
        ItemDefinition(id: 282, name: "Mushroom Stew", iconIndex: 72, maximumStackSize: 1, foodHealing: 10),
        ItemDefinition(
            id: 283, name: "Golden Sword", iconIndex: 68, maximumStackSize: 1, maximumDurability: 32,
            attackDamage: 4),
        ItemDefinition(
            id: 284, name: "Golden Shovel", iconIndex: 84, maximumStackSize: 1, maximumDurability: 32),
        ItemDefinition(
            id: 285, name: "Golden Pickaxe", iconIndex: 100, maximumStackSize: 1, maximumDurability: 32,
            attackDamage: 2),
        ItemDefinition(
            id: 286, name: "Golden Axe", iconIndex: 116, maximumStackSize: 1, maximumDurability: 32,
            attackDamage: 3),
        ItemDefinition(id: 287, name: "String", iconIndex: 8),
        ItemDefinition(id: 288, name: "Feather", iconIndex: 24),
        ItemDefinition(id: 289, name: "Gunpowder", iconIndex: 40),
        ItemDefinition(
            id: 290, name: "Wooden Hoe", iconIndex: 128, maximumStackSize: 1, maximumDurability: 59),
        ItemDefinition(
            id: 291, name: "Stone Hoe", iconIndex: 129, maximumStackSize: 1, maximumDurability: 131),
        ItemDefinition(
            id: 292, name: "Iron Hoe", iconIndex: 130, maximumStackSize: 1, maximumDurability: 250),
        ItemDefinition(
            id: 293, name: "Diamond Hoe", iconIndex: 131, maximumStackSize: 1, maximumDurability: 1561),
        ItemDefinition(
            id: 294, name: "Golden Hoe", iconIndex: 132, maximumStackSize: 1, maximumDurability: 32),
        ItemDefinition(id: 295, name: "Seeds", iconIndex: 9),
        ItemDefinition(id: 296, name: "Wheat", iconIndex: 25),
        ItemDefinition(id: 297, name: "Bread", iconIndex: 41, maximumStackSize: 1, foodHealing: 5),
        ItemDefinition(
            id: 298, name: "Leather Cap", iconIndex: 0, maximumStackSize: 1, maximumDurability: 33,
            armorSlot: 0, armorPoints: 3),
        ItemDefinition(
            id: 299, name: "Leather Tunic", iconIndex: 16, maximumStackSize: 1, maximumDurability: 48,
            armorSlot: 1, armorPoints: 8),
        ItemDefinition(
            id: 300, name: "Leather Pants", iconIndex: 32, maximumStackSize: 1, maximumDurability: 45,
            armorSlot: 2, armorPoints: 6),
        ItemDefinition(
            id: 301, name: "Leather Boots", iconIndex: 48, maximumStackSize: 1, maximumDurability: 39,
            armorSlot: 3, armorPoints: 3),
        ItemDefinition(
            id: 302, name: "Chain Helmet", iconIndex: 1, maximumStackSize: 1, maximumDurability: 66,
            armorSlot: 0, armorPoints: 3),
        ItemDefinition(
            id: 303, name: "Chain Chestplate", iconIndex: 17, maximumStackSize: 1, maximumDurability: 96,
            armorSlot: 1, armorPoints: 8),
        ItemDefinition(
            id: 304, name: "Chain Leggings", iconIndex: 33, maximumStackSize: 1, maximumDurability: 90,
            armorSlot: 2, armorPoints: 6),
        ItemDefinition(
            id: 305, name: "Chain Boots", iconIndex: 49, maximumStackSize: 1, maximumDurability: 78,
            armorSlot: 3, armorPoints: 3),
        ItemDefinition(
            id: 306, name: "Iron Helmet", iconIndex: 2, maximumStackSize: 1, maximumDurability: 132,
            armorSlot: 0, armorPoints: 3),
        ItemDefinition(
            id: 307, name: "Iron Chestplate", iconIndex: 18, maximumStackSize: 1, maximumDurability: 192,
            armorSlot: 1, armorPoints: 8),
        ItemDefinition(
            id: 308, name: "Iron Leggings", iconIndex: 34, maximumStackSize: 1, maximumDurability: 180,
            armorSlot: 2, armorPoints: 6),
        ItemDefinition(
            id: 309, name: "Iron Boots", iconIndex: 50, maximumStackSize: 1, maximumDurability: 156,
            armorSlot: 3, armorPoints: 3),
        ItemDefinition(
            id: 310, name: "Diamond Helmet", iconIndex: 3, maximumStackSize: 1, maximumDurability: 264,
            armorSlot: 0, armorPoints: 3),
        ItemDefinition(
            id: 311, name: "Diamond Chestplate", iconIndex: 19, maximumStackSize: 1, maximumDurability: 384,
            armorSlot: 1, armorPoints: 8),
        ItemDefinition(
            id: 312, name: "Diamond Leggings", iconIndex: 35, maximumStackSize: 1, maximumDurability: 360,
            armorSlot: 2, armorPoints: 6),
        ItemDefinition(
            id: 313, name: "Diamond Boots", iconIndex: 51, maximumStackSize: 1, maximumDurability: 312,
            armorSlot: 3, armorPoints: 3),
        ItemDefinition(
            id: 314, name: "Golden Helmet", iconIndex: 4, maximumStackSize: 1, maximumDurability: 66,
            armorSlot: 0, armorPoints: 3),
        ItemDefinition(
            id: 315, name: "Golden Chestplate", iconIndex: 20, maximumStackSize: 1, maximumDurability: 96,
            armorSlot: 1, armorPoints: 8),
        ItemDefinition(
            id: 316, name: "Golden Leggings", iconIndex: 36, maximumStackSize: 1, maximumDurability: 90,
            armorSlot: 2, armorPoints: 6),
        ItemDefinition(
            id: 317, name: "Golden boots", iconIndex: 52, maximumStackSize: 1, maximumDurability: 78,
            armorSlot: 3, armorPoints: 3),
        ItemDefinition(id: 318, name: "Flint", iconIndex: 6),
        ItemDefinition(id: 319, name: "Raw Porkchop", iconIndex: 87, maximumStackSize: 1, foodHealing: 3),
        ItemDefinition(id: 320, name: "Cooked Porkchop", iconIndex: 88, maximumStackSize: 1, foodHealing: 8),
        ItemDefinition(id: 321, name: "Painting", iconIndex: 26),
        ItemDefinition(id: 322, name: "Golden Apple", iconIndex: 11, maximumStackSize: 1, foodHealing: 42),
        ItemDefinition(id: 323, name: "Sign", iconIndex: 42, maximumStackSize: 1),
        ItemDefinition(id: 324, name: "Wooden Door", iconIndex: 43, maximumStackSize: 1),
        ItemDefinition(id: 325, name: "Bucket", iconIndex: 74, maximumStackSize: 1),
        ItemDefinition(
            id: 326, name: "Water Bucket", iconIndex: 75, maximumStackSize: 1, containerItemID: 325),
        ItemDefinition(
            id: 327, name: "Lava bucket", iconIndex: 76, maximumStackSize: 1, containerItemID: 325),
        ItemDefinition(id: 328, name: "Minecart", iconIndex: 135, maximumStackSize: 1),
        ItemDefinition(id: 329, name: "Saddle", iconIndex: 104, maximumStackSize: 1),
        ItemDefinition(id: 330, name: "Iron Door", iconIndex: 44, maximumStackSize: 1),
        ItemDefinition(id: 331, name: "Redstone", iconIndex: 56),
        ItemDefinition(id: 332, name: "Snowball", iconIndex: 14, maximumStackSize: 16),
        ItemDefinition(id: 333, name: "Boat", iconIndex: 136, maximumStackSize: 1),
        ItemDefinition(id: 334, name: "Leather", iconIndex: 103),
        ItemDefinition(id: 335, name: "Milk", iconIndex: 77, maximumStackSize: 1, containerItemID: 325),
        ItemDefinition(id: 336, name: "Brick", iconIndex: 22),
        ItemDefinition(id: 337, name: "Clay", iconIndex: 57),
        ItemDefinition(id: 338, name: "Sugar Canes", iconIndex: 27),
        ItemDefinition(id: 339, name: "Paper", iconIndex: 58),
        ItemDefinition(id: 340, name: "Book", iconIndex: 59),
        ItemDefinition(id: 341, name: "Slimeball", iconIndex: 30),
        ItemDefinition(id: 342, name: "Minecart with Chest", iconIndex: 151, maximumStackSize: 1),
        ItemDefinition(id: 343, name: "Minecart with Furnace", iconIndex: 167, maximumStackSize: 1),
        ItemDefinition(id: 344, name: "Egg", iconIndex: 12, maximumStackSize: 16),
        ItemDefinition(id: 345, name: "Compass", iconIndex: 54),
        ItemDefinition(
            id: 346, name: "Fishing Rod", iconIndex: 69, maximumStackSize: 1, maximumDurability: 64),
        ItemDefinition(id: 347, name: "Clock", iconIndex: 70),
        ItemDefinition(id: 348, name: "Glowstone Dust", iconIndex: 73),
        ItemDefinition(id: 349, name: "Raw Fish", iconIndex: 89, maximumStackSize: 1, foodHealing: 2),
        ItemDefinition(id: 350, name: "Cooked Fish", iconIndex: 90, maximumStackSize: 1, foodHealing: 5),
        ItemDefinition(id: 351, name: "item.dyePowder", iconIndex: 78, hasSubtypes: true),
        ItemDefinition(id: 352, name: "Bone", iconIndex: 28),
        ItemDefinition(id: 353, name: "Sugar", iconIndex: 13),
        ItemDefinition(id: 354, name: "Cake", iconIndex: 29, maximumStackSize: 1),
        ItemDefinition(id: 355, name: "Bed", iconIndex: 45, maximumStackSize: 1),
        ItemDefinition(id: 356, name: "Redstone Repeater", iconIndex: 86),
        ItemDefinition(id: 357, name: "Cookie", iconIndex: 92, maximumStackSize: 8, foodHealing: 1),
        ItemDefinition(id: 358, name: "Map", iconIndex: 60, maximumStackSize: 1),
        ItemDefinition(id: 359, name: "Shears", iconIndex: 93, maximumStackSize: 1, maximumDurability: 238),
        ItemDefinition(id: 2256, name: "Music Disc (13)", iconIndex: 240, maximumStackSize: 1),
        ItemDefinition(id: 2257, name: "Music Disc (Cat)", iconIndex: 241, maximumStackSize: 1),
    ]
    private static let catalog = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}
