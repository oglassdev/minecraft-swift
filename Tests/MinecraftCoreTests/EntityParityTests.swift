import Testing

@testable import MinecraftCore

@Suite struct EntityParityTests {
    @Test func spatialCollisionCandidatesKeepSourceOrderAfterMovingAndSpawning() {
        var bodies = [
            GameEntity(id: 1, kind: "boat", position: SIMD3(8.1, 1, -0.1)),
            GameEntity(id: 2, kind: "cow", position: SIMD3(-0.1, 1, -0.1)),
            GameEntity(id: 3, kind: "boat", position: SIMD3(0.1, 1, -0.1)),
        ]
        var index = EntitySpatialIndex(bodies)
        let query = AxisAlignedBox(min: SIMD3(-10, 0, -2), max: SIMD3(10, 4, 2))
        let mover = GameEntity(id: 4, kind: "minecart", position: .zero)
        for stage in 0..<3 {
            if stage == 1 {
                bodies[0].position.x = -8.1
                index.update(EntityCollisionBody(bodies[0]), at: 0)
            } else if stage == 2 {
                bodies.append(GameEntity(id: 5, kind: "boat", position: SIMD3(-7.9, 1, -0.1)))
                index.append(EntityCollisionBody(bodies[3]))
            }
            let indexed = EntityCollisionView(index: index).boxes(
                movingID: mover.id, vehicle: true, intersecting: query)
            let legacy = EntityCollision.boxes(moving: mover, among: bodies, intersecting: query)
            #expect(indexed == legacy)
        }
    }

    @Test func entityCollisionBoxesMatchOriginalMoverRules() {
        let world = BlockWorld()
        for (kind, expected) in [("boat", 0.949999988079071), ("minecart", 2.0)] {
            var mover = GameEntity(id: 1, kind: "zombie", position: SIMD3(0, 1, 0), velocity: SIMD3(2, 0, 0))
            let body = GameEntity(id: 2, kind: kind, position: SIMD3(2, 1, 0))
            EntityMotion.move(&mover, world: world, bodies: [body])
            #expect(mover.position.x == expected)
        }
        var cart = GameEntity(id: 1, kind: "minecart", position: SIMD3(0, 1, 0), velocity: SIMD3(2, 0, 0))
        let mob = GameEntity(id: 2, kind: "zombie", position: SIMD3(2, 1, 0))
        EntityMotion.move(&cart, world: world, bodies: [mob])
        #expect(cart.position.x == 1.2099999785423279)
    }

    @Test func cartCollisionImpulsesMatchOriginalFurnacePriorities() {
        let expected: [[Double]] = [
            [0.1114928760953639, -0.04212678090165321, 0.12850712450068252, -0.07787321939637001],
            [0.2099999964237213, 0.06999999880790711, 0.32850712450068253, 0.07212678060363001],
            [-0.08850712390463608, -0.19212678090165322, -0.06999999880790711, -0.13999999761581422],
        ]
        for furnace in 0..<3 {
            var a = GameEntity(
                id: 1, kind: "minecart", position: SIMD3(0, 1, 0), velocity: SIMD3(0.3, 0, 0.1))
            var b = GameEntity(
                id: 2, kind: "minecart", position: SIMD3(0.8, 1, 0.2), velocity: SIMD3(-0.1, 0, -0.2))
            b.previousPosition.x = 0
            if furnace == 1 { a.metadata = 2 }
            if furnace == 2 { b.metadata = 2 }
            EntityCollision.push(receiver: &a, other: &b)
            let actual = [a.velocity.x, a.velocity.z, b.velocity.x, b.velocity.z]
            #expect(zip(actual, expected[furnace]).allSatisfy { abs($0 - $1) < 0.00000000000001 })
        }
        var cart = GameEntity(id: 1, kind: "minecart", position: SIMD3(0, 1, 0), velocity: SIMD3(0.2, 0, 0))
        var passenger = GameEntity(id: 2, kind: "cow", position: SIMD3(0.8, 1, 0))
        EntityCollision.push(receiver: &cart, other: &passenger)
        #expect(cart.riderID == passenger.id)
    }

