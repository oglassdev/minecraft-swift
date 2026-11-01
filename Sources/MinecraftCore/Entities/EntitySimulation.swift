import Foundation

public struct EntitySimulation: Sendable {
    public internal(set) var entities: [GameEntity] = []
    public var naturalSpawningEnabled: Bool
    public var spawnPosition = SIMD3<Double>.zero
    public var rainStrength: Float = 0
    public var thunderStrength: Float = 0
    public var localPlayerName = "Player"
    public let seed: Int64
    var random: JavaRandom
    var entityRandoms: [Int64: JavaRandom] = [:]
    var spatialIndex: EntitySpatialIndex?
    private var constructionRandom: JavaRandom
    var queuedEvents: [BlockEvent] = []
    var ridingInput = SIMD2<Float>.zero
    var effectRandoms: [Int64: JavaRandom] = [:]
    var explosionContexts: [ExplosionContext] = []
    var flameRandom: JavaRandom
    var spawnSetWarmed = false
    private var nextID: Int64 = 1
    public var nextEntityID: Int64 { nextID }
    public var playerRidingEntityID: Int64? { ridingEntityID(for: 0) }

    public init(seed: Int64, naturalSpawningEnabled: Bool = true) {
        self.seed = seed
        self.random = JavaRandom(seed: seed)
        self.constructionRandom = JavaRandom(seed: seed ^ 0x4d43_454e_5449_5459)
        self.flameRandom = JavaRandom(seed: seed ^ 0x5deec_e66d)
        self.naturalSpawningEnabled = naturalSpawningEnabled
    }

    public mutating func restore(_ restored: [GameEntity]) {
        spatialIndex = nil
        var ids: Set<Int64> = []
        entities = restored.filter { ids.insert($0.id).inserted }
        nextID = max(nextID, (entities.map(\.id).max() ?? 0) + 1)
        let live = Set(entities.map(\.id))
        entityRandoms = entityRandoms.filter { live.contains($0.key) }
    }

    public mutating func reserveIDs(through id: Int64) { nextID = max(nextID, id + 1) }

    public mutating func setEntityRandomSeed(_ seed: Int64, for id: Int64) {
        entityRandoms[id] = JavaRandom(seed: seed)
        if entities.first(where: { $0.id == id })?.kind == "lightningBolt" {
            effectRandoms[id] = JavaRandom(seed: seed)
        }
    }

    mutating func entityRandom(for id: Int64) -> JavaRandom {
        if let generator = entityRandoms[id] { return generator }
        let generator = JavaRandom(seed: constructionRandom.nextLong())
        entityRandoms[id] = generator
        return generator
    }

    @discardableResult
    public mutating func spawn(
        kind: String, position: SIMD3<Double>, velocity: SIMD3<Double> = .zero,
        metadata: UInt8? = nil, fuseTicks: Int? = nil
    ) -> Int64 {
        let callerRandom = random
        let entityID = nextID
        random = JavaRandom(seed: constructionRandom.nextLong())
        defer {
            entityRandoms[entityID] = random
            random = callerRandom
        }
        let components = kind.split(separator: ":")
        var entity = GameEntity(
            id: nextID, kind: String(components.first ?? Substring(kind)), position: position,
            velocity: velocity)
        if entity.kind == "fallingSand", components.count >= 2,
            let id = UInt8(components[1]), let block = BlockKind(rawValue: id)
        {
            entity.fallingBlock = BlockState(
                block, metadata: components.count > 2 ? UInt8(components[2]) ?? 0 : 0)
        }
        nextID += 1
        entity.yaw = constructionRandom.nextFloat() * BetaMath.pi * 2
        if ["boat", "minecart"].contains(entity.kind) {
            entity.vehicleYaw = 0
            entity.yaw = -BetaMath.pi
        }
        if let metadata { entity.metadata = metadata }
        if entity.kind == "primedTnt" {
            if velocity == .zero {
                let angle =
                    Float(constructionRandom.nextDouble() * Double(BetaMath.pi) * 2) * BetaMath.pi / 180
                entity.velocity = SIMD3(
                    Double(-sin(angle) * 0.02), Double(Float(0.2)), Double(-cos(angle) * 0.02))
            }
            if let fuseTicks { entity.fuseTicks = fuseTicks }
        } else if entity.kind == "lightningBolt" {
            entity.effectSeed = random.nextLong()
            entity.lightningFlashes = random.nextInt(bound: 3) + 1
            effectRandoms[entity.id] = random
        } else if entity.kind == "chicken" {
            entity.specialTicks = random.nextInt(bound: 6000) + 6000
        } else if entity.kind == "squid" {
            entity.squidPhaseVelocity = 1 / (random.nextFloat() + 1) * 0.2
        } else if entity.kind == "slime" {
            let size = metadata.map(Int.init) ?? (1 << random.nextInt(bound: 3))
            entity.metadata = UInt8(max(1, size))
            entity.width = Double(Float(0.6) * Float(max(1, size)))
            entity.height = entity.width
            entity.health = max(1, size * size)
            entity.specialTicks = random.nextInt(bound: 20) + 10
        }
        entities.append(entity)
        spatialIndex?.append(EntityCollisionBody(entity))
        return entity.id
    }

