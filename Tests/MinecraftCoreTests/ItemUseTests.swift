import Foundation
import MinecraftCore
import Testing

@Suite struct ItemUseTests {
    @Test func originalProjectilesConsumeItemsAndUseOriginalSoundPitch() {
        var actions = ItemActions(seed: 123_456_789)
        var world = BlockWorld()
        var player = Player(position: SIMD3(2, 65, -3))
        var inventory = PlayerInventory()
        var entities = EntitySimulation(seed: 0, naturalSpawningEnabled: false)
        inventory.slots[5] = ItemStack(id: 262, count: 2)
        for (index, id) in [UInt16(261), 332, 344, 346].enumerated() {
            inventory.slots[0] = ItemStack(id: id, count: id == 332 || id == 344 ? 2 : 1)
            let result = actions.useInAir(
                world: &world, player: &player, inventory: &inventory,
                entities: &entities, yaw: 0, pitch: 0)
            #expect(result.handled)
            #expect(inventory.selectedStack?.count == 1)
            #expect(inventory.slots[5]?.count == 1)
            guard case .sound(let name, _, let volume, let pitch) = result.events.first else {
                Issue.record("Missing bow sound")
                return
            }
            #expect(name == "random.bow")
            #expect(volume == (id == 261 ? 1 : 0.5))
            let expected: [Float] = [0.938425064, 0.361883968, 0.407008410, 0.443484634]
            #expect(pitch == expected[index])
            let entity = entities.entities.last!
            #expect(entity.position.x == 2.1599999964237213)
            #expect(entity.position.y == (id == 346 ? 66.51999999850989 : 66.64000000059605))
            #expect(entity.position.z == -3)
            #expect(entity.projectileOwner == 0)
        }
        inventory.slots[0] = ItemStack(id: 261)
        inventory.slots[5] = nil
        let count = entities.entities.count
        #expect(
            !actions.useInAir(
                world: &world, player: &player, inventory: &inventory,
                entities: &entities, yaw: 0, pitch: 0
            ).handled)
        #expect(entities.entities.count == count)
        inventory.slots[0] = ItemStack(id: 346)
        #expect(
            actions.useInAir(
                world: &world, player: &player, inventory: &inventory,
                entities: &entities, yaw: 0, pitch: 0
            ).handled)
        #expect(!entities.entities.contains { $0.kind == "fishingHook" })
        #expect(inventory.selectedStack?.damage == 0)
    }

    @Test func vehiclePlacementAndAirConsumption() {
        var actions = ItemActions(seed: 0)
        var world = BlockWorld()
        world[BlockPosition(0, 63, -3)] = .stillWater
        world[BlockPosition(4, 65, -3)] = .rail
        var player = Player(position: SIMD3(0.5, 65, -2.5), health: 10)
        var inventory = PlayerInventory()
        var entities = EntitySimulation(seed: 0, naturalSpawningEnabled: false)
        inventory.slots[0] = ItemStack(id: 333)
        #expect(
            actions.useInAir(
                world: &world, player: &player, inventory: &inventory,
                entities: &entities, yaw: 0, pitch: -.pi / 2
            ).handled)
        #expect(inventory.selectedStack == nil)
        #expect(entities.entities.last?.kind == "boat")
        #expect(entities.entities.last?.position == SIMD3(0.5, 64, -2.5))
        let hit = BlockRaycast.hit(in: world, origin: SIMD3(4.5, 67, -2.5), direction: SIMD3(0, -1, 0))!
        for (id, type) in [(UInt16(328), UInt8(0)), (342, 1), (343, 2)] {
            inventory.slots[0] = ItemStack(id: id)
            #expect(
                actions.useOnBlock(
                    hit: hit, world: &world, player: &player, inventory: &inventory,
                    entities: &entities, yaw: 0, pitch: 0
                ).handled)
            #expect(inventory.selectedStack == nil)
            #expect(entities.entities.last?.metadata == type)
            #expect(entities.entities.last?.position == SIMD3(4.5, 65.5, -2.5))
        }
        inventory.slots[0] = ItemStack(id: 335)
        #expect(
            !actions.useInAir(
                world: &world, player: &player, inventory: &inventory,
                entities: &entities, yaw: 0, pitch: 0
            ).handled)
        world[BlockPosition(0, 66, -5)] = .stone
        #expect(
            actions.useInAir(
                world: &world, player: &player, inventory: &inventory,
                entities: &entities, yaw: 0, pitch: 0
            ).handled)
        #expect(inventory.selectedStack?.id == 325)
        inventory.slots[0] = ItemStack(id: 282)
        #expect(
            actions.useInAir(
                world: &world, player: &player, inventory: &inventory,
                entities: &entities, yaw: 0, pitch: 0
            ).handled)
        #expect(player.health == 20)
        #expect(inventory.selectedStack?.id == 281)
        inventory.slots[0] = ItemStack(id: 260)
        #expect(
            actions.useInAir(
                world: &world, player: &player, inventory: &inventory,
                entities: &entities, yaw: 0, pitch: 0
            ).handled)
        #expect(player.health == 20)
        #expect(inventory.selectedStack == nil)
        world[BlockPosition(10, 65, 0)] = .stone
        inventory.slots[0] = ItemStack(id: 321)
        let wall = BlockRaycast.hit(in: world, origin: SIMD3(10.5, 65.5, -2), direction: SIMD3(0, 0, 1))!
        #expect(
            actions.useOnBlock(
                hit: wall, world: &world, player: &player, inventory: &inventory,
                entities: &entities, yaw: 0, pitch: 0
            ).handled)
        #expect(inventory.selectedStack == nil)
        #expect(entities.entities.last?.kind == "painting")
    }

    @Test func mapColorsMatchOriginalItemMap() {
        var overworld = BlockWorld()
        var nether = BlockWorld(dimension: -1)
        for cx in -8...8 {
            for cz in -8...8 {
                var chunk = Chunk(position: ChunkPosition(cx, cz))
                for x in 0..<16 {
                    for z in 0..<16 {
                        let value = (cx * 16 + x) * 3 + (cz * 16 + z) * 5
                        let height = 60 + (value % 13 + 13) % 13
                        for y in 0...max(64, height) {
                            let kind: BlockKind =
                                y < height
                                ? .stone : (y == height ? (height < 64 ? .sand : .grass) : .stillWater)
                            chunk[x, y, z] = BlockState(kind)
                        }
                    }
                }
                overworld.setChunk(chunk)
                nether.setChunk(chunk)
            }
        }
        let vectors: [(BlockWorld, [UInt64])] = [
            (overworld, [0xa64b_5d39_2ab0_3955, 0xc1d2_9f0f_eff2_8c6e, 0x3672_88ab_d0ea_9760]),
            (nether, [0x620c_cfd6_c2a7_d322, 0x8efa_a656_651d_1e0a, 0x6eed_ffc1_4656_25cc]),
        ]
        for (world, expected) in vectors {
            for (scale, expected) in zip([UInt8(0), 3, 4], expected) {
                var map = BetaMapData(
                    id: 0, centerX: -13, centerZ: 21, dimension: world.dimension, scale: scale)
                for _ in 0..<16 { map.update(world: world, position: SIMD3(-3.75, 65, 7.25)) }
                let hash = map.colors.reduce(UInt64(0xcbf2_9ce4_8422_2325)) {
                    ($0 ^ UInt64($1)) &* 0x100_0000_01b3
                }
                #expect(hash == expected, "Original map pixels: \(String(hash, radix: 16))")
                #expect(map.updateCounter == 16)
                #expect(map.rgbaPixels.count == 65536)
                if scale > 0 { #expect(map.rgbaPixels[3] == 16) }
            }
        }
    }

    @Test func mapCraftingStorageAndLegacyShape() throws {
        var maps = BetaMapCollection()
        let crafted = maps.craft(at: SIMD3(-3.75, 70, 7.25), dimension: -1)
        #expect(crafted == ItemStack(id: 358, damage: 0))
        #expect(maps[0]?.centerX == -4)
        #expect(maps[0]?.centerZ == 7)
        #expect(maps[0]?.scale == 3)
        var inventory = PlayerInventory()
        inventory.slots[0] = ItemStack(id: 358, damage: 99)
        maps.update(
            world: BlockWorld(), player: Player(position: .zero), inventory: &inventory,
            spawn: BlockPosition(20, 64, -30))
        #expect(inventory.selectedStack?.damage == 1)
        #expect(maps[1]?.centerX == 20)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = BetaMapStorage(directory: directory)
        try storage.save(maps)
        #expect(
            Array(try Data(contentsOf: directory.appendingPathComponent("map_0.dat")).prefix(2)) == [
                0x1f, 0x8b,
            ])
        #expect(
            try Data(contentsOf: directory.appendingPathComponent("idcounts.dat")).first
                == NBTTagType.compound.rawValue)
        var restored = try storage.load()
        #expect(restored[0]?.nbtDocument == maps[0]?.nbtDocument)
        #expect(restored.craft(at: .zero, dimension: 0).damage == 2)
        // Written by the unmodified original MapData and CompressedStreamTools.
        let originalMap = Data(
            base64Encoded:
                "H4sIAAAAAAAA/+3Ky4nCYAAGwM83pgPrsAFhKwnmxwRiAiawy55sdSvJChbhZeY8VVJl29Rzvcnh96sMc3kkOa2z++6auc1zld10rfuyWeXYdPcyTN04LK/9897Lsvwdsr+O/fiYkkvOAQAAAAAAAAAAAAAAAAAAAD5tnX1buls755n8A7/ij/5gQAAA"
        )!
        try originalMap.write(to: directory.appendingPathComponent("map_7.dat"))
        try Data(base64Encoded: "CgAAAgAFb3RoZXIAYwIAA21hcAAHAA==")!.write(
            to: directory.appendingPathComponent("idcounts.dat"))
        var original = try storage.load()
        #expect(original[7]?.centerX == -31)
        #expect(original[7]?.dimension == -1)
        #expect(original[7]?.colors[0] == 51)
        #expect(original.idCounts["other"] == 99)
        #expect(original.craft(at: .zero, dimension: 0).damage == 8)
        let legacy = NBTDocument(
            tag: .compound([
                "data": .compound([
                    "width": .short(2), "height": .short(2), "scale": .byte(-1),
                    "colors": .byteArray([4, 5, 6, 7]),
                ])
            ]))
        let map = try BetaMapData.decode(id: 12, document: legacy)
        #expect(map.scale == 0)
        #expect(map.colors[63 + 63 * 128] == 4)
        #expect(map.colors[64 + 64 * 128] == 7)
    }

    @Test func mapMarkersAndOriginalDialDamping() {
        var map = BetaMapData(id: 0, centerX: 0, centerZ: 0, dimension: 0)
        let marker = map.marker(position: SIMD3(-3.75, 70, 7.25), yaw: 0, dimension: 0)!
        #expect(marker.x == 0)
        #expect(marker.y == 2)
        #expect(marker.rotation == 8)
        #expect(map.marker(position: .zero, yaw: 0, dimension: -1) == nil)
        #expect(map.marker(position: SIMD3(513, 0, 0), yaw: 0, dimension: 0) == nil)
        map.applyNetwork([1, 0xf0, 244, 20])
        #expect(map.networkMarkers.first?.rotation == 15)
        #expect(map.networkMarkers.first?.pixelPosition == SIMD2(58, 74))
        map.applyNetwork([0, 7, 8, 49, 50])
        #expect(map.colors[7 + 8 * 128] == 49)
        #expect(map.colors[7 + 9 * 128] == 50)
        var random = JavaRandom(seed: 0)
        var compass = ItemDialState()
        compass.tickCompass(
            position: SIMD3(0, 65, 0), yaw: 0, spawn: BlockPosition(10, 64, 0), dimension: 0, random: &random)
        #expect(compass.angle == 0.08000000000000002)
        var watch = ItemDialState()
        watch.tickClock(celestialAngle: 0.25, dimension: 0, random: &random)
        #expect(watch.angle == -0.08000000000000002)
    }
}
