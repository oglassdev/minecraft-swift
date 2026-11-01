import Foundation

extension EntitySimulation {
    @discardableResult
    public mutating func shootFromPlayer(kind: String, player: Player, yaw: Float, pitch: Float) -> Int64 {
        let yawAngle = (yaw * 180 / BetaMath.pi + 180) / 180 * BetaMath.pi
        let pitchAngle = (-pitch * 180 / BetaMath.pi) / 180 * BetaMath.pi
        let sine = EntityMotion.sine(yawAngle)
        let cosine = EntityMotion.cosine(yawAngle)
        let scale: Float = GameEntity.canonicalKind(kind) == "arrow" ? 1 : 0.4
        let direction = SIMD3(
            Double(-sine * EntityMotion.cosine(pitchAngle) * scale),
            Double(-EntityMotion.sine(pitchAngle) * scale),
            Double(cosine * EntityMotion.cosine(pitchAngle) * scale))
        let origin =
            player.position
            + SIMD3(
                -Double(cosine * 0.16), Double(Float(1.62)) + Double(Float(0.12)) - Double(Float(0.1)),
                -Double(sine * 0.16))
        return shoot(kind: kind, origin: origin, direction: direction, speed: 1.5, inaccuracy: 1)
    }

    @discardableResult
    public mutating func shoot(
        kind: String, origin: SIMD3<Double>, direction: SIMD3<Double>, speed: Float = 1.5,
        inaccuracy: Float = 1, ownerID: Int64? = 0, randomSeed: Int64? = nil
    ) -> Int64 {
        let id = spawn(kind: kind, position: origin)
        if let randomSeed { setEntityRandomSeed(randomSeed, for: id) }
        let callerRandom = random
        random = entityRandom(for: id)
        defer {
            entityRandoms[id] = random
            random = callerRandom
        }
        if GameEntity.canonicalKind(kind) == "fireball" {
            let aim =
                direction + SIMD3(random.nextGaussian(), random.nextGaussian(), random.nextGaussian()) * 0.4
            let length = Double(Float(sqrt(EntityMotion.squaredLength(aim))))
            update(id: id) {
                $0.projectileOwner = ownerID
                $0.acceleration = length > 0 ? aim / length * 0.1 : .zero
            }
            return id
        }
        if kind == "arrow", let ownerID, entities.first(where: { $0.id == ownerID })?.kind == "skeleton" {
            _ = random.nextGaussian()
            _ = random.nextGaussian()
            _ = random.nextGaussian()
        }
        let length = Double(Float(sqrt(EntityMotion.squaredLength(direction))))
        var direction = length > 0 ? direction / length : .zero
        direction +=
            SIMD3(random.nextGaussian(), random.nextGaussian(), random.nextGaussian()) * Double(Float(0.0075))
            * Double(inaccuracy)
        let velocity = direction * Double(speed)
        update(id: id) {
            $0.projectileOwner = ownerID
            $0.velocity = velocity
            $0.yaw = Float(atan2(velocity.x, -velocity.z))
            $0.pitch = Float(
                atan2(velocity.y, Double(Float(sqrt(velocity.x * velocity.x + velocity.z * velocity.z)))))
            $0.previousYaw = $0.yaw
            $0.previousPitch = $0.pitch
        }
        return id
    }

