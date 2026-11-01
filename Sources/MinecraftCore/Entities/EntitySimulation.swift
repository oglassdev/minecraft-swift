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
    var queuedEvents: [BlockEvent] = []
    var ridingInput = SIMD2<Float>.zero
    var effectRandoms: [Int64: JavaRandom] = [:]
    var explosionContexts: [ExplosionContext] = []
    var flameRandom: JavaRandom
    var spawnSetWarmed = false
    private var nextID: Int64 = 1
    public var nextEntityID: Int64 { nextID }
    public var playerRidingEntityID: Int64? { entities.first { $0.riderID == 0 && $0.health > 0 }?.id }

    public init(seed: Int64, naturalSpawningEnabled: Bool = true) {
        self.seed = seed
        self.random = JavaRandom(seed: seed)
        self.flameRandom = JavaRandom(seed: seed ^ 0x5deec_e66d)
        self.naturalSpawningEnabled = naturalSpawningEnabled
    }

    public mutating func restore(_ restored: [GameEntity]) {
        var ids: Set<Int64> = []
        entities = restored.filter { ids.insert($0.id).inserted }
        nextID = max(nextID, (entities.map(\.id).max() ?? 0) + 1)
    }

    public mutating func reserveIDs(through id: Int64) { nextID = max(nextID, id + 1) }

    @discardableResult
    public mutating func spawn(
        kind: String, position: SIMD3<Double>, velocity: SIMD3<Double> = .zero,
        metadata: UInt8? = nil, fuseTicks: Int? = nil
    ) -> Int64 {
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
        entity.yaw = random.nextFloat() * BetaMath.pi * 2
        if let metadata { entity.metadata = metadata }
        if entity.kind == "primedTnt" {
            if velocity == .zero {
                let angle = Float(random.nextDouble() * Double(BetaMath.pi) * 2) * BetaMath.pi / 180
                entity.velocity = SIMD3(
                    Double(-sin(angle) * 0.02), Double(Float(0.2)), Double(-cos(angle) * 0.02))
            }
            if let fuseTicks { entity.fuseTicks = fuseTicks }
        } else if entity.kind == "lightningBolt" {
            var effectRandom = JavaRandom(seed: random.nextLong())
            entity.effectSeed = effectRandom.nextLong()
            entity.lightningFlashes = effectRandom.nextInt(bound: 3) + 1
            effectRandoms[entity.id] = effectRandom
        } else if entity.kind == "squid" {
            entity.squidPhaseVelocity = 1 / (random.nextFloat() + 1) * 0.2
        } else if entity.kind == "slime" {
            let size = metadata.map(Int.init) ?? (1 << random.nextInt(bound: 3))
            entity.metadata = UInt8(max(1, size))
            entity.width = Double(Float(0.6) * Float(max(1, size)))
            entity.height = entity.width
            entity.health = max(1, size * size)
            entity.specialTicks = random.nextInt(bound: 20) + 10
        } else if entity.kind == "sheep", metadata == nil {
            let color = random.nextInt(bound: 100)
            if color < 5 {
                entity.metadata = 15
            } else if color < 10 {
                entity.metadata = 7
            } else if color < 15 {
                entity.metadata = 8
            } else {
                entity.metadata = random.nextInt(bound: 500) == 0 ? 6 : 0
            }
        }
        entities.append(entity)
        return entity.id
    }

    @discardableResult
    public mutating func drop(_ stack: ItemStack, at position: SIMD3<Double>, pickupDelay: Int = 10) -> Int64
    {
        let velocity = SIMD3(
            Double(Float(random.nextDouble() * Double(Float(0.2)) - Double(Float(0.1)))),
            Double(Float(0.2)), Double(Float(random.nextDouble() * Double(Float(0.2)) - Double(Float(0.1)))))
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
        let count = entities.count
        for index in 0..<count {
            var entity = entities[index]
            entity.previousPosition = entity.position
            entity.stepEvents.removeAll(keepingCapacity: true)
            entity.pendingPigFall = nil
            entity.ageTicks += 1
            if entity.attackCooldown > 0 { entity.attackCooldown -= 1 }
            if entity.pickupDelay > 0 { entity.pickupDelay -= 1 }
            if entity.hurtTicks > 0 { entity.hurtTicks -= 1 }
            if entity.isLiving && entity.health <= 0 {
                if !entity.lootDropped {
                    events += loot(for: entity)
                    entity.lootDropped = true
                }
                entity.deathTicks += 1
                if entity.kind == "slime", entity.deathTicks == 20, entity.health == 0, entity.metadata > 1 {
                    splitSlime(entity)
                }
                entity.velocity.y -= 0.08
                _ = EntityMotion.move(&entity, world: world)
                entity.velocity *= SIMD3(0.91, Double(Float(0.98)), 0.91)
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
                    events.append(
                        .dropItem(
                            position: entity.position + SIMD3(0, entity.height / 2, 0),
                            stack: ItemStack(id: 321)))
                }
            case "item": events += tickItem(&entity, world: world, player: player, inventory: &inventory)
            case "primedTnt":
                entity.velocity.y -= Double(Float(0.04))
                _ = EntityMotion.move(&entity, world: world)
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
            case "boat", "minecart": events += tickVehicle(&entity, world: world, player: &player)
            default:
                events += tickMob(&entity, world: world, player: &player, inventory: &inventory, time: time)
            }
            if entity.kind == "pig", entity.riderID == 0 {
                player.teleport(to: entity.position + SIMD3(0, entity.height * 0.75 - 0.5, 0))
            }
            if entity.position.y < -64 { entity.health = 0 }
            events += entity.stepEvents.map { .stepped(at: $0, position: entity.position) }
            if let distance = entity.pendingPigFall { events.append(.pigFall(distance: distance)) }
            entities[index] = entity
        }
        entities.removeAll { $0.health <= 0 && (!$0.isLiving || $0.deathTicks >= 20) }
        player.isMounted = playerRidingEntityID != nil
        pushNearbyEntities(player: &player)
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
        for index in entities.indices
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
        var entity = entities[index]
        var amount = amount
        if entity.kind == "wolf" {
            entity.metadata &= ~1
            if let sourceID, sourceID != 0 { amount = (amount + 1) / 2 }
        }
        entity.idleTicks = 0
        if entity.kind == "painting" {
            entity.health = 0
            queuedEvents.append(
                .dropItem(
                    position: entity.position + SIMD3(0, entity.height / 2, 0), stack: ItemStack(id: 321)))
            entities[index] = entity
            return true
        }
        if !entity.isLiving {
            entity.health -= amount
            if entity.health <= 0 {
                queuedEvents += loot(for: entity)
                entity.lootDropped = true
            }
            entities[index] = entity
            return true
        }
        if entity.hurtTicks > 10 {
            guard amount > entity.lastDamage else { return false }
            entity.health -= amount - entity.lastDamage
        } else {
            entity.health -= amount
            entity.hurtTicks = 20
        }
        entity.lastDamage = amount
        retaliate(&entity, index: index, sourceID: sourceID)
        let away = EntityMotion.normalized(
            SIMD3(entity.position.x - sourcePosition.x, 0, entity.position.z - sourcePosition.z))
        entity.velocity = entity.velocity / 2 + away * Double(Float(0.4))
        entity.velocity.y = min(entity.velocity.y + Double(Float(0.4)), Double(Float(0.4)))
        queuedEvents.append(
            .sound(
                name: sound(for: entity.kind, dead: entity.health <= 0), position: entity.position, volume: 1,
                pitch: 1))
        if entity.health <= 0 {
            queuedEvents += loot(for: entity)
            entity.lootDropped = true
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
            stack(5, 3)
            stack(280, 2)
        case "minecart":
            stack(328, 1)
            if entity.metadata == 1 { stack(54, 1) }
            if entity.metadata == 2 { stack(61, 1) }
            stacks += entity.contents.compactMap { $0 }
        default: break
        }
        return stacks.map { .dropItem(position: entity.position, stack: $0) }
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
