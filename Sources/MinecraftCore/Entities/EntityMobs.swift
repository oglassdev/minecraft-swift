import Foundation

extension EntitySimulation {
    mutating func tickMob(
        _ entity: inout GameEntity, world: BlockWorld, player: inout Player,
        inventory: inout PlayerInventory, time: Int64
    ) -> [BlockEvent] {
        guard entity.isLiving else { return [] }
        var events: [BlockEvent] = []
        if entity.kind == "pigZombie", entity.specialTicks > 0 {
            entity.specialTicks -= 1
            if entity.specialTicks == 0 {
                events.append(
                    .sound(
                        name: "mob.zombiepig.zpigangry", position: entity.position, volume: 2,
                        pitch: ((random.nextFloat() - random.nextFloat()) * 0.2 + 1) * 1.8))
            }
        }
        if player.difficulty == 0
            && ["zombie", "pigZombie", "skeleton", "creeper", "spider", "ghast"].contains(entity.kind)
        {
            entity.health = 0
            entity.lootDropped = true
            entity.deathTicks = 21
            return []
        }
        if entity.kind == "ghast" { return tickGhast(&entity, world: world, player: player) }
        if entity.kind == "squid" { return tickSquid(&entity, world: world) }
        let cell = BlockPosition(
            Int(floor(entity.position.x)), Int(floor(entity.position.y + entity.height * 0.66)),
            Int(floor(entity.position.z)))
        let brightness = EntityMotion.brightness(
            light: EntityMotion.light(
                in: world, position: cell, time: time, rain: rainStrength, thunder: thunderStrength),
            dimension: world.dimension)
        let day =
            EntityMotion.skyDarkening(
                time: time, dimension: world.dimension, rain: rainStrength, thunder: thunderStrength) < 4
        let localPlayer = livingTarget(id: 0, player: player)!
        let playerDistance = Float(sqrt(EntityMotion.squaredLength(localPlayer.position - entity.position)))
        let hadTarget = entity.targetEntityID != nil
        if entity.targetEntityID == nil, entity.isHostile, playerDistance < 16, player.health > 0,
            entity.kind == "spider"
                ? brightness < 0.5
                : (entity.kind == "wolf" || canSee(entity, target: localPlayer, world: world))
        {
            entity.targetEntityID = 0
        } else if let target = livingTarget(id: entity.targetEntityID, player: player), target.health <= 0 {
            entity.targetEntityID = nil
        } else if entity.targetEntityID != nil
            && livingTarget(id: entity.targetEntityID, player: player) == nil
        {
            entity.targetEntityID = nil
        }
        if ["zombie", "skeleton"].contains(entity.kind), day, brightness > 0.5,
            EntityMotion.skyVisible(in: world, position: entity.position),
            random.nextFloat() * 30 < (brightness - 0.4) * 2
        {
            entity.fireTicks = 300
        }
        let water = (touching: entity.isInWater, acceleration: SIMD3<Double>.zero)
        guard entity.health > 0 else { return events }
        if entity.kind == "slime" {
            return events
                + tickSlime(
                    &entity, world: world, player: &player, inventory: &inventory,
                    visible: canSee(entity, target: localPlayer, world: world))
        }
        var attacking = entity.kind == "wolf" && (entity.metadata & 1 != 0 || entity.wolfShaking)
        var target = livingTarget(id: entity.targetEntityID, player: player)
        if hadTarget, let victim = target, victim.health > 0, canSee(entity, target: victim, world: world) {
            let distance = Float(sqrt(EntityMotion.squaredLength(victim.position - entity.position)))
            switch entity.kind {
            case "creeper":
                if distance < (entity.fuseTicks > 0 ? 7 : 3) {
                    if entity.fuseTicks == 0 {
                        events.append(
                            .sound(name: "random.fuse", position: entity.position, volume: 1, pitch: 0.5))
                    }
                    entity.fuseTicks += 1
                    attacking = true
                    if entity.fuseTicks >= 30 {
                        entity.health = 0
                        entity.lootDropped = true
                        entity.deathTicks = 21
                        events.append(
                            explosionEvent(
                                at: entity.position, power: entity.metadata & 1 == 0 ? 3 : 6, source: .monster
                            ))
                        return events
                    }
                } else {
                    entity.fuseTicks = max(0, entity.fuseTicks - 1)
                }
            case "skeleton":
                if distance < 10 {
                    let delta = victim.position - entity.position
                    if entity.attackCooldown == 0 {
                        let angle = (entity.yaw * 180 / BetaMath.pi + 180) / 180 * BetaMath.pi
                        let origin =
                            entity.eyePosition
                            + SIMD3(
                                -Double(EntityMotion.cosine(angle) * 0.16),
                                -Double(Float(0.1)) + Double(Float(1.4)),
                                -Double(EntityMotion.sine(angle) * 0.16))
                        let arc = Double(Float(sqrt(delta.x * delta.x + delta.z * delta.z)) * 0.2)
                        events.append(
                            .sound(
                                name: "random.bow", position: entity.position, volume: 1,
                                pitch: 1 / (random.nextFloat() * 0.4 + 0.8)))
                        shoot(
                            kind: "arrow", origin: origin,
                            direction: SIMD3(
                                delta.x, victim.eye.y - Double(Float(0.2)) - origin.y + arc, delta.z),
                            speed: 0.6, inaccuracy: 12, ownerID: entity.id)
                        entity.attackCooldown = 30
                    }
                    entity.yaw = Float(atan2(delta.x, -delta.z))
                    attacking = true
                }
            case "spider", "wolf":
                if entity.kind == "spider", brightness > 0.5, random.nextInt(bound: 100) == 0 {
                    entity.targetEntityID = nil
                    target = nil
                } else if distance > 2 && distance < 6 && random.nextInt(bound: 10) == 0 {
                    if entity.onGround { EntityMotion.pounce(&entity, toward: victim.position) }
                } else if distance < (entity.kind == "wolf" ? 1.5 : 2),
                    entity.kind == "wolf" || entity.attackCooldown == 0,
                    victim.bounds.max.y > entity.bounds.min.y, victim.bounds.min.y < entity.bounds.max.y
                {
                    entity.attackCooldown = 20
                    _ = melee(
                        &entity, target: victim, amount: entity.kind == "wolf" && entity.owner != nil ? 4 : 2,
                        player: &player, inventory: &inventory)
                }
            default:
                if distance < 2, entity.attackCooldown == 0, victim.bounds.max.y > entity.bounds.min.y,
                    victim.bounds.min.y < entity.bounds.max.y
                {
                    entity.attackCooldown = 20
                    _ = melee(
                        &entity, target: victim,
                        amount: ["zombie", "pigZombie"].contains(entity.kind) ? 5 : 2, player: &player,
                        inventory: &inventory)
                }
            }
        } else if entity.kind == "creeper", hadTarget {
            entity.fuseTicks = max(0, entity.fuseTicks - 1)
        }
        entity.targetPosition = target?.feet
        if !hadTarget, let target {
            entity.path = BetaPathfinder.path(in: world, entity: entity, toward: target.feet)
            entity.pathIndex = 0
        }
        if entity.kind == "wolf", water.touching {
            entity.metadata &= ~1
            attacking = entity.wolfShaking
        }
        let movement = creatureMovement(
            &entity, world: world, player: player, time: time, attacking: attacking,
            sitting: entity.kind == "wolf" && entity.metadata & 1 != 0, combatTarget: target)
        if entity.kind == "wolf" {
            events += wolfBehavior(
                &entity, world: world, player: player, attacking: attacking, water: water.touching,
                inventory: inventory)
        }
        _ = EntityMotion.living(
            &entity, world: world, forward: movement.forward, strafe: movement.strafe, jump: movement.jump,
            collisions: collisionView())
        if entity.kind == "wolf" { events += wolfEffects(&entity, world: world, water: water.touching) }
        if entity.kind == "chicken" {
            entity.updateChickenWings()
            entity.specialTicks -= 1
            if entity.specialTicks <= 0 {
                events.append(
                    .sound(
                        name: "mob.chickenplop", position: entity.position, volume: 1,
                        pitch: (random.nextFloat() - random.nextFloat()) * 0.2 + 1))
                events.append(.dropItem(position: entity.position, stack: ItemStack(id: 344)))
                entity.specialTicks = random.nextInt(bound: 6000) + 6000
            }
        }
        return events
    }