    @discardableResult
    public mutating func drop(_ stack: ItemStack, at position: SIMD3<Double>, pickupDelay: Int = 10) -> Int64
    {
        let velocity = SIMD3(
            Double(Float(constructionRandom.nextDouble() * Double(Float(0.2)) - Double(Float(0.1)))),
            Double(Float(0.2)),
            Double(Float(constructionRandom.nextDouble() * Double(Float(0.2)) - Double(Float(0.1)))))
        let id = spawn(
            kind: "item", position: position - SIMD3(0, Double(Float(0.25)) / 2, 0), velocity: velocity)
        entities[entities.count - 1].itemStack = stack
        entities[entities.count - 1].pickupDelay = pickupDelay
        return id
    }

    @discardableResult
    public mutating func drop(
        _ stack: ItemStack, at position: SIMD3<Double>, velocity: SIMD3<Double>, pickupDelay: Int = 10
    ) -> Int64 {
        let id = spawn(
            kind: "item", position: position - SIMD3(0, Double(Float(0.25)) / 2, 0), velocity: velocity)
        entities[entities.count - 1].itemStack = stack
        entities[entities.count - 1].pickupDelay = pickupDelay
        return id
    }

    public mutating func setRidingInput(forward: Float, strafe: Float) {
        ridingInput = SIMD2(strafe, forward)
    }

