import Testing

@testable import MinecraftCore

@Suite struct EntityTests {
    @Test func spiderAndWolfPounceMatchOriginalImpulseAndWolfTeleport() {
        var entity = GameEntity(
            id: 1, kind: "spider", position: SIMD3(0, 1, 0), velocity: SIMD3(0.1, 0.2, -0.1))
        EntityMotion.pounce(&entity, toward: SIMD3(4, 1, 0))
        #expect(entity.velocity == SIMD3(0.4200000062584877, 0.4000000059604645, -0.020000000298023225))
        var world = BlockWorld()
        for x in 18...22 { for z in -2...2 { world[BlockPosition(x, 0, z)] = .stone } }
        var simulation = EntitySimulation(seed: 0, naturalSpawningEnabled: false)
        var wolf = GameEntity(id: 2, kind: "wolf", position: SIMD3(0.5, 1, 0.5))
        wolf.owner = "Player"
        wolf.metadata = 4
        let player = Player(position: SIMD3(20.5, 1, 0.5))
        _ = simulation.wolfBehavior(
            &wolf, world: world, player: player, attacking: false, water: false, inventory: PlayerInventory())
        #expect(wolf.position == SIMD3(18.5, 1, -1.5))
    }

    @Test func mobsRetaliateAgainstEachOtherAndSeatedWolvesDefendTheirOwner() {
        var world = floorWorld()
        var simulation = EntitySimulation(seed: 0, naturalSpawningEnabled: false)
        let skeleton = simulation.spawn(kind: "skeleton", position: SIMD3(0.5, 1, 0.5))
        let zombie = simulation.spawn(kind: "zombie", position: SIMD3(1.5, 1, 0.5))
        let accepted = simulation.hurtEntity(
            at: 1, amount: 1, sourcePosition: SIMD3(0.5, 1, 0.5), sourceID: skeleton)
        #expect(accepted)
        #expect(simulation.entities[1].targetEntityID == skeleton)
        var player = Player(position: SIMD3(30, 1, 30))
        var inventory = PlayerInventory()
        _ = simulation.tick(world: &world, player: &player, inventory: &inventory, time: 18000)
        #expect(simulation.entities.first { $0.id == skeleton }?.health == 15)
        #expect(simulation.entities.first { $0.id == skeleton }?.targetEntityID == zombie)
        let wolf = simulation.spawn(kind: "wolf", position: SIMD3(3, 1, 3))
        simulation.update(id: wolf) {
            $0.owner = "Player"
            $0.metadata = 5
        }
        simulation.alertOwnedWolves(against: zombie, from: SIMD3(0, 2, 0), defending: false)
        #expect(simulation.entities.first { $0.id == wolf }?.targetEntityID == nil)
        simulation.alertOwnedWolves(against: zombie, from: SIMD3(0, 2, 0), defending: true)
        #expect(simulation.entities.first { $0.id == wolf }?.targetEntityID == zombie)
        #expect(simulation.entities.first { $0.id == wolf }!.metadata & 1 == 0)
    }

    @Test func wolfFoodHealingAndRiddenPigFallUseOriginalOutcomes() {
        var simulation = EntitySimulation(seed: 0, naturalSpawningEnabled: false)
        var player = Player(position: SIMD3(0.5, 1, 0.5))
        var inventory = PlayerInventory()
        inventory.slots[0] = ItemStack(id: 320)
        let wolf = simulation.spawn(kind: "wolf", position: SIMD3(2.5, 1, 0.5))
        simulation.update(id: wolf) {
            $0.owner = "Player"
            $0.metadata = 4
            $0.health = 14
        }
        let used = simulation.interact(
            origin: player.eyePositionDouble, direction: SIMD3(2, -1, 0), player: &player,
            inventory: &inventory)
        #expect(used)
        #expect(simulation.entities[0].health == 17)
        simulation.restore([])
        let pig = simulation.spawn(kind: "pig", position: SIMD3(2.5, 8, 2.5), metadata: 1)
        simulation.update(id: pig) { $0.riderID = 0 }
        var world = floorWorld()
        var falls: [Float] = []
        for tick in 0..<60 {
            for event in simulation.tick(
                world: &world, player: &player, inventory: &inventory, time: Int64(tick))
            {
                if case .pigFall(let distance) = event { falls.append(distance) }
            }
        }
        #expect(falls.count == 1)
        #expect((falls.first ?? 0) > 5)
    }