    mutating func tickProjectile(
        _ entity: inout GameEntity, world: BlockWorld, player: inout Player, inventory: inout PlayerInventory
    ) -> [BlockEvent] {
        var events: [BlockEvent] = []
        if entity.kind == "fireball" { entity.fireTicks = 10 }
        if entity.inGround {
            if let block = entity.stuckBlock, world.state(at: block) != entity.stuckState {
                entity.inGround = false
                entity.velocity *= SIMD3(
                    Double(random.nextFloat() * 0.2), Double(random.nextFloat() * 0.2),
                    Double(random.nextFloat() * 0.2))
                entity.ageTicks = 0
                entity.ticksInGround = 0
            } else {
                entity.ticksInGround += 1
                if entity.ticksInGround >= 1200 { entity.health = 0 }
                if player.health > 0, entity.kind == "arrow", entity.projectileOwner == 0,
                    entity.pickupDelay == 0,
                    entity.bounds.intersects(player.bounds.expanded(by: SIMD3(1, 0, 1))),
                    inventory.insert(ItemStack(id: 262)) == nil
                {
                    entity.health = 0
                    return [.sound(name: "random.pop", position: entity.position, volume: 0.2, pitch: 2)]
                }
                return []
            }
        }
        let distance = sqrt(EntityMotion.squaredLength(entity.velocity))
        let direction = EntityMotion.normalized(entity.velocity)
        let block = BlockRaycast.hit(
            in: world, origin: entity.position, direction: direction, reach: distance,
            collidableOnly: entity.kind == "arrow")
        var target = nearestEntity(
            origin: entity.position, direction: direction, reach: block?.distance ?? distance,
            excluding: entity.id)
        let immunity = entity.kind == "fireball" ? 25 : 5
        if let hit = target, entities[hit.index].id == entity.projectileOwner && entity.ageTicks < immunity {
            target = nil
        }
        let canHitPlayer = entity.projectileOwner != 0 || entity.ageTicks >= immunity
        let playerHit =
            canHitPlayer
            ? player.bounds.expanded(by: SIMD3(repeating: 0.3)).rayIntersection(
                origin: entity.position, direction: direction, reach: block?.distance ?? distance) : nil
        let hitPlayer = playerHit != nil && (target == nil || playerHit!.distance < target!.distance)
        if block != nil || target != nil || hitPlayer {
            let damage = entity.kind == "arrow" ? 4 : 0
            var accepted = true
            if hitPlayer {
                if damage > 0 {
                    let owner = entities.first { $0.id == entity.projectileOwner }
                    let source: PlayerDamageSource =
                        owner.map {
                            ["zombie", "skeleton", "creeper", "spider", "pigZombie"].contains($0.kind)
                        } == true ? .monster : .environment
                    accepted = player.damage(damage, source: source, inventory: &inventory)
                    if accepted, let owner {
                        alertOwnedWolves(against: owner.id, from: player.eyePositionDouble, defending: true)
                    }
                }
            } else if let target {
                accepted = hurtEntity(
                    at: target.index, amount: damage, sourcePosition: entity.position,
                    sourceID: entity.projectileOwner)
            }
            if entity.kind == "arrow", target != nil || hitPlayer {
                if accepted {
                    entity.health = 0
                } else {
                    entity.velocity *= -Double(Float(0.1))
                    entity.yaw += BetaMath.pi
                    entity.ageTicks = 0
                }
                events.append(
                    .sound(
                        name: "random.drr", position: entity.position, volume: 1,
                        pitch: 1.2 / (random.nextFloat() * 0.2 + 0.9)))
                return events
            }
            if entity.kind == "arrow", let block {
                let hitMovement = block.point - entity.position
                updateProjectileAngles(&entity, velocity: hitMovement)
                entity.position = block.point - direction * Double(Float(0.05))
                entity.velocity = SIMD3(
                    Double(Float(hitMovement.x)), Double(Float(hitMovement.y)), Double(Float(hitMovement.z)))
                entity.velocity *= Double(Float(0.99))
                entity.velocity.y -= Double(Float(0.03))
                entity.inGround = true
                entity.stuckBlock = block.position
                entity.stuckState = world.state(at: block.position)
                entity.pickupDelay = 7
                events.append(
                    .sound(
                        name: "random.drr", position: entity.position, volume: 1,
                        pitch: 1.2 / (random.nextFloat() * 0.2 + 0.9)))
                return events
            }
            if entity.kind == "fireball" {
                events.append(explosionEvent(at: entity.position, power: 1, ignitesFire: true))
            } else {
                for _ in 0..<8 { events.append(.particle(name: "snowballpoof", position: entity.position)) }
                if entity.kind == "egg", random.nextInt(bound: 8) == 0 {
                    let count = random.nextInt(bound: 32) == 0 ? 4 : 1
                    for _ in 0..<count { spawn(kind: "chicken", position: entity.position) }
                }
            }
            entity.health = 0
            return events
        }
        entity.position += entity.velocity
        updateProjectileAngles(&entity, velocity: entity.velocity)
        let water = EntityMotion.isFluid(in: world, bounds: entity.bounds, water: true)
        if entity.kind == "fireball" {
            entity.velocity =
                (entity.velocity + entity.acceleration) * Double(water ? Float(0.8) : Float(0.95))
            events.append(.particle(name: "smoke", position: entity.position))
        } else {
            entity.velocity *= Double(water ? Float(0.8) : Float(0.99))
            entity.velocity.y -= Double(Float(0.03))
        }
        return events
    }

    private func updateProjectileAngles(_ entity: inout GameEntity, velocity: SIMD3<Double>) {
        let horizontal = Double(Float(sqrt(velocity.x * velocity.x + velocity.z * velocity.z)))
        let yaw = Float(atan2(velocity.x, -velocity.z))
        let pitch = Float(atan2(velocity.y, horizontal))
        while yaw - entity.previousYaw < -BetaMath.pi { entity.previousYaw -= 2 * BetaMath.pi }
        while yaw - entity.previousYaw >= BetaMath.pi { entity.previousYaw += 2 * BetaMath.pi }
        while pitch - entity.previousPitch < -BetaMath.pi { entity.previousPitch -= 2 * BetaMath.pi }
        while pitch - entity.previousPitch >= BetaMath.pi { entity.previousPitch += 2 * BetaMath.pi }
        entity.yaw = entity.previousYaw + (yaw - entity.previousYaw) * 0.2
        entity.pitch = entity.previousPitch + (pitch - entity.previousPitch) * 0.2
    }
}