    public mutating func tick(
        world: inout BlockWorld, player: inout Player, inventory: inout PlayerInventory, time: Int64
    ) -> [BlockEvent] {
        player.isMounted = playerRidingEntityID != nil
        var events = queuedEvents
        queuedEvents.removeAll(keepingCapacity: true)
        spatialIndex = EntitySpatialIndex(entities)
        applyPlayerCollisions(player: &player)
        var scheduledCount = entities.count
        var order = entityTickOrder(count: scheduledCount)
        var cursor = 0
        while cursor < order.count {
            let index = order[cursor]
            cursor += 1
            var entity = entities[index]
            let callerRandom = random
            random = entityRandom(for: entity.id)
            defer {
                entityRandoms[entity.id] = random
                random = callerRandom
                refreshSpatialBody(at: index)
                if entities.count > scheduledCount {
                    order.append(contentsOf: scheduledCount..<entities.count)
                    scheduledCount = entities.count
                }
            }
            entity.previousPosition = entity.position
            entity.previousYaw = entity.yaw
            entity.previousPitch = entity.pitch
            entity.previousBodyYawDegrees = entity.bodyYawDegrees
            let riding = ridingEntityID(for: entity.id) != nil
            if riding { entity.velocity = .zero }
            entity.stepEvents.removeAll(keepingCapacity: true)
            entity.pendingPigFall = nil
            entity.ageTicks += 1
            events += tickEnvironment(&entity, world: world)
            if entity.pickupDelay > 0 { entity.pickupDelay -= 1 }
            if entity.vehicleDamage > 0 { entity.vehicleDamage -= 1 }
            if entity.vehicleHitTicks > 0 { entity.vehicleHitTicks -= 1 }
            if entity.isLiving && entity.health <= 0 {
                if !entity.lootDropped {
                    events += loot(for: entity)
                    entity.lootDropped = true
                }
                entity.deathTicks += 1
                if entity.kind == "slime", entity.deathTicks == 21, entity.health == 0, entity.metadata > 1 {
                    splitSlime(entity)
                }
                if entity.deathTicks > 20 {
                    for _ in 0..<20 {
                        _ = random.nextGaussian()
                        _ = random.nextGaussian()
                        _ = random.nextGaussian()
                        let point =
                            entity.sourcePosition
                            + SIMD3(
                                Double(random.nextFloat() * Float(entity.width) * 2 - Float(entity.width)),
                                Double(random.nextFloat() * Float(entity.height)),
                                Double(random.nextFloat() * Float(entity.width) * 2 - Float(entity.width)))
                        events.append(.particle(name: "explode", position: point))
                    }
                }
                _ = EntityMotion.living(
                    &entity, world: world, forward: 0, jump: false, collisions: collisionView(player: player))
                applyEntityContacts(&entity, player: &player)
                entity.updateBodyYaw()
                entities[index] = entity
                continue
            }
            guard entity.health > 0 else { continue }
            switch entity.kind {
            case "lightningBolt":
                events += tickLightning(&entity, world: &world, player: &player, inventory: &inventory)
            case "fishingHook":
                events += tickFishingHook(&entity, world: world, player: player, inventory: inventory)
            case "painting":
                if entity.ageTicks % 101 == 0 && !paintingFits(entity, world: world) {
                    entity.health = 0
                    entity.lootDropped = true
                    events.append(
                        .dropItem(
                            position: entity.position + SIMD3(0, entity.height / 2, 0),
                            stack: ItemStack(id: 321)))
                }
            case "item": events += tickItem(&entity, world: world, player: player, inventory: &inventory)
            case "primedTnt":
                entity.velocity.y -= Double(Float(0.04))
                _ = EntityMotion.move(&entity, world: world, collisions: collisionView(player: player))
                entity.velocity *= Double(Float(0.98))
                if entity.onGround { entity.velocity *= SIMD3(Double(Float(0.7)), -0.5, Double(Float(0.7))) }
                let expired = entity.fuseTicks <= 0
                entity.fuseTicks -= 1
                if expired {
                    entity.health = 0
                    events.append(
                        explosionEvent(at: entity.position + SIMD3(0, entity.height / 2, 0), power: 4))
                } else {
                    events.append(.particle(name: "smoke", position: entity.position + SIMD3(0, 0.5, 0)))
                }
            case "fallingSand": events += tickFallingBlock(&entity, world: &world)
            case "arrow", "snowball", "egg", "fireball":
                events += tickProjectile(&entity, world: world, player: &player, inventory: &inventory)
            case "boat", "minecart": events += tickVehicle(&entity, world: &world, player: &player)
            default:
                events += tickMob(&entity, world: world, player: &player, inventory: &inventory, time: time)
            }
            if entity.kind == "pig", entity.riderID == 0 {
                player.teleport(to: Self.riderPosition(on: entity, isPlayer: true))
            }
            if riding, let position = mountedPosition(for: entity.id) { entity.position = position }
            if entity.position.y < -64 {
                if entity.isLiving { _ = entity.receiveDamage(4) } else { entity.health = 0 }
            }
            events += damageEffects(&entity)
            events += entity.stepEvents.map { .stepped(at: $0, position: entity.position) }
            if let distance = entity.pendingPigFall { events.append(.pigFall(distance: distance)) }
            if entity.isLiving || ["boat", "minecart"].contains(entity.kind) {
                applyEntityContacts(&entity, player: &player)
            }
            entity.updateBodyYaw()
            entities[index] = entity
        }
        spatialIndex = nil
        let livingCount = entities.count
        entities.removeAll { $0.health <= 0 && (!$0.isLiving || $0.deathTicks > 20) }
        if entities.count != livingCount {
            let live = Set(entities.map(\.id))
            entityRandoms = entityRandoms.filter { live.contains($0.key) }
        }
        player.isMounted = playerRidingEntityID != nil
        if naturalSpawningEnabled { spawnNatural(in: world, near: player, time: time) }
        events += queuedEvents
        queuedEvents.removeAll(keepingCapacity: true)
        return events
    }