    @Test func squidSwimmingMatchesOriginalPhaseAndMotionTrace() {
        var world = BlockWorld()
        for x in 6...15 {
            for y in 58...70 { for z in 6...15 { world[BlockPosition(x, y, z)] = .stillWater } }
        }
        var simulation = EntitySimulation(seed: 0, naturalSpawningEnabled: false)
        let id = simulation.spawn(kind: "squid", position: SIMD3(10, 64, 10))
        simulation.update(id: id) { $0.squidPhaseVelocity = 0.2 }
        simulation.random = JavaRandom(seed: 1234)
        var player = Player(position: SIMD3(1000, 64, 1000))
        var inventory = PlayerInventory()
        for tick in 1...32 {
            _ = simulation.tick(world: &world, player: &player, inventory: &inventory, time: Int64(tick))
            if tick == 12 {
                #expect(abs(simulation.entities[0].squidTentacleAngle - 0.758473754) < 0.0000001)
            }
        }
        let entity = simulation.entities[0]
        #expect(
            EntityMotion.squaredLength(
                entity.position - SIMD3(8.697950599715114, 63.22716648452923, 11.55270648561418))
                < 0.000000000000000001)
        #expect(abs(entity.squidPhase - 0.116812706) < 0.00000001)
        #expect(abs(entity.squidBodyRotation - 83.3582230) < 0.00001)
    }

    @Test func projectileLaunchAndFixtureCollisionMatchOriginalRules() {
        var simulation = EntitySimulation(seed: 1234, naturalSpawningEnabled: false)
        simulation.shoot(
            kind: "arrow", origin: SIMD3(0.5, 3, 0.5), direction: SIMD3(0.3, 0.4, -0.5), speed: 0.6,
            inaccuracy: 12)
        let expected = SIMD3(0.2621810460613616, 0.3628828545068006, -0.36278660297994214)
        #expect(
            EntityMotion.squaredLength(simulation.entities[0].velocity - expected) < 0.00000000000000000001)
        var world = floorWorld()
        world.setBlock(BlockState(.rail), at: BlockPosition(0, 1, 0))
        var player = Player(position: SIMD3(30, 1, 30))
        var inventory = PlayerInventory()
        for kind in ["egg", "arrow"] {
            simulation.restore([])
            simulation.spawn(kind: kind, position: SIMD3(0.5, 1.05, -0.5), velocity: SIMD3(0, 0, 1))
            _ = simulation.tick(world: &world, player: &player, inventory: &inventory, time: 0)
            #expect(simulation.entities.contains { $0.kind == kind } == (kind == "arrow"))
        }
    }

    @Test func naturalSpawningSeparatesRawSkyAndEffectiveLightRolls() {
        var chunk = Chunk(position: ChunkPosition(0, 0))
        chunk[0, 0, 0] = BlockState(.grass)
        let index = Chunk.index(x: 0, y: 1, z: 0)
        chunk.skyLight[index] = 15
        var world = BlockWorld()
        world.setChunk(chunk)
        let zombie = GameEntity(id: 1, kind: "zombie", position: SIMD3(0.5, 1, 0.5))
        var simulation = EntitySimulation(seed: 0, naturalSpawningEnabled: false)
        simulation.random = JavaRandom(seed: 0)
        let night = simulation.canSpawnNaturally(zombie, in: world, time: 18000, difficulty: 2)
        #expect(night)
        simulation.random = JavaRandom(seed: 4096)
        let skyRejected = simulation.canSpawnNaturally(zombie, in: world, time: 18000, difficulty: 2)
        #expect(!skyRejected)
        simulation.random = JavaRandom(seed: 0)
        let day = simulation.canSpawnNaturally(zombie, in: world, time: 6000, difficulty: 2)
        #expect(!day)
        chunk.skyLight[index] = 0
        chunk.blockLight[index] = 15
        world.setChunk(chunk)
        simulation.random = JavaRandom(seed: 0)
        let lit = simulation.canSpawnNaturally(zombie, in: world, time: 18000, difficulty: 2)
        #expect(!lit)
    }

    @Test func ghastFlightMatchesOriginalControlledAirTrace() {
        var world = BlockWorld()
        var player = Player(position: SIMD3(1000, 64, 1000))
        var inventory = PlayerInventory()
        var simulation = EntitySimulation(seed: 0, naturalSpawningEnabled: false)
        simulation.spawn(kind: "ghast", position: SIMD3(10, 64, 10))
        simulation.random = JavaRandom(seed: 1234)
        let positions: [SIMD3<Double>] = [
            SIMD3(9.984743044642123, 63.902355485709585, 9.984743044642123),
            SIMD3(9.970859214866325, 63.813498975144476, 9.970859214866325),
            SIMD3(9.986037144818727, 63.688442932614464, 10.043507639865783),
            SIMD3(9.999849061473473, 63.574641930632424, 10.109617708520574),
            SIMD3(10.040441192443026, 63.4277027308696, 10.255409908418034),
        ]
        for (tick, expected) in positions.enumerated() {
            _ = simulation.tick(world: &world, player: &player, inventory: &inventory, time: Int64(tick))
            let delta = simulation.entities[0].position - expected
            #expect(EntityMotion.squaredLength(delta) < 0.00000000000000000001)
        }
    }

    @Test func slimesSplitAtOriginalDeathTimeAndSmallSlimesDoNotAttack() {
        var world = floorWorld()
        var player = Player(position: SIMD3(0.5, 1, 0.5))
        var inventory = PlayerInventory()
        var simulation = EntitySimulation(seed: 0, naturalSpawningEnabled: false)
        simulation.spawn(kind: "slime", position: SIMD3(0.5, 1, 0.5), metadata: 1)
        for tick in 0..<10 {
            _ = simulation.tick(world: &world, player: &player, inventory: &inventory, time: Int64(tick))
        }
        #expect(player.health == 20)
        var dead = GameEntity(id: 100, kind: "slime", position: SIMD3(2, 1, 2))
        dead.metadata = 4
        dead.health = 0
        dead.deathTicks = 19
        dead.lootDropped = true
        simulation.restore([dead])
        _ = simulation.tick(world: &world, player: &player, inventory: &inventory, time: 11)
        #expect(simulation.entities.count == 4)
        #expect(simulation.entities.allSatisfy { $0.metadata == 2 && $0.health == 4 })
        #expect(Set(simulation.entities.map { $0.position.x }) == [1.5, 2.5])
        dead.health = -1
        simulation.restore([dead])
        _ = simulation.tick(world: &world, player: &player, inventory: &inventory, time: 12)
        #expect(simulation.entities.isEmpty)
    }

    @Test func fishingRetrievalMatchesOriginalWearAndTug() {
        let player = Player(position: SIMD3(3, 5 - Double(Float(1.62)), -2))
        for fixture in 0..<4 {
            var simulation = EntitySimulation(seed: 0, naturalSpawningEnabled: false)
            let target = simulation.spawn(kind: "cow", position: SIMD3(4, 1, 0))
            let hook = simulation.castFishingHook(origin: SIMD3(0.5, 2, 0.5), direction: SIMD3(0, 0, -1))
            simulation.update(id: hook) {
                if fixture == 1 { $0.biteTicks = 17 }
                if fixture == 2 { $0.inGround = true }
                if fixture == 3 { $0.hookedEntityID = target }
            }
            let wear = simulation.retrieveFishingHook(player: player)
            #expect(wear == fixture)
            #expect(!simulation.entities.contains { $0.kind == "fishingHook" })
            let caught =
                fixture == 1
                ? simulation.entities.first { $0.itemStack?.id == 349 }
                : simulation.entities.first { $0.id == target }
            if fixture == 1 || fixture == 3 {
                #expect(caught?.velocity.x == 0.25)
                #expect(abs((caught?.velocity.y ?? 0) - 0.4722660064697266) < 0.000000000001)
                #expect(caught?.velocity.z == -0.25)
            }
            var world = BlockWorld()
            var movingPlayer = player
            var inventory = PlayerInventory()
            let events = simulation.tick(world: &world, player: &movingPlayer, inventory: &inventory, time: 0)
            #expect(events.contains { if case .fishCaught = $0 { true } else { false } } == (fixture == 1))
        }
    }

    @Test func paintingsUseOriginalAttachmentGeometryAndDropWhenSupportBreaks() {
        var painting = GameEntity(id: 5, kind: "painting", position: .zero)
        BetaPainting.configure(&painting, anchor: BlockPosition(2, 64, -3), direction: 1, motive: "Pointer")
        #expect(painting.position == SIMD3(1.9375, 63, -2))
        #expect(painting.width == 4 && painting.height == 4)
        var world = BlockWorld()
        for y in 62...67 { for z in -5...1 { world[BlockPosition(2, y, z)] = .stone } }
        var simulation = EntitySimulation(seed: 0, naturalSpawningEnabled: false)
        let placed = simulation.placePainting(
            at: BlockPosition(2, 64, -3), facing: BlockPosition(-1, 0, 0), world: world)
        #expect(placed)
        let id = simulation.entities[0].id
        simulation.update(id: id) { $0.ageTicks = 100 }
        for y in 62...67 { for z in -5...1 { world[BlockPosition(2, y, z)] = nil } }
        var player = Player(position: SIMD3(20, 64, 0))
        var inventory = PlayerInventory()
        let events = simulation.tick(world: &world, player: &player, inventory: &inventory, time: 0)
        #expect(simulation.entities.isEmpty)
        #expect(events.contains { if case .dropItem(_, let stack) = $0 { stack.id == 321 } else { false } })
    }

    @Test func weatherFlashAndCelestialLightMatchOriginalTraces() {
        var world = BlockWorld()
        var player = Player(position: SIMD3(30, 1, 30))
        var inventory = PlayerInventory()
        var simulation = EntitySimulation(seed: 0, naturalSpawningEnabled: false)
        let id = simulation.spawn(kind: "lightning", position: SIMD3(0.5, 1, 0.5))
        simulation.update(id: id) { $0.lightningFlashes = 2 }
        simulation.effectRandoms[id] = JavaRandom(seed: 1234)
        let expected = [1, 0, -1, 1, 0, -1, -2, -3, -4, 1, 0]
        for (tick, state) in expected.enumerated() {
            let events = simulation.tick(
                world: &world, player: &player, inventory: &inventory, time: Int64(tick))
            #expect(simulation.entities.first?.lightningState == state)
            if tick == 0 {
                #expect(
                    events.contains {
                        if case .sound("ambient.weather.thunder", _, 10000, let pitch) = $0 {
                            abs(pitch - 0.92931646) < 0.0000001
                        } else {
                            false
                        }
                    })
            }
        }
        _ = simulation.tick(world: &world, player: &player, inventory: &inventory, time: 12)
        #expect(simulation.entities.isEmpty)
        let times: [Int64] = [0, 6000, 12000, 12500, 13000, 18000, 23000, 23500]
        #expect(times.map { EntityMotion.skyDarkening(time: $0) } == [0, 0, 0, 3, 6, 11, 6, 3])
    }

    @Test func minecartRailSamplingAndPoweredKickMatchOriginal() {
        var world = BlockWorld()
        let expected: [SIMD3<Double>] = [
            SIMD3(0.5, 1.5, 0.75), SIMD3(0.25, 1.5, 0.5), SIMD3(0.25, 1.75, 0.5), SIMD3(0.25, 2.25, 0.5),
            SIMD3(0.5, 1.75, 0.75), SIMD3(0.5, 2.25, 0.75), SIMD3(0.5, 1.5, 1), SIMD3(0.25, 1.5, 0.75),
            SIMD3(0, 1.5, 0.5), SIMD3(0.75, 1.5, 0.25),
        ]
        for shape in 0..<10 {
            world.setBlock(BlockState(.rail, metadata: UInt8(shape)), at: BlockPosition(0, 1, 0))
            #expect(EntitySimulation.railPoint(SIMD3(0.25, 1, 0.75), world: world) == expected[shape])
        }
        for x in -5...5 { world.setBlock(BlockState(.rail, metadata: 1), at: BlockPosition(x, 1, 0)) }
        var simulation = EntitySimulation(seed: 0, naturalSpawningEnabled: false)
        var player = Player(position: SIMD3(30, 1, 30))
        var inventory = PlayerInventory()
        simulation.spawn(kind: "minecart", position: SIMD3(0.5, 1, 0.5), velocity: SIMD3(0.2, 0, 0))
        let xValues = [0.7, 0.8919999957084657, 1.0763199874687197, 1.2532671756034857, 1.4231364724159863]
        for (tick, x) in xValues.enumerated() {
            _ = simulation.tick(world: &world, player: &player, inventory: &inventory, time: Int64(tick))
            #expect(abs(simulation.entities[0].position.x - x) < 0.000000000001)
            #expect(abs(simulation.entities[0].position.y - 1.1500000059604645) < 0.000000000001)
        }
        simulation.restore([])
        world.setBlock(BlockState(.poweredRail, metadata: 9), at: BlockPosition(0, 1, 0))
        world[BlockPosition(-1, 1, 0)] = .stone
        simulation.spawn(kind: "minecart", position: SIMD3(0.5, 1, 0.5))
        _ = simulation.tick(world: &world, player: &player, inventory: &inventory, time: 6)
        #expect(simulation.entities[0].velocity.x == 0.02)
    }
    @Test func pathfinderMatchesOriginalHeapAndVoxelRules() {
        let expected = [
            "0,1,0;1,1,0;2,1,0;3,1,0;4,1,0;5,1,0;",
            "0,1,0;1,1,0;1,1,-1;1,1,-2;2,1,-2;3,1,-2;4,1,-2;4,1,-1;5,1,-1;5,1,0;",
            "0,1,0;1,1,0;2,2,0;3,1,0;4,1,0;5,1,0;",
            "0,1,0;1,1,0;1,1,-1;2,1,-1;3,1,-1;4,1,-1;4,1,0;5,1,0;",
            "0,1,0;1,1,0;2,1,0;3,1,0;4,1,0;5,1,0;",
        ]
        for fixture in 0..<5 {
            var world = floorWorld()
            if fixture == 1 {
                for y in 1...2 { for z in -1...1 { world[BlockPosition(2, y, z)] = .stone } }
            } else if fixture == 2 {
                world[BlockPosition(2, 1, 0)] = .slab
            } else if fixture >= 3 {
                for y in 1...2 {
                    world.setBlock(
                        BlockState(.woodenDoor, metadata: fixture == 4 ? 4 : 0), at: BlockPosition(2, y, 0))
                }
            }
            let entity = GameEntity(id: 1, kind: "zombie", position: SIMD3(0.5, 1, 0.5))
            let path = BetaPathfinder.path(in: world, entity: entity, toward: SIMD3(5.5, 1.5, 0.5))
            let text = path.map { "\($0.x),\($0.y),\($0.z);" }.joined()
            #expect(text == expected[fixture])
        }
    }

    @Test func authoritativeEntityUpdatesOnlyAdvancePresentation() {
        var simulation = EntitySimulation(seed: 7)
        var entity = GameEntity(id: 90, kind: "player", position: SIMD3(0, 1, 0))
        entity.yaw = .pi - 0.1
        simulation.upsert(entity)
        simulation.update(id: 90) {
            $0.remotePosition = SIMD3(3, 1, 0)
            $0.remoteYaw = -.pi + 0.1
            $0.remoteTicks = 3
        }
        simulation.tickRemote()
        #expect(simulation.entities[0].position == SIMD3(1, 1, 0))
        simulation.tickRemote()
        simulation.tickRemote()
        #expect(simulation.entities[0].position == SIMD3(3, 1, 0))
        #expect(abs((simulation.entities[0].yaw - (-.pi + 0.1)).remainder(dividingBy: .pi * 2)) < 0.000001)
        #expect(simulation.entities.count == 1)
        #expect(simulation.entities[0].ageTicks == 3)
        simulation.remove(ids: [90])
        #expect(simulation.entities.isEmpty)
        #expect(simulation.nextEntityID == 91)
    }
    private func floorWorld() -> BlockWorld {
        var world = BlockWorld()
        for x in -5...5 { for z in -5...5 { world[BlockPosition(x, 0, z)] = .stone } }
        return world
    }

    @Test func restoredEntitiesPreserveTheReservedIDRange() {
        var simulation = EntitySimulation(seed: 0, naturalSpawningEnabled: false)
        simulation.reserveIDs(through: 1000)
        let entity = GameEntity(id: 10, kind: "Pig", position: SIMD3(0.5, 1, 0.5))
        simulation.restore([entity, entity])
        #expect(simulation.entities.count == 1)
        let spawned = simulation.spawn(kind: "cow", position: SIMD3(3, 1, 3))
        #expect(spawned == 1001)
        #expect(simulation.nextEntityID == 1002)
    }

    @Test func droppedItemsWaitForPickupAndExpireAfterFiveMinutes() {
        var world = floorWorld()
        var player = Player(position: SIMD3(0.5, 1, 0.5))
        var inventory = PlayerInventory()
        var simulation = EntitySimulation(seed: 7, naturalSpawningEnabled: false)
        simulation.drop(ItemStack(id: 4, count: 3), at: SIMD3(0.5, 1.125, 0.5), pickupDelay: 2)
        _ = simulation.tick(world: &world, player: &player, inventory: &inventory, time: 18000)
        #expect(inventory.slots.compactMap { $0 }.isEmpty)
        _ = simulation.tick(world: &world, player: &player, inventory: &inventory, time: 18001)
        #expect(inventory.slots[0]?.id == 4)
        #expect(inventory.slots[0]?.count == 3)
        #expect(simulation.entities.isEmpty)
        var old = GameEntity(id: 20, kind: "item", position: SIMD3(4.5, 1, 4.5))
        old.itemStack = ItemStack(id: 3)
        old.ageTicks = 5999
        simulation.restore([old])
        _ = simulation.tick(world: &world, player: &player, inventory: &inventory, time: 18002)
        #expect(simulation.entities.isEmpty)
    }

    @Test func tntUsesTheOriginalPostDecrementFuse() {
        var world = floorWorld()
        var player = Player(position: SIMD3(30, 1, 30))
        var inventory = PlayerInventory()
        var simulation = EntitySimulation(seed: 8, naturalSpawningEnabled: false)
        simulation.spawn(kind: "PrimedTnt", position: SIMD3(0.5, 2, 0.5))
        for tick in 0..<80 {
            let events = simulation.tick(
                world: &world, player: &player, inventory: &inventory, time: Int64(tick))
            #expect(!events.contains { if case .explosion = $0 { true } else { false } })
        }
        let events = simulation.tick(world: &world, player: &player, inventory: &inventory, time: 80)
        #expect(events.contains { if case .explosion(_, 4) = $0 { true } else { false } })
        #expect(simulation.entities.isEmpty)
    }

    @Test func arrowsApplyBetaDragGravityAndEmbedInSolidBlocks() {
        var world = floorWorld()
        world[BlockPosition(2, 3, 0)] = .stone
        var player = Player(position: SIMD3(30, 1, 30))
        var inventory = PlayerInventory()
        var simulation = EntitySimulation(seed: 3, naturalSpawningEnabled: false)
        simulation.spawn(kind: "arrow", position: SIMD3(0.5, 3.5, 0.5), velocity: SIMD3(1, 0, 0))
        _ = simulation.tick(world: &world, player: &player, inventory: &inventory, time: 18000)
        #expect(simulation.entities[0].position == SIMD3(1.5, 3.5, 0.5))
        #expect(abs(simulation.entities[0].velocity.x - Double(Float(0.99))) < 0.000000001)
        #expect(simulation.entities[0].velocity.y == -Double(Float(0.03)))
        _ = simulation.tick(world: &world, player: &player, inventory: &inventory, time: 18001)
        #expect(simulation.entities[0].inGround)
        #expect(simulation.entities[0].stuckBlock == BlockPosition(2, 3, 0))
        world[BlockPosition(2, 3, 0)] = nil
        _ = simulation.tick(world: &world, player: &player, inventory: &inventory, time: 18002)
        #expect(!simulation.entities[0].inGround)
    }

    @Test func explosionRaysMatchTheOriginalClientAndBedrockSurvives() {
        var random = JavaRandom(seed: 1234)
        let affected = BetaExplosion.affectedBlocks(
            in: BlockWorld(), at: SIMD3(0.5, 5.5, 0.5), power: 2, random: &random)
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for position in affected.sorted(by: {
            $0.x == $1.x ? ($0.y == $1.y ? $0.z < $1.z : $0.y < $1.y) : $0.x < $1.x
        }) {
            for value in [position.x, position.y, position.z] {
                hash ^= UInt64(bitPattern: Int64(value))
                hash &*= 0x100_0000_01b3
            }
        }
        // Golden set is produced by qx.a() in the SHA1-verified original client with java.util.Random(1234).
        #expect(affected.count == 210)
        #expect(hash == 17_196_253_871_700_097_541)
        var world = BlockWorld()
        world[BlockPosition(0, 5, 0)] = .bedrock
        var player = Player(position: SIMD3(30, 1, 30))
        var simulation = EntitySimulation(seed: 1234, naturalSpawningEnabled: false)
        _ = simulation.explode(at: SIMD3(0.5, 5.5, 0.5), power: 4, world: &world, player: &player)
        #expect(world[BlockPosition(0, 5, 0)] == .bedrock)
    }

    @Test func hostileCombatHonorsCooldownsAndCreepersFuseAtThirtyTicks() {
        var world = floorWorld()
        var player = Player(position: SIMD3(0.5, 1, 0.5))
        var inventory = PlayerInventory()
        var simulation = EntitySimulation(seed: 5, naturalSpawningEnabled: false)
        simulation.spawn(kind: "zombie", position: SIMD3(0.5, 1, -0.5))
        _ = simulation.tick(world: &world, player: &player, inventory: &inventory, time: 18000)
        #expect(player.health == 20)
        _ = simulation.tick(world: &world, player: &player, inventory: &inventory, time: 18001)
        #expect(player.health == 15)
        simulation.restore([])
        simulation.spawn(kind: "creeper", position: SIMD3(0.5, 1, -1.5))
        var exploded = false
        for tick in 0..<31 {
            let events = simulation.tick(
                world: &world, player: &player, inventory: &inventory, time: Int64(18000 + tick))
            if events.contains(where: { if case .explosion(_, 3) = $0 { true } else { false } }) {
                exploded = true
            }
        }
        #expect(exploded)
        #expect(simulation.entities.isEmpty)
    }

    @Test func cowsExchangeHeldBucketsForMilk() {
        var player = Player(position: SIMD3(0.5, 1, 0.5))
        var inventory = PlayerInventory()
        inventory.slots[0] = ItemStack(id: 325)
        var simulation = EntitySimulation(seed: 1, naturalSpawningEnabled: false)
        simulation.spawn(kind: "cow", position: SIMD3(2.5, 1, 0.5))
        let used = simulation.interact(
            origin: player.eyePositionDouble, direction: SIMD3(2, -0.8, 0), player: &player,
            inventory: &inventory)
        #expect(used)
        #expect(inventory.selectedStack?.id == 335)
    }
}
