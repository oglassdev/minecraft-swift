import Foundation

extension EntitySimulation {
    @discardableResult
    public mutating func castFishingHook(ownerID: Int64 = 0, origin: SIMD3<Double>, direction: SIMD3<Double>)
        -> Int64
    {
        let id = shoot(
            kind: "fishingHook", origin: origin, direction: direction, speed: 1.5, inaccuracy: 1,
            ownerID: ownerID)
        return id
    }

    @discardableResult
    public mutating func retrieveFishingHook(ownerID: Int64 = 0, player: Player) -> Int {
        guard
            let index = entities.firstIndex(where: {
                $0.kind == "fishingHook" && $0.projectileOwner == ownerID && $0.health > 0
            })
        else { return 0 }
        let hook = entities[index]
        let ownerPosition =
            ownerID == 0
            ? player.position + SIMD3(0, Double(Float(1.62)), 0)
            : (entities.first { $0.id == ownerID }?.position ?? player.position)
        let delta = ownerPosition - hook.position
        let distance = Double(Float(sqrt(EntityMotion.squaredLength(delta))))
        let impulse = delta * 0.1 + SIMD3(0, Double(Float(sqrt(distance))) * 0.08, 0)
        var wear = 0
        if let targetID = hook.hookedEntityID,
            let target = entities.firstIndex(where: { $0.id == targetID && $0.health > 0 })
        {
            entities[target].velocity += impulse
            wear = 3
        } else if hook.biteTicks > 0 {
            let id = drop(ItemStack(id: 349), at: hook.position, pickupDelay: 0)
            update(id: id) { $0.velocity = impulse }
            queuedEvents.append(.fishCaught)
            wear = 1
        }
        if hook.inGround { wear = 2 }
        remove(ids: [hook.id])
        return wear
    }

