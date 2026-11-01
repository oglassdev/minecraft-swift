import Foundation
import Testing

@testable import MinecraftCore

struct PersistenceTests {
    @Test func originalJavaNBTSupportsAllBetaTagsAndModifiedUTF8() throws {
        let source = try fixture(Self.javaNBT)
        let document = try NBTCodec.decode(source)
        let values = try #require(document.tag.compoundValue)
        #expect(values["byte"] == .byte(-7))
        #expect(values["short"] == .short(-1234))
        #expect(values["int"] == .int(-123_456_789))
        #expect(values["long"] == .long(-1_234_567_890_123_456_789))
        #expect(values["float"] == .float(1.25))
        #expect(values["double"] == .double(-123.5))
        #expect(values["bytes"] == .byteArray([0, 127, 128, 255]))
        #expect(values["text"] == .string("A\0😀"))
        #expect(values["list"] == .list(.compound, [.compound(["nested": .string("yes")])]))
        #expect(values["empty"] == .list(.byte, []))
        #expect(try NBTCodec.decode(NBTCodec.encode(document)) == document)
    }

    @Test func levelDatLoadsJavaPlayerAndPreservesUnknownFieldsWithBackup() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let levelURL = directory.appendingPathComponent("level.dat")
        try fixture(Self.javaLevel).write(to: levelURL)
        let storage = WorldStorage(directory: directory)
        var level = try #require(try storage.loadLevel())
        #expect(level.seed == 123_456_789)
        #expect(level.time == 9000)
        #expect(level.spawn == BlockPosition(1, 65, 2))
        #expect(level.player.position == SIMD3(1.5, 65, 2.5))
        #expect(abs(level.player.yaw + .pi / 2) < 0.00001)
        #expect(abs(level.player.pitch - .pi / 6) < 0.00001)
        #expect(level.player.inventory.slots[0] == ItemStack(id: 264, count: 3))
        #expect(level.player.inventory.armor[3] == ItemStack(id: 310, damage: 17))
        level.time = 9100
        level.nextEntityID = 200
        storage.reserveEntityIDs(through: 250)
        level.player.inventory.slots[0]?.count = 2
        level.player.dimension = -1
        level.weather = WorldWeather(
            seed: level.seed, raining: true, thundering: false,
            rainTime: 1234, thunderTime: 5678)
        try storage.saveLevel(level)
        let gzip = try Data(contentsOf: levelURL)
        #expect(Array(gzip.prefix(2)) == [0x1F, 0x8B])
        let rewritten = try NBTCodec.decode(NBTCompression.gzip.decompress(gzip))
        let root = try #require(rewritten.tag.compoundValue)
        let data = try #require(root["Data"]?.compoundValue)
        let player = try #require(data["Player"]?.compoundValue)
        #expect(root["CustomRoot"] == .string("keep level root"))
        #expect(data["CustomWorld"] == .string("keep world"))
        #expect(player["CustomPlayer"] == .string("keep player"))
        #expect(player["Dimension"] == .int(-1))
        #expect(data["version"] == .int(19132))
        #expect(data["SwiftNextEntityID"] == .long(251))
        #expect(data["rainTime"] == .int(1234))
        #expect(data["thunderTime"] == .int(5678))
        #expect(data["raining"] == .byte(1))
        #expect(data["thundering"] == .byte(0))
        let savedWeather = try #require(try WorldStorage(directory: directory).loadLevel()).weather
        #expect(savedWeather.raining && !savedWeather.thundering)
        #expect(savedWeather.rainTime == 1234 && savedWeather.thunderTime == 5678)
        #expect(savedWeather.rainStrength == 1 && savedWeather.thunderStrength == 0)
        let slots = try #require(player["Inventory"]?.listValue)
        #expect(slots.contains { $0.compoundValue?["Slot"] == .byte(99) })
        #expect(slots.contains { $0.compoundValue?["Extra"] == .string("keep item") })
        try Data([1, 2, 3]).write(to: levelURL)
        let recovered = try #require(try WorldStorage(directory: directory).loadLevel())
        #expect(recovered.time == 9000)
        #expect(recovered.player.inventory.slots[0]?.count == 3)
    }

    @Test func javaMcRegionChunkPreservesNibblesUnknownDataAndTileEntities() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let regionDirectory = directory.appendingPathComponent("region")
        try FileManager.default.createDirectory(at: regionDirectory, withIntermediateDirectories: true)
        let url = regionDirectory.appendingPathComponent("r.-1.-1.mcr")
        let position = ChunkPosition(-1, -1)
        let compressed = try fixture(Self.javaChunk)
        var region = Data(count: 12288)
        putUInt32(0x0201, in: &region, at: 1023 * 4)
        putUInt32(UInt32(compressed.count + 1), in: &region, at: 8192)
        region[8196] = 2
        region.replaceSubrange(8197..<8197 + compressed.count, with: compressed)
        try region.write(to: url)

        let storage = WorldStorage(directory: directory)
        var chunk = try #require(try storage.loadChunk(at: position))
        #expect(chunk.position == position)
        #expect(chunk.blockIDs[321] == 250)
        #expect(chunk.metadata[320] == 3)
        #expect(chunk.metadata[321] == 10)
        #expect(chunk.skyLight.allSatisfy { $0 == 15 })
        #expect(chunk.isTerrainPopulated)
        let chest = BlockPosition(-15, 64, -14)
        var chestSlots = [ItemStack?](repeating: nil, count: 27)
        chestSlots[0] = ItemStack(id: 264, count: 3)
        #expect(chunk.blockEntities[chest] == .chest(slots: chestSlots))
        chestSlots[0]?.count = 1
        chunk.blockEntities[chest] = .chest(slots: chestSlots)
        chunk[3, 65, 4] = BlockState(.stone)
        chunk.skyLight[321] = 14
        try storage.saveChunk(chunk, worldTime: 5678)
        let output = try #require(try McRegionFile(url: url).readChunk(at: position))
        let root = try #require(output.tag.compoundValue)
        let level = try #require(root["Level"]?.compoundValue)
        #expect(root["RootExtra"] == .string("keep root"))
        #expect(level["ModData"]?.compoundValue?["text"] == .string("A\0😀"))
        #expect(level["LastUpdate"] == .long(5678))
        #expect(level["Entities"]?.listValue?.first?.compoundValue?["CustomEntity"] == .string("keep entity"))
        let tiles = try #require(level["TileEntities"]?.listValue)
        #expect(tiles.contains { $0.compoundValue?["id"] == .string("Piston") })
        #expect(tiles.contains { $0.compoundValue?["CustomChest"] == .string("keep chest") })
        #expect(level["HeightMap"]?.byteArrayValue?[4 << 4 | 3] == 66)
        let loaded = try #require(try WorldStorage(directory: directory).loadChunk(at: position))
        #expect(loaded.blockIDs == chunk.blockIDs)
        #expect(loaded.metadata == chunk.metadata)
        #expect(loaded.skyLight == chunk.skyLight)
        #expect(loaded.blockEntities[chest] == .chest(slots: chestSlots))
    }

    @Test func optionalPlayerBedSpawnRoundTripsAndClearsWithoutChangingWorldSpawn() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("level.dat")
        var original = try NBTCodec.decode(NBTCompression.gzip.decompress(fixture(Self.javaLevel)))
        var root = try #require(original.tag.compoundValue)
        var data = try #require(root["Data"]?.compoundValue)
        var player = try #require(data["Player"]?.compoundValue)
        player["SpawnX"] = .int(-12)
        player["SpawnY"] = .int(64)
        data["Player"] = .compound(player)
        root["Data"] = .compound(data)
        original.tag = .compound(root)
        try NBTCompression.gzip.compress(NBTCodec.encode(original)).write(to: url)
        let storage = WorldStorage(directory: directory)
        var level = try #require(try storage.loadLevel())
        #expect(level.player.bedSpawn == nil)
        #expect(level.spawn == BlockPosition(1, 65, 2))
        level.player.bedSpawn = BlockPosition(-12, 64, 34)
        try storage.saveLevel(level)
        let saved = try NBTCodec.decode(NBTCompression.gzip.decompress(Data(contentsOf: url)))
        let savedData = try #require(saved.tag.compoundValue?["Data"]?.compoundValue)
        let savedPlayer = try #require(savedData["Player"]?.compoundValue)
        #expect(savedPlayer["SpawnX"] == .int(-12))
        #expect(savedPlayer["SpawnY"] == .int(64))
        #expect(savedPlayer["SpawnZ"] == .int(34))
        #expect(
            savedData["SpawnX"] == .int(1) && savedData["SpawnY"] == .int(65)
                && savedData["SpawnZ"] == .int(2))
        #expect(savedPlayer["CustomPlayer"] == .string("keep player"))
        let reopened = WorldStorage(directory: directory)
        var restored = try #require(try reopened.loadLevel())
        #expect(restored.player.bedSpawn == BlockPosition(-12, 64, 34))
        restored.player.bedSpawn = nil
        try reopened.saveLevel(restored)
        let cleared = try NBTCodec.decode(NBTCompression.gzip.decompress(Data(contentsOf: url)))
        let clearedPlayer = try #require(
            cleared.tag.compoundValue?["Data"]?.compoundValue?["Player"]?.compoundValue)
        #expect(["SpawnX", "SpawnY", "SpawnZ"].allSatisfy { clearedPlayer[$0] == nil })
        let final = try #require(try WorldStorage(directory: directory).loadLevel())
        #expect(final.player.bedSpawn == nil && final.spawn == BlockPosition(1, 65, 2))
    }

    @Test func regionReallocationReusesSectorsWithoutChangingNeighbors() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("r.0.0.mcr")
        let region = McRegionFile(url: url)
        let first = ChunkPosition(0, 0)
        let neighbor = ChunkPosition(1, 0)
        let third = ChunkPosition(2, 0)
        let small = NBTDocument(tag: .compound(["value": .int(42)]))
        var random: UInt32 = 123
        let bytes: [UInt8] = (0..<30000).map { _ in
            random ^= random << 13
            random ^= random >> 17
            random ^= random << 5
            return UInt8(truncatingIfNeeded: random)
        }
        let large = NBTDocument(tag: .compound(["bytes": .byteArray(bytes)]))
        try region.writeChunk(small, at: first)
        try region.writeChunk(small, at: neighbor)
        try region.writeChunk(large, at: first)
        let grown = try Data(contentsOf: url).count
        #expect(try region.readChunk(at: neighbor) == small)
        #expect(try region.readChunk(at: first) == large)
        try region.writeChunk(small, at: first)
        try region.writeChunk(large, at: third)
        #expect(try Data(contentsOf: url).count == grown)
        #expect(try region.readChunk(at: neighbor) == small)
        #expect(try region.readChunk(at: third) == large)
    }

    @Test func blockEntityContainersAndFurnaceProgressRoundTrip() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        var chunk = Chunk(position: ChunkPosition(0, 0))
        let furnace = FurnaceState(
            input: ItemStack(id: 15, count: 2), fuel: ItemStack(id: 263),
            output: ItemStack(id: 265), burnTicksRemaining: 900, cookTicks: 73)
        chunk.blockEntities = [
            BlockPosition(0, 64, 0): .furnace(furnace),
            BlockPosition(1, 64, 0): .dispenser(
                slots: [ItemStack(id: 262)] + Array(repeating: nil, count: 8)),
            BlockPosition(2, 64, 0): .sign(lines: ["one", "two", "three", "four"]),
            BlockPosition(3, 64, 0): .spawner(mobID: "Skeleton", delay: 133),
            BlockPosition(4, 64, 0): .note(pitch: 24),
            BlockPosition(5, 64, 0): .jukebox(record: 2256),
            BlockPosition(6, 64, 0): .piston(
                PistonState(
                    block: BlockState(.stone, metadata: 3),
                    facing: 5, extending: true, isSource: false, progress: 0.5)),
        ]
        let storage = WorldStorage(directory: directory)
        try storage.saveChunk(chunk, worldTime: 400)
        let loaded = try #require(try storage.loadChunk(at: chunk.position))
        #expect(loaded.blockEntities == chunk.blockEntities)
        #expect(!loaded.isTerrainPopulated)
    }

    @Test func vanillaEntityKindsOffsetsAndUnknownTagsSurviveSaving() throws {
        let item: NBTTag = .compound([
            "id": .string("Item"), "Pos": .list(.double, [.double(2), .double(64.125), .double(3)]),
            "Age": .short(123), "Health": .short(5),
            "Item": .compound(["id": .short(263), "Count": .byte(4), "Damage": .short(1)]),
        ])
        let sheep: NBTTag = .compound([
            "id": .string("Sheep"), "Pos": .list(.double, [.double(4), .double(64), .double(5)]),
            "Color": .byte(3), "Sheared": .byte(1), "Health": .short(7), "CustomMob": .string("retain"),
            "FallDistance": .float(2.5),
        ])
        let minecart: NBTTag = .compound([
            "id": .string("Minecart"),
            "Pos": .list(.double, [.double(6), .double(64 + Double(Float(0.7) / 2)), .double(7)]),
            "Type": .int(1),
        ])
        let painting = try NBTCodec.decode(fixture(Self.javaPainting)).tag
        var nextID: Int64 = 1
        let decoded = EntityNBT.decode([item, sheep, minecart, painting], nextID: &nextID)
        #expect(decoded.entities.count == 4)
        #expect(Set(decoded.entities.map(\.id)).count == 4)
        #expect(decoded.entities[0].position.y == 64)
        #expect(decoded.entities[0].itemStack == ItemStack(id: 263, count: 4, damage: 1))
        #expect(decoded.entities[0].ageTicks == 123)
        #expect(decoded.entities[1].metadata == 19)
        #expect(decoded.entities[1].health == 7)
        #expect(decoded.entities[1].fallDistance == 2.5)
        #expect(decoded.entities[2].position.y == 64)
        #expect(decoded.entities[2].metadata == 1)
        #expect(decoded.entities[3].kind == "painting")
        #expect(decoded.entities[3].position == SIMD3(1.9375, 63, -2))
        #expect(decoded.entities[3].paintingAnchor == BlockPosition(2, 64, -3))
        #expect(decoded.entities[3].paintingMotive == "Pointer")
        #expect(decoded.entities[3].paintingFacing == 1)
        let rewritten = EntityNBT.encode(decoded.entities, previous: decoded.entries)
        let savedPainting = rewritten.listValue?.first { $0.compoundValue?["id"] == .string("Painting") }?
            .compoundValue
        #expect(savedPainting?["Pos"] == .list(.double, [.double(1.9375), .double(65), .double(-2)]))
        #expect(savedPainting?["Dir"] == .byte(1))
        #expect(rewritten.listValue?.contains { $0.compoundValue?["CustomMob"] == .string("retain") } == true)
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        var chunk = Chunk(position: ChunkPosition(0, 0))
        chunk.entities = decoded.entities
        let storage = WorldStorage(directory: directory)
        try storage.saveChunk(chunk, worldTime: 123)
        let restored = try #require(try storage.loadChunk(at: chunk.position))
        #expect(restored.entities.map(\.kind) == decoded.entities.map(\.kind))
        #expect(restored.entities.map(\.position) == decoded.entities.map(\.position))
        #expect(restored.entities.map(\.id) == decoded.entities.map(\.id))
        #expect(restored.entities[0].itemStack == decoded.entities[0].itemStack)
        #expect(restored.entities[1].metadata == decoded.entities[1].metadata)
    }

    @Test func dimensionsKeepRegionDataAndCachedUnknownTagsSeparate() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let position = ChunkPosition(0, 0)
        let storage = WorldStorage(directory: directory)
        var overworld = Chunk(position: position)
        overworld[0, 64, 0] = BlockState(.grass)
        try storage.saveChunk(overworld, worldTime: 100)
        let overworldRegion = McRegionFile(url: directory.appendingPathComponent("region/r.0.0.mcr"))
        var original = try #require(try overworldRegion.readChunk(at: position))
        var root = try #require(original.tag.compoundValue)
        root["OverworldOnly"] = .string("retained in overworld")
        original.tag = .compound(root)
        try overworldRegion.writeChunk(original, at: position)
        _ = try storage.loadChunk(at: position)
        storage.dimension = -1
        var nether = Chunk(position: position)
        nether[0, 64, 0] = BlockState(.netherrack)
        try storage.saveChunk(nether, worldTime: 200)
        let netherRegion = McRegionFile(url: directory.appendingPathComponent("DIM-1/region/r.0.0.mcr"))
        let netherDocument = try #require(try netherRegion.readChunk(at: position))
        #expect(netherDocument.tag.compoundValue?["OverworldOnly"] == nil)
        #expect(try storage.loadChunk(at: position)?[0, 64, 0]?.kind == .netherrack)
        storage.dimension = 0
        #expect(try storage.loadChunk(at: position)?[0, 64, 0]?.kind == .grass)
        #expect(
            try overworldRegion.readChunk(at: position)?.tag.compoundValue?["OverworldOnly"]
                == .string("retained in overworld"))
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "MinecraftPersistence-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func fixture(_ base64: String) throws -> Data { try #require(Data(base64Encoded: base64)) }

    private func putUInt32(_ value: UInt32, in data: inout Data, at offset: Int) {
        for index in 0..<4 { data[offset + index] = UInt8(truncatingIfNeeded: value >> (24 - index * 8)) }
    }

    // These fixtures were encoded by Beta 1.7.3's original Java NBT classes.
    private static let javaPainting =
        "CgAACQAGTW90aW9uBgAAAAMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAANBaXIBLAEACE9uR3JvdW5kAAEAA0RpcgEJAAhSb3RhdGlvbgUAAAACQrQAAAAAAAAFAAxGYWxsRGlzdGFuY2UAAAAACAAGTW90aXZlAAdQb2ludGVyCQADUG9zBgAAAAM//wAAAAAAAEBQQAAAAAAAwAAAAAAAAAACAARGaXJlAAADAAVUaWxlWQAAAEAIAAJpZAAIUGFpbnRpbmcDAAVUaWxlWAAAAAIDAAVUaWxlWv////0A"
    private static let javaNBT =
        "CgAAAQAEYnl0ZfkGAAZkb3VibGXAXuAAAAAAAAcABWJ5dGVzAAAABAB/gP8CAAVzaG9ydPsuCAAEdGV4dAAJQcCA7aC97biABQAFZmxvYXQ/oAAACQAEbGlzdAoAAAABCAAGbmVzdGVkAAN5ZXMACgAIY29tcG91bmQIAAZuZXN0ZWQAA3llcwADAANpbnT4pDLrBAAEbG9uZ+7d7wuCFn7rCQAFZW1wdHkBAAAAAAA="
    private static let javaChunk =
        "eJzt3L2OHEUQAOCa27/ZPQdExH4CAgJSG58tQDpLJ2xSpPFtc7fan1nt9KJbB3Dyk1iChyBB8jOQI5FbBuGIn+CY3TsQIkV4hfR9SU93dVXXvECNIsoYflzX+cFFXlUxnKa0vL1q96PoHafP06wT3acndXPVGkT/3qw+nTYRl8G/9Nu+GwAA3rT39t0AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/iUGUj6ab48nZeY64G1cAAAAAAAAAAAAAAAAAAADA3g1i+GHaDgN4WC0jin1PJ9i7boyOqyZ/shxXOd0cfTeKwcN6fL/KVRHdJ5ucfu1Hf1yvn8zSi09/2F0aRG8baHYlvry8Oohec16v8u/vlNHN6SLH8P0Xl6+ef/vqm8te9D6b1VW+8zxiGN3ZpMmjNq8oo79ITU7j6GzaSqMoT+v5sl4vxv+IdKIzWeRfvn73ZbdNrxdnP37/0+Gzt794OYxemi/zprjpaXRvVp9O/xr2AAAAAAAAAAAAAAAAAAAAAOzfILrbIQb/h1EAX+27AQAAAAAAAAAAAAAAAAAAAHgDOtG9OKmbq1YRbz1Oq1U1WZzUy/WsymlcDOPW48ksPVjkSZ6kZtRmHJRxeLRucj0/Ok9NjtE0peXt0+13J4qLttDP7bppb95t16ft/vUweh/lNN+lF0V0H83qHAdxMBkXZRG9o3q9yJ2D6N+v5tVZai+V21gb2D1wU/X1n1V7US5X9dkqNc2d3R9cP3Kd0z+ZtK0tYhjl35suyrh13fTudBOHu67TbnPz2geTapHbu38AHQBu1Q=="
    private static let javaLevel =
        "H4sIAAAAAAAA/01RPUsDQRB995HL3iUgAe0DNvaCbTSJoEElJIJf1eKN8fDuNmw2X51/Q/+AnZWNIIilhZV/xNLS3VsPnWbmDe+9mZ2NAIaoM50okQ2EUFi5IRo3U5pR2pS6EcHvcsV9RAOexyIbEsXQUb34WGOoWeWJkGmMqJDOTR0h6Kd8STJEcChUIvJAa7zW852J+9d3m1ufm0Uw1K2RFaFWOI0L4CLYI56qazRCeH0xsU7fKGK7//C4equzb7GHsJtklE/0SINDsIFQ3GxQ0dBtPwFvX6Yf7uczypWQy8joGCq7CyU5wmJ2oihz4A9TfRIXbhI7zEGlI6a58vRGXZ7xEWndL2dkOVslx/njNErOZcGBU3Lc/z568WA45vP8TNc7JTg3K5fg1IxjCA/M3xzxjFBvk+LNq2ShppJ8+Mf65fYM6xseqjOS9gy9F+AHvhOJHekBAAA="
}
