import MinecraftCore
import Testing

@Suite struct PlayerPhysicsTests {
    @Test func upperDoorShapesFollowTheLowerDoorMetadata() {
        var world = BlockWorld()
        let lower = BlockPosition(0, 1, 0)
        let upper = BlockPosition(0, 2, 0)
        world.setBlock(BlockState(.woodenDoor, metadata: 2), at: lower)
        world.setBlock(BlockState(.woodenDoor, metadata: 8), at: upper)
        let hit = BlockRaycast.hit(in: world, origin: SIMD3(-1, 2.5, 0.5), direction: SIMD3(1, 0, 0))
        #expect(hit?.position == upper)
        #expect(hit?.distance == 1.8125)
        let upperState = BlockState(.woodenDoor, metadata: 8)
        #expect(BlockCollision.boxes(for: upperState, at: upper, in: world).first?.min.x == 0.8125)
        world.setBlock(BlockState(.woodenDoor, metadata: 6), at: lower)
        #expect(BlockRaycast.hit(in: world, origin: SIMD3(-1, 2.5, 0.5), direction: SIMD3(1, 0, 0)) == nil)
    }

    @Test func armorWearAndCarryMatchOriginalPlayerDamage() {
        let world = floorWorld()
        var player = settledPlayer(in: world)
        var inventory = PlayerInventory()
        inventory.armor = [ItemStack(id: 313), ItemStack(id: 312), ItemStack(id: 311), ItemStack(id: 310)]
        var health: [Int] = []
        for _ in 0..<10 {
            let accepted = player.damage(1, inventory: &inventory)
            #expect(accepted)
            health.append(player.health)
            for _ in 0..<20 { player.tick(input: PlayerInput(), yaw: 0, world: world, inventory: &inventory) }
        }
        #expect(health == [20, 20, 20, 20, 19, 19, 19, 19, 18, 18])
        #expect(inventory.armorProtection == 19)
        #expect(inventory.armor.allSatisfy { $0?.damage == 10 })
    }

    @Test func difficultyScalesOnlyMonsterAndArrowDamage() {
        for difficulty in 0..<4 {
            var player = Player(position: .zero)
            player.difficulty = difficulty
            let accepted = player.damage(5, source: .monster)
            #expect(player.health == [20, 18, 15, 13][difficulty])
            #expect(accepted == (difficulty != 0))
            var environment = Player(position: .zero)
            environment.difficulty = difficulty
            environment.damage(5)
            #expect(environment.health == 15)
        }
        var remote = Player(position: SIMD3(1, 10, 1))
        remote.localDamageEnabled = false
        remote.addVelocity(SIMD3(0.2, 0.1, 0))
        remote.damage(10)
        remote.setHealthFromServer(7)
        #expect(remote.health == 7)
        #expect(remote.velocity == SIMD3(0.2, 0.1, 0))
    }
    private func floorWorld() -> BlockWorld {
        var world = BlockWorld()
        for x in -8...8 {
            for z in -8...8 { world[BlockPosition(x, 0, z)] = .stone }
        }
        return world
    }

    private func settledPlayer(in world: BlockWorld) -> Player {
        var player = Player(position: SIMD3(0.5, 1, 0.5))
        for _ in 0..<3 { player.tick(input: PlayerInput(), yaw: 0, world: world) }
        return player
    }

    @Test func groundMovementMatchesOriginalClientTrace() {
        let world = floorWorld()
        var player = settledPlayer(in: world)
        for _ in 0..<20 { player.tick(input: PlayerInput(forward: 1), yaw: 0, world: world) }
        // Golden trace invokes sn.a(FFF) from the SHA1-verified Beta client, with its float friction.
        #expect(abs(player.position.z - -3.5575807523491996) < 0.0000000001)
        #expect(abs(player.velocity.z - -0.11785839549095858) < 0.0000000001)
        #expect(player.onGround)
        #expect(player.health == 20)
        let steps = player.drainStepEvents().compactMap { event -> BlockPosition? in
            if case .stepped(let position, _) = event { return position }
            return nil
        }
        #expect(steps == [BlockPosition(0, 0, -2), BlockPosition(0, 0, -3)])
        #expect(player.drainStepEvents().isEmpty)
    }

    @Test func jumpUsesBetaImpulseAndClearsTheGround() {
        let world = floorWorld()
        var player = settledPlayer(in: world)
        player.tick(input: PlayerInput(jump: true), yaw: 0, world: world)
        #expect(abs(player.position.y - 1.4199999868869781) < 0.000000001)
        #expect(abs(player.velocity.y - (Double(Float(0.42)) - 0.08) * Double(Float(0.98))) < 0.000000001)
        #expect(!player.onGround)
        var highest = player.position.y
        for _ in 0..<30 {
            player.tick(input: PlayerInput(), yaw: 0, world: world)
            highest = max(highest, player.position.y)
        }
        #expect(abs(highest - 2.2522033402537236) < 0.000000001)
        #expect(abs(player.position.y - 1) < 0.000000001)
        #expect(player.onGround)
    }

