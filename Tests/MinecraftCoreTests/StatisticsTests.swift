import Foundation
import Testing

@testable import MinecraftCore

@Suite struct StatisticsTests {
    @Test func originalRegistryAliasesAndPresentation() {
        #expect(StatisticRegistry.registered.count == 486)
        #expect(StatisticRegistry.all.count == 467)
        #expect(StatisticRegistry.general.count == 23)
        #expect(StatisticRegistry.blocks.count == 68 && StatisticRegistry.items.count == 106)
        #expect(Achievements.all.count == 16)
        #expect(StatisticRegistry.mine(blockID: 2)?.id == 16_777_219)
        #expect(StatisticRegistry.mine(blockID: 60)?.id == 16_777_219)
        #expect(StatisticRegistry.mine(blockID: 74)?.id == 16_777_289)
        #expect(StatisticRegistry.use(itemID: 359)?.checksumKey == "null")
        #expect(StatisticRegistry.definition(for: 1100)?.formatted(24001) == "20.00 m")
        #expect(StatisticRegistry.definition(for: 2000)?.formatted(100000) == "1.00 km")
        #expect(StatisticRegistry.definition(for: 2023)?.formatted(12345) == "12,345")
        #expect(Achievements.all[4].icon.id == 62 && Achievements.all[11].isSpecial)
        #expect(BlockMining.durabilityCostHittingEntity(with: ItemStack(id: 257)) == 2)
        #expect(BlockMining.durabilityCostHittingEntity(with: ItemStack(id: 290)) == 0)
        #expect(!BlockMining.recordsUseWhenMining(with: ItemStack(id: 359)))
    }

    @Test func exactOriginalJSONAndChecksum() throws {
        let changes = [
            StatisticChange(id: 1100, value: 24001), StatisticChange(id: 5_242_880, value: 1),
            StatisticChange(id: 16_777_233, value: 7),
        ]
        let expected =
            "{\r\n  \"user\":{\r\n    \"name\":\"Player\",\r\n    \"sessionid\":\"local\"\r\n  },\r\n  \"stats-change\":[\r\n    {\"1100\":24001},\r\n    {\"5242880\":1},\r\n    {\"16777233\":7}\r\n  ],\r\n  \"checksum\":\"cb511e6462cb2068c5e10a66c2674fe3\"\r\n}"
        #expect(StatisticsFileCodec.encode(changes) == expected)
        #expect(try StatisticsFileCodec.decode(expected) == [1100: 24001, 5_242_880: 1, 16_777_233: 7])
        #expect(StatisticsFileCodec.checksum([]) == "f5ddaf0ca7929578b408c909429f68f2")
        #expect(
            StatisticsFileCodec.checksum([StatisticChange(id: 16_908_647, value: 5)])
                == "9e7f53a441300dc0b8b89787bd85e4")
        let tampered = expected.replacingOccurrences(of: "24001", with: "24002")
        #expect(throws: StatisticsFileError.checksumMismatch) { try StatisticsFileCodec.decode(tampered) }
    }

    @Test func achievementsUseOriginalEventsAndRequireParents() {
        var stats = PlayerStatistics()
        let earlyWood = stats.recordPickup(ItemStack(id: 17))
        #expect(earlyWood.isEmpty && !stats.isUnlocked(Achievements.gettingWood))
        let inventory = stats.recordInventoryOpen()
        #expect(inventory.map(\.id) == [Achievements.takingInventory])
        _ = stats.recordMine(.wood)
        #expect(!stats.isUnlocked(Achievements.gettingWood))
        _ = stats.recordPickup(ItemStack(id: 17))
        _ = stats.recordCraft(ItemStack(id: 58))
        _ = stats.recordCraft(ItemStack(id: 270))
        _ = stats.recordCraft(ItemStack(id: 257))
        #expect(!stats.isUnlocked(Achievements.gettingAnUpgrade))
        _ = stats.recordCraft(ItemStack(id: 274))
        _ = stats.recordCraft(ItemStack(id: 61))
        _ = stats.recordPickup(ItemStack(id: 265))
        #expect(!stats.isUnlocked(Achievements.acquireHardware))
        let iron = stats.recordCraft(ItemStack(id: 265, count: 4), source: .furnace)
        #expect(iron.map(\.id) == [Achievements.acquireHardware])
        _ = stats.recordCraft(ItemStack(id: 268))
        _ = stats.recordKill(kind: "Cow")
        #expect(!stats.isUnlocked(Achievements.cowTipper))
        _ = stats.recordPickup(ItemStack(id: 334))
        _ = stats.recordKill(kind: "Slime")
        #expect(!stats.isUnlocked(Achievements.monsterHunter))
        _ = stats.recordKill(kind: "Zombie")
        #expect(stats.isUnlocked(Achievements.monsterHunter))
        #expect(stats.value(for: 2023) == 3)
        #expect(stats.value(for: 16_842_752 + 265) == 4)
        let repeated = stats.recordInventoryOpen()
        #expect(repeated.isEmpty && stats.value(for: Achievements.takingInventory) == 2)
    }

    @Test func travelUsesRoundedCentimetersAndMinecartDisplacement() {
        var stats = PlayerStatistics()
        for id in Achievements.takingInventory...Achievements.acquireHardware { stats.increment(id) }
        _ = stats.recordTravel(from: .zero, to: SIMD3(0.1, 0, 0), mode: .minecart)
        _ = stats.recordTravel(from: SIMD3(0.1, 0, 0), to: SIMD3(500, 0, 0), mode: .minecart)
        _ = stats.recordTravel(from: SIMD3(500, 0, 0), to: .zero, mode: .minecart)
        #expect(!stats.isUnlocked(Achievements.onARail))
        let rail = stats.recordTravel(from: .zero, to: SIMD3(1000, 0, 0), mode: .minecart)
        #expect(rail.map(\.id) == [Achievements.onARail])
        _ = stats.recordTravel(from: .zero, to: SIMD3(0.25, 0, 0), mode: .flying)
        #expect(stats.value(for: 2004) == 0)
        _ = stats.recordTravel(from: .zero, to: SIMD3(0.256, 0, 0), mode: .flying)
        #expect(stats.value(for: 2004) == 26)
        _ = stats.recordTravel(from: .zero, to: SIMD3(1, 1, 0), mode: .diving)
        #expect(stats.value(for: 2005) == 141)
    }

    @Test func localStorageMergesBaselineAndKeepsPendingBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = StatisticsStorage(directory: directory, username: "Player")
        try Data(StatisticsFileCodec.encode(values: [1000: 10]).utf8)
            .write(to: directory.appendingPathComponent("stats_player.dat"))
        try Data(StatisticsFileCodec.encode(values: [1000: 2]).utf8)
            .write(to: directory.appendingPathComponent("stats_Player_unsent.dat"))
        var stats = try storage.load()
        #expect(stats.value(for: 1000) == 12 && stats.pendingChanges[1000] == 2)
        stats.increment(1000, by: 3)
        try storage.save(stats)
        let restored = try storage.load()
        #expect(restored.value(for: 1000) == 15 && restored.pendingChanges[1000] == 5)
        let old = try StatisticsFileCodec.decode(
            String(contentsOf: directory.appendingPathComponent("stats_player_unsent.old"), encoding: .utf8))
        #expect(old[1000] == 2)
    }
}
