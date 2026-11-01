enum BetaStatisticsData {
    static let definitions: [StatisticDefinition] = [
        .init(
            id: 1000, key: "stat.startGame", name: "Times played",
            checksumKey: "43ddd8b48469d9a8c011718aa846facb", category: .general, itemID: nil,
            isIndependent: true, isListed: true),
        .init(
            id: 1001, key: "stat.createWorld", name: "Worlds played",
            checksumKey: "aaed8c669f583cf35300f7c5d5396fce", category: .general, itemID: nil,
            isIndependent: true, isListed: true),
        .init(
            id: 1002, key: "stat.loadWorld", name: "Saves loaded",
            checksumKey: "d517ae73160fd8576d7687ead1c1a973", category: .general, itemID: nil,
            isIndependent: true, isListed: true),
        .init(
            id: 1003, key: "stat.joinMultiplayer", name: "Multiplayer joins",
            checksumKey: "ac37df168bae3c69a24d7fd5bae913c7", category: .general, itemID: nil,
            isIndependent: true, isListed: true),
        .init(
            id: 1004, key: "stat.leaveGame", name: "Games quit",
            checksumKey: "6d2591e94464b8327afadbdba44978d", category: .general, itemID: nil,
            isIndependent: true, isListed: true),
        .init(
            id: 1100, key: "stat.playOneMinute", name: "Minutes Played",
            checksumKey: "8b1df73e012e2ae34cd2d84a72a7898b", category: .general, itemID: nil,
            isIndependent: true, isListed: true),
        .init(
            id: 2000, key: "stat.walkOneCm", name: "Distance Walked",
            checksumKey: "c9ee0d494e0524c86a577cf684f5816d", category: .general, itemID: nil,
            isIndependent: true, isListed: true),
        .init(
            id: 2001, key: "stat.swimOneCm", name: "Distance Swum",
            checksumKey: "cd7a2836ea0b77b23a6131222f5be354", category: .general, itemID: nil,
            isIndependent: true, isListed: true),
        .init(
            id: 2002, key: "stat.fallOneCm", name: "Distance Fallen",
            checksumKey: "381aeedb2c5c5a7a9a01333e0eebc839", category: .general, itemID: nil,
            isIndependent: true, isListed: true),
        .init(
            id: 2003, key: "stat.climbOneCm", name: "Distance Climbed",
            checksumKey: "229048d1bb9e928831734cb2e5000286", category: .general, itemID: nil,
            isIndependent: true, isListed: true),
        .init(
            id: 2004, key: "stat.flyOneCm", name: "Distance Flown",
            checksumKey: "b2c088c3c6928bfe29684a75ae1b127c", category: .general, itemID: nil,
            isIndependent: true, isListed: true),
        .init(
            id: 2005, key: "stat.diveOneCm", name: "Distance Dove",
            checksumKey: "1ce3491a1021a5aed07c687e3f6133e6", category: .general, itemID: nil,
            isIndependent: true, isListed: true),
        .init(
            id: 2006, key: "stat.minecartOneCm", name: "Distance by Minecart",
            checksumKey: "6c3d114caffd8160f7d56fc8757419a", category: .general, itemID: nil,
            isIndependent: true, isListed: true),
        .init(
            id: 2007, key: "stat.boatOneCm", name: "Distance by Boat",
            checksumKey: "bcb501cfac8f7e73b455563bddbcb417", category: .general, itemID: nil,
            isIndependent: true, isListed: true),
        .init(
            id: 2008, key: "stat.pigOneCm", name: "Distance by Pig",
            checksumKey: "e1aa93d7bba48898a32810c43c6ff5c3", category: .general, itemID: nil,
            isIndependent: true, isListed: true),
        .init(
            id: 2010, key: "stat.jump", name: "Jumps", checksumKey: "d0818779df1b967cc2f8ffc3ada631ec",
            category: .general, itemID: nil, isIndependent: true, isListed: true),
        .init(
            id: 2011, key: "stat.drop", name: "Items Dropped",
            checksumKey: "ecf0dbe93240e84edf6bd263645e634f", category: .general, itemID: nil,
            isIndependent: true, isListed: true),
        .init(
            id: 2020, key: "stat.damageDealt", name: "Damage Dealt",
            checksumKey: "b4a67353e11c3039ad755a3e96b4a046", category: .general, itemID: nil,
            isIndependent: false, isListed: true),
        .init(
            id: 2021, key: "stat.damageTaken", name: "Damage Taken",
            checksumKey: "1bb21f7731a5b3ffc6a1e2b586dae3f5", category: .general, itemID: nil,
            isIndependent: false, isListed: true),
        .init(
            id: 2022, key: "stat.deaths", name: "Number of Deaths",
            checksumKey: "e58162e284df8fe339f05626eb46d835", category: .general, itemID: nil,
            isIndependent: false, isListed: true),
        .init(
            id: 2023, key: "stat.mobKills", name: "Mob Kills",
            checksumKey: "739948643f5f6f685aea81c42883a480", category: .general, itemID: nil,
            isIndependent: false, isListed: true),
        .init(
            id: 2024, key: "stat.playerKills", name: "Player Kills",
            checksumKey: "799b0d35362a9574d3226c2d762b53c6", category: .general, itemID: nil,
            isIndependent: false, isListed: true),
        .init(
            id: 2025, key: "stat.fishCaught", name: "Fish Caught",
            checksumKey: "5ec18fbb462516a1e1a3427e0595a7d6", category: .general, itemID: nil,
            isIndependent: false, isListed: true),
        .init(
            id: 5_242_880, key: "achievement.openInventory", name: "Taking Inventory",
            checksumKey: "8099ff561e194072c9086dea38757a89", category: .achievement, itemID: nil,
            isIndependent: true, isListed: true),
        .init(
            id: 5_242_881, key: "achievement.mineWood", name: "Getting Wood",
            checksumKey: "90b3d9a90a8cf3e21527fc8fe3b43c49", category: .achievement, itemID: nil,
            isIndependent: false, isListed: true),
        .init(
            id: 5_242_882, key: "achievement.buildWorkBench", name: "Benchmarking",
            checksumKey: "c9806dd45be8ebed3e4ab94f66e65212", category: .achievement, itemID: nil,
            isIndependent: false, isListed: true),
        .init(
            id: 5_242_883, key: "achievement.buildPickaxe", name: "Time to Mine!",
            checksumKey: "f382ded5f9a4299e3879dea4f7fe1c50", category: .achievement, itemID: nil,
            isIndependent: false, isListed: true),
        .init(
            id: 5_242_884, key: "achievement.buildFurnace", name: "Hot Topic",
            checksumKey: "27af08a994f76a2a08ec8671d14fdcc2", category: .achievement, itemID: nil,
            isIndependent: false, isListed: true),
        .init(
            id: 5_242_885, key: "achievement.acquireIron", name: "Acquire Hardware",
            checksumKey: "9969ce4355ae7338470461f48f4e5ef5", category: .achievement, itemID: nil,
            isIndependent: false, isListed: true),
        .init(
            id: 5_242_886, key: "achievement.buildHoe", name: "Time to Farm!",
            checksumKey: "39208e0b0f070629cad494da5fb95f0d", category: .achievement, itemID: nil,
            isIndependent: false, isListed: true),
        .init(
            id: 5_242_887, key: "achievement.makeBread", name: "Bake Bread",
            checksumKey: "678e63329d3d813f22e0f15006a93768", category: .achievement, itemID: nil,
            isIndependent: false, isListed: true),
        .init(
            id: 5_242_888, key: "achievement.bakeCake", name: "The Lie",
            checksumKey: "694ffe9efa49193780d4b757115c9064", category: .achievement, itemID: nil,
            isIndependent: false, isListed: true),
        .init(
            id: 5_242_889, key: "achievement.buildBetterPickaxe", name: "Getting an Upgrade",
            checksumKey: "9080a51ccefd23f9924bae9a854e7b49", category: .achievement, itemID: nil,
            isIndependent: false, isListed: true),
        .init(
            id: 5_242_890, key: "achievement.cookFish", name: "Delicious Fish",
            checksumKey: "5f1d51ccd1b4adf141707907233f8379", category: .achievement, itemID: nil,
            isIndependent: false, isListed: true),
        .init(
            id: 5_242_891, key: "achievement.onARail", name: "On A Rail",
            checksumKey: "73df45f45e0b7484ef51441ad0e50604", category: .achievement, itemID: nil,
            isIndependent: false, isListed: true),
        .init(
            id: 5_242_892, key: "achievement.buildSword", name: "Time to Strike!",
            checksumKey: "c9e52234c475354483dc3e9e6386af61", category: .achievement, itemID: nil,
            isIndependent: false, isListed: true),
        .init(
            id: 5_242_893, key: "achievement.killEnemy", name: "Monster Hunter",
            checksumKey: "3c3ee1df989ecf5de70a5673acfa33b8", category: .achievement, itemID: nil,
            isIndependent: false, isListed: true),
        .init(
            id: 5_242_894, key: "achievement.killCow", name: "Cow Tipper",
            checksumKey: "468cc8b546e1586406b78ad733976f5f", category: .achievement, itemID: nil,
            isIndependent: false, isListed: true),
        .init(
            id: 5_242_895, key: "achievement.flyPig", name: "When Pigs Fly",
            checksumKey: "e546a7afaaa6c6729e3b062fc4ace4ae", category: .achievement, itemID: nil,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_217, key: "stat.mineBlock.1", name: "Stone Mined",
            checksumKey: "9012132a1d0f770eca67e62a68247137", category: .mine, itemID: 1, isIndependent: false,
            isListed: true),
        .init(
            id: 16_777_218, key: "stat.mineBlock.2", name: "Grass Mined", checksumKey: "null",
            category: .mine, itemID: 2, isIndependent: false, isListed: false),
        .init(
            id: 16_777_219, key: "stat.mineBlock.3", name: "Dirt Mined",
            checksumKey: "58fc65723143afeb33f742c17e028c94", category: .mine, itemID: 3, isIndependent: false,
            isListed: true),
        .init(
            id: 16_777_220, key: "stat.mineBlock.4", name: "Cobblestone Mined",
            checksumKey: "1d5e2088f7137e304366873dd829ca98", category: .mine, itemID: 4, isIndependent: false,
            isListed: true),
        .init(
            id: 16_777_221, key: "stat.mineBlock.5", name: "Wooden Planks Mined",
            checksumKey: "66a18fa3f554756edc12bf1a08586bc8", category: .mine, itemID: 5, isIndependent: false,
            isListed: true),
        .init(
            id: 16_777_222, key: "stat.mineBlock.6", name: "Sapling Mined",
            checksumKey: "4007295f7bdae0b78a6e47a9d64521", category: .mine, itemID: 6, isIndependent: false,
            isListed: true),
        .init(
            id: 16_777_228, key: "stat.mineBlock.12", name: "Sand Mined",
            checksumKey: "c154160ce7b52d4bdc220fc954edf796", category: .mine, itemID: 12,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_229, key: "stat.mineBlock.13", name: "Gravel Mined",
            checksumKey: "2400808c6f442f2663b6869e4930c879", category: .mine, itemID: 13,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_230, key: "stat.mineBlock.14", name: "Gold Ore Mined",
            checksumKey: "7ae3b31e8e0f2f22f50fbf224e1fe4f7", category: .mine, itemID: 14,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_231, key: "stat.mineBlock.15", name: "Iron Ore Mined",
            checksumKey: "fe5698e183b10037e38f979a411489b8", category: .mine, itemID: 15,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_232, key: "stat.mineBlock.16", name: "Coal Ore Mined",
            checksumKey: "aeae00c7b4a95ff05423c1629bf3ad7e", category: .mine, itemID: 16,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_233, key: "stat.mineBlock.17", name: "Wood Mined",
            checksumKey: "72153ea3d60930cebf4c0d37fac89102", category: .mine, itemID: 17,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_235, key: "stat.mineBlock.19", name: "Sponge Mined",
            checksumKey: "f517ab768fbb35e275440b74b6631bfc", category: .mine, itemID: 19,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_236, key: "stat.mineBlock.20", name: "Glass Mined",
            checksumKey: "623df9298630687873579ea16bb97e7b", category: .mine, itemID: 20,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_237, key: "stat.mineBlock.21", name: "Lapis Lazuli Ore Mined",
            checksumKey: "6984cb9e6a322728be736860b97b971a", category: .mine, itemID: 21,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_238, key: "stat.mineBlock.22", name: "Lapis Lazuli Block Mined",
            checksumKey: "6947378f4e2abb24b47e2b943945b16f", category: .mine, itemID: 22,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_239, key: "stat.mineBlock.23", name: "Dispenser Mined",
            checksumKey: "55a585682bf0569a60a71a66f031ca2", category: .mine, itemID: 23, isIndependent: false,
            isListed: true),
        .init(
            id: 16_777_240, key: "stat.mineBlock.24", name: "Sandstone Mined",
            checksumKey: "f653295b0c48244dc2aa68fc5b94fa29", category: .mine, itemID: 24,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_241, key: "stat.mineBlock.25", name: "Note Block Mined",
            checksumKey: "c213fb7ee968403b24ff6ede98686add", category: .mine, itemID: 25,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_243, key: "stat.mineBlock.27", name: "Powered Rail Mined",
            checksumKey: "afd641da6f3834b319b761ba6d72ff74", category: .mine, itemID: 27,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_244, key: "stat.mineBlock.28", name: "Detector Rail Mined",
            checksumKey: "8d822c710a221b8a407b2def97885470", category: .mine, itemID: 28,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_245, key: "stat.mineBlock.29", name: "Sticky Piston Mined", checksumKey: "null",
            category: .mine, itemID: 29, isIndependent: false, isListed: true),
        .init(
            id: 16_777_246, key: "stat.mineBlock.30", name: "Cobweb Mined",
            checksumKey: "9c99187cc6fd9c958417b4736772e4d3", category: .mine, itemID: 30,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_247, key: "stat.mineBlock.31", name: "tile.tallgrass.name Mined", checksumKey: "null",
            category: .mine, itemID: 31, isIndependent: false, isListed: true),
        .init(
            id: 16_777_248, key: "stat.mineBlock.32", name: "tile.deadbush.name Mined", checksumKey: "null",
            category: .mine, itemID: 32, isIndependent: false, isListed: true),
        .init(
            id: 16_777_249, key: "stat.mineBlock.33", name: "Piston Mined", checksumKey: "null",
            category: .mine, itemID: 33, isIndependent: false, isListed: true),
        .init(
            id: 16_777_250, key: "stat.mineBlock.34", name: "null.name Mined", checksumKey: "null",
            category: .mine, itemID: 34, isIndependent: false, isListed: true),
        .init(
            id: 16_777_251, key: "stat.mineBlock.35", name: "Wool Mined",
            checksumKey: "6418210d69669c4a602148ed42ab2ecd", category: .mine, itemID: 35,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_252, key: "stat.mineBlock.36", name: "null.name Mined", checksumKey: "null",
            category: .mine, itemID: 36, isIndependent: false, isListed: true),
        .init(
            id: 16_777_253, key: "stat.mineBlock.37", name: "Flower Mined",
            checksumKey: "afe51ea56dc8c831f9b0b5ae02bac702", category: .mine, itemID: 37,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_254, key: "stat.mineBlock.38", name: "Rose Mined",
            checksumKey: "95812c1d4021558b6a7f62521228c52a", category: .mine, itemID: 38,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_255, key: "stat.mineBlock.39", name: "Mushroom Mined",
            checksumKey: "3a1252acb6fe968751d2b61d57557e09", category: .mine, itemID: 39,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_256, key: "stat.mineBlock.40", name: "Mushroom Mined", checksumKey: "null",
            category: .mine, itemID: 40, isIndependent: false, isListed: false),
        .init(
            id: 16_777_257, key: "stat.mineBlock.41", name: "Block of Gold Mined",
            checksumKey: "fd7caeeb5d16756028f19ba016ed1970", category: .mine, itemID: 41,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_258, key: "stat.mineBlock.42", name: "Block of Iron Mined",
            checksumKey: "6339b8043c05d19c6b15135eade95f94", category: .mine, itemID: 42,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_259, key: "stat.mineBlock.43", name: "tile.stoneSlab.name Mined", checksumKey: "null",
            category: .mine, itemID: 43, isIndependent: false, isListed: false),
        .init(
            id: 16_777_260, key: "stat.mineBlock.44", name: "tile.stoneSlab.name Mined",
            checksumKey: "aa1ed939a8b275df9dc5474bc0477a33", category: .mine, itemID: 44,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_261, key: "stat.mineBlock.45", name: "Bricks Mined",
            checksumKey: "b631dcf219d3add3560f243ff6cceb75", category: .mine, itemID: 45,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_262, key: "stat.mineBlock.46", name: "TNT Mined",
            checksumKey: "91eca0c33ac53fb155feb15db48c43de", category: .mine, itemID: 46,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_263, key: "stat.mineBlock.47", name: "Bookshelf Mined",
            checksumKey: "b681c19d7812c281b4b2feabb88697f4", category: .mine, itemID: 47,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_264, key: "stat.mineBlock.48", name: "Moss Stone Mined",
            checksumKey: "a2b07ae4f37a65fe1f5992826b578b02", category: .mine, itemID: 48,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_265, key: "stat.mineBlock.49", name: "Obsidian Mined",
            checksumKey: "af5255a4dcb486e2ab11669fd3de8441", category: .mine, itemID: 49,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_266, key: "stat.mineBlock.50", name: "Torch Mined",
            checksumKey: "8a4b2b706f219e52a261e342b47a3964", category: .mine, itemID: 50,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_269, key: "stat.mineBlock.53", name: "Wooden Stairs Mined",
            checksumKey: "921cb54cfb47ca9eca0edcf8e660e3cd", category: .mine, itemID: 53,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_270, key: "stat.mineBlock.54", name: "Chest Mined",
            checksumKey: "b79b3a522d1e2f865eb1e9aeb63dc66a", category: .mine, itemID: 54,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_272, key: "stat.mineBlock.56", name: "Diamond Ore Mined",
            checksumKey: "36e1c1dd8cbb267488e1669811319e7e", category: .mine, itemID: 56,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_273, key: "stat.mineBlock.57", name: "Block of Diamond Mined",
            checksumKey: "c84a7d710228024c2e100a79a2c30e55", category: .mine, itemID: 57,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_274, key: "stat.mineBlock.58", name: "Crafting Table Mined",
            checksumKey: "a1674e3020689bae5680f29f937e5424", category: .mine, itemID: 58,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_276, key: "stat.mineBlock.60", name: "Farmland Mined", checksumKey: "null",
            category: .mine, itemID: 60, isIndependent: false, isListed: false),
        .init(
            id: 16_777_277, key: "stat.mineBlock.61", name: "Furnace Mined",
            checksumKey: "46b34dd723f7efeb38f670925ee3824f", category: .mine, itemID: 61,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_278, key: "stat.mineBlock.62", name: "Furnace Mined", checksumKey: "null",
            category: .mine, itemID: 62, isIndependent: false, isListed: false),
        .init(
            id: 16_777_281, key: "stat.mineBlock.65", name: "Ladder Mined",
            checksumKey: "da71e3e4f9a25c6621d2f0b40ffd1c72", category: .mine, itemID: 65,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_282, key: "stat.mineBlock.66", name: "Rail Mined",
            checksumKey: "388109bb9b9b49c1f5bb604abee91671", category: .mine, itemID: 66,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_283, key: "stat.mineBlock.67", name: "Stone Stairs Mined",
            checksumKey: "eb6912fd84b2d57ed3433acb3f85d3e6", category: .mine, itemID: 67,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_285, key: "stat.mineBlock.69", name: "Lever Mined",
            checksumKey: "619967351702f1d570d4d0195bbbcc1e", category: .mine, itemID: 69,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_286, key: "stat.mineBlock.70", name: "Pressure Plate Mined",
            checksumKey: "ebff74d54387fb154d5b467e01d92b64", category: .mine, itemID: 70,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_288, key: "stat.mineBlock.72", name: "Pressure Plate Mined",
            checksumKey: "f8154dd7c9c1d397dd64eeb6569d7d34", category: .mine, itemID: 72,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_289, key: "stat.mineBlock.73", name: "Redstone Ore Mined",
            checksumKey: "971cc6f827398c6c4755b310c6795672", category: .mine, itemID: 73,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_290, key: "stat.mineBlock.74", name: "Redstone Ore Mined", checksumKey: "null",
            category: .mine, itemID: 74, isIndependent: false, isListed: false),
        .init(
            id: 16_777_291, key: "stat.mineBlock.75", name: "Redstone Torch Mined",
            checksumKey: "bb952ff9523f248ddaae56317e91a509", category: .mine, itemID: 75,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_292, key: "stat.mineBlock.76", name: "Redstone Torch Mined", checksumKey: "null",
            category: .mine, itemID: 76, isIndependent: false, isListed: false),
        .init(
            id: 16_777_293, key: "stat.mineBlock.77", name: "Button Mined",
            checksumKey: "e5c24577cf35a31bd217d206b88a7499", category: .mine, itemID: 77,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_294, key: "stat.mineBlock.78", name: "Snow Mined",
            checksumKey: "f4c170867c75982e604358da611b26e3", category: .mine, itemID: 78,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_295, key: "stat.mineBlock.79", name: "Ice Mined",
            checksumKey: "922200512d058ecc0ef19a0efcdb51bf", category: .mine, itemID: 79,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_296, key: "stat.mineBlock.80", name: "Snow Mined",
            checksumKey: "39283c3dbafb10b2a732f9d6ef3e08b6", category: .mine, itemID: 80,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_297, key: "stat.mineBlock.81", name: "Cactus Mined",
            checksumKey: "3603ae881c41c957a89aaa30990c0040", category: .mine, itemID: 81,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_298, key: "stat.mineBlock.82", name: "Clay Mined",
            checksumKey: "fbf9e47600457d091060b0f877458a83", category: .mine, itemID: 82,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_300, key: "stat.mineBlock.84", name: "Jukebox Mined",
            checksumKey: "2b0d53bafa91c68bf59b5863354bd7ae", category: .mine, itemID: 84,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_301, key: "stat.mineBlock.85", name: "Fence Mined",
            checksumKey: "50b99fabae858e971eb02ed5146fd63a", category: .mine, itemID: 85,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_302, key: "stat.mineBlock.86", name: "Pumpkin Mined",
            checksumKey: "7a32eac396b4cf3930ba9ca7b5d8dbae", category: .mine, itemID: 86,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_303, key: "stat.mineBlock.87", name: "Netherrack Mined",
            checksumKey: "115f1e956219026bb9cca0bcafb2b11b", category: .mine, itemID: 87,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_304, key: "stat.mineBlock.88", name: "Soul Sand Mined",
            checksumKey: "afb2f032a96d859ca5f24d8ff129bd64", category: .mine, itemID: 88,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_305, key: "stat.mineBlock.89", name: "Glowstone Mined",
            checksumKey: "372b3a0fd7c09f64f3cfcab89f03a9a0", category: .mine, itemID: 89,
            isIndependent: false, isListed: true),
        .init(
            id: 16_777_306, key: "stat.mineBlock.90", name: "Portal Mined",
            checksumKey: "e4b6233ac91337dcc3940e309d21c3c", category: .mine, itemID: 90, isIndependent: false,
            isListed: true),
        .init(
            id: 16_777_307, key: "stat.mineBlock.91", name: "Jack 'o' Lantern Mined", checksumKey: "null",
            category: .mine, itemID: 91, isIndependent: false, isListed: false),
        .init(
            id: 16_777_311, key: "stat.mineBlock.95", name: "Locked chest Mined",
            checksumKey: "d290638555ce76ce3053c70fdacf7d55", category: .mine, itemID: 95,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_753, key: "stat.craftItem.1", name: "Stone Crafted",
            checksumKey: "f6282e18f6f87e4cf68970579aac7219", category: .craft, itemID: 1,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_757, key: "stat.craftItem.5", name: "Wooden Planks Crafted",
            checksumKey: "1a13db89ae6fdbb152856edbe3688d95", category: .craft, itemID: 5,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_772, key: "stat.craftItem.20", name: "Glass Crafted",
            checksumKey: "b59c880de07e668eaba0888fc4de229a", category: .craft, itemID: 20,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_774, key: "stat.craftItem.22", name: "Lapis Lazuli Block Crafted",
            checksumKey: "6f2eab110a33c15cb17238708244db4d", category: .craft, itemID: 22,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_775, key: "stat.craftItem.23", name: "Dispenser Crafted",
            checksumKey: "bcc06ff4c56de9b4a1557d3c47ec1783", category: .craft, itemID: 23,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_776, key: "stat.craftItem.24", name: "Sandstone Crafted",
            checksumKey: "6b6c09ee89a933288c37f55d2187eddd", category: .craft, itemID: 24,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_777, key: "stat.craftItem.25", name: "Note Block Crafted",
            checksumKey: "fdc779803765398f0c782a1fd55a9d86", category: .craft, itemID: 25,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_779, key: "stat.craftItem.27", name: "Powered Rail Crafted",
            checksumKey: "9667a31366f5dcf740d64b775402c64", category: .craft, itemID: 27,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_780, key: "stat.craftItem.28", name: "Detector Rail Crafted",
            checksumKey: "b02509b360e6f14eac4fb03f55c11fed", category: .craft, itemID: 28,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_781, key: "stat.craftItem.29", name: "Sticky Piston Crafted", checksumKey: "null",
            category: .craft, itemID: 29, isIndependent: false, isListed: true),
        .init(
            id: 16_842_785, key: "stat.craftItem.33", name: "Piston Crafted", checksumKey: "null",
            category: .craft, itemID: 33, isIndependent: false, isListed: true),
        .init(
            id: 16_842_787, key: "stat.craftItem.35", name: "Wool Crafted",
            checksumKey: "e49146643faf3308ca7246d82fc5b2bb", category: .craft, itemID: 35,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_793, key: "stat.craftItem.41", name: "Block of Gold Crafted",
            checksumKey: "d5ac3bcc56cbc370ae3b172dd6ed5df4", category: .craft, itemID: 41,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_794, key: "stat.craftItem.42", name: "Block of Iron Crafted",
            checksumKey: "d347d92a886b9d445d7d60b090a5bcda", category: .craft, itemID: 42,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_796, key: "stat.craftItem.44", name: "tile.stoneSlab.name Crafted",
            checksumKey: "48be99a37d3a885d38657a50d6f77365", category: .craft, itemID: 44,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_797, key: "stat.craftItem.45", name: "Bricks Crafted",
            checksumKey: "8da03c2f611c7f0654aa71096832b5c", category: .craft, itemID: 45,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_798, key: "stat.craftItem.46", name: "TNT Crafted",
            checksumKey: "377a21bcb39dcfcb4a0902a7555a984f", category: .craft, itemID: 46,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_799, key: "stat.craftItem.47", name: "Bookshelf Crafted",
            checksumKey: "d4831a785c1c65ad2054bb1232babf0c", category: .craft, itemID: 47,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_802, key: "stat.craftItem.50", name: "Torch Crafted",
            checksumKey: "9b2a96570a99f6677e299d8215b1eecd", category: .craft, itemID: 50,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_805, key: "stat.craftItem.53", name: "Wooden Stairs Crafted",
            checksumKey: "9e359ce06b5603c820bd749592beb4a7", category: .craft, itemID: 53,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_806, key: "stat.craftItem.54", name: "Chest Crafted",
            checksumKey: "919bc6715eddf74c0517372ead95cdcb", category: .craft, itemID: 54,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_809, key: "stat.craftItem.57", name: "Block of Diamond Crafted",
            checksumKey: "fef5bbbc588422579bf3de8a49c73e18", category: .craft, itemID: 57,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_810, key: "stat.craftItem.58", name: "Crafting Table Crafted",
            checksumKey: "8ecd9ec7607c958cdf2e252f516fe3d8", category: .craft, itemID: 58,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_813, key: "stat.craftItem.61", name: "Furnace Crafted",
            checksumKey: "899942760d5a83d94cf58a536be6171e", category: .craft, itemID: 61,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_817, key: "stat.craftItem.65", name: "Ladder Crafted",
            checksumKey: "bad6f1072232c28353aabf42142cbd26", category: .craft, itemID: 65,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_818, key: "stat.craftItem.66", name: "Rail Crafted",
            checksumKey: "bd0c4079c99e529e55abef5ac44dcdf8", category: .craft, itemID: 66,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_819, key: "stat.craftItem.67", name: "Stone Stairs Crafted",
            checksumKey: "ae608e1ca5ca083163d92974d7c66b06", category: .craft, itemID: 67,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_821, key: "stat.craftItem.69", name: "Lever Crafted",
            checksumKey: "42b4814e4e61191b61a8d3f7c6041938", category: .craft, itemID: 69,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_822, key: "stat.craftItem.70", name: "Pressure Plate Crafted",
            checksumKey: "d69011621d777519c5ab6a68da8959", category: .craft, itemID: 70, isIndependent: false,
            isListed: true),
        .init(
            id: 16_842_824, key: "stat.craftItem.72", name: "Pressure Plate Crafted",
            checksumKey: "2368ffe803beb1d06772e96eeffd9cc9", category: .craft, itemID: 72,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_828, key: "stat.craftItem.76", name: "Redstone Torch Crafted",
            checksumKey: "6a15bcf38bcf78021f9416ac395cac85", category: .craft, itemID: 76,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_829, key: "stat.craftItem.77", name: "Button Crafted",
            checksumKey: "41cce73f9ce59993afa3517becd4bd3c", category: .craft, itemID: 77,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_832, key: "stat.craftItem.80", name: "Snow Crafted",
            checksumKey: "3b10180dc99ab99568b51010d89c655c", category: .craft, itemID: 80,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_834, key: "stat.craftItem.82", name: "Clay Crafted",
            checksumKey: "58efc828918aa006d5af09e32fe7799b", category: .craft, itemID: 82,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_836, key: "stat.craftItem.84", name: "Jukebox Crafted",
            checksumKey: "a304f875b846d65498366479fbf34568", category: .craft, itemID: 84,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_837, key: "stat.craftItem.85", name: "Fence Crafted",
            checksumKey: "4c903ddf3b9cd49a952a3889fc2c5573", category: .craft, itemID: 85,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_841, key: "stat.craftItem.89", name: "Glowstone Crafted",
            checksumKey: "2c471142bddf9a982a48e0ecb52cbb8", category: .craft, itemID: 89,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_843, key: "stat.craftItem.91", name: "Jack 'o' Lantern Crafted",
            checksumKey: "bfc9dce4c1ccef959c57360fb9f70205", category: .craft, itemID: 91,
            isIndependent: false, isListed: true),
        .init(
            id: 16_842_848, key: "stat.craftItem.96", name: "Trapdoor Crafted", checksumKey: "null",
            category: .craft, itemID: 96, isIndependent: false, isListed: true),
        .init(
            id: 16_843_008, key: "stat.craftItem.256", name: "Iron Shovel Crafted",
            checksumKey: "91f14375672f1b2003202ec7682771cb", category: .craft, itemID: 256,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_009, key: "stat.craftItem.257", name: "Iron Pickaxe Crafted",
            checksumKey: "f5007e4886946d1eb603979a35726d69", category: .craft, itemID: 257,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_010, key: "stat.craftItem.258", name: "Iron Axe Crafted",
            checksumKey: "bcfe734d49949142a5073766188213dc", category: .craft, itemID: 258,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_011, key: "stat.craftItem.259", name: "Flint and Steel Crafted",
            checksumKey: "88ea7e11c57b09139afe92169c443e20", category: .craft, itemID: 259,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_013, key: "stat.craftItem.261", name: "Bow Crafted",
            checksumKey: "3fe45d065187550d481cc745780c29c2", category: .craft, itemID: 261,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_014, key: "stat.craftItem.262", name: "Arrow Crafted",
            checksumKey: "b0bde3daab8a1cc6354cd86c65db90e2", category: .craft, itemID: 262,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_015, key: "stat.craftItem.263", name: "Coal Crafted",
            checksumKey: "7184233667abf34d2ee3eea20fb9f82b", category: .craft, itemID: 263,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_016, key: "stat.craftItem.264", name: "Diamond Crafted",
            checksumKey: "e2288c9f60d09d5f2882175abf161bd", category: .craft, itemID: 264,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_017, key: "stat.craftItem.265", name: "Iron Ingot Crafted",
            checksumKey: "e3108d8ee8530e50d7b425de217a4585", category: .craft, itemID: 265,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_018, key: "stat.craftItem.266", name: "Gold Ingot Crafted",
            checksumKey: "7bddb0161d99059f0a6c1c09d0b35b34", category: .craft, itemID: 266,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_019, key: "stat.craftItem.267", name: "Iron Sword Crafted",
            checksumKey: "87545673867c5cf2f97ea6cc3e0d3595", category: .craft, itemID: 267,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_020, key: "stat.craftItem.268", name: "Wooden Sword Crafted",
            checksumKey: "90e2ab194dab9f482eca64c651ea41e9", category: .craft, itemID: 268,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_021, key: "stat.craftItem.269", name: "Wooden Shovel Crafted",
            checksumKey: "58d3e73bd29c14b6ec97d4187cee5500", category: .craft, itemID: 269,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_022, key: "stat.craftItem.270", name: "Wooden Pickaxe Crafted",
            checksumKey: "847f1b6f38ebf442a1d34cac0fd6080e", category: .craft, itemID: 270,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_023, key: "stat.craftItem.271", name: "Wooden Axe Crafted",
            checksumKey: "5d01d19f8441e4d5dd5c41266f480ffc", category: .craft, itemID: 271,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_024, key: "stat.craftItem.272", name: "Stone Sword Crafted",
            checksumKey: "ed65803a11251872c6cf659381d0aaaa", category: .craft, itemID: 272,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_025, key: "stat.craftItem.273", name: "Stone Shovel Crafted",
            checksumKey: "aa1c8e137823bf5245f0d27c980796e7", category: .craft, itemID: 273,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_026, key: "stat.craftItem.274", name: "Stone Pickaxe Crafted",
            checksumKey: "6f3d105b3e6d1624af4ce68b2a55362d", category: .craft, itemID: 274,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_027, key: "stat.craftItem.275", name: "Stone Axe Crafted",
            checksumKey: "ecc0eb0ba51e2c14aaa006e168eacc8c", category: .craft, itemID: 275,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_028, key: "stat.craftItem.276", name: "Diamond Sword Crafted",
            checksumKey: "69ee29bc3bd715b3203d888ca2a88cc0", category: .craft, itemID: 276,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_029, key: "stat.craftItem.277", name: "Diamond Shovel Crafted",
            checksumKey: "bf398d8ec9fef1d04c67fbf474fda790", category: .craft, itemID: 277,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_030, key: "stat.craftItem.278", name: "Diamond Pickaxe Crafted",
            checksumKey: "46bd8fadf2f12988d808e69dcfc138cb", category: .craft, itemID: 278,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_031, key: "stat.craftItem.279", name: "Diamond Axe Crafted",
            checksumKey: "fa2f9de197813d8e32d78bd184603161", category: .craft, itemID: 279,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_032, key: "stat.craftItem.280", name: "Stick Crafted",
            checksumKey: "af44f7fe9a4366c67479a44b24ae80b", category: .craft, itemID: 280,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_033, key: "stat.craftItem.281", name: "Bowl Crafted",
            checksumKey: "c02e9379a6624b40fef669494a7e7183", category: .craft, itemID: 281,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_034, key: "stat.craftItem.282", name: "Mushroom Stew Crafted",
            checksumKey: "e2f097a36cdf87a1b211d27eb31dea32", category: .craft, itemID: 282,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_035, key: "stat.craftItem.283", name: "Golden Sword Crafted",
            checksumKey: "2f79ed9030fe0339dec2eb43f56fa369", category: .craft, itemID: 283,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_036, key: "stat.craftItem.284", name: "Golden Shovel Crafted",
            checksumKey: "6e381ac09bfc75ef7f71e02f3b99f279", category: .craft, itemID: 284,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_037, key: "stat.craftItem.285", name: "Golden Pickaxe Crafted",
            checksumKey: "a2d01853631a9b52006ad32497ddc865", category: .craft, itemID: 285,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_038, key: "stat.craftItem.286", name: "Golden Axe Crafted",
            checksumKey: "501ead1cb03222808aa09b376c9d5cac", category: .craft, itemID: 286,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_042, key: "stat.craftItem.290", name: "Wooden Hoe Crafted",
            checksumKey: "322d7c02f205806126f1529564ab3cd0", category: .craft, itemID: 290,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_043, key: "stat.craftItem.291", name: "Stone Hoe Crafted",
            checksumKey: "660acf0ca76261ec49deb7a7bd072f8c", category: .craft, itemID: 291,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_044, key: "stat.craftItem.292", name: "Iron Hoe Crafted",
            checksumKey: "d8dd28acc9e4431ff8eb481c1d8d9832", category: .craft, itemID: 292,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_045, key: "stat.craftItem.293", name: "Diamond Hoe Crafted",
            checksumKey: "72ae59db2ef5c472f671b31f1c6f07ce", category: .craft, itemID: 293,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_046, key: "stat.craftItem.294", name: "Golden Hoe Crafted",
            checksumKey: "cee09c2303e44dfbbaadbf167cdc503c", category: .craft, itemID: 294,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_049, key: "stat.craftItem.297", name: "Bread Crafted",
            checksumKey: "47171b2af8bb14c3816f52f79579b46d", category: .craft, itemID: 297,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_050, key: "stat.craftItem.298", name: "Leather Cap Crafted",
            checksumKey: "6b29998dbe690122afdf6da71e905009", category: .craft, itemID: 298,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_051, key: "stat.craftItem.299", name: "Leather Tunic Crafted",
            checksumKey: "5f9f017aa89719c7a282aa222c65baf", category: .craft, itemID: 299,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_052, key: "stat.craftItem.300", name: "Leather Pants Crafted",
            checksumKey: "216a61701714cb3f04e23a74a1336864", category: .craft, itemID: 300,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_053, key: "stat.craftItem.301", name: "Leather Boots Crafted",
            checksumKey: "e146704e3fe30e6821352ceb3b090184", category: .craft, itemID: 301,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_054, key: "stat.craftItem.302", name: "Chain Helmet Crafted",
            checksumKey: "5aa0a467c7451f88f9c6056e8c7427cc", category: .craft, itemID: 302,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_055, key: "stat.craftItem.303", name: "Chain Chestplate Crafted",
            checksumKey: "6881fc74a0574433e9e0f05f7cae53f7", category: .craft, itemID: 303,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_056, key: "stat.craftItem.304", name: "Chain Leggings Crafted",
            checksumKey: "d8e023c15aa80df2445c782c6b2179da", category: .craft, itemID: 304,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_057, key: "stat.craftItem.305", name: "Chain Boots Crafted",
            checksumKey: "bf533b7d78ccc350cfd2f41a8e1f0822", category: .craft, itemID: 305,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_058, key: "stat.craftItem.306", name: "Iron Helmet Crafted",
            checksumKey: "d129fce211dfb56e80195a11f39ab1e9", category: .craft, itemID: 306,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_059, key: "stat.craftItem.307", name: "Iron Chestplate Crafted",
            checksumKey: "c649596d99d96be696332cb08b4a33f2", category: .craft, itemID: 307,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_060, key: "stat.craftItem.308", name: "Iron Leggings Crafted",
            checksumKey: "cf6d7dfef99b200a4551cd65467fb9fc", category: .craft, itemID: 308,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_061, key: "stat.craftItem.309", name: "Iron Boots Crafted",
            checksumKey: "441d86175b74884ef3f672066ae52c90", category: .craft, itemID: 309,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_062, key: "stat.craftItem.310", name: "Diamond Helmet Crafted",
            checksumKey: "d22de0ebc290280b2699b5cb77568fcb", category: .craft, itemID: 310,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_063, key: "stat.craftItem.311", name: "Diamond Chestplate Crafted",
            checksumKey: "f50f8b7fafde6d640ced3ec4d797f807", category: .craft, itemID: 311,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_064, key: "stat.craftItem.312", name: "Diamond Leggings Crafted",
            checksumKey: "e6f28eea0ebbad0d18d23ea3c15f2102", category: .craft, itemID: 312,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_065, key: "stat.craftItem.313", name: "Diamond Boots Crafted",
            checksumKey: "a393477443f20a1a8a511c390024f963", category: .craft, itemID: 313,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_066, key: "stat.craftItem.314", name: "Golden Helmet Crafted",
            checksumKey: "935aa84de286e8bced6a127b69347997", category: .craft, itemID: 314,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_067, key: "stat.craftItem.315", name: "Golden Chestplate Crafted",
            checksumKey: "d6efe6a63f529d675417c2092546e144", category: .craft, itemID: 315,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_068, key: "stat.craftItem.316", name: "Golden Leggings Crafted",
            checksumKey: "6dda3129884399b67b935bb4e51ad34f", category: .craft, itemID: 316,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_069, key: "stat.craftItem.317", name: "Golden boots Crafted",
            checksumKey: "63cc6da6165cc068740827890b4460ed", category: .craft, itemID: 317,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_072, key: "stat.craftItem.320", name: "Cooked Porkchop Crafted",
            checksumKey: "d752bd5dd907feec915d036d76707ee5", category: .craft, itemID: 320,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_073, key: "stat.craftItem.321", name: "Painting Crafted",
            checksumKey: "168e43895b105169862fa2e3c205529b", category: .craft, itemID: 321,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_074, key: "stat.craftItem.322", name: "Golden Apple Crafted",
            checksumKey: "ba8bd10757ab9a4446f024952bf3f1e3", category: .craft, itemID: 322,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_075, key: "stat.craftItem.323", name: "Sign Crafted",
            checksumKey: "b34ec8f0f5f92acf230925c89eacec65", category: .craft, itemID: 323,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_076, key: "stat.craftItem.324", name: "Wooden Door Crafted",
            checksumKey: "1b11a34d5c6cee280c727938ee96054b", category: .craft, itemID: 324,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_077, key: "stat.craftItem.325", name: "Bucket Crafted",
            checksumKey: "ff170af78a0a674445f16e24394546c0", category: .craft, itemID: 325,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_080, key: "stat.craftItem.328", name: "Minecart Crafted",
            checksumKey: "4945e39d1260ff273c49d39dfc58c2a8", category: .craft, itemID: 328,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_082, key: "stat.craftItem.330", name: "Iron Door Crafted",
            checksumKey: "5574b9699d71e02f3efb48f3712da8bf", category: .craft, itemID: 330,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_085, key: "stat.craftItem.333", name: "Boat Crafted",
            checksumKey: "b30c099494e63d26f755d58ba109136a", category: .craft, itemID: 333,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_088, key: "stat.craftItem.336", name: "Brick Crafted",
            checksumKey: "5e5d08b1780bfd69747216c24b7aee92", category: .craft, itemID: 336,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_091, key: "stat.craftItem.339", name: "Paper Crafted",
            checksumKey: "37603e187bd7ad9dceccb8ef2b6b5335", category: .craft, itemID: 339,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_092, key: "stat.craftItem.340", name: "Book Crafted",
            checksumKey: "d84a39f3d30a72b13640e3afb7ea2018", category: .craft, itemID: 340,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_094, key: "stat.craftItem.342", name: "Minecart with Chest Crafted",
            checksumKey: "356c3f0d5b88d0e2077d85168eac6306", category: .craft, itemID: 342,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_095, key: "stat.craftItem.343", name: "Minecart with Furnace Crafted",
            checksumKey: "50f6c2ffdc69bea12cd7b58c69824be1", category: .craft, itemID: 343,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_097, key: "stat.craftItem.345", name: "Compass Crafted",
            checksumKey: "4e72dc4d35b34147ce69d691aa2937e3", category: .craft, itemID: 345,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_098, key: "stat.craftItem.346", name: "Fishing Rod Crafted",
            checksumKey: "503a4fb49cbfebe1fb71ef185c8ced56", category: .craft, itemID: 346,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_099, key: "stat.craftItem.347", name: "Clock Crafted",
            checksumKey: "c373e78822d440c926edf7f1b700d4c5", category: .craft, itemID: 347,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_102, key: "stat.craftItem.350", name: "Cooked Fish Crafted",
            checksumKey: "603020acbbdc6e8765c2e2cd589f7933", category: .craft, itemID: 350,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_103, key: "stat.craftItem.351", name: "item.dyePowder.name Crafted",
            checksumKey: "d4d1b946336039e515c3e4a392694223", category: .craft, itemID: 351,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_105, key: "stat.craftItem.353", name: "Sugar Crafted",
            checksumKey: "3b91182484dc677a0bf27263e612d818", category: .craft, itemID: 353,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_106, key: "stat.craftItem.354", name: "Cake Crafted",
            checksumKey: "affab7221afa03df4b7306b9ce50be7f", category: .craft, itemID: 354,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_107, key: "stat.craftItem.355", name: "Bed Crafted",
            checksumKey: "e3710bc197d17e0dc78ae3f607c46048", category: .craft, itemID: 355,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_108, key: "stat.craftItem.356", name: "Redstone Repeater Crafted",
            checksumKey: "4e225dd49c0231b617a15ded1ba6cb0a", category: .craft, itemID: 356,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_109, key: "stat.craftItem.357", name: "Cookie Crafted",
            checksumKey: "35715377a038019c56925b2e661cfdab", category: .craft, itemID: 357,
            isIndependent: false, isListed: true),
        .init(
            id: 16_843_110, key: "stat.craftItem.358", name: "Map Crafted", checksumKey: "null",
            category: .craft, itemID: 358, isIndependent: false, isListed: true),
        .init(
            id: 16_843_111, key: "stat.craftItem.359", name: "Shears Crafted", checksumKey: "null",
            category: .craft, itemID: 359, isIndependent: false, isListed: true),
        .init(
            id: 16_908_289, key: "stat.useItem.1", name: "Stone Used",
            checksumKey: "83cfae9a11032a88e08c95b7fcef84cc", category: .use, itemID: 1, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_290, key: "stat.useItem.2", name: "Grass Used", checksumKey: "null", category: .use,
            itemID: 2, isIndependent: false, isListed: false),
        .init(
            id: 16_908_291, key: "stat.useItem.3", name: "Dirt Used",
            checksumKey: "39a4ea3b5ddf7f89b41faf675f7bfc0f", category: .use, itemID: 3, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_292, key: "stat.useItem.4", name: "Cobblestone Used",
            checksumKey: "64ec21dc8495fb180cc94f59f873efb8", category: .use, itemID: 4, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_293, key: "stat.useItem.5", name: "Wooden Planks Used",
            checksumKey: "fda16e9858404b9545649ba21a828a6a", category: .use, itemID: 5, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_294, key: "stat.useItem.6", name: "Sapling Used",
            checksumKey: "a57157213ffc25d269ea46e45984eae0", category: .use, itemID: 6, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_295, key: "stat.useItem.7", name: "Bedrock Used",
            checksumKey: "90f2ac6ac3005ad4cabcd248831f2205", category: .use, itemID: 7, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_296, key: "stat.useItem.8", name: "Water Used",
            checksumKey: "4adafcbbef5ace168ca03e173af10452", category: .use, itemID: 8, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_297, key: "stat.useItem.9", name: "Water Used", checksumKey: "null", category: .use,
            itemID: 9, isIndependent: false, isListed: false),
        .init(
            id: 16_908_298, key: "stat.useItem.10", name: "Lava Used",
            checksumKey: "bb2e0425d8b489fc856cab2c0828f2ff", category: .use, itemID: 10, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_299, key: "stat.useItem.11", name: "Lava Used", checksumKey: "null", category: .use,
            itemID: 11, isIndependent: false, isListed: false),
        .init(
            id: 16_908_300, key: "stat.useItem.12", name: "Sand Used",
            checksumKey: "76b80613789c553593097956002a392b", category: .use, itemID: 12, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_301, key: "stat.useItem.13", name: "Gravel Used",
            checksumKey: "23bd5cc4fb97d25e432604be0958320d", category: .use, itemID: 13, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_302, key: "stat.useItem.14", name: "Gold Ore Used",
            checksumKey: "7b129f5775b2d4997681338012130cad", category: .use, itemID: 14, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_303, key: "stat.useItem.15", name: "Iron Ore Used",
            checksumKey: "4935425ac3ef59e71bca7c4c8bf7e2ea", category: .use, itemID: 15, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_304, key: "stat.useItem.16", name: "Coal Ore Used",
            checksumKey: "564d5c2df622b99692929bedbcd7f4b1", category: .use, itemID: 16, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_305, key: "stat.useItem.17", name: "Wood Used",
            checksumKey: "e06bb538b6b224ce1376b47804ee2bbb", category: .use, itemID: 17, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_306, key: "stat.useItem.18", name: "Leaves Used",
            checksumKey: "f13b4a0fa66e65ed33dcbd7ead08ac46", category: .use, itemID: 18, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_307, key: "stat.useItem.19", name: "Sponge Used",
            checksumKey: "29710a54739e35ae0d34919fca091640", category: .use, itemID: 19, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_308, key: "stat.useItem.20", name: "Glass Used",
            checksumKey: "8693b46ac89dd595f8e3efd4437e6e90", category: .use, itemID: 20, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_309, key: "stat.useItem.21", name: "Lapis Lazuli Ore Used",
            checksumKey: "3ebf10825c7d8f2e17deae70b37d1fbd", category: .use, itemID: 21, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_310, key: "stat.useItem.22", name: "Lapis Lazuli Block Used",
            checksumKey: "354d414b2a1f29494a80b3acedb72ae2", category: .use, itemID: 22, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_311, key: "stat.useItem.23", name: "Dispenser Used",
            checksumKey: "de662954670ec00899809b916abe6c60", category: .use, itemID: 23, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_312, key: "stat.useItem.24", name: "Sandstone Used",
            checksumKey: "831dd7a79cd7e5f3cad86690c6724902", category: .use, itemID: 24, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_313, key: "stat.useItem.25", name: "Note Block Used",
            checksumKey: "265f19645487a858e4f53b9706cdff03", category: .use, itemID: 25, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_314, key: "stat.useItem.26", name: "Bed Used",
            checksumKey: "2ad06f9f7e24f920fb067e2f2cc7869c", category: .use, itemID: 26, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_315, key: "stat.useItem.27", name: "Powered Rail Used",
            checksumKey: "99f3286cc36b9a4393b3e967878b01d4", category: .use, itemID: 27, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_316, key: "stat.useItem.28", name: "Detector Rail Used",
            checksumKey: "4fbc91a39f7f4814f8f79ba425e4f30a", category: .use, itemID: 28, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_317, key: "stat.useItem.29", name: "Sticky Piston Used", checksumKey: "null",
            category: .use, itemID: 29, isIndependent: false, isListed: true),
        .init(
            id: 16_908_318, key: "stat.useItem.30", name: "Cobweb Used",
            checksumKey: "ccb82be2278587dd637ac763a1087c7", category: .use, itemID: 30, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_319, key: "stat.useItem.31", name: "tile.tallgrass.name Used", checksumKey: "null",
            category: .use, itemID: 31, isIndependent: false, isListed: true),
        .init(
            id: 16_908_320, key: "stat.useItem.32", name: "tile.deadbush.name Used", checksumKey: "null",
            category: .use, itemID: 32, isIndependent: false, isListed: true),
        .init(
            id: 16_908_321, key: "stat.useItem.33", name: "Piston Used", checksumKey: "null", category: .use,
            itemID: 33, isIndependent: false, isListed: true),
        .init(
            id: 16_908_322, key: "stat.useItem.34", name: "null.name Used", checksumKey: "null",
            category: .use, itemID: 34, isIndependent: false, isListed: true),
        .init(
            id: 16_908_323, key: "stat.useItem.35", name: "Wool Used",
            checksumKey: "8e8a2f6a87c3701e76650680e7b2f6e6", category: .use, itemID: 35, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_324, key: "stat.useItem.36", name: "null.name Used", checksumKey: "null",
            category: .use, itemID: 36, isIndependent: false, isListed: true),
        .init(
            id: 16_908_325, key: "stat.useItem.37", name: "Flower Used",
            checksumKey: "fcd992a9a44518d5de6bd09c409ea7de", category: .use, itemID: 37, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_326, key: "stat.useItem.38", name: "Rose Used",
            checksumKey: "e41e706456c10963824e032484992946", category: .use, itemID: 38, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_327, key: "stat.useItem.39", name: "Mushroom Used",
            checksumKey: "662301d3344073cc69887a27a8c42f24", category: .use, itemID: 39, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_328, key: "stat.useItem.40", name: "Mushroom Used", checksumKey: "null",
            category: .use, itemID: 40, isIndependent: false, isListed: false),
        .init(
            id: 16_908_329, key: "stat.useItem.41", name: "Block of Gold Used",
            checksumKey: "313738e052612f868d55f47940080288", category: .use, itemID: 41, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_330, key: "stat.useItem.42", name: "Block of Iron Used",
            checksumKey: "79474b10f860f09be4e9183ad5f1c7b4", category: .use, itemID: 42, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_331, key: "stat.useItem.43", name: "tile.stoneSlab.name Used", checksumKey: "null",
            category: .use, itemID: 43, isIndependent: false, isListed: false),
        .init(
            id: 16_908_332, key: "stat.useItem.44", name: "tile.stoneSlab.name Used",
            checksumKey: "60a3062d151151a2ff229a02d3221337", category: .use, itemID: 44, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_333, key: "stat.useItem.45", name: "Bricks Used",
            checksumKey: "833c8c420ce04aa18b9912ff05e5ced2", category: .use, itemID: 45, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_334, key: "stat.useItem.46", name: "TNT Used",
            checksumKey: "6e0f4183ad7abbb63c5b6a1ead24214a", category: .use, itemID: 46, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_335, key: "stat.useItem.47", name: "Bookshelf Used",
            checksumKey: "477292deea02d72acc1087b2425c570a", category: .use, itemID: 47, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_336, key: "stat.useItem.48", name: "Moss Stone Used",
            checksumKey: "82cf44076f1a94ed31f3172433a80ef6", category: .use, itemID: 48, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_337, key: "stat.useItem.49", name: "Obsidian Used",
            checksumKey: "84f64a9f8523d35a1cf8319f580dd578", category: .use, itemID: 49, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_338, key: "stat.useItem.50", name: "Torch Used",
            checksumKey: "b6365376050089a025a1ed1d85a85dba", category: .use, itemID: 50, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_339, key: "stat.useItem.51", name: "Fire Used",
            checksumKey: "4e989db8b445f22b61bd4d30daee1a05", category: .use, itemID: 51, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_340, key: "stat.useItem.52", name: "Monster Spawner Used",
            checksumKey: "50ec890e85029d44ea96bfa31d8ed16a", category: .use, itemID: 52, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_341, key: "stat.useItem.53", name: "Wooden Stairs Used",
            checksumKey: "b4f23438454d39a742546dafd5d3cfc6", category: .use, itemID: 53, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_342, key: "stat.useItem.54", name: "Chest Used",
            checksumKey: "5414035b686e0fb0a1ce0d535d0a0f82", category: .use, itemID: 54, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_343, key: "stat.useItem.55", name: "Redstone Dust Used",
            checksumKey: "72d6218e86d3787422fa6b03f30ccaf3", category: .use, itemID: 55, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_344, key: "stat.useItem.56", name: "Diamond Ore Used",
            checksumKey: "ddfe42c53aae03dd94c2d3163869ddc0", category: .use, itemID: 56, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_345, key: "stat.useItem.57", name: "Block of Diamond Used",
            checksumKey: "b8b09ac7af1bb81e28715a3e0f0eeb17", category: .use, itemID: 57, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_346, key: "stat.useItem.58", name: "Crafting Table Used",
            checksumKey: "c53d28ac584d8053ec438f692a58cd1a", category: .use, itemID: 58, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_347, key: "stat.useItem.59", name: "Crops Used",
            checksumKey: "243cf7fb2bf36e60e3a25cde83b33a5e", category: .use, itemID: 59, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_348, key: "stat.useItem.60", name: "Farmland Used", checksumKey: "null",
            category: .use, itemID: 60, isIndependent: false, isListed: false),
        .init(
            id: 16_908_349, key: "stat.useItem.61", name: "Furnace Used",
            checksumKey: "2837ae3dabc00c4c5515bafa34a302dc", category: .use, itemID: 61, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_350, key: "stat.useItem.62", name: "Furnace Used", checksumKey: "null", category: .use,
            itemID: 62, isIndependent: false, isListed: false),
        .init(
            id: 16_908_351, key: "stat.useItem.63", name: "Sign Used",
            checksumKey: "4973e12438ce4c870f6ba1c158873c43", category: .use, itemID: 63, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_352, key: "stat.useItem.64", name: "Wooden Door Used",
            checksumKey: "37678301896aa95cc358bcd73308232c", category: .use, itemID: 64, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_353, key: "stat.useItem.65", name: "Ladder Used",
            checksumKey: "31c5e38768bda9a8a7cd1bbca7c9226d", category: .use, itemID: 65, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_354, key: "stat.useItem.66", name: "Rail Used",
            checksumKey: "5ff1e27f9ef25fcf0a3c51b0551f7fd2", category: .use, itemID: 66, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_355, key: "stat.useItem.67", name: "Stone Stairs Used",
            checksumKey: "60a060ee3e51167f4d87cf6d923f9ca7", category: .use, itemID: 67, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_356, key: "stat.useItem.68", name: "Sign Used",
            checksumKey: "b24aa4a609b3483b795c4f3bf89116b7", category: .use, itemID: 68, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_357, key: "stat.useItem.69", name: "Lever Used",
            checksumKey: "7a17a96ff758cd4ff8c0ffd070230cc7", category: .use, itemID: 69, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_358, key: "stat.useItem.70", name: "Pressure Plate Used",
            checksumKey: "c14586711c04239a174c192d24b8ce20", category: .use, itemID: 70, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_359, key: "stat.useItem.71", name: "Iron Door Used",
            checksumKey: "1f0abe2925128be5191932a1cc4a3019", category: .use, itemID: 71, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_360, key: "stat.useItem.72", name: "Pressure Plate Used",
            checksumKey: "a9c8343cf444aa7686d9dd2b40e90a47", category: .use, itemID: 72, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_361, key: "stat.useItem.73", name: "Redstone Ore Used",
            checksumKey: "94a02b3ef18bb35970105bf276001fe0", category: .use, itemID: 73, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_362, key: "stat.useItem.74", name: "Redstone Ore Used", checksumKey: "null",
            category: .use, itemID: 74, isIndependent: false, isListed: false),
        .init(
            id: 16_908_363, key: "stat.useItem.75", name: "Redstone Torch Used",
            checksumKey: "bfa45b4169d1944debabc84b04880837", category: .use, itemID: 75, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_364, key: "stat.useItem.76", name: "Redstone Torch Used", checksumKey: "null",
            category: .use, itemID: 76, isIndependent: false, isListed: false),
        .init(
            id: 16_908_365, key: "stat.useItem.77", name: "Button Used",
            checksumKey: "a3d0bb31ba7c30209129e4366e072b05", category: .use, itemID: 77, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_366, key: "stat.useItem.78", name: "Snow Used",
            checksumKey: "de6d35451526c85c7c5907a0adcbeff7", category: .use, itemID: 78, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_367, key: "stat.useItem.79", name: "Ice Used",
            checksumKey: "4a0d45a9aedaa06eb574f88f580c265b", category: .use, itemID: 79, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_368, key: "stat.useItem.80", name: "Snow Used",
            checksumKey: "56ab2510d3cb4787bdcfa9680aa7e757", category: .use, itemID: 80, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_369, key: "stat.useItem.81", name: "Cactus Used",
            checksumKey: "feef935305ae32e1972d3b017a4eb", category: .use, itemID: 81, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_370, key: "stat.useItem.82", name: "Clay Used",
            checksumKey: "41b270e7ecb39d0b81d1b60f32c3943", category: .use, itemID: 82, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_371, key: "stat.useItem.83", name: "Sugar cane Used",
            checksumKey: "b159339fc55e60000efee4c55d0e1d1c", category: .use, itemID: 83, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_372, key: "stat.useItem.84", name: "Jukebox Used",
            checksumKey: "74ca5387c7d373fc88e65e0623d5991f", category: .use, itemID: 84, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_373, key: "stat.useItem.85", name: "Fence Used",
            checksumKey: "8b8ae20ea681d47cd899f74f75bde08d", category: .use, itemID: 85, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_374, key: "stat.useItem.86", name: "Pumpkin Used",
            checksumKey: "5cb926f4743f6ccdb4988c8b35dc97dd", category: .use, itemID: 86, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_375, key: "stat.useItem.87", name: "Netherrack Used",
            checksumKey: "947a02e037fe9d31c8eb4c4a22dba58c", category: .use, itemID: 87, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_376, key: "stat.useItem.88", name: "Soul Sand Used",
            checksumKey: "2c2a7e8a269a770cc4afbe695e662601", category: .use, itemID: 88, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_377, key: "stat.useItem.89", name: "Glowstone Used",
            checksumKey: "9a992e19651652de8b4f5ce07d1d2af0", category: .use, itemID: 89, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_378, key: "stat.useItem.90", name: "Portal Used",
            checksumKey: "3e37efadc720d972ddc30ccae606ab00", category: .use, itemID: 90, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_379, key: "stat.useItem.91", name: "Jack 'o' Lantern Used", checksumKey: "null",
            category: .use, itemID: 91, isIndependent: false, isListed: false),
        .init(
            id: 16_908_380, key: "stat.useItem.92", name: "Cake Used",
            checksumKey: "77b1802a2504a685bf8ff34a1f9de6c3", category: .use, itemID: 92, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_381, key: "stat.useItem.93", name: "tile.diode.name Used",
            checksumKey: "45c0dbda39dca97dc634a6e89f037716", category: .use, itemID: 93, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_382, key: "stat.useItem.94", name: "tile.diode.name Used", checksumKey: "null",
            category: .use, itemID: 94, isIndependent: false, isListed: false),
        .init(
            id: 16_908_383, key: "stat.useItem.95", name: "Locked chest Used",
            checksumKey: "ca404ded18b83fd872a5810c8a44517d", category: .use, itemID: 95, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_384, key: "stat.useItem.96", name: "Trapdoor Used", checksumKey: "null",
            category: .use, itemID: 96, isIndependent: false, isListed: true),
        .init(
            id: 16_908_544, key: "stat.useItem.256", name: "Iron Shovel Used",
            checksumKey: "12512904b67d2091dd516dc8eeb0cfa0", category: .use, itemID: 256,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_545, key: "stat.useItem.257", name: "Iron Pickaxe Used",
            checksumKey: "a5c35cc01a263f91419d3e8e981708f1", category: .use, itemID: 257,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_546, key: "stat.useItem.258", name: "Iron Axe Used",
            checksumKey: "f6bdebf227e42c204066cede8cb5928c", category: .use, itemID: 258,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_547, key: "stat.useItem.259", name: "Flint and Steel Used",
            checksumKey: "9c44e6d3ab80afa2bb52fe3499559d5e", category: .use, itemID: 259,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_548, key: "stat.useItem.260", name: "Apple Used",
            checksumKey: "2e1799ddfdab14417c2a8e24d8c0c731", category: .use, itemID: 260,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_549, key: "stat.useItem.261", name: "Bow Used",
            checksumKey: "3f4169a181feb5d2532efc6aa91f2ee5", category: .use, itemID: 261,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_550, key: "stat.useItem.262", name: "Arrow Used",
            checksumKey: "895725d3432cbf374b1cce4f7db28e9", category: .use, itemID: 262, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_551, key: "stat.useItem.263", name: "Coal Used",
            checksumKey: "12892864f18d30521b6f4a6c45b65ece", category: .use, itemID: 263,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_552, key: "stat.useItem.264", name: "Diamond Used",
            checksumKey: "146f6c3458adde8e0bca04d976275f85", category: .use, itemID: 264,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_553, key: "stat.useItem.265", name: "Iron Ingot Used",
            checksumKey: "7c40dbd9451129b4762f3ab04ce7ffb9", category: .use, itemID: 265,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_554, key: "stat.useItem.266", name: "Gold Ingot Used",
            checksumKey: "56d763eeb6a0107c2146d7dccd686d2a", category: .use, itemID: 266,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_555, key: "stat.useItem.267", name: "Iron Sword Used",
            checksumKey: "9a4fff004ae419711c2a876b57cba69f", category: .use, itemID: 267,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_556, key: "stat.useItem.268", name: "Wooden Sword Used",
            checksumKey: "170ff67dd90d8d3d8dae393037da5e9b", category: .use, itemID: 268,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_557, key: "stat.useItem.269", name: "Wooden Shovel Used",
            checksumKey: "3e65d657af8611cb3578cd8713419d4c", category: .use, itemID: 269,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_558, key: "stat.useItem.270", name: "Wooden Pickaxe Used",
            checksumKey: "f3cb95383f698c4e9721b5aaa5fac3a7", category: .use, itemID: 270,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_559, key: "stat.useItem.271", name: "Wooden Axe Used",
            checksumKey: "65bd006dc163a186f2dbb127f8ec0b27", category: .use, itemID: 271,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_560, key: "stat.useItem.272", name: "Stone Sword Used",
            checksumKey: "8c6479d786f9117e04910153a4f47d86", category: .use, itemID: 272,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_561, key: "stat.useItem.273", name: "Stone Shovel Used",
            checksumKey: "75a25bd69f36250789d914ac01da34c1", category: .use, itemID: 273,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_562, key: "stat.useItem.274", name: "Stone Pickaxe Used",
            checksumKey: "87a28b2bf2fad838af72ce00e2fb1937", category: .use, itemID: 274,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_563, key: "stat.useItem.275", name: "Stone Axe Used",
            checksumKey: "249ff32d605c5ba0a07694ff4fbbf15a", category: .use, itemID: 275,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_564, key: "stat.useItem.276", name: "Diamond Sword Used",
            checksumKey: "ba3b355eb9134bcd7522a1fc203c4c58", category: .use, itemID: 276,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_565, key: "stat.useItem.277", name: "Diamond Shovel Used",
            checksumKey: "321e1cb3657d2aca73fb9a8083d9c3bf", category: .use, itemID: 277,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_566, key: "stat.useItem.278", name: "Diamond Pickaxe Used",
            checksumKey: "adb182051fab2c2269df89b4f75e505e", category: .use, itemID: 278,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_567, key: "stat.useItem.279", name: "Diamond Axe Used",
            checksumKey: "3d9ae8982f01fb6a6c56cffbe2fa074e", category: .use, itemID: 279,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_568, key: "stat.useItem.280", name: "Stick Used",
            checksumKey: "1efffb054b2c864f5ebe180ae46891c3", category: .use, itemID: 280,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_569, key: "stat.useItem.281", name: "Bowl Used",
            checksumKey: "25c73629d0b6b46690d222cecf331ba2", category: .use, itemID: 281,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_570, key: "stat.useItem.282", name: "Mushroom Stew Used",
            checksumKey: "6a46694c996e5721b14c9da1f00fe62c", category: .use, itemID: 282,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_571, key: "stat.useItem.283", name: "Golden Sword Used",
            checksumKey: "5efc1c291eef23fe33f5209388b8cc33", category: .use, itemID: 283,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_572, key: "stat.useItem.284", name: "Golden Shovel Used",
            checksumKey: "f71fc7deef6835c8efc305a00f1e8b8f", category: .use, itemID: 284,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_573, key: "stat.useItem.285", name: "Golden Pickaxe Used",
            checksumKey: "15484a373254c6024d90edf3b7a82947", category: .use, itemID: 285,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_574, key: "stat.useItem.286", name: "Golden Axe Used",
            checksumKey: "8253f1aaa2205dcaf828903cfce46e4", category: .use, itemID: 286, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_575, key: "stat.useItem.287", name: "String Used",
            checksumKey: "ab778410d1fb2c0e55fec0c7d764b17c", category: .use, itemID: 287,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_576, key: "stat.useItem.288", name: "Feather Used",
            checksumKey: "19ad61c04ff3ae082955f72fc8771866", category: .use, itemID: 288,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_577, key: "stat.useItem.289", name: "Gunpowder Used",
            checksumKey: "b5d3eeff40086643a03f034b5345504d", category: .use, itemID: 289,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_578, key: "stat.useItem.290", name: "Wooden Hoe Used",
            checksumKey: "3d647bf5562e743263cbd90be36b6a1c", category: .use, itemID: 290,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_579, key: "stat.useItem.291", name: "Stone Hoe Used",
            checksumKey: "5a9d2fb7050009785421257d5ef24416", category: .use, itemID: 291,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_580, key: "stat.useItem.292", name: "Iron Hoe Used",
            checksumKey: "909b03e2d2eeee2e868b5aaf446e81ea", category: .use, itemID: 292,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_581, key: "stat.useItem.293", name: "Diamond Hoe Used",
            checksumKey: "e603a4cbfdfcbf4d0bfe25efb753b424", category: .use, itemID: 293,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_582, key: "stat.useItem.294", name: "Golden Hoe Used",
            checksumKey: "e355f481f99220e50e4b2b2eb45dcc56", category: .use, itemID: 294,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_583, key: "stat.useItem.295", name: "Seeds Used",
            checksumKey: "73a25e59c2d18ae77db02928b0a70e3", category: .use, itemID: 295, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_584, key: "stat.useItem.296", name: "Wheat Used",
            checksumKey: "8f81a2fb647f817422a299829994de7b", category: .use, itemID: 296,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_585, key: "stat.useItem.297", name: "Bread Used",
            checksumKey: "128e9978380ee9ef981d2e12d008255e", category: .use, itemID: 297,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_586, key: "stat.useItem.298", name: "Leather Cap Used",
            checksumKey: "fd1453f3e2a3125e7d16cfe6fd2d4722", category: .use, itemID: 298,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_587, key: "stat.useItem.299", name: "Leather Tunic Used",
            checksumKey: "8e27b6f750bec22333a5d4108ce1e094", category: .use, itemID: 299,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_588, key: "stat.useItem.300", name: "Leather Pants Used",
            checksumKey: "b2169f6190bdf95236037bed2301712b", category: .use, itemID: 300,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_589, key: "stat.useItem.301", name: "Leather Boots Used",
            checksumKey: "536e6340e5328075ede672428d94d921", category: .use, itemID: 301,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_590, key: "stat.useItem.302", name: "Chain Helmet Used",
            checksumKey: "cb9eede8b783b4a5d7ff7529e3fb1f44", category: .use, itemID: 302,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_591, key: "stat.useItem.303", name: "Chain Chestplate Used",
            checksumKey: "267d51d891c3c32b3a02577d38f4e242", category: .use, itemID: 303,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_592, key: "stat.useItem.304", name: "Chain Leggings Used",
            checksumKey: "3f31e8ab260f02acca218c720fafc7b8", category: .use, itemID: 304,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_593, key: "stat.useItem.305", name: "Chain Boots Used",
            checksumKey: "552869a63aa3151e79e875596f31e505", category: .use, itemID: 305,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_594, key: "stat.useItem.306", name: "Iron Helmet Used",
            checksumKey: "c5b0399e7fc64f0561a82063773e1282", category: .use, itemID: 306,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_595, key: "stat.useItem.307", name: "Iron Chestplate Used",
            checksumKey: "cfd61cdbf22133caeca528da9b53474e", category: .use, itemID: 307,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_596, key: "stat.useItem.308", name: "Iron Leggings Used",
            checksumKey: "8d3802169313f270d5adcda790170ca2", category: .use, itemID: 308,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_597, key: "stat.useItem.309", name: "Iron Boots Used",
            checksumKey: "a82c4f31d6d3f5bef9aa3062945c02d6", category: .use, itemID: 309,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_598, key: "stat.useItem.310", name: "Diamond Helmet Used",
            checksumKey: "85eca649072752e9ffafdefa1287470f", category: .use, itemID: 310,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_599, key: "stat.useItem.311", name: "Diamond Chestplate Used",
            checksumKey: "98ffd259abbe2e4794c00716a9d2da7", category: .use, itemID: 311, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_600, key: "stat.useItem.312", name: "Diamond Leggings Used",
            checksumKey: "263f8fab89ae0f9d695a74512443070b", category: .use, itemID: 312,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_601, key: "stat.useItem.313", name: "Diamond Boots Used",
            checksumKey: "b4ae28e8babe7bd09b2a392780565dbe", category: .use, itemID: 313,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_602, key: "stat.useItem.314", name: "Golden Helmet Used",
            checksumKey: "dfd84b5b35231267a47891cc8c8f48ba", category: .use, itemID: 314,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_603, key: "stat.useItem.315", name: "Golden Chestplate Used",
            checksumKey: "f6990bbd57862a238aaf68b0c2f4c998", category: .use, itemID: 315,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_604, key: "stat.useItem.316", name: "Golden Leggings Used",
            checksumKey: "9dca837e109ae977a89ed64dd17fab10", category: .use, itemID: 316,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_605, key: "stat.useItem.317", name: "Golden boots Used",
            checksumKey: "ebdb407fd6e4d5c450f73173487c3162", category: .use, itemID: 317,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_606, key: "stat.useItem.318", name: "Flint Used",
            checksumKey: "fdf869946d814f4f2aeebe269db06e31", category: .use, itemID: 318,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_607, key: "stat.useItem.319", name: "Raw Porkchop Used",
            checksumKey: "f9ea1fa393862a86e79ffade6a2662e7", category: .use, itemID: 319,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_608, key: "stat.useItem.320", name: "Cooked Porkchop Used",
            checksumKey: "60491b4f5956534afd5959e7c2411cda", category: .use, itemID: 320,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_609, key: "stat.useItem.321", name: "Painting Used",
            checksumKey: "b78fc6d8b8b8ecb1266eb9c04c5129b", category: .use, itemID: 321, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_610, key: "stat.useItem.322", name: "Golden Apple Used",
            checksumKey: "add241f6dcfe6af3f096a45b96fb04e1", category: .use, itemID: 322,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_611, key: "stat.useItem.323", name: "Sign Used",
            checksumKey: "38760b28c0d26204b1e0383ca318947a", category: .use, itemID: 323,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_612, key: "stat.useItem.324", name: "Wooden Door Used",
            checksumKey: "d3d8076b8b7a911b7cbbf5099f8ffd48", category: .use, itemID: 324,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_613, key: "stat.useItem.325", name: "Bucket Used",
            checksumKey: "fc78be6fb5735b715325ac499990550e", category: .use, itemID: 325,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_614, key: "stat.useItem.326", name: "Water Bucket Used",
            checksumKey: "a7504fcd85d6696a8880f32b97b34a60", category: .use, itemID: 326,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_615, key: "stat.useItem.327", name: "Lava bucket Used",
            checksumKey: "f0821b6fdc8ebbf8a6fcb37c75086b1d", category: .use, itemID: 327,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_616, key: "stat.useItem.328", name: "Minecart Used",
            checksumKey: "88b0e1b842fc88f0cbc5f38e95d68417", category: .use, itemID: 328,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_617, key: "stat.useItem.329", name: "Saddle Used",
            checksumKey: "d977f8453c349a44baa7e05c3dd81cb8", category: .use, itemID: 329,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_618, key: "stat.useItem.330", name: "Iron Door Used",
            checksumKey: "26184c3c1edfa7623d5620433c0ff36", category: .use, itemID: 330, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_619, key: "stat.useItem.331", name: "Redstone Used",
            checksumKey: "8edbf7f3996852add4fcb18008cb722f", category: .use, itemID: 331,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_620, key: "stat.useItem.332", name: "Snowball Used",
            checksumKey: "39e5881696ed1141fb934593dd6bab70", category: .use, itemID: 332,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_621, key: "stat.useItem.333", name: "Boat Used",
            checksumKey: "1e0d787240ea16af6edbbdb1ab372fe7", category: .use, itemID: 333,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_622, key: "stat.useItem.334", name: "Leather Used",
            checksumKey: "af6ec83a0b072b4abd4194d8d43f7f02", category: .use, itemID: 334,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_623, key: "stat.useItem.335", name: "Milk Used",
            checksumKey: "658b5f77ff892a455a7fce5dc93268ac", category: .use, itemID: 335,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_624, key: "stat.useItem.336", name: "Brick Used",
            checksumKey: "6474336f089d541c9cec4a1df0c3b6cf", category: .use, itemID: 336,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_625, key: "stat.useItem.337", name: "Clay Used",
            checksumKey: "72cfc6fe503df207d53119aa7d5b84b4", category: .use, itemID: 337,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_626, key: "stat.useItem.338", name: "Sugar Canes Used",
            checksumKey: "3070c2283ca5fd0fe00f7880a4bcdf18", category: .use, itemID: 338,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_627, key: "stat.useItem.339", name: "Paper Used",
            checksumKey: "340cef5b043dceb7073ede0be69d700d", category: .use, itemID: 339,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_628, key: "stat.useItem.340", name: "Book Used",
            checksumKey: "24dda1839a72d6707ed1932f6f32bd8e", category: .use, itemID: 340,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_629, key: "stat.useItem.341", name: "Slimeball Used",
            checksumKey: "1c50c7d94cec18710417d513708094d1", category: .use, itemID: 341,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_630, key: "stat.useItem.342", name: "Minecart with Chest Used",
            checksumKey: "2b1f11fed636bf7892650b9adc9b8e94", category: .use, itemID: 342,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_631, key: "stat.useItem.343", name: "Minecart with Furnace Used",
            checksumKey: "afd9ba61c39fa742a840fe6ab2cfb490", category: .use, itemID: 343,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_632, key: "stat.useItem.344", name: "Egg Used",
            checksumKey: "b709157ffabe225e820218b020508173", category: .use, itemID: 344,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_633, key: "stat.useItem.345", name: "Compass Used",
            checksumKey: "3e9f7b867952f7b2df48e156402d558", category: .use, itemID: 345, isIndependent: false,
            isListed: true),
        .init(
            id: 16_908_634, key: "stat.useItem.346", name: "Fishing Rod Used",
            checksumKey: "ab9f22a1fbc265d19a4dd7f84f3a4585", category: .use, itemID: 346,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_635, key: "stat.useItem.347", name: "Clock Used",
            checksumKey: "c89cf9510108d63d7d181b3f7c546094", category: .use, itemID: 347,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_636, key: "stat.useItem.348", name: "Glowstone Dust Used",
            checksumKey: "c7af3251ce44f2dafb2c192d817e9c52", category: .use, itemID: 348,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_637, key: "stat.useItem.349", name: "Raw Fish Used",
            checksumKey: "796f607d214012447b7c552673f95b4a", category: .use, itemID: 349,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_638, key: "stat.useItem.350", name: "Cooked Fish Used",
            checksumKey: "ea796bd83dd7689d322085c74d0957a7", category: .use, itemID: 350,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_639, key: "stat.useItem.351", name: "item.dyePowder.name Used",
            checksumKey: "ce2f6f842d68418baad5fc2ecefcb879", category: .use, itemID: 351,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_640, key: "stat.useItem.352", name: "Bone Used",
            checksumKey: "6b3016429a5f814f3cccaff484a46831", category: .use, itemID: 352,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_641, key: "stat.useItem.353", name: "Sugar Used",
            checksumKey: "7dea9bdb69c9c5965609eab99af9f9d9", category: .use, itemID: 353,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_642, key: "stat.useItem.354", name: "Cake Used",
            checksumKey: "3add5c50b3427182fcb7dd04fe953945", category: .use, itemID: 354,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_643, key: "stat.useItem.355", name: "Bed Used",
            checksumKey: "4175965cd5cee134d43038ac54858b0f", category: .use, itemID: 355,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_644, key: "stat.useItem.356", name: "Redstone Repeater Used",
            checksumKey: "feae27a32b6cc95860ec46da6d37c4b0", category: .use, itemID: 356,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_645, key: "stat.useItem.357", name: "Cookie Used",
            checksumKey: "5898813ee0b2785afc9dad2524f56162", category: .use, itemID: 357,
            isIndependent: false, isListed: true),
        .init(
            id: 16_908_646, key: "stat.useItem.358", name: "Map Used", checksumKey: "null", category: .use,
            itemID: 358, isIndependent: false, isListed: true),
        .init(
            id: 16_908_647, key: "stat.useItem.359", name: "Shears Used", checksumKey: "null", category: .use,
            itemID: 359, isIndependent: false, isListed: true),
        .init(
            id: 16_910_544, key: "stat.useItem.2256", name: "Music Disc Used",
            checksumKey: "adb04e128238341b88a18532f3448d13", category: .use, itemID: 2256,
            isIndependent: false, isListed: true),
        .init(
            id: 16_910_545, key: "stat.useItem.2257", name: "Music Disc Used",
            checksumKey: "8e274d3a14b5cb87cbce019d0a3b9a23", category: .use, itemID: 2257,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_080, key: "stat.breakItem.256", name: "Iron Shovel Depleted",
            checksumKey: "cfed396d9f54d3c04bc390a004916c52", category: .depleted, itemID: 256,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_081, key: "stat.breakItem.257", name: "Iron Pickaxe Depleted",
            checksumKey: "64f1b3409c0937114f77f9933a4e2b82", category: .depleted, itemID: 257,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_082, key: "stat.breakItem.258", name: "Iron Axe Depleted",
            checksumKey: "5a6e9dc254405a6cb066472172fa09b1", category: .depleted, itemID: 258,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_083, key: "stat.breakItem.259", name: "Flint and Steel Depleted",
            checksumKey: "b23adf8b24d9a42637977c3322f02b75", category: .depleted, itemID: 259,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_091, key: "stat.breakItem.267", name: "Iron Sword Depleted",
            checksumKey: "df1b76bca1e6a035d3e22e7c01f67bc6", category: .depleted, itemID: 267,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_092, key: "stat.breakItem.268", name: "Wooden Sword Depleted",
            checksumKey: "4bb3d702d36739ba62041c0c936cbfb6", category: .depleted, itemID: 268,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_093, key: "stat.breakItem.269", name: "Wooden Shovel Depleted",
            checksumKey: "d02062bdb07f81100381ef87e6fc2922", category: .depleted, itemID: 269,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_094, key: "stat.breakItem.270", name: "Wooden Pickaxe Depleted",
            checksumKey: "1a0d208f9f489b37b800c6eeaaa752c9", category: .depleted, itemID: 270,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_095, key: "stat.breakItem.271", name: "Wooden Axe Depleted",
            checksumKey: "34ee6807c2040168606740d0e3f46e30", category: .depleted, itemID: 271,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_096, key: "stat.breakItem.272", name: "Stone Sword Depleted",
            checksumKey: "9b8bb8517841df03f1a894b238251068", category: .depleted, itemID: 272,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_097, key: "stat.breakItem.273", name: "Stone Shovel Depleted",
            checksumKey: "bb0b43349ffa6aa13b5d84ca70d25eb3", category: .depleted, itemID: 273,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_098, key: "stat.breakItem.274", name: "Stone Pickaxe Depleted",
            checksumKey: "b3b647da85fe51c6da997e28b66cb4c3", category: .depleted, itemID: 274,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_099, key: "stat.breakItem.275", name: "Stone Axe Depleted",
            checksumKey: "d33c3d7d3fbc6880e0e03ce573644b1e", category: .depleted, itemID: 275,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_100, key: "stat.breakItem.276", name: "Diamond Sword Depleted",
            checksumKey: "17d45fba9866349c133608e9d42e4ac9", category: .depleted, itemID: 276,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_101, key: "stat.breakItem.277", name: "Diamond Shovel Depleted",
            checksumKey: "74205e9529729bd0ef51c3d544c1e372", category: .depleted, itemID: 277,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_102, key: "stat.breakItem.278", name: "Diamond Pickaxe Depleted",
            checksumKey: "edf620106dc10c10a3357436a306400d", category: .depleted, itemID: 278,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_103, key: "stat.breakItem.279", name: "Diamond Axe Depleted",
            checksumKey: "74b3a17953dca5a0cb9bb8c47b241eca", category: .depleted, itemID: 279,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_107, key: "stat.breakItem.283", name: "Golden Sword Depleted",
            checksumKey: "1938aff98985ef5e79c7003868c1e91", category: .depleted, itemID: 283,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_108, key: "stat.breakItem.284", name: "Golden Shovel Depleted",
            checksumKey: "14b782f5d9afda571ce6c8bad868e2bd", category: .depleted, itemID: 284,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_109, key: "stat.breakItem.285", name: "Golden Pickaxe Depleted",
            checksumKey: "cb124718b4ecfb29a900e1e617c79544", category: .depleted, itemID: 285,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_110, key: "stat.breakItem.286", name: "Golden Axe Depleted",
            checksumKey: "ae3c73a1546a058da74d4b8a588b59f2", category: .depleted, itemID: 286,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_114, key: "stat.breakItem.290", name: "Wooden Hoe Depleted",
            checksumKey: "cbdefe9bd14088ad45141843474d2bb0", category: .depleted, itemID: 290,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_115, key: "stat.breakItem.291", name: "Stone Hoe Depleted",
            checksumKey: "641938697f84f6e7b59ebc08edc4648b", category: .depleted, itemID: 291,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_116, key: "stat.breakItem.292", name: "Iron Hoe Depleted",
            checksumKey: "74ccb1de521aa54c65ffcb906ffd1d3b", category: .depleted, itemID: 292,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_117, key: "stat.breakItem.293", name: "Diamond Hoe Depleted",
            checksumKey: "fffed44e7bb844ad6c69f7eb4540cff3", category: .depleted, itemID: 293,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_118, key: "stat.breakItem.294", name: "Golden Hoe Depleted",
            checksumKey: "536b2d3a4009eed61300bf5f0af7419e", category: .depleted, itemID: 294,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_122, key: "stat.breakItem.298", name: "Leather Cap Depleted",
            checksumKey: "8a8ea889723fc0f8de50c53339819871", category: .depleted, itemID: 298,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_123, key: "stat.breakItem.299", name: "Leather Tunic Depleted",
            checksumKey: "768b65f8e24b1e042b75cf6f576cfcd1", category: .depleted, itemID: 299,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_124, key: "stat.breakItem.300", name: "Leather Pants Depleted",
            checksumKey: "a4b5522486920acfc2ed97e105c7831", category: .depleted, itemID: 300,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_125, key: "stat.breakItem.301", name: "Leather Boots Depleted",
            checksumKey: "6e9b513f3c219f4276556070b36a0339", category: .depleted, itemID: 301,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_126, key: "stat.breakItem.302", name: "Chain Helmet Depleted",
            checksumKey: "942450301cd8068c9a14352c1cecc2d0", category: .depleted, itemID: 302,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_127, key: "stat.breakItem.303", name: "Chain Chestplate Depleted",
            checksumKey: "c98e2b8eb252d75a2a1f90144596ada4", category: .depleted, itemID: 303,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_128, key: "stat.breakItem.304", name: "Chain Leggings Depleted",
            checksumKey: "7b13a95332dac62ad73cddf33d3bba0f", category: .depleted, itemID: 304,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_129, key: "stat.breakItem.305", name: "Chain Boots Depleted",
            checksumKey: "1951adc5a346867490626a854788b9ad", category: .depleted, itemID: 305,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_130, key: "stat.breakItem.306", name: "Iron Helmet Depleted",
            checksumKey: "b75636944eeba77a4ce3f254460e0d49", category: .depleted, itemID: 306,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_131, key: "stat.breakItem.307", name: "Iron Chestplate Depleted",
            checksumKey: "bb5bc2285c0a2e24548533f59af76788", category: .depleted, itemID: 307,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_132, key: "stat.breakItem.308", name: "Iron Leggings Depleted",
            checksumKey: "929561410b14786db52aa89b675a9759", category: .depleted, itemID: 308,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_133, key: "stat.breakItem.309", name: "Iron Boots Depleted",
            checksumKey: "6b07bd2605f311d8134a8170ba49fd73", category: .depleted, itemID: 309,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_134, key: "stat.breakItem.310", name: "Diamond Helmet Depleted",
            checksumKey: "2f97923d891e3e8c1967d53f7734ff55", category: .depleted, itemID: 310,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_135, key: "stat.breakItem.311", name: "Diamond Chestplate Depleted",
            checksumKey: "dea0b11c8760d28eafbe76e25df7d301", category: .depleted, itemID: 311,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_136, key: "stat.breakItem.312", name: "Diamond Leggings Depleted",
            checksumKey: "586e309c00ba6f3c2ada595b742bef23", category: .depleted, itemID: 312,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_137, key: "stat.breakItem.313", name: "Diamond Boots Depleted",
            checksumKey: "29e48d74dc5062eb900d376196fd4f23", category: .depleted, itemID: 313,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_138, key: "stat.breakItem.314", name: "Golden Helmet Depleted",
            checksumKey: "fa79e8b641b225166b17ea86a9ecb174", category: .depleted, itemID: 314,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_139, key: "stat.breakItem.315", name: "Golden Chestplate Depleted",
            checksumKey: "7a66328b6b976337ff5bde5c7edccaa5", category: .depleted, itemID: 315,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_140, key: "stat.breakItem.316", name: "Golden Leggings Depleted",
            checksumKey: "95559b402657cf222a87248d1e6ce0f5", category: .depleted, itemID: 316,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_141, key: "stat.breakItem.317", name: "Golden boots Depleted",
            checksumKey: "52843420526ced65d57513afad342515", category: .depleted, itemID: 317,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_170, key: "stat.breakItem.346", name: "Fishing Rod Depleted",
            checksumKey: "56690bacbebf8107b83e80528f40740", category: .depleted, itemID: 346,
            isIndependent: false, isListed: true),
        .init(
            id: 16_974_183, key: "stat.breakItem.359", name: "Shears Depleted", checksumKey: "null",
            category: .depleted, itemID: 359, isIndependent: false, isListed: true),
    ]

    static let aliases: [[UInt16: Int]] = [
        [
            1: 16_777_217, 2: 16_777_219, 3: 16_777_219, 4: 16_777_220, 5: 16_777_221, 6: 16_777_222,
            12: 16_777_228, 13: 16_777_229, 14: 16_777_230, 15: 16_777_231, 16: 16_777_232, 17: 16_777_233,
            19: 16_777_235, 20: 16_777_236, 21: 16_777_237, 22: 16_777_238, 23: 16_777_239, 24: 16_777_240,
            25: 16_777_241, 27: 16_777_243, 28: 16_777_244, 29: 16_777_245, 30: 16_777_246, 31: 16_777_247,
            32: 16_777_248, 33: 16_777_249, 34: 16_777_250, 35: 16_777_251, 36: 16_777_252, 37: 16_777_253,
            38: 16_777_254, 39: 16_777_255, 40: 16_777_255, 41: 16_777_257, 42: 16_777_258, 43: 16_777_260,
            44: 16_777_260, 45: 16_777_261, 46: 16_777_262, 47: 16_777_263, 48: 16_777_264, 49: 16_777_265,
            50: 16_777_266, 53: 16_777_269, 54: 16_777_270, 56: 16_777_272, 57: 16_777_273, 58: 16_777_274,
            60: 16_777_219, 61: 16_777_277, 62: 16_777_277, 65: 16_777_281, 66: 16_777_282, 67: 16_777_283,
            69: 16_777_285, 70: 16_777_286, 72: 16_777_288, 73: 16_777_289, 74: 16_777_289, 75: 16_777_291,
            76: 16_777_291, 77: 16_777_293, 78: 16_777_294, 79: 16_777_295, 80: 16_777_296, 81: 16_777_297,
            82: 16_777_298, 84: 16_777_300, 85: 16_777_301, 86: 16_777_302, 87: 16_777_303, 88: 16_777_304,
            89: 16_777_305, 90: 16_777_306, 91: 16_777_302, 95: 16_777_311,
        ],
        [
            1: 16_842_753, 5: 16_842_757, 20: 16_842_772, 22: 16_842_774, 23: 16_842_775, 24: 16_842_776,
            25: 16_842_777, 27: 16_842_779, 28: 16_842_780, 29: 16_842_781, 33: 16_842_785, 35: 16_842_787,
            41: 16_842_793, 42: 16_842_794, 43: 16_842_796, 44: 16_842_796, 45: 16_842_797, 46: 16_842_798,
            47: 16_842_799, 50: 16_842_802, 53: 16_842_805, 54: 16_842_806, 57: 16_842_809, 58: 16_842_810,
            61: 16_842_813, 62: 16_842_813, 65: 16_842_817, 66: 16_842_818, 67: 16_842_819, 69: 16_842_821,
            70: 16_842_822, 72: 16_842_824, 75: 16_842_828, 76: 16_842_828, 77: 16_842_829, 80: 16_842_832,
            82: 16_842_834, 84: 16_842_836, 85: 16_842_837, 86: 16_842_843, 89: 16_842_841, 91: 16_842_843,
            96: 16_842_848, 256: 16_843_008, 257: 16_843_009, 258: 16_843_010, 259: 16_843_011,
            261: 16_843_013, 262: 16_843_014, 263: 16_843_015, 264: 16_843_016, 265: 16_843_017,
            266: 16_843_018, 267: 16_843_019, 268: 16_843_020, 269: 16_843_021, 270: 16_843_022,
            271: 16_843_023, 272: 16_843_024, 273: 16_843_025, 274: 16_843_026, 275: 16_843_027,
            276: 16_843_028, 277: 16_843_029, 278: 16_843_030, 279: 16_843_031, 280: 16_843_032,
            281: 16_843_033, 282: 16_843_034, 283: 16_843_035, 284: 16_843_036, 285: 16_843_037,
            286: 16_843_038, 290: 16_843_042, 291: 16_843_043, 292: 16_843_044, 293: 16_843_045,
            294: 16_843_046, 297: 16_843_049, 298: 16_843_050, 299: 16_843_051, 300: 16_843_052,
            301: 16_843_053, 302: 16_843_054, 303: 16_843_055, 304: 16_843_056, 305: 16_843_057,
            306: 16_843_058, 307: 16_843_059, 308: 16_843_060, 309: 16_843_061, 310: 16_843_062,
            311: 16_843_063, 312: 16_843_064, 313: 16_843_065, 314: 16_843_066, 315: 16_843_067,
            316: 16_843_068, 317: 16_843_069, 320: 16_843_072, 321: 16_843_073, 322: 16_843_074,
            323: 16_843_075, 324: 16_843_076, 325: 16_843_077, 328: 16_843_080, 330: 16_843_082,
            333: 16_843_085, 336: 16_843_088, 339: 16_843_091, 340: 16_843_092, 342: 16_843_094,
            343: 16_843_095, 345: 16_843_097, 346: 16_843_098, 347: 16_843_099, 350: 16_843_102,
            351: 16_843_103, 353: 16_843_105, 354: 16_843_106, 355: 16_843_107, 356: 16_843_108,
            357: 16_843_109, 358: 16_843_110, 359: 16_843_111,
        ],
        [
            1: 16_908_289, 2: 16_908_291, 3: 16_908_291, 4: 16_908_292, 5: 16_908_293, 6: 16_908_294,
            7: 16_908_295, 8: 16_908_296, 9: 16_908_296, 10: 16_908_298, 11: 16_908_299, 12: 16_908_300,
            13: 16_908_301, 14: 16_908_302, 15: 16_908_303, 16: 16_908_304, 17: 16_908_305, 18: 16_908_306,
            19: 16_908_307, 20: 16_908_308, 21: 16_908_309, 22: 16_908_310, 23: 16_908_311, 24: 16_908_312,
            25: 16_908_313, 26: 16_908_314, 27: 16_908_315, 28: 16_908_316, 29: 16_908_317, 30: 16_908_318,
            31: 16_908_319, 32: 16_908_320, 33: 16_908_321, 34: 16_908_322, 35: 16_908_323, 36: 16_908_324,
            37: 16_908_325, 38: 16_908_326, 39: 16_908_327, 40: 16_908_327, 41: 16_908_329, 42: 16_908_330,
            43: 16_908_332, 44: 16_908_332, 45: 16_908_333, 46: 16_908_334, 47: 16_908_335, 48: 16_908_336,
            49: 16_908_337, 50: 16_908_338, 51: 16_908_339, 52: 16_908_340, 53: 16_908_341, 54: 16_908_342,
            55: 16_908_343, 56: 16_908_344, 57: 16_908_345, 58: 16_908_346, 59: 16_908_347, 60: 16_908_291,
            61: 16_908_349, 62: 16_908_349, 63: 16_908_351, 64: 16_908_352, 65: 16_908_353, 66: 16_908_354,
            67: 16_908_355, 68: 16_908_356, 69: 16_908_357, 70: 16_908_358, 71: 16_908_359, 72: 16_908_360,
            73: 16_908_361, 74: 16_908_361, 75: 16_908_363, 76: 16_908_363, 77: 16_908_365, 78: 16_908_366,
            79: 16_908_367, 80: 16_908_368, 81: 16_908_369, 82: 16_908_370, 83: 16_908_371, 84: 16_908_372,
            85: 16_908_373, 86: 16_908_374, 87: 16_908_375, 88: 16_908_376, 89: 16_908_377, 90: 16_908_378,
            91: 16_908_374, 92: 16_908_380, 93: 16_908_381, 94: 16_908_381, 95: 16_908_383, 96: 16_908_384,
            256: 16_908_544, 257: 16_908_545, 258: 16_908_546, 259: 16_908_547, 260: 16_908_548,
            261: 16_908_549, 262: 16_908_550, 263: 16_908_551, 264: 16_908_552, 265: 16_908_553,
            266: 16_908_554, 267: 16_908_555, 268: 16_908_556, 269: 16_908_557, 270: 16_908_558,
            271: 16_908_559, 272: 16_908_560, 273: 16_908_561, 274: 16_908_562, 275: 16_908_563,
            276: 16_908_564, 277: 16_908_565, 278: 16_908_566, 279: 16_908_567, 280: 16_908_568,
            281: 16_908_569, 282: 16_908_570, 283: 16_908_571, 284: 16_908_572, 285: 16_908_573,
            286: 16_908_574, 287: 16_908_575, 288: 16_908_576, 289: 16_908_577, 290: 16_908_578,
            291: 16_908_579, 292: 16_908_580, 293: 16_908_581, 294: 16_908_582, 295: 16_908_583,
            296: 16_908_584, 297: 16_908_585, 298: 16_908_586, 299: 16_908_587, 300: 16_908_588,
            301: 16_908_589, 302: 16_908_590, 303: 16_908_591, 304: 16_908_592, 305: 16_908_593,
            306: 16_908_594, 307: 16_908_595, 308: 16_908_596, 309: 16_908_597, 310: 16_908_598,
            311: 16_908_599, 312: 16_908_600, 313: 16_908_601, 314: 16_908_602, 315: 16_908_603,
            316: 16_908_604, 317: 16_908_605, 318: 16_908_606, 319: 16_908_607, 320: 16_908_608,
            321: 16_908_609, 322: 16_908_610, 323: 16_908_611, 324: 16_908_612, 325: 16_908_613,
            326: 16_908_614, 327: 16_908_615, 328: 16_908_616, 329: 16_908_617, 330: 16_908_618,
            331: 16_908_619, 332: 16_908_620, 333: 16_908_621, 334: 16_908_622, 335: 16_908_623,
            336: 16_908_624, 337: 16_908_625, 338: 16_908_626, 339: 16_908_627, 340: 16_908_628,
            341: 16_908_629, 342: 16_908_630, 343: 16_908_631, 344: 16_908_632, 345: 16_908_633,
            346: 16_908_634, 347: 16_908_635, 348: 16_908_636, 349: 16_908_637, 350: 16_908_638,
            351: 16_908_639, 352: 16_908_640, 353: 16_908_641, 354: 16_908_642, 355: 16_908_643,
            356: 16_908_644, 357: 16_908_645, 358: 16_908_646, 359: 16_908_647, 2256: 16_910_544,
            2257: 16_910_545,
        ],
        [
            256: 16_974_080, 257: 16_974_081, 258: 16_974_082, 259: 16_974_083, 267: 16_974_091,
            268: 16_974_092, 269: 16_974_093, 270: 16_974_094, 271: 16_974_095, 272: 16_974_096,
            273: 16_974_097, 274: 16_974_098, 275: 16_974_099, 276: 16_974_100, 277: 16_974_101,
            278: 16_974_102, 279: 16_974_103, 283: 16_974_107, 284: 16_974_108, 285: 16_974_109,
            286: 16_974_110, 290: 16_974_114, 291: 16_974_115, 292: 16_974_116, 293: 16_974_117,
            294: 16_974_118, 298: 16_974_122, 299: 16_974_123, 300: 16_974_124, 301: 16_974_125,
            302: 16_974_126, 303: 16_974_127, 304: 16_974_128, 305: 16_974_129, 306: 16_974_130,
            307: 16_974_131, 308: 16_974_132, 309: 16_974_133, 310: 16_974_134, 311: 16_974_135,
            312: 16_974_136, 313: 16_974_137, 314: 16_974_138, 315: 16_974_139, 316: 16_974_140,
            317: 16_974_141, 346: 16_974_170, 359: 16_974_183,
        ],
    ]

    static let achievements: [AchievementDefinition] = [
        .init(
            id: 5_242_880, key: "openInventory", title: "Taking Inventory",
            description: "Open your inventory.", column: 0, row: 0, parentID: nil,
            icon: ItemStack(id: 340, damage: 0), isSpecial: false),
        .init(
            id: 5_242_881, key: "mineWood", title: "Getting Wood",
            description: "Attack a tree until a block of wood pops out", column: 2, row: 1,
            parentID: 5_242_880, icon: ItemStack(id: 17, damage: 0), isSpecial: false),
        .init(
            id: 5_242_882, key: "buildWorkBench", title: "Benchmarking",
            description: "Craft a workbench with four blocks of planks", column: 4, row: -1,
            parentID: 5_242_881, icon: ItemStack(id: 58, damage: 0), isSpecial: false),
        .init(
            id: 5_242_883, key: "buildPickaxe", title: "Time to Mine!",
            description: "Use planks and sticks to make a pickaxe", column: 4, row: 2, parentID: 5_242_882,
            icon: ItemStack(id: 270, damage: 0), isSpecial: false),
        .init(
            id: 5_242_884, key: "buildFurnace", title: "Hot Topic",
            description: "Construct a furnace out of eight stone blocks", column: 3, row: 4,
            parentID: 5_242_883, icon: ItemStack(id: 62, damage: 0), isSpecial: false),
        .init(
            id: 5_242_885, key: "acquireIron", title: "Acquire Hardware", description: "Smelt an iron ingot",
            column: 1, row: 4, parentID: 5_242_884, icon: ItemStack(id: 265, damage: 0), isSpecial: false),
        .init(
            id: 5_242_886, key: "buildHoe", title: "Time to Farm!",
            description: "Use planks and sticks to make a hoe", column: 2, row: -3, parentID: 5_242_882,
            icon: ItemStack(id: 290, damage: 0), isSpecial: false),
        .init(
            id: 5_242_887, key: "makeBread", title: "Bake Bread", description: "Turn wheat into bread",
            column: -1, row: -3, parentID: 5_242_886, icon: ItemStack(id: 297, damage: 0), isSpecial: false),
        .init(
            id: 5_242_888, key: "bakeCake", title: "The Lie", description: "Wheat, sugar, milk and eggs!",
            column: 0, row: -5, parentID: 5_242_886, icon: ItemStack(id: 354, damage: 0), isSpecial: false),
        .init(
            id: 5_242_889, key: "buildBetterPickaxe", title: "Getting an Upgrade",
            description: "Construct a better pickaxe", column: 6, row: 2, parentID: 5_242_883,
            icon: ItemStack(id: 274, damage: 0), isSpecial: false),
        .init(
            id: 5_242_890, key: "cookFish", title: "Delicious Fish", description: "Catch and cook fish!",
            column: 2, row: 6, parentID: 5_242_884, icon: ItemStack(id: 350, damage: 0), isSpecial: false),
        .init(
            id: 5_242_891, key: "onARail", title: "On A Rail",
            description: "Travel by minecart at least 1 km from where you started", column: 2, row: 3,
            parentID: 5_242_885, icon: ItemStack(id: 66, damage: 0), isSpecial: true),
        .init(
            id: 5_242_892, key: "buildSword", title: "Time to Strike!",
            description: "Use planks and sticks to make a sword", column: 6, row: -1, parentID: 5_242_882,
            icon: ItemStack(id: 268, damage: 0), isSpecial: false),
        .init(
            id: 5_242_893, key: "killEnemy", title: "Monster Hunter",
            description: "Attack and destroy a monster", column: 8, row: -1, parentID: 5_242_892,
            icon: ItemStack(id: 352, damage: 0), isSpecial: false),
        .init(
            id: 5_242_894, key: "killCow", title: "Cow Tipper", description: "Harvest some leather",
            column: 7, row: -3, parentID: 5_242_892, icon: ItemStack(id: 334, damage: 0), isSpecial: false),
        .init(
            id: 5_242_895, key: "flyPig", title: "When Pigs Fly", description: "Fly a pig off a cliff",
            column: 8, row: -4, parentID: 5_242_894, icon: ItemStack(id: 329, damage: 0), isSpecial: true),
    ]
}