    public mutating func attack(
        origin: SIMD3<Double>, direction: SIMD3<Double>, reach: Double = 4, damage: Int,
        world: BlockWorld? = nil
    ) -> Bool {
        guard let hit = nearestEntity(origin: origin, direction: direction, reach: reach),
            entities[hit.index].isLiving
                || ["boat", "minecart", "fireball", "painting"].contains(entities[hit.index].kind)
        else { return false }
        if let world,
            let block = BlockRaycast.hit(in: world, origin: origin, direction: direction, reach: reach),
            block.distance < hit.distance
        {
            return false
        }
        if entities[hit.index].kind == "fireball" {
            let direction = EntityMotion.normalized(direction)
            entities[hit.index].velocity = direction
            entities[hit.index].acceleration = direction * 0.1
            entities[hit.index].projectileOwner = 0
            return true
        }
        let targetID = entities[hit.index].id
        let accepted = hurtEntity(at: hit.index, amount: damage, sourcePosition: origin, sourceID: 0)
        if accepted { alertOwnedWolves(against: targetID, from: origin, defending: false) }
        return accepted
    }

    func nearestEntity(
        origin: SIMD3<Double>, direction: SIMD3<Double>, reach: Double, excluding id: Int64? = nil
    ) -> (index: Int, distance: Double)? {
        let direction = EntityMotion.normalized(direction)
        guard direction != .zero else { return nil }
        var result: (Int, Double)?
        let end = origin + direction * reach
        let area = AxisAlignedBox(
            min: SIMD3(min(origin.x, end.x), min(origin.y, end.y), min(origin.z, end.z)),
            max: SIMD3(max(origin.x, end.x), max(origin.y, end.y), max(origin.z, end.z)))
        for index in contactCandidates(in: area.expanded(by: SIMD3(repeating: 0.1)))
        where entities[index].health > 0 && entities[index].id != id
            && (entities[index].isLiving
                || ["boat", "minecart", "fireball", "primedTnt", "fallingSand", "painting"].contains(
                    entities[index].kind))
        {
            guard
                let hit = entities[index].bounds.expanded(by: SIMD3(repeating: 0.1)).rayIntersection(
                    origin: origin, direction: direction, reach: reach)
            else { continue }
            if result == nil || hit.distance < result!.1 { result = (index, hit.distance) }
        }
        return result
    }

    @discardableResult
    mutating func hurtEntity(
        at index: Int, amount: Int, sourcePosition: SIMD3<Double>, sourceID: Int64? = nil
    ) -> Bool {
        guard entities.indices.contains(index), entities[index].health > 0 else { return false }
        let callerRandom = random
        let entityID = entities[index].id
        random = entityRandom(for: entityID)
        defer {
            entityRandoms[entityID] = random
            random = callerRandom
            refreshSpatialBody(at: index)
        }
        var entity = entities[index]
        var amount = amount
        if entity.kind == "wolf" {
            entity.metadata &= ~1
            if let sourceID, sourceID != 0 { amount = (amount + 1) / 2 }
        }
        entity.idleTicks = 0
        if entity.kind == "painting" {
            entity.health = 0
            entity.lootDropped = true
            queuedEvents.append(
                .dropItem(
                    position: entity.position + SIMD3(0, entity.height / 2, 0), stack: ItemStack(id: 321)))
            entities[index] = entity
            return true
        }
        if !entity.isLiving {
            guard ["boat", "minecart", "item"].contains(entity.kind) else { return false }
            if ["boat", "minecart"].contains(entity.kind) {
                entity.vehicleDamage += amount * 10
                entity.vehicleHitTicks = 10
                entity.vehicleForwardDirection = -entity.vehicleForwardDirection
                if entity.vehicleDamage > 40 { entity.health = 0 }
                if entity.health <= 0 {
                    queuedEvents += loot(for: entity)
                    entity.lootDropped = true
                }
                entities[index] = entity
                return true
            }
            entity.health -= amount
            if entity.health <= 0 {
                queuedEvents += loot(for: entity)
                entity.lootDropped = true
            }
            entities[index] = entity
            return true
        }
        let result = entity.receiveDamage(amount)
        guard result != .ignored else { return false }
        retaliate(&entity, index: index, sourceID: sourceID)
        if result == .full, let sourceID {
            let delta = sourcePosition - entity.sourcePosition
            let length = Double(Float(sqrt(delta.x * delta.x + delta.z * delta.z)))
            entity.attackedAtYaw =
                Float(atan2(delta.z, delta.x) * 180 / Double(BetaMath.pi)) - (entity.yaw + BetaMath.pi) * 180
                / BetaMath.pi
            entity.velocity /= 2
            if length > 0 {
                entity.velocity.x -= delta.x / length * Double(Float(0.4))
                entity.velocity.z -= delta.z / length * Double(Float(0.4))
            }
            entity.velocity.y = min(entity.velocity.y + Double(Float(0.4)), Double(Float(0.4)))
            _ = sourceID
        }
        queuedEvents += damageEffects(&entity)
        if entity.health <= 0 {
            if entity.kind == "creeper", let sourceID,
                entities.contains(where: { $0.id == sourceID && $0.kind == "skeleton" })
            {
                queuedEvents.append(
                    .dropItem(
                        position: entity.position,
                        stack: ItemStack(id: UInt16(2256 + random.nextInt(bound: 2)))))
            }
        }
        entities[index] = entity
        return true
    }