    @Test func collisionStepsOntoSlabsButStopsAtFullWalls() {
        var slabWorld = floorWorld()
        slabWorld[BlockPosition(0, 1, -1)] = .slab
        var player = settledPlayer(in: slabWorld)
        var stepped = false
        for _ in 0..<15 {
            player.tick(input: PlayerInput(forward: 1), yaw: 0, world: slabWorld)
            if player.position.y == 1.5 { stepped = true }
        }
        #expect(stepped)
        #expect(player.position.z < -1)

        var wallWorld = floorWorld()
        wallWorld[BlockPosition(0, 1, -1)] = .stone
        wallWorld[BlockPosition(0, 2, -1)] = .stone
        player = settledPlayer(in: wallWorld)
        for _ in 0..<20 { player.tick(input: PlayerInput(forward: 1), yaw: 0, world: wallWorld) }
        #expect(abs(player.position.z - Player.width / 2) < 0.000000001)
        #expect(player.position.y == 1)
        #expect(player.isCollidingHorizontally)
    }

    @Test func sneakingPreventsWalkingOffAnEdge() {
        var world = BlockWorld()
        world[BlockPosition(0, 0, 0)] = .stone
        var player = settledPlayer(in: world)
        for _ in 0..<60 { player.tick(input: PlayerInput(forward: 1, sneak: true), yaw: 0, world: world) }
        #expect(player.position.y == 1)
        #expect(player.bounds.max.z > 0)
        #expect(player.health == 20)
        #expect(player.drainStepEvents().isEmpty)
    }

    @Test func fallsDealDamageAndWaterUsesFluidDrag() {
        let world = floorWorld()
        var player = Player(position: SIMD3(0.5, 8, 0.5))
        for _ in 0..<60 { player.tick(input: PlayerInput(), yaw: 0, world: world) }
        #expect(player.position.y == 1)
        #expect(player.health == 16)

        var water = world
        for y in 1...4 { water[BlockPosition(0, y, 0)] = .stillWater }
        player = Player(position: SIMD3(0.5, 1, 0.5))
        player.tick(input: PlayerInput(jump: true), yaw: 0, world: water)
        #expect(player.isInWater)
        #expect(abs(player.position.y - (1 + Double(Float(0.04)))) < 0.000000001)
        #expect(abs(player.velocity.y - (Double(Float(0.04)) * Double(Float(0.8)) - 0.02)) < 0.000000001)
    }

    @Test func raycastHandlesNegativeCoordinatesAndPartialBlocks() {
        var world = BlockWorld()
        world[BlockPosition(-2, 2, 0)] = .slab
        world[BlockPosition(-3, 2, 0)] = .stone
        let origin = SIMD3<Double>(0.5, 2.75, 0.5)
        let hit = BlockRaycast.hit(in: world, origin: origin, direction: SIMD3(-1, 0, 0))
        #expect(hit?.position == BlockPosition(-3, 2, 0))
        #expect(hit?.face == BlockPosition(1, 0, 0))
        #expect(hit?.adjacentPosition == BlockPosition(-2, 2, 0))
        #expect(hit?.distance == 2.5)
        #expect(BlockRaycast.hit(in: world, origin: origin, direction: SIMD3(-1, 0, 0), reach: 2) == nil)
        #expect(BlockRaycast.hit(in: world, origin: origin, direction: .zero) == nil)
    }

    @Test func bucketRaycastsCanSelectSourcesWithoutBlockingOrdinaryTargeting() {
        var world = BlockWorld()
        world[BlockPosition(0, 2, 0)] = .stillWater
        world[BlockPosition(0, 2, -1)] = .stone
        let origin = SIMD3<Double>(0.5, 2.5, 1.5)
        let direction = SIMD3<Double>(0, 0, -1)
        #expect(
            BlockRaycast.hit(in: world, origin: origin, direction: direction)?.position
                == BlockPosition(0, 2, -1))
        #expect(
            BlockRaycast.hit(in: world, origin: origin, direction: direction, includeLiquids: true)?.position
                == BlockPosition(0, 2, 0))
    }

    @Test func fluidLevelGradientsPushThePlayerWithoutTurningWaterIntoACollider() {
        var world = BlockWorld()
        world.setBlock(BlockState(.water), at: BlockPosition(0, 2, 0))
        world.setBlock(BlockState(.water, metadata: 1), at: BlockPosition(1, 2, 0))
        #expect(FluidPhysics.flow(in: world, at: BlockPosition(0, 2, 0)) == SIMD3(1, 0, 0))
        var player = Player(position: SIMD3(0.5, 2, 0.5))
        player.tick(input: PlayerInput(), yaw: 0, world: world)
        #expect(abs(player.position.x - 0.514) < 0.000000001)
        #expect(abs(player.velocity.x - 0.014 * Double(Float(0.8))) < 0.000000001)
        #expect(BlockCollision.boxes(for: BlockState(.water), at: BlockPosition(0, 2, 0)).isEmpty)
        #expect(BlockCollision.boxes(for: BlockState(.cobweb), at: BlockPosition(0, 2, 0)).isEmpty)
        world.setBlock(BlockState(.water, metadata: 8), at: BlockPosition(0, 2, 0))
        world[BlockPosition(1, 2, 0)] = .glass
        #expect(FluidPhysics.flow(in: world, at: BlockPosition(0, 2, 0)).y < 0)
    }
}