    mutating func tickGhast(_ entity: inout GameEntity, world: BlockWorld, player: Player)
        -> [BlockEvent]
    {
        var events: [BlockEvent] = []
        let goal = entity.targetPosition ?? .zero
        let delta = goal - entity.position
        let distance = Double(Float(sqrt(EntityMotion.squaredLength(delta))))
        if distance < 1 || distance > 60 {
            entity.targetPosition =
                entity.position
                + SIMD3(
                    Double((random.nextFloat() * 2 - 1) * 16), Double((random.nextFloat() * 2 - 1) * 16),
                    Double((random.nextFloat() * 2 - 1) * 16))
        }
        let expired = entity.movementCooldown <= 0
        entity.movementCooldown -= 1
        if expired {
            entity.movementCooldown += random.nextInt(bound: 5) + 2
            var clear = distance > 0
            if distance > 0 {
                let step = (entity.targetPosition ?? goal) - entity.position
                var bounds = entity.bounds
                var count = 1
                while Double(count) < distance {
                    bounds = bounds.offset(by: step / distance)
                    if !BlockCollision.boxes(in: world, intersecting: bounds).isEmpty {
                        clear = false
                        break
                    }
                    count += 1
                }
                if clear { entity.velocity += delta / distance * 0.1 }
            }
            if !clear { entity.targetPosition = entity.position }
        }
        if player.health <= 0 { entity.targetEntityID = nil }
        let refresh = entity.targetRefreshTicks <= 0
        if entity.targetEntityID != nil { entity.targetRefreshTicks -= 1 }
        let playerDelta = player.position + SIMD3(0, Double(Float(1.62)), 0) - entity.position
        let playerDistance = EntityMotion.squaredLength(playerDelta)
        if entity.targetEntityID == nil || refresh {
            if player.health > 0 && playerDistance < 10000 {
                entity.targetEntityID = 0
                entity.targetRefreshTicks = 20
            }
        }
        if entity.targetEntityID == 0 && playerDistance < 4096 {
            let aim =
                player.position + SIMD3(0, Player.height / 2, 0)
                - (entity.position + SIMD3(0, entity.height / 2, 0))
            entity.yaw = -Float(atan2(aim.x, aim.z)) - BetaMath.pi
            let vision =
                player.position + SIMD3(0, Double(Float(1.62)) + Double(Float(0.12)), 0)
                - (entity.position + SIMD3(0, Double(Float(entity.height) * 0.85), 0))
            if BlockRaycast.hit(
                in: world, origin: entity.position + SIMD3(0, Double(Float(entity.height) * 0.85), 0),
                direction: vision, reach: sqrt(EntityMotion.squaredLength(vision))) == nil
            {
                if entity.specialTicks == 10 {
                    events.append(
                        .sound(
                            name: "mob.ghast.charge", position: entity.position, volume: 10,
                            pitch: (random.nextFloat() - random.nextFloat()) * 0.2 + 1))
                }
                entity.specialTicks += 1
                if entity.specialTicks == 20 {
                    events.append(
                        .sound(
                            name: "mob.ghast.fireball", position: entity.position, volume: 10,
                            pitch: (random.nextFloat() - random.nextFloat()) * 0.2 + 1))
                    let direction = SIMD3(
                        Double(sin(entity.yaw) * cos(entity.pitch)), Double(sin(entity.pitch)),
                        Double(-cos(entity.yaw) * cos(entity.pitch)))
                    let origin =
                        entity.position + SIMD3(direction.x * 4, entity.height / 2 + 0.5, direction.z * 4)
                    shoot(
                        kind: "fireball", origin: origin, direction: aim, speed: 1, inaccuracy: 0,
                        ownerID: entity.id)
                    entity.specialTicks = -40
                }
            } else if entity.specialTicks > 0 {
                entity.specialTicks -= 1
            }
        } else {
            entity.yaw = -Float(atan2(entity.velocity.x, entity.velocity.z)) - BetaMath.pi
            if entity.specialTicks > 0 { entity.specialTicks -= 1 }
        }
        entity.metadata = entity.specialTicks > 10 ? 1 : 0
        let water = EntityMotion.isFluid(in: world, bounds: entity.bounds, water: true)
        let lava = EntityMotion.isFluid(in: world, bounds: entity.bounds, water: false)
        var friction: Float = 0.91
        if entity.onGround {
            let cell = BlockPosition(
                Int(floor(entity.position.x)), Int(floor(entity.position.y)) - 1,
                Int(floor(entity.position.z)))
            friction = (world[cell] == .ice ? Float(0.98) : Float(0.6)) * 0.91
        }
        _ = EntityMotion.move(&entity, world: world, collisions: collisionView())
        entity.velocity *= water ? Double(Float(0.8)) : (lava ? 0.5 : Double(friction))
        entity.updateLimbSwing()
        return events
    }