    @Test func boatAirMotionAndCrashMatchOriginalVectors() {
        var world = BlockWorld()
        var player = Player(position: SIMD3(30, 1, 30))
        var inventory = PlayerInventory()
        var simulation = EntitySimulation(seed: 1234, naturalSpawningEnabled: false)
        simulation.spawn(kind: "boat", position: SIMD3(0.5, 1, 0.5), velocity: SIMD3(0.2, 0, 0))
        let heights = [
            0.9600000008940697, 0.8820000031143427, 0.7679000070475042, 0.6195050130382551,
            0.43852977139254445,
        ]
        for tick in 0..<5 {
            _ = simulation.tick(world: &world, player: &player, inventory: &inventory, time: Int64(tick))
            #expect(abs(simulation.entities[0].position.y - heights[tick]) < 0.000000000001)
            #expect(simulation.entities[0].vehicleYaw == Float(-20 * (tick + 1)))
        }
        simulation.restore([])
        for y in 0...4 { for z in -5...5 { world[BlockPosition(1, y, z)] = .stone } }
        simulation.spawn(kind: "boat", position: SIMD3(0, 1, 0), velocity: SIMD3(0.3, 0, 0.3))
        let events = simulation.tick(world: &world, player: &player, inventory: &inventory, time: 6)
        #expect(simulation.entities.isEmpty)
        #expect(
            events.reduce(0) { sum, event in
                if case .dropItem(_, let stack) = event { sum + stack.count } else { sum }
            } == 5)
    }

    @Test func fireAndDamageTimersMatchOriginalLivingVectors() {
        var simulation = EntitySimulation(seed: 1234, naturalSpawningEnabled: false)
        var entity = GameEntity(id: 1, kind: "zombie", position: SIMD3(0, 1, 0))
        entity.fireTicks = 40
        for tick in 1...3 {
            _ = simulation.tickEnvironment(&entity, world: BlockWorld())
            #expect(entity.health == 19)
            #expect(entity.fireTicks == 40 - tick)
            #expect(entity.hurtTicks == 10 - tick)
            #expect(entity.hurtResistance == 20 - tick)
            #expect(entity.previousHealth == 20)
        }
        entity = GameEntity(id: 1, kind: "zombie", position: SIMD3(0, 1, 0))
        let first = entity.receiveDamage(3)
        let second = entity.receiveDamage(2)
        let third = entity.receiveDamage(5)
        #expect(first == .full && second == .ignored && third == .additional)
        #expect(
            entity.health == 15 && entity.previousHealth == 20 && entity.hurtTicks == 10
                && entity.hurtResistance == 20)
    }

    @Test func deadPlayersCannotPickUpDroppedItemsOrArrows() {
        var simulation = EntitySimulation(seed: 0, naturalSpawningEnabled: false)
        var player = Player(position: SIMD3(0.5, 1, 0.5), health: 0)
        var inventory = PlayerInventory()
        var world = BlockWorld()
        simulation.drop(ItemStack(id: 4), at: SIMD3(0.5, 1.125, 0.5), pickupDelay: 0)
        var arrow = GameEntity(id: 20, kind: "arrow", position: SIMD3(0.5, 1, 0.5))
        arrow.projectileOwner = 0
        arrow.inGround = true
        simulation.upsert(arrow)
        _ = simulation.tick(world: &world, player: &player, inventory: &inventory, time: 0)
        #expect(inventory.slots.allSatisfy { $0 == nil })
        #expect(simulation.entities.count == 2)
    }

    @Test func mountedAndDismountedFeetMatchOriginalPlayerOffsets() {
        var simulation = EntitySimulation(seed: 0, naturalSpawningEnabled: false)
        var player = Player(position: .zero)
        let cart = simulation.spawn(kind: "minecart", position: SIMD3(0.5, 1, 0.5))
        simulation.update(id: cart) { $0.riderID = 0 }
        #expect(simulation.mountedPosition(for: 0) == SIMD3(0.5, 0.5499999821186066, 0.5))
        simulation.dismountPlayer(player: &player)
        #expect(player.position == SIMD3(0.5, 1.699999988079071, 0.5))
        simulation.restore([])
        let boat = simulation.spawn(kind: "boat", position: SIMD3(0.5, 1, 0.5))
        simulation.update(id: boat) { $0.riderID = 0 }
        #expect(simulation.mountedPosition(for: 0) == SIMD3(0.9, 0.5, 0.5))
    }

    @Test func offsetRailProjectionMatchesOriginalSlopeAndCornerVectors() {
        let vectors: [(UInt8, SIMD3<Double>, SIMD3<Double>)] = [
            (2, SIMD3(0.10000000000000003, 0.6000000000000001, 0.5), SIMD3(0.7, 1.2, 0.5)),
            (
                6, SIMD3(0.5378679656440358, 0.5, 0.9621320343559642),
                SIMD3(0.9621320343559642, 0.5, 0.5378679656440358)
            ),
            (
                7, SIMD3(0.3621320343559642, 0.5, 0.8621320343559642),
                SIMD3(-0.06213203435596415, 0.5, 0.43786796564403585)
            ),
        ]
        for (metadata, before, after) in vectors {
            var world = BlockWorld()
            world.setBlock(BlockState(.rail, metadata: metadata), at: BlockPosition(0, 0, 0))
            #expect(
                EntitySimulation.railOffsetPoint(SIMD3(0.4, 0.5, 0.4), offset: -0.3, world: world)
                    == before)
            #expect(
                EntitySimulation.railOffsetPoint(SIMD3(0.4, 0.5, 0.4), offset: 0.3, world: world)
                    == after)
        }
        var world = BlockWorld()
        world.setBlock(BlockState(.rail, metadata: 2), at: BlockPosition(0, 0, 0))
        world.setBlock(BlockState(.rail, metadata: 1), at: BlockPosition(1, 1, 0))
        #expect(
            EntitySimulation.railOffsetPoint(SIMD3(0.9, 1.4, 0.5), offset: 0.3, world: world)
                == SIMD3(1.2, 1.5, 0.5))
    }

    @Test func appendedSlimeChildrenTickAndPushOnOriginalDeathFrame() {
        var simulation = EntitySimulation(seed: 0, naturalSpawningEnabled: false)
        var slime = GameEntity(id: 1, kind: "slime", position: SIMD3(2, 1, 2))
        slime.metadata = 4
        slime.width = Double(Float(0.6) * 4)
        slime.height = slime.width
        slime.health = 0
        slime.deathTicks = 20
        slime.lootDropped = true
        simulation.restore([slime])
        simulation.setEntityRandomSeed(1234, for: 1)
        var world = BlockWorld()
        var player = Player(position: SIMD3(40, 1, 40))
        var inventory = PlayerInventory()
        _ = simulation.tick(world: &world, player: &player, inventory: &inventory, time: 0)
        let positions = [
            SIMD3(1.4646446598087564, 1.5, 1.4646446598087564),
            SIMD3(2.585355340883853, 1.5, 1.466352061089676),
            SIMD3(1.4163520554399676, 1.5, 2.6329732968089954),
            SIMD3(2.6312264984740916, 1.5, 2.629219895394967),
        ]
        #expect(simulation.entities.count == 4)
        for (entity, position) in zip(simulation.entities, positions) {
            #expect(entity.ageTicks == 1)
            #expect(EntityMotion.squaredLength(entity.position - position) < 0.00000000000000000001)
        }
    }

    @Test func unrelatedEntityRandomDrawsDoNotChangeSquidMotion() {
        var squid = GameEntity(id: 1, kind: "squid", position: SIMD3(0, 8, 0))
        squid.squidPhaseVelocity = 0.15
        var noise = GameEntity(id: 2, kind: "cow", position: SIMD3(50, 8, 50))
        noise.ambientTicks = 1000
        noise.fireTicks = 40
        var control = EntitySimulation(seed: 0, naturalSpawningEnabled: false)
        var crowded = EntitySimulation(seed: 0, naturalSpawningEnabled: false)
        control.restore([squid])
        crowded.restore([noise, squid])
        control.setEntityRandomSeed(1234, for: 1)
        crowded.setEntityRandomSeed(1234, for: 1)
        var world = BlockWorld()
        var player = Player(position: SIMD3(30, 8, 30))
        var inventory = PlayerInventory()
        for tick in 0..<8 {
            _ = control.tick(world: &world, player: &player, inventory: &inventory, time: Int64(tick))
            _ = crowded.tick(world: &world, player: &player, inventory: &inventory, time: Int64(tick))
        }
        let a = control.entities[0]
        let b = crowded.entities.first { $0.id == 1 }!
        #expect(a.position == b.position && a.velocity == b.velocity)
        #expect(a.squidPhase == b.squidPhase && a.squidPhaseVelocity == b.squidPhaseVelocity)
    }
}