    mutating func tickFishingHook(
        _ hook: inout GameEntity, world: BlockWorld, player: Player, inventory: PlayerInventory
    ) -> [BlockEvent] {
        let ownerPosition: SIMD3<Double>
        if hook.projectileOwner == 0 {
            ownerPosition = player.position + SIMD3(0, Double(Float(1.62)), 0)
            guard player.health > 0, inventory.selectedStack?.id == 346 else {
                hook.health = 0
                return []
            }
        } else if let owner = entities.first(where: { $0.id == hook.projectileOwner && $0.health > 0 }) {
            ownerPosition = owner.position
        } else {
            hook.health = 0
            return []
        }
        guard EntityMotion.squaredLength(hook.position - ownerPosition) <= 1024 else {
            hook.health = 0
            return []
        }
        if let targetID = hook.hookedEntityID {
            if targetID == 0, player.health > 0 {
                hook.position = player.position + SIMD3(0, Player.height * 0.8, 0)
                return []
            }
            if let target = entities.first(where: { $0.id == targetID && $0.health > 0 }) {
                hook.position = target.position + SIMD3(0, target.height * 0.8, 0)
                return []
            }
            hook.hookedEntityID = nil
        }
        if hook.inGround {
            let cell = hook.stuckBlock ?? BlockPosition(-1, -1, -1)
            if world[cell] == hook.stuckState?.kind {
                hook.ticksInGround += 1
                if hook.ticksInGround == 1200 { hook.health = 0 }
                return []
            }
            hook.inGround = false
            hook.velocity *= SIMD3(
                Double(random.nextFloat() * 0.2), Double(random.nextFloat() * 0.2),
                Double(random.nextFloat() * 0.2))
            hook.ticksInGround = 0
        }
        let distance = sqrt(EntityMotion.squaredLength(hook.velocity))
        let direction = EntityMotion.normalized(hook.velocity)
        let block = BlockRaycast.hit(in: world, origin: hook.position, direction: direction, reach: distance)
        if let target = nearestEntity(
            origin: hook.position, direction: direction, reach: block?.distance ?? distance,
            excluding: hook.id), entities[target.index].id != hook.projectileOwner || hook.ageTicks >= 5
        {
            if hurtEntity(
                at: target.index, amount: 0, sourcePosition: ownerPosition, sourceID: hook.projectileOwner)
            {
                hook.hookedEntityID = entities[target.index].id
            }
        } else if block != nil {
            hook.inGround = true
            return []
        }
        let collided = EntityMotion.move(&hook, world: world, collisions: collisionView())
        let horizontal = Double(
            Float(sqrt(hook.velocity.x * hook.velocity.x + hook.velocity.z * hook.velocity.z)))
        let yaw = Float(atan2(hook.velocity.x, -hook.velocity.z))
        let pitch = Float(atan2(hook.velocity.y, horizontal))
        hook.yaw += (yaw - hook.yaw).remainder(dividingBy: BetaMath.pi * 2) * 0.2
        hook.pitch += (pitch - hook.pitch).remainder(dividingBy: BetaMath.pi * 2) * 0.2
        var drag: Float = hook.onGround || collided ? 0.5 : 0.92
        var submerged = 0.0
        for layer in 0..<5 {
            let bounds = AxisAlignedBox(
                min: SIMD3(
                    hook.bounds.min.x, hook.bounds.min.y + hook.height * Double(layer) / 5, hook.bounds.min.z),
                max: SIMD3(
                    hook.bounds.max.x, hook.bounds.min.y + hook.height * Double(layer + 1) / 5,
                    hook.bounds.max.z))
            if fishingWater(in: world, bounds: bounds) { submerged += 0.2 }
        }
        var events: [BlockEvent] = []
        if submerged > 0 {
            if hook.biteTicks > 0 {
                hook.biteTicks -= 1
            } else {
                let exposed =
                    rainStrength > 0.2
                    && EntityMotion.skyVisible(in: world, position: hook.position + SIMD3(0, 1, 0))
                if random.nextInt(bound: exposed ? 300 : 500) == 0 {
                    hook.biteTicks = random.nextInt(bound: 30) + 10
                    hook.velocity.y -= Double(Float(0.2))
                    events.append(
                        .sound(
                            name: "random.splash", position: hook.position, volume: 0.25,
                            pitch: 1 + (random.nextFloat() - random.nextFloat()) * 0.4))
                    for _ in 0..<6 {
                        let x = Double((random.nextFloat() * 2 - 1) * Float(hook.width))
                        let z = Double((random.nextFloat() * 2 - 1) * Float(hook.width))
                        events.append(
                            .particle(
                                name: "bubble",
                                position: SIMD3(
                                    hook.position.x + x, floor(hook.bounds.min.y) + 1, hook.position.z + z)))
                        _ = random.nextFloat()
                    }
                    for _ in 0..<6 {
                        let x = Double((random.nextFloat() * 2 - 1) * Float(hook.width))
                        let z = Double((random.nextFloat() * 2 - 1) * Float(hook.width))
                        events.append(
                            .particle(
                                name: "splash",
                                position: SIMD3(
                                    hook.position.x + x, floor(hook.bounds.min.y) + 1, hook.position.z + z)))
                    }
                }
            }
        }
        if hook.biteTicks > 0 {
            hook.velocity.y -=
                Double(random.nextFloat()) * Double(random.nextFloat()) * Double(random.nextFloat()) * 0.2
        }
        hook.velocity.y += Double(Float(0.04)) * (submerged * 2 - 1)
        if submerged > 0 {
            drag = Float(Double(drag) * 0.9)
            hook.velocity.y *= 0.8
        }
        hook.velocity *= Double(drag)
        return events
    }

    private func fishingWater(in world: BlockWorld, bounds: AxisAlignedBox) -> Bool {
        for x in Int(floor(bounds.min.x))...Int(floor(bounds.max.x)) {
            for y in Int(floor(bounds.min.y))...Int(floor(bounds.max.y)) {
                for z in Int(floor(bounds.min.z))...Int(floor(bounds.max.z)) {
                    guard let state = world.state(at: BlockPosition(x, y, z)),
                        state.kind == .water || state.kind == .stillWater
                    else { continue }
                    let surface = Double(y + 1) - (state.metadata < 8 ? Double(state.metadata) / 8 : 0)
                    if surface >= bounds.min.y { return true }
                }
            }
        }
        return false
    }
}