    mutating func tickSquid(_ entity: inout GameEntity, world: BlockWorld) -> [BlockEvent] {
        let baseContact = FluidPhysics.waterContact(
            in: world, bounds: entity.bounds.expanded(by: SIMD3(-0.001, -Double(Float(0.4)) - 0.001, -0.001)))
        entity.velocity += baseContact.acceleration
        if random.nextInt(bound: 50) == 0 || !baseContact.touching || entity.squidDirection == .zero {
            let angle = random.nextFloat() * BetaMath.pi * 2
            entity.squidDirection = SIMD3(
                EntityMotion.cosine(angle) * 0.2, -0.1 + random.nextFloat() * 0.2,
                EntityMotion.sine(angle) * 0.2)
        }
        entity.velocity +=
            FluidPhysics.waterContact(
                in: world, bounds: entity.bounds.expanded(by: SIMD3(0, -Double(Float(0.6)), 0))
            ).acceleration
        _ = EntityMotion.move(&entity, world: world, collisions: collisionView())
        entity.squidPhase += entity.squidPhaseVelocity
        if entity.squidPhase > Float(Double.pi * 2) {
            entity.squidPhase -= Float(Double.pi * 2)
            if random.nextInt(bound: 10) == 0 {
                entity.squidPhaseVelocity = 1 / (random.nextFloat() + 1) * 0.2
            }
        }
        let water = FluidPhysics.waterContact(
            in: world, bounds: entity.bounds.expanded(by: SIMD3(0, -Double(Float(0.6)), 0)))
        if water.touching {
            if entity.squidPhase < BetaMath.pi {
                let fraction = entity.squidPhase / BetaMath.pi
                entity.squidTentacleAngle =
                    EntityMotion.sine(fraction * fraction * BetaMath.pi) * BetaMath.pi * 0.25
                if fraction > 0.75 {
                    entity.squidPropulsion = 1
                    entity.squidRotationSpeed = 1
                } else {
                    entity.squidRotationSpeed *= 0.8
                }
            } else {
                entity.squidTentacleAngle = 0
                entity.squidPropulsion *= 0.9
                entity.squidRotationSpeed *= 0.99
            }
            entity.velocity = SIMD3<Double>(entity.squidDirection * entity.squidPropulsion)
            let horizontal = Float(
                sqrt(entity.velocity.x * entity.velocity.x + entity.velocity.z * entity.velocity.z))
            let yaw = -Float(atan2(entity.velocity.x, entity.velocity.z)) * 180 / BetaMath.pi
            entity.squidYaw += (yaw - entity.squidYaw) * 0.1
            entity.yaw = entity.squidYaw * BetaMath.pi / 180 - BetaMath.pi
            entity.squidBodyRotation += BetaMath.pi * entity.squidRotationSpeed * 1.5
            entity.squidBodyPitch +=
                (-Float(atan2(Double(horizontal), entity.velocity.y)) * 180 / BetaMath.pi
                    - entity.squidBodyPitch) * 0.1
        } else {
            entity.squidTentacleAngle = abs(EntityMotion.sine(entity.squidPhase)) * BetaMath.pi * 0.25
            entity.velocity.x = 0
            entity.velocity.y = (entity.velocity.y - 0.08) * Double(Float(0.98))
            entity.velocity.z = 0
            entity.squidBodyPitch = Float(
                Double(entity.squidBodyPitch) + Double(-90 - entity.squidBodyPitch) * 0.02)
        }
        entity.pitch = entity.squidBodyPitch * BetaMath.pi / 180
        return []
    }
}