    mutating func loot(for entity: GameEntity) -> [BlockEvent] {
        var stacks: [ItemStack] = []
        func stack(_ id: UInt16, _ count: Int, damage: UInt16 = 0) {
            if count > 0 { stacks.append(ItemStack(id: id, count: count, damage: damage)) }
        }
        switch entity.kind {
        case "painting": stack(321, 1)
        case "pig": stack(entity.fireTicks > 0 ? 320 : 319, random.nextInt(bound: 3))
        case "cow": stack(334, random.nextInt(bound: 3))
        case "chicken", "zombie": stack(288, random.nextInt(bound: 3))
        case "sheep": if entity.metadata & 16 == 0 { stack(35, 1, damage: UInt16(entity.metadata & 15)) }
        case "squid": stack(351, random.nextInt(bound: 3) + 1)
        case "skeleton":
            stack(262, random.nextInt(bound: 3))
            stack(352, random.nextInt(bound: 3))
        case "creeper", "ghast": stack(289, random.nextInt(bound: 3))
        case "spider": stack(287, random.nextInt(bound: 3))
        case "pigZombie": stack(320, random.nextInt(bound: 3))
        case "slime":
            if entity.metadata <= 1 {
                stack(341, random.nextInt(bound: 3))
            }
        case "boat":
            for _ in 0..<3 { stack(5, 1) }
            for _ in 0..<2 { stack(280, 1) }
        case "minecart":
            stack(328, 1)
            if entity.metadata == 1 { stack(54, 1) }
            if entity.metadata == 2 { stack(61, 1) }
            stacks += entity.contents.compactMap { $0 }
        default: break
        }
        return stacks.map { .dropItem(position: entity.sourcePosition, stack: $0) }
    }

    func sound(for kind: String, dead: Bool) -> String {
        switch kind {
        case "pig": dead ? "mob.pigdeath" : "mob.pig"
        case "cow": "mob.cowhurt"
        case "sheep": "mob.sheep"
        case "chicken": "mob.chickenhurt"
        case "zombie": dead ? "mob.zombiedeath" : "mob.zombiehurt"
        case "pigZombie": dead ? "mob.zombiepig.zpigdeath" : "mob.zombiepig.zpighurt"
        case "skeleton": "mob.skeletonhurt"
        case "creeper": dead ? "mob.creeperdeath" : "mob.creeper"
        case "spider": dead ? "mob.spiderdeath" : "mob.spider"
        case "wolf": dead ? "mob.wolf.death" : "mob.wolf.hurt"
        case "ghast": dead ? "mob.ghast.death" : "mob.ghast.scream"
        default: "random.hurt"
        }
    }
}
