import Foundation
import Testing

@testable import MinecraftCore

struct WorldServiceTests {
    @Test func newWorldUsesBetaSpawnBeforeSavingAndRestoresItsExactPosition() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "MinecraftNewWorld-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = WorldService(
            directory: directory, newWorldSeed: 123_456_789, newWorldName: "New fixture")
        let loaded = try await service.load(radius: 1)
        let spawn = loaded.level.spawn
        #expect(loaded.world.seed == 123_456_789 && loaded.level.name == "New fixture")
        #expect(spawn.y == 64 && loaded.center == spawn.chunk)
        #expect(loaded.level.player.position.x == Double(spawn.x) + 0.5)
        #expect(loaded.level.player.position.z == Double(spawn.z) + 0.5)
        #expect(loaded.level.player.position.y >= 65)
        #expect(
            BlockCollision.boxes(
                in: loaded.world, intersecting: Player(position: loaded.level.player.position).bounds
            )
            .isEmpty)
        try await service.save(chunks: Array(loaded.world.chunks.values), level: loaded.level)
        let restarted = try await WorldService(directory: directory).load(radius: 1)
        #expect(restarted.level.spawn == spawn)
        expectPlayer(restarted.level.player, equals: loaded.level.player)
    }

    @Test func savedGameSurvivesRealmTravelRestartAndStaleSaveRejection() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "MinecraftService-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = WorldStorage(directory: directory)
        for dimension: Int8 in [0, -1] {
            storage.dimension = dimension
            for x in -3...3 {
                for z in -3...3 {
                    var chunk = Chunk(position: ChunkPosition(x, z))
                    chunk.isTerrainPopulated = true
                    for localX in 0..<16 {
                        for localZ in 0..<16 {
                            chunk[localX, dimension == 0 ? 63 : 31, localZ] = BlockState(
                                dimension == 0 ? .grass : .netherrack)
                        }
                    }
                    try storage.saveChunk(chunk, worldTime: 100)
                }
            }
        }
        var inventory = PlayerInventory()
        inventory.slots[0] = ItemStack(id: 264, count: 3)
        inventory.slots[1] = ItemStack(id: 278, damage: 17)
        inventory.armor[3] = ItemStack(id: 310, damage: 12)
        let initialPlayer = SavedPlayer(
            position: SIMD3(8.5, 64, 8.5), velocity: .zero, yaw: 0.7, pitch: -0.3,
            health: 17, inventory: inventory)
        let initialLevel = SavedLevel(
            seed: 37, time: 1200, spawn: BlockPosition(8, 64, 8), player: initialPlayer,
            name: "Actor fixture", nextEntityID: 99,
            weather: WorldWeather(seed: 37, raining: true, rainTime: 3456, thunderTime: 7890))
        try storage.saveLevel(initialLevel)
        var colors = Array(repeating: UInt8(0), count: 16384)
        colors[10 + 20 * 128] = 14
        let originalMap = BetaMapData(
            id: 7, centerX: 16, centerZ: -16, dimension: 0, scale: 2, colors: colors)
        let initialMaps = BetaMapCollection(maps: [7: originalMap], idCounts: ["map": 7, "other": 23])
        try BetaMapStorage(directory: directory.appendingPathComponent("data")).save(initialMaps)

        let service = WorldService(directory: directory, newWorldSeed: 999, newWorldName: "Unused")
        let loaded = try await service.load(radius: 1)
        #expect(loaded.world.dimension == 0 && loaded.world.chunks.count == 9 && loaded.radius == 1)
        #expect(loaded.center == ChunkPosition(0, 0))
        #expect(loaded.level.seed == 37 && loaded.level.name == "Actor fixture")
        expectPlayer(loaded.level.player, equals: initialPlayer)
        expectMaps(loaded.maps, equals: initialMaps)

        let marker = BlockPosition(1, 64, 1)
        var overworld = loaded.world
        overworld[marker] = .diamondBlock
        var overworldLevel = loaded.level
        overworldLevel.time = 2400
        overworldLevel.player.position = SIMD3(9.25, 65.125, 8.5)
        overworldLevel.player.velocity = SIMD3(0.125, 0.25, -0.125)
        overworldLevel.player.yaw = 1.1
        overworldLevel.player.pitch = -0.25
        overworldLevel.player.health = 13
        overworldLevel.player.inventory.slots[0]?.count = 7
        overworldLevel.player.inventory.selectedHotbar = 2
        var maps = loaded.maps
        overworldLevel.player.inventory.slots[2] = maps.craft(
            at: overworldLevel.player.position, dimension: 0)
        maps.applyNetwork(id: 7, bytes: [0, 12, 34, 20, 21, 22])
        try await service.save(chunks: Array(overworld.chunks.values), level: overworldLevel, maps: maps)
        let savedOverworld = try await service.load(radius: 1)
        #expect(savedOverworld.world[marker] == .diamondBlock)
        expectPlayer(savedOverworld.level.player, equals: overworldLevel.player)
        expectMaps(savedOverworld.maps, equals: maps)
        #expect(savedOverworld.level.nextEntityID == 99)

        let arrival = SIMD3<Double>(6.5, 34, 5.5)
        let nether = try await service.travel(
            from: savedOverworld.world, level: savedOverworld.level, to: -1,
            position: arrival, yaw: savedOverworld.level.player.yaw, placePortal: false, maps: maps)
        #expect(
            nether.world.dimension == -1 && nether.level.player.dimension == -1
                && nether.world.chunks.count == 49)
        #expect(nether.level.player.position == arrival && nether.level.player.velocity == .zero)
        #expect(nether.world[BlockPosition(1, 31, 1)] == .netherrack && nether.world[marker] == nil)
        #expect(nether.level.player.inventory == overworldLevel.player.inventory)
        expectMaps(nether.maps, equals: maps)
        var netherWorld = nether.world
        netherWorld[marker] = .glowstone
        var netherLevel = nether.level
        netherLevel.time = 3600
        netherLevel.player.position = SIMD3(6.75, 35, 5.25)
        netherLevel.player.velocity = SIMD3(0.25, 0, -0.5)
        netherLevel.player.yaw = -0.75
        netherLevel.player.pitch = 0.2
        netherLevel.player.health = 11
        netherLevel.player.inventory.slots[0]?.count = 5
        netherLevel.player.inventory.slots[3] = maps.craft(at: netherLevel.player.position, dimension: -1)
        maps.applyNetwork(id: 8, bytes: [0, 5, 6, 30, 31])
        try await service.save(
            chunks: [#require(netherWorld.chunks[ChunkPosition(0, 0)])], level: netherLevel, maps: maps)
        let activeLevelData = try Data(contentsOf: directory.appendingPathComponent("level.dat"))
        let activeCountData = try Data(contentsOf: directory.appendingPathComponent("data/idcounts.dat"))
        let netherRegion = directory.appendingPathComponent("DIM-1/region/r.0.0.mcr")
        #expect(FileManager.default.fileExists(atPath: netherRegion.path))

        var staleWorld = savedOverworld.world
        staleWorld[marker] = .goldBlock
        var staleLevel = savedOverworld.level
        staleLevel.time = -99
        staleLevel.player.inventory = PlayerInventory()
        let staleChunk = try #require(staleWorld.chunks[ChunkPosition(0, 0)])
        let staleMaps = BetaMapCollection(idCounts: ["map": 100])
        try await service.save(chunks: [staleChunk], level: staleLevel, maps: staleMaps)
        try await service.saveChunks([staleChunk], worldTime: -99, dimension: 0)
        await #expect(throws: WorldService.TransitionError.self) {
            try await service.travel(
                from: staleWorld, level: staleLevel, to: 0,
                position: staleLevel.player.position, yaw: 0, placePortal: false, maps: staleMaps)
        }
        #expect(try Data(contentsOf: directory.appendingPathComponent("level.dat")) == activeLevelData)
        #expect(
            try Data(contentsOf: directory.appendingPathComponent("data/idcounts.dat")) == activeCountData)

        let restarted = WorldService(directory: directory)
        let restoredNether = try await restarted.load(radius: 1)
        #expect(restoredNether.world.dimension == -1 && restoredNether.world[marker] == .glowstone)
        #expect(restoredNether.world.climate(atX: 1, z: 1).temperature == 1)
        #expect(restoredNether.world.climate(atX: 1, z: 1).humidity == 0)
        expectPlayer(restoredNether.level.player, equals: netherLevel.player)
        expectMaps(restoredNether.maps, equals: maps)
        #expect(restoredNether.level.time == 3600 && restoredNether.level.weather.raining)
        #expect(
            restoredNether.level.weather.rainTime == 3456 && restoredNether.level.weather.thunderTime == 7890)
        let returned = try await restarted.travel(
            from: restoredNether.world, level: restoredNether.level, to: 0,
            position: overworldLevel.player.position, yaw: restoredNether.level.player.yaw,
            placePortal: false, maps: restoredNether.maps)
        #expect(returned.world.dimension == 0 && returned.world[marker] == .diamondBlock)
        #expect(returned.level.player.position == overworldLevel.player.position)
        #expect(
            returned.level.player.inventory == netherLevel.player.inventory
                && returned.level.player.health == 11)
        #expect(returned.level.player.velocity == .zero)
        expectMaps(returned.maps, equals: maps)
        let finalLoad = try await WorldService(directory: directory).load(radius: 1)
        expectPlayer(finalLoad.level.player, equals: returned.level.player)
        expectMaps(finalLoad.maps, equals: maps)
        #expect(finalLoad.world[marker] == .diamondBlock && finalLoad.level.player.dimension == 0)
        #expect(finalLoad.maps.idCounts == ["map": 9, "other": 23])
        #expect(finalLoad.maps[9]?.dimension == -1)
        #expect(
            FileManager.default.fileExists(atPath: directory.appendingPathComponent("data/map_9.dat").path))
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("DIM-1/data").path))
        let diskNether = try #require(
            try WorldStorage(directory: directory, dimension: -1).loadChunk(at: ChunkPosition(0, 0)))
        #expect(diskNether[1, 64, 1]?.kind == .glowstone)
    }

    private func expectPlayer(_ actual: SavedPlayer, equals expected: SavedPlayer) {
        #expect(actual.position == expected.position && actual.velocity == expected.velocity)
        #expect(abs(actual.yaw - expected.yaw) < 0.00001 && abs(actual.pitch - expected.pitch) < 0.00001)
        #expect(
            actual.inventory == expected.inventory && actual.health == expected.health
                && actual.dimension == expected.dimension)
    }

    private func expectMaps(_ actual: BetaMapCollection, equals expected: BetaMapCollection) {
        #expect(actual.idCounts == expected.idCounts && Set(actual.maps.keys) == Set(expected.maps.keys))
        for (id, map) in expected.maps {
            #expect(actual[id]?.centerX == map.centerX && actual[id]?.centerZ == map.centerZ)
            #expect(actual[id]?.dimension == map.dimension && actual[id]?.scale == map.scale)
            #expect(actual[id]?.colors == map.colors)
        }
    }
}
